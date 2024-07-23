#!/usr/bin/env tclsh
# @file
#   Copyright 2018-2024 The University of Birmingham
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.


# Launch Xilinx Vivado or ISE implementation and possibly write bitstream in text mode

#parsing command options
set parameters {
  {no_bitstream    "If set, the bitstream file will not be produced."}
  {recreate        "If set, the project will be re-created if it already exists."}
  {no_reset        "If set, runs (synthesis and implementation) won't be reset before launching them."}
  {check_syntax    "If set, the HDL syntax will be checked at the beginning of the workflow."}
  {njobs.arg 4     "Number of jobs. Default: 4"}
  {ext_path.arg "" "Sets the absolute path for the external libraries."}
  {lib.arg  "" "Compiled simulation library path"}
  {synth_only      "If set, only the synthesis will be performed."}
  {impl_only       "If set, only the implementation will be performed. This assumes synthesis should was already done."}
  {simset.arg  ""    "Simulation sets, separated by commas, to be run."}
  {verbose         "If set, launch the script in verbose mode"}
}

set usage " \[OPTIONS\] <directive> <project>\n The most common <directive> values are CREATE (or C), WORKFLOW (or W), SIMULATE (or S).

** Directives (case insensitive):
- CREATE or C: Create the project, replacing it if already existing.
- WORKFLOW or W: Launches the complete workflow, creates the project if not existing.
- CREATEWORKFLOW or CW: Creates the project -even if existing- and launches the complete workflow.
- SIMULATE or S: Simulate the project, creating it if not existing.
- IMPLEMENT: Runs the implementation only, the project must already exist and be synthesised.
- SYNTHESIS: Runs the synthesis only, creates the project if not existing.
- LIST or L: Only list all the projects
"

set tcl_path [file normalize "[file dirname [info script]]"]
source $tcl_path/hog.tcl
# Quartus needs extra packages and treats the argv in a different way
if {[IsQuartus]} {
  load_package report
  set argv $quartus(args)
}

Msg Debug "s: $::argv0 a: $argv"

lassign [InitLauncher $::argv0 $tcl_path $parameters $usage $argv] directive project project_name group_name repo_path old_path bin_dir top_path cmd ide

Msg Debug "Returned by InitLauncher: $project $project_name $group_name $repo_path $old_path $bin_dir $top_path $cmd"

if {[CheckCustomCommands $top_path/commands/]} {
  append usage "\n** Custom Commands:\n"
  dict for {command script} [GetCustomCommands $top_path/commands/] {
    append usage "- $command: runs $script \n"
  }
}
append usage "\n** Options:"

######## DEFAULTS #########
set do_implementation 0; set do_synthesis 0; set do_bitstream 0; set do_create 0; set do_compile 0; set do_simulation 0; set recreate 0; set reset 1;

set default_commands {

  \^C(REATE)?$ {
    set do_create 1
    set recreate 1
  }

  \^I(MPL(EMENT(ATION)?)?)?$ {
    set do_implementation 1
    set do_bitstream 1
    set do_compile 1
  }

  \^SYNT(H(ESIS(E)?)?)? {
    set do_synthesis 1
    set do_compile 1
  }

  \^S(IM(ULAT(ION|E)?)?)?$ {
    set do_simulation 1
    set do_create 1
  }

  \^W(ORK(FLOW)?)?$ {
    set do_implementation 1
    set do_synthesis 1
    set do_bitstream 1
    set do_compile 1
  }

  \^(CREATEWORKFLOW|CW)$ {
    set do_implementation 1
    set do_synthesis 1
    set do_bitstream 1
    set do_compile 1
    set recreate 1
  }

  default {
    Msg Status "ERROR: Unknown directive $directive.\n\n[cmdline::usage $parameters $usage]"
    exit 1
  }
}

set custom_commands ""
dict for {command script} [GetCustomCommands $top_path/commands/] {
  append custom_commands "
  \\^$command\$ {
    Msg Info \"Running custom script: $script\"
    source \"$script\"
    Msg Info \"Done running custom script...\"
    exit
  }
 "
}

Msg Debug "looking for a $directive in : $default_commands $custom_commands"
switch -regexp -- $directive "$default_commands $custom_commands"

if {$cmd == -1} {
#This is if the project was not found
  Msg Status "\n\nPossible projects are:"
  ListProjects $repo_path
  Msg Status "\n"
  exit 1
} elseif {$cmd == -2} {
  # Project not given but needed
  Msg Status "ERROR: You must specify a project with directive $directive.\n\n[cmdline::usage $parameters $usage]"
  Msg Status "\n Possible projects are:"
  ListProjects $repo_path
  Msg Status "\n"
  exit 1

} elseif {$cmd == 0} {
  #This script was launched within the IDE,: Vivado, Quartus, etc
  Msg Info "$::argv0 was launched from the IDE."

} else {
  # This script was launched with Tclsh, we need to check the arguments and if everything is right launche the IDE on this script and return
  Msg Info "Launching command: $cmd..."

  # Check if the IDE is actually in the path...
  set ret [catch {exec which $ide}]
  if {$ret != 0} {
    Msg Error "$ide not found in your system. Make sure to add $ide to your PATH enviromental variable."
    exit $ret
  }

  if {[string first libero $cmd] >= 0} {
    # The SCRIPT_ARGS: flag of libero makes tcl crazy...
    # Let's pipe the command into a shell script and remove it later
    set libero_script [open "launch-libero-hog.sh" w]
    puts $libero_script "#!/bin/sh"
    puts $libero_script $cmd
    close $libero_script
    set cmd "sh launch-libero-hog.sh"
  }



  set ret [catch {exec -ignorestderr {*}$cmd >@ stdout} result]

  if {$ret != 0} {
    Msg Error "IDE returned an error state."
  } else {
    Msg Info "All done."
    exit 0
  }

  if {[string first libero $cmd] >= 0} {
    file delete "launch-libero-hog.sh"
  }

  exit $ret
}

#After this line, we are in the IDE
##################################################################################

# We need to Import tcllib if we are using Libero
if {[IsLibero]} {
  if {[info exists env(HOG_TCLLIB_PATH)]} {
    lappend auto_path $env(HOG_TCLLIB_PATH)
  } else {
    puts "ERROR: To run Hog with Microsemi Libero SoC, you need to define the HOG_TCLLIB_PATH variable."
    return
  }
}

if {[catch {package require cmdline} ERROR] || [catch {package require struct::matrix} ERROR]} {
  puts "$ERROR\n Tcllib not found. If you are running this script on tclsh for debuggin purpose ONLY, you can fix this by installing 'tcllib'"
  exit 1
}

lassign [ GetOptions $::argv $parameters $usage] option_list arg_list

if {[catch {array set options [cmdline::getoptions option_list $parameters $usage]}] || [llength $arg_list] != 2 } {
  Msg Info [cmdline::usage $parameters $usage]
  exit 1
} else {
  set main_folder [file normalize "$repo_path/Projects/$project_name/$project.runs/"]
  if {[IsLibero]} {
    set main_folder [file normalize "$repo_path/Projects/$project_name/"]
  }
  set main_sim_folder [file normalize "$repo_path/Projects/$project_name/$project.sim/"]
  set check_syntax 0
  set ext_path ""
  set simlib_path ""

  #Quartus only
  set project_path [file normalize "$repo_path/Projects/$project_name/"]
}


if { $options(no_bitstream) == 1 } {
  set do_bitstream 0
  set do_compile 0
}

if { $options(recreate) == 1 } {
  set recreate 1
}

if { $options(synth_only) == 1} {
  set do_implementation 0
  set do_synthesis 1
  set do_bitstream 0
  set do_create 1
  set do_compile 1
}

if { $options(impl_only) == 1} {
  set do_implementation 0
  set do_synthesis 0
  set do_bitstream 0
  set do_create 0
  set do_compile 1
}


if { $options(no_reset) == 1 } {
  set reset 0
}

if { $options(check_syntax) == 1 } {
  set check_syntax 1
}

if { $do_simulation == 1 } {
  set simsets $options(simset)
}

if { $options(ext_path) != ""} {
  set ext_path $options(ext_path)
}

if {$options(lib)!= ""} {
  set lib_path [file normalize $options(lib)]
} else {
  if {[info exists env(HOG_SIMULATION_LIB_PATH)]} {
    set lib_path $env(HOG_SIMULATION_LIB_PATH)
  } else {
    if {[file exists "$repo_path/SimulationLib"]} {
      set lib_path [file normalize "$repo_path/SimulationLib"]
    } else {
      set lib_path ""
    }
  }
}



if { $options(verbose) == 1 } {
  variable ::DEBUG_MODE 1
}

Msg Info "Number of jobs set to $options(njobs)."


if {[IsXilinx]} {

  ############# Vivado or ISE ####################

  #Go to Hog/Tcl
  cd $tcl_path

  ############# CREATE or OPEN project ############
  if {[IsISE]} {
    set project_file [file normalize $repo_path/Projects/$project_name/$project.ppr]
  } else {
    set project_file [file normalize $repo_path/Projects/$project_name/$project.xpr]
  }

  if {[file exists $project_file]} {
    Msg Info "Found project file $project_file for $project_name."
    set proj_found 1
  } else {
    Msg Info "Project file not found for $project_name."
    set proj_found 0
  }

  if {($proj_found == 0 || $recreate == 1) && ($do_synthesis == 1 || $do_create == 1)} {
    Msg Info "Creating (possibly replacing) the project $project_name..."
    lassign [GetConfFiles $repo_path/Top/$project_name] conf sim pre post

    if {[file exists $conf]} {
      #Still not sure of the difference between project and project_name
      CreateProject -simlib_path $lib_path $project_name $repo_path
    } else {
      Msg Error "Project $project_name is incomplete: no hog.conf file found, please create one..."
    }
  } else {
    Msg Info "Opening existing project file $project_file..."
    file mkdir "$repo_path/Projects/$project_name/$project.gen/sources_1"
    open_project $project_file
  }

  ########## CHECK SYNTAX ###########
  if { $check_syntax == 1 } {
    if {[IsISE]} {
      Msg Info "Checking syntax option is not supported by Xilinx PlanAhead. Skipping.."
    } else {
      Msg Info "Checking syntax for project $project_name..."
      set syntax [check_syntax -return_string]

      if {[string first "CRITICAL" $syntax ] != -1} {
        check_syntax
        exit 1
      }
    }
  } else {
    Msg Debug "Skipping syntax check for project $project_name"
  }

  ############# SYNTH ###############
  if {$reset == 1 && $do_create == 0} {
    Msg Info "Resetting run before launching synthesis..."
    reset_run synth_1

  }

  if {[IsISE]} {
    source  $tcl_path/../../Hog/Tcl/integrated/pre-synthesis.tcl
  }

  if {$do_synthesis == 1} {
    launch_runs synth_1  -jobs $options(njobs) -dir $main_folder
    wait_on_run synth_1
    set prog [get_property PROGRESS [get_runs synth_1]]
    set status [get_property STATUS [get_runs synth_1]]
    Msg Info "Run: synth_1 progress: $prog, status : $status"

    # Copy IP reports in bin/
    set ips [get_ips *]

    #go to repository path
    cd $tcl_path/../..

    lassign [GetRepoVersions [file normalize ./Top/$project_name] $repo_path $ext_path ] sha
    set describe [GetHogDescribe $sha $repo_path]
    Msg Info "Git describe set to $describe"

    foreach ip $ips {
      set xci_file [get_property IP_FILE $ip]

      set xci_path [file dirname $xci_file]
      set xci_ip_name [file rootname [file tail $xci_file]]
      foreach rptfile [glob -nocomplain -directory $xci_path *.rpt] {
        file copy $rptfile $bin_dir/$project_name-$describe/reports
      }

      # Let's leave the following commented part
      # We moved the Handle ip to the post-synthesis, in that case we can't use get_runs so to find out which IP was run, we loop over the directories enedind with _synth_1 in the .runs directory
      #
      #    ######### Copy IP to IP repository
      #    if {[IsVivado]} {
      #    	set gen_path [get_property IP_OUTPUT_DIR $ip]
      #    	if {($ip_path != "")} {
      #    	  # IP is not in the gitlab repo
      #    	  set force 0
      #    	  if [info exist runs] {
      #    	    if {[lsearch $runs $ip\_synth_1] != -1} {
      #    	      Msg Info "$ip was synthesized, will force the copy to the IP repository..."
      #    	      set force 1
      #    	    }
      #    	  }
      #    	  Msg Info "Copying synthesised IP $xci_ip_name ($xci_file) to $ip_path..."
      #    	  HandleIP push $xci_file $ip_path $repo_path $gen_path $force
      #    	}
      #    }

    }

    if {$prog ne "100%"} {
      Msg Error "Synthesis error, status is: $status"
    }
  } else {
    Msg Debug "Skipping synthesis (and IP handling)..."
  }

  ############### IMPL ###################

  if {$do_implementation == 1 } {

    Msg Info "Starting implementation flow..."
    if { $reset == 1 && $do_create == 0} {
      Msg Info "Resetting run before launching implementation..."
      reset_run impl_1
    }

    if {[IsISE]} {source $tcl_path/../../Hog/Tcl/integrated/pre-implementation.tcl}
    launch_runs impl_1 -jobs $options(njobs) -dir $main_folder
    wait_on_run impl_1
    if {[IsISE]} {source $tcl_path/../../Hog/Tcl/integrated/post-implementation.tcl}

    set prog [get_property PROGRESS [get_runs impl_1]]
    set status [get_property STATUS [get_runs impl_1]]
    Msg Info "Run: impl_1 progress: $prog, status : $status"

    # Check timing
    if {[IsISE]} {

      set status_file [open "$main_folder/timing.txt" "w"]
      puts $status_file "## $project_name Timing summary"

      set f [open [lindex [glob "$main_folder/impl_1/*.twr" 0]]]
      set errs -1
      while {[gets $f line] >= 0} {
        if { [string match "Timing summary:" $line] } {
          while {[gets $f line] >= 0} {
            if { [string match "Timing errors:*" $line] } {
              set errs [regexp -inline -- {[0-9]+} $line]
            }
            if { [string match "*Footnotes*" $line ] } {
              break
            }
            puts $status_file "$line"
          }
        }
      }

      close $f
      close $status_file

      if {$errs == 0} {
        Msg Info "Time requirements are met"
        file rename -force "$main_folder/timing.txt" "$main_folder/timing_ok.txt"
        set timing_ok 1
      } else {
        Msg CriticalWarning "Time requirements are NOT met"
        file rename -force "$main_folder/timing.txt" "$main_folder/timing_error.txt"
        set timing_ok 0
      }
    }

    if {[IsVivado]} {
      set wns [get_property STATS.WNS [get_runs [current_run]]]
      set tns [get_property STATS.TNS [get_runs [current_run]]]
      set whs [get_property STATS.WHS [get_runs [current_run]]]
      set ths [get_property STATS.THS [get_runs [current_run]]]

      if {$wns >= 0 && $whs >= 0} {
        Msg Info "Time requirements are met"
        set status_file [open "$main_folder/timing_ok.txt" "w"]
        set timing_ok 1
      } else {
        Msg CriticalWarning "Time requirements are NOT met"
        set status_file [open "$main_folder/timing_error.txt" "w"]
        set timing_ok 0
      }

      Msg Status "*** Timing summary ***"
      Msg Status "WNS: $wns"
      Msg Status "TNS: $tns"
      Msg Status "WHS: $whs"
      Msg Status "THS: $ths"

      struct::matrix m
      m add columns 5
      m add row

      puts $status_file "## $project_name Timing summary"

      m add row  "| **Parameter** | \"**value (ns)**\" |"
      m add row  "| --- | --- |"
      m add row  "|  WNS:  |  $wns  |"
      m add row  "|  TNS:  |  $tns  |"
      m add row  "|  WHS:  |  $whs  |"
      m add row  "|  THS:  |  $ths  |"

      puts $status_file [m format 2string]
      puts $status_file "\n"
      if {$timing_ok == 1} {
        puts $status_file " Time requirements are met."
      } else {
        puts $status_file "Time requirements are **NOT** met."
      }
      puts $status_file "\n\n"
      close $status_file
    }

    if {$prog ne "100%"} {
      Msg Error "Implementation error"
    }

    if {$do_bitstream == 1} {
      Msg Info "Starting write bitstream flow..."
      if {[IsISE]} {
	      # PlanAhead command
        Msg Info "running pre-bitstream"
        source  $tcl_path/../../Hog/Tcl/integrated/pre-bitstream.tcl
        launch_runs impl_1 -to_step Bitgen $options(njobs) -dir $main_folder
        wait_on_run impl_1
        Msg Info "running post-bitstream"
        source  $tcl_path/../../Hog/Tcl/integrated/post-bitstream.tcl
      } elseif { [string first Vivado [version]] ==0} {
        # Vivado command
        launch_runs impl_1 -to_step [BinaryStepName [get_property PART [current_project]]] $options(njobs) -dir $main_folder
        wait_on_run impl_1
      }

      set prog [get_property PROGRESS [get_runs impl_1]]
      set status [get_property STATUS [get_runs impl_1]]
      Msg Info "Run: impl_1 progress: $prog, status : $status"

      if {$prog ne "100%"} {
        Msg Error "Write bitstream error, status is: $status"
      }

      if {[IsVivado]} {
        Msg Status "*** Timing summary (again) ***"
        Msg Status "WNS: $wns"
        Msg Status "TNS: $tns"
        Msg Status "WHS: $whs"
        Msg Status "THS: $ths"
      }
    }

    #Go to repository path
    cd $repo_path

    lassign [GetRepoVersions [file normalize ./Top/$project_name] $repo_path] sha
    set describe [GetHogDescribe $sha $repo_path]
    Msg Info "Git describe set to $describe"

    set dst_dir [file normalize "$bin_dir/$project_name\-$describe"]

    file mkdir $dst_dir

    #Version table
    if {[file exists $main_folder/versions.txt]} {
      file copy -force $main_folder/versions.txt $dst_dir
    } else {
      Msg Warning "No versions file found in $main_folder/versions.txt"
    }
    #Timing file
    set timing_files [ glob -nocomplain "$main_folder/timing_*.txt" ]
    set timing_file [file normalize [lindex $timing_files 0]]

    if {[file exists $timing_file]} {
      file copy -force $timing_file $dst_dir/
    } else {
      Msg Warning "No timing file found, not a problem if running locally"
    }

  }

  if {$do_simulation == 1} {
    ##################### SIMULATION #######################
    set simsets_todo ""
    if {$simsets != ""} {
      set simsets_todo [split $simsets ","]
      Msg Info "Will run only the following simsets (if they exist): $simsets_todo"
    }

    set failed []
    set success []
    set sim_dic [dict create]

    Msg Info "Retrieving list of simulation sets..."
    foreach s [get_filesets] {
      set type [get_property FILESET_TYPE $s]
      if {$type eq "SimulationSrcs"} {
        if {$simsets_todo != "" && $s ni $simsets_todo} {
          Msg Info "Skipping $s as it was not specified with the -simset option..."
          continue
        }
        if {[file exists "$repo_path/Top/$project_name/list/$s.sim"]} {
          set fp [open "$repo_path/Top/$project_name/list/$s.sim" r]
          set file_data [read $fp]
          close $fp
          set data [split $file_data "\n"]
          set n [llength $data]
          Msg Info "$n lines read from $s.sim"

          set firstline [lindex $data 0]
          # Find simulator
          if { [regexp {^ *\#Simulator} $firstline] } {
            set simulator_prop [regexp -all -inline {\S+} $firstline]
            set simulator [string tolower [lindex $simulator_prop 1]]
          } else {
            Msg Warning "Simulator not set in $s.sim. The first line of $s.sim should be #Simulator <SIMULATOR_NAME>, where <SIMULATOR_NAME> can be xsim, questa, modelsim, riviera, activehdl, ies, or vcs, e.g. #Simulator questa. Setting simulator by default as xsim."
            set simulator "xsim"
          }
          if {$simulator eq "skip_simulation"} {
            Msg Info "Skipping simulation for $s"
            continue
          }
          set_property "target_simulator" $simulator [current_project]
          Msg Info "Creating simulation scripts for $s..."
          current_fileset -simset $s
          set sim_dir $main_sim_folder/$s/behav
          if { ([string tolower $simulator] eq "xsim") } {
            set sim_name "xsim:$s"
            if { [catch { launch_simulation -simset [get_filesets $s] } log] } {
              Msg CriticalWarning "Simulation failed for $s, error info: $::errorInfo"
              lappend failed $sim_name
            } else {
              lappend success $sim_name
            }
          } else {
            Msg Info "Simulation library path is set to $lib_path."
            set simlib_ok 1
            if {!([file exists $lib_path])} {
              Msg Warning "Could not find simulation library path: $lib_path, $simulator simulation will not work."
              set simlib_ok 0
            }

            if {$simlib_ok == 1} {
              set_property "compxlib.${simulator}_compiled_library_dir" [file normalize $lib_path] [current_project]
              launch_simulation -scripts_only -simset [get_filesets $s]
              set top_name [get_property TOP $s]
              set sim_script  [file normalize $sim_dir/$simulator/]
              Msg Info "Adding simulation script location $sim_script for $s..."
              lappend sim_scripts $sim_script
              dict append sim_dic $sim_script $s
            } else {
              Msg Error "Cannot run $simulator simulations without a valid library path"
              exit -1
            }
          }
        }
      }
    }

    if {[info exists sim_scripts]} {
      # Only for modelsim/questasim
      Msg Info "Generating IP simulation targets, if any..."

      foreach ip [get_ips] {
        generate_target simulation -quiet $ip
      }


      Msg Status "\n\n"
      Msg Info "====== Starting simulations runs ======"
      Msg Status "\n\n"

      foreach s $sim_scripts {
        cd $s
        set cmd ./compile.sh
        Msg Info " ************* Compiling: $s  ************* "
        lassign [ExecuteRet $cmd] ret log
        set sim_name "comp:[dict get $sim_dic $s]"
        if {$ret != 0} {
          Msg CriticalWarning "Compilation failed for $s, error info: $::errorInfo"
          lappend failed $sim_name
        } else {
          lappend success $sim_name
        }
        Msg Info "###################### Compilation log starts ######################"
        Msg Info "\n\n$log\n\n"
        Msg Info "######################  Compilation log ends  ######################"


        if { [file exists "./elaborate.sh"] } {
          set cmd ./elaborate.sh
          Msg Info " ************* Elaborating: $s  ************* "
          lassign [ExecuteRet $cmd] ret log
          set sim_name "elab:[dict get $sim_dic $s]"
          if {$ret != 0} {
            Msg CriticalWarning "Elaboration failed for $s, error info: $::errorInfo"
            lappend failed $sim_name
          } else {
            lappend success $sim_name
          }
          Msg Info "###################### Elaboration log starts ######################"
          Msg Info "\n\n$log\n\n"
          Msg Info "######################  Elaboration log ends  ######################"
        }
        set cmd ./simulate.sh
        Msg Info " ************* Simulating: $s  ************* "
        lassign [ExecuteRet $cmd] ret log

        # If HOG_SIMPASS_STR is set, search for the string and update return code from simulation if the string is not found in simulation log
        if {[info exists env(HOG_SIMPASS_STR)]} {
          Msg Info "Searching for simulation pass string: '$env(HOG_SIMPASS_STR)'"
          if {[string first $env(HOG_SIMPASS_STR) $log] == -1} {
            set ret 1
          }
        }

        set sim_name "sim:[dict get $sim_dic $s]"
        if {$ret != 0} {
          Msg CriticalWarning "Simulation failed for $s, error info: $::errorInfo"
          lappend failed $sim_name
        } else {
          lappend success $sim_name
        }
        Msg Info "###################### Simulation log starts ######################"
        Msg Info "\n\n$log\n\n"
        Msg Info "######################  Simulation log ends  ######################"

      }
    }


    if {[llength $success] > 0} {
      set successes [join $success "\n"]
      Msg Info "The following simulation sets were successful:\n\n$successes\n\n"
    }

    if {[llength $failed] > 0} {
      set failures [join $failed "\n"]
      Msg Error "The following simulation sets have failed:\n\n$failures\n\n"
      exit -1
    } elseif {[llength $success] > 0} {
      Msg Info "All the [llength $success] compilations, elaborations and simulations were successful."
    }

    Msg Info "Simulation done."

  }




} elseif [IsQuartus] {
  ############## Quartus ########################
  set argv ""
  #############################
  # Recreate the project file #
  #############################
  if { [catch {package require ::quartus::project} ERROR] } {
    Msg Error "$ERROR\n Can not find package ::quartus::project"
    cd $old_path
    return 1
  } else {
    Msg Info "Loaded package ::quartus::project"
  }

  if {[file exists "$project_path/$project.qpf" ]} {
    Msg Info "Found project file $project.qpf for $project_name."
    set proj_found 1
  } else {
    Msg Warning "Project file not found for $project_name."
    set proj_found 0
  }

  if { $proj_found == 0 || $recreate == 1 || $do_create == 1} {
    Msg Info "Creating (possibly replacing) the project $project_name..."
    lassign [GetConfFiles $repo_path/Top/$project_name] conf sim pre post tcl_file

    if {[file exists $conf]} {
      CreateProject -simlib_path $lib_path $project_name $repo_path
    } else {
      Msg Error "Project $project_name is incomplete: not Tcl file or hog.conf file found."
    }
  }

  if {[file exists "$project_path" ]} {
    cd $project_path
  } else {
    Msg Error "Project directory not found for $project_name."
    return 1
  }

  if { ![is_project_open ] } {
    Msg Info "Opening existing project file $project_name..."
    project_open $project -current_revision
  }

  Msg Info "Number of jobs set to $options(njobs)."
  set_global_assignment -name NUM_PARALLEL_PROCESSORS $options(njobs)

  load_package flow

  ################
  # CHECK SYNTAX #
  ################
  if { $check_syntax == 1 } {
    Msg Info "Checking syntax for project $project_name..."
    lassign [GetHogFiles -list_files "*.src" "$repo_path/Top/$project_name/list/" $repo_path] src_files dummy
    dict for {lib files} $src_files {
      foreach f $files {
        set file_extension [file extension $f]
        if { $file_extension == ".vhd" || $file_extension == ".vhdl" || $file_extension == ".v" ||  $file_extension == ".sv" } {
          if { [catch {execute_module -tool map -args "--analyze_file=$f"} result]} {
            Msg Error "\nResult: $result\n"
            Msg Error "Check syntax failed.\n"
          } else {
            if { $result == "" } {
              Msg Info "Check syntax was successful for $f.\n"
            } else {
              Msg Warning "Found syntax error in file $f:\n $result\n"
            }
          }
        }
      }
    }
  }

  # keep track of the current revision and of the top level entity name
  lassign [GetRepoVersions [file normalize $repo_path/Top/$project_name] $repo_path ] sha
  set describe [GetHogDescribe $sha $repo_path]
  #set top_level_name [ get_global_assignment -name TOP_LEVEL_ENTITY ]
  set revision [get_current_revision]
  if { $do_compile == 1 } {
    if {[catch {execute_flow -compile} result]} {
      Msg Error "Result: $result\n"
      Msg Error "Full compile flow failed. See the report file.\n"
    } else {
      Msg Info "Full compile Flow was successful for revision $revision.\n"
    }
    if {[file exists "output_files/versions.txt" ]} {
      set dst_dir [file normalize "$repo_path/bin/$project_name\-$describe"]
      file mkdir $dst_dir
      file copy -force "output_files/versions.txt" $dst_dir
    }
  } else {
    #############################
    # Analysis and Synthesis
    #############################
    if { $do_synthesis == 1 } {


      #run PRE_FLOW_SCRIPT by hand
      set tool_and_command [ split [get_global_assignment -name PRE_FLOW_SCRIPT_FILE] ":"]
      set tool [lindex $tool_and_command 0]
      set pre_flow_script [lindex $tool_and_command 1]
      set cmd "$tool -t $pre_flow_script quartus_map $project $revision"
      #Close project to avoid conflict with pre synthesis script
      project_close

      lassign [ExecuteRet {*}$cmd ] ret log
      if {$ret != 0} {
        Msg Warning "Can not execute command $cmd"
        Msg Warning "LOG: $log"
      } else {
        Msg Info "Pre flow script executed!"
      }

      # Re-open project
      if { ![is_project_open ] } {
        Msg Info "Re-opening project file $project_name..."
        project_open $project -current_revision
      }

      # Execute synthesis
      if {[catch {execute_module -tool map -args "--parallel"} result]} {
        Msg Error "Result: $result\n"
        Msg Error "Analysis & Synthesis failed. See the report file.\n"
      } else {
        Msg Info "Analysis & Synthesis was successful for revision $revision.\n"
      }
    }
    #############################
    # Place & Route
    #############################
    if { $do_implementation == 1 } {
      if {[catch {execute_module -tool fit} result]} {
        Msg Error "Result: $result\n"
        Msg Error "Place & Route failed. See the report file.\n"
      } else {
        Msg Info "\nINFO: Place & Route was successful for revision $revision.\n"
      }
      #############################
      # Generate bitstream
      #############################
      if { $do_bitstream == 1 } {
        if {[catch {execute_module -tool asm} result]} {
          Msg Error "Result: $result\n"
          Msg Error "Generate bitstream failed. See the report file.\n"
        } else {
          Msg Info "Generate bitstream was successful for revision $revision.\n"
        }
      }
      #############################
      # Additional tools to be run on the project
      #############################
      #TODO
      if {[catch {execute_module -tool sta -args "--do_report_timing"} result]} {
        Msg Error "Result: $result\n"
        Msg Error "Time Quest failed. See the report file.\n"
      } else {
        Msg Info "Time Quest was successfully run for revision $revision.\n"
        load_package report
        load_report
        set panel "Timing Analyzer||Timing Analyzer Summary"
        set device       [ get_report_panel_data -name $panel -col 1 -row_name "Device Name" ]
        set timing_model [ get_report_panel_data -name $panel -col 1 -row_name "Timing Models" ]
        set delay_model  [ get_report_panel_data -name $panel -col 1 -row_name "Delay Model" ]
        #set slack        [ get_timing_analysis_summary_results -slack ]
        Msg Info "*******************************************************************"
        Msg Info "Device: $device"
        Msg Info "Timing Models: $timing_model"
        Msg Info "Delay Model: $delay_model"
        Msg Info "Slack:"
        #Msg Info  $slack
        Msg Info "*******************************************************************"
      }
    }
  }

  # close project
  project_close

} elseif {[IsLibero]} {

  ############# CREATE or OPEN project ############
  set project_file [file normalize $repo_path/Projects/$project_name/$project.prjx]

  if {[file exists $project_file]} {
    Msg Info "Found project file $project_file for $project_name."
    set proj_found 1
  } else {
    Msg Info "Project file not found for $project_name."
    set proj_found 0
  }

  if {($proj_found == 0 || $recreate == 1) && ($do_synthesis == 1  || $do_create == 1)} {
    Msg Info "Creating (possibly replacing) the project $project_name..."
    lassign [GetConfFiles $repo_path/Top/$project_name] conf sim pre post

    if {[file exists $conf]} {
      CreateProject -simlib_path $lib_path $project_name $repo_path
    } else {
      Msg Error "Project $project_name is incomplete: no hog.conf file found, please create one..."
    }
  } else {
    Msg Info "Opening existing project file $project_file..."
    open_project -file $project_file -do_backup_on_convert 1 -backup_file {./Projects/$project_file.zip}
  }

  ########## CHECK SYNTAX ###########
  if { $check_syntax == 1 } {
    Msg Info "Checking syntax option is not supported for Microchip Libero Soc yet. Skipping.."
  }

  defvar_set -name RWNETLIST_32_64_MIXED_FLOW -value 0

  ############# SYNTH ###############

  if {$do_synthesis == 1} {
    Msg Info "Run SYNTHESIS..."
    if {[catch {run_tool -name {SYNTHESIZE}  }] } {
      Msg Error "SYNTHESIZE FAILED!"
    } else {
      Msg Info "SYNTHESIZE PASSED!"
    }
  } else {
    Msg Debug "Skipping synthesis (and IP handling)..."
  }

  ############### IMPL ###################

  if {$do_implementation == 1 } {

    Msg Info "Starting implementation flow..."
    if {[catch {run_tool -name {PLACEROUTE}  }] } {
      Msg Error "PLACEROUTE FAILED!"
    } else {
      Msg Info "PLACEROUTE PASSED."
    }

    # source $tcl_path/../../Hog/Tcl/integrated/post-implementation.tcl

    # Check timing
    Msg Info "Run VERIFYTIMING ..."
    if {[catch {run_tool -name {VERIFYTIMING} -script {Hog/Tcl/integrated/libero_timing.tcl} }] } {
      Msg CriticalWarning "VERIFYTIMING FAILED!"
    } else {
      Msg Info "VERIFYTIMING PASSED \n"
    }


    if {$do_bitstream == 1} {
      Msg Info "Starting write bitstream flow..."
      Msg Info "Run GENERATEPROGRAMMINGDATA ..."
      if {[catch {run_tool -name {GENERATEPROGRAMMINGDATA}  }] } {
        Msg Error "GENERATEPROGRAMMINGDATA FAILED!"
      } else {
        Msg Info "GENERATEPROGRAMMINGDATA PASSED."
      }
      Msg Info "Sourcing Hog/Tcl/integrated/post-bitstream.tcl"
      source $tcl_path/../../Hog/Tcl/integrated/post-bitstream.tcl
    }

    #Go to repository path
    cd $repo_path

    lassign [GetRepoVersions [file normalize ./Top/$project_name] $repo_path] sha
    set describe [GetHogDescribe $sha $repo_path]
    Msg Info "Git describe set to $describe"

    set dst_dir [file normalize "$bin_dir/$project_name\-$describe"]
    file mkdir $dst_dir/reports

    #Version table
    if {[file exists $main_folder/versions.txt]} {
      file copy -force $main_folder/versions.txt $dst_dir
    } else {
      Msg Warning "No versions file found in $main_folder/versions.txt"
    }
    #Timing file
    set timing_file_path [file normalize "$repo_path/Projects/timing_libero.txt"]
    if {[file exists $timing_file_path]} {
      file copy -force $timing_file_path $dst_dir/reports/Timing.txt
      set timing_file [open $timing_file_path "r"]
      set status_file [open "$dst_dir/timing.txt" "w"]
      puts $status_file "## $project_name Timing summary\n\n"
      puts $status_file "|  |  |"
      puts $status_file "| --- | --- |"
      while {[gets $timing_file line] >= 0} {
        if { [string match "SUMMARY" $line] } {
          while {[gets $timing_file line] >= 0} {
            if { [string match "END SUMMARY" $line ] } {
              break
            }
            if {[string first ":" $line] == -1} {
              continue
            }
            set out_string "| [string map {: | } $line] |"
            puts $status_file "$out_string"
          }
        }
      }
    } else {
      Msg Warning "No timing file found, not a problem if running locally"
    }

  }


} else {
  Msg Error "Impossible condition. You need to run this in an IDE."
  exit 1
}

Msg Info "All done."
cd $old_path
