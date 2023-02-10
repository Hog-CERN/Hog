# @file
#   Copyright 2018-2023 The University of Birmingham
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
  {synth_only      "If set, only the synthesis will be performed."}
  {impl_only       "If set, only the implementation will be performed. This assumes synthesis should was already done."}
  {recreate        "If set, the project will be re-created if it already exists."}
  {no_reset        "If set, runs (synthesis and implementation) won't be reset before launching them."}
  {check_syntax    "If set, the HDL syntax will be checked at the beginning of the workflow."}
  {njobs.arg 4 "Number of jobs. Default: 4"}
  {ext_path.arg "" "Sets the absolute path for the external libraries."}
  {simlib_path.arg  "" "Path of simulation libs"}
  {verbose         "If set, launch the script in verbose mode"}
}

set usage "\[OPTIONS\] <project> \n. Options:"

set tcl_path [file normalize "[file dirname [info script]]/.."]
source $tcl_path/hog.tcl

lassign [InitLauncher $::argv0 $tcl_path $parameters $usage $argv] project project_name group_name repo_path old_path bin_dir top_path cmd

if {$cmd == 0} {
  #This script was launched within the IDE,: Vivado, Quartus, etc
  Msg Info "$::argv0 was launched from the IDE."
  
} else {
  #This script was launched with Tclsh, we need to check the arguments and if everything is right launche the IDE on this script and return
  Msg Info "Launching $cmd..."

  set ret [catch {exec -ignorestderr {*}$cmd >@ stdout} result]
  
  if {$ret != 0} {
    Msg CriticalWarning "IDE returned an error state."
  } else {
    Msg "All done."
  }
  exit $ret
}


if {[catch {package require cmdline} ERROR] || [catch {package require struct::matrix} ERROR]} {
  puts "$ERROR\n Tcllib not found. If you are running this script on tclsh, you can fix this by installing 'tcllib'"
  exit 1
}




if {[catch {array set options [cmdline::getoptions ::argv $parameters $usage]}] ||  [llength $argv] < 1 } {
  Msg Info [cmdline::usage $parameters $usage]
  exit 1
} else {

  set main_folder [file normalize "$repo_path/Projects/$project_name/$project.runs/"]

  set do_implementation 1
  set do_synthesis 1
  set do_bitstream 1
  set recreate 0
  set reset 1
  set check_syntax 0
  set ext_path ""
  set simlib_path ""
}



#Go to Hog/Tcl
cd $tcl_path

if { $options(no_bitstream) == 1 } {
  set do_bitstream 0
}

if { $options(recreate) == 1 } {
  set recreate 1
}

if { $options(synth_only) == 1 } {
  set do_implementation 0
}

if { $options(impl_only) == 1 } {
  set do_synthesis 0
}

if { $options(no_reset) == 1 } {
  set reset 0
}

if { $options(check_syntax) == 1 } {
  set check_syntax 1
}

if { $options(ext_path) != ""} {
  set ext_path $options(ext_path)
}

if { $options(simlib_path) != ""} {
  set workflow_simlib_path $options(simlib_path)
}

if { $options(verbose) == 1 } {
  variable ::DEBUG_MODE 1
}


# Let's leave the following commented section in case something comes up
# It was able to retrieve the ips before creating the project, but this cannot be used if generated file are in the Projects folder

#Copy IP from IP repository
# if { $options(ip_path) != "" } {
#   set ip_path $options(ip_path)
# 
#   Msg Info "Getting IPs for $project_name..."
#   set ips {}
#   lassign [GetHogFiles -list_files "*.src" -repo_path $repo_path "$repo_path/Top/$project_name/list/" ] src_files dummy
#   dict for {f files} $src_files {
#     #library names have a .src extension in values returned by GetHogFiles
#     if { [file ext $f] == ".ip" } {
#       lappend ips {*}$files
#     }
#   }
# 
#   Msg Info "Copying IPs from $ip_path..."
#   set copied_ips 0
#   set repo_ips {}
#   foreach ip $ips {
#     set ip_folder [file dirname $ip]
#     set files_in_folder [glob -directory $ip_folder -- *]
#     if { [llength $files_in_folder] == 1 } {
#       set ret [HandleIP pull $ip $ip_path $repo_path $main_folder]
#       if {$ret == 0} {
#         incr copied_ips
#       }
#     } else {
#       Msg Info "Synthesised files for IP $ip are already in the repository. Do not copy from IP repository..."
#       lappend repo_ips $ip
#     }
#   }
#   Msg Info "$copied_ips IPs were copied from the IP repository."
# }


if {$do_synthesis == 0} {
  Msg Info "Will launch implementation only..."

} else {
  if {$do_implementation == 1} {
    if {$do_bitstream == 1} {
      Msg Info "Will launch implementation and write bitstream..."
    } else {
      Msg Info "Will launch implementation only..."
    }
  } else {
    Msg Info "Will launch synthesis only..."
  }
}

Msg Info "Number of jobs set to $options(njobs)."

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

if {($proj_found == 0 || $recreate == 1) && $do_synthesis == 1} {
  Msg Info "Creating (possibly replacing) the project $project_name..."
  lassign [GetConfFiles $repo_path/Top/$project_name] conf sim pre post

  if {[file exists $conf]} {
    source ./create_project.tcl
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
  Msg Info "Skipping syntax check for project $project_name"
}

############# SYNTH ###############
if {$reset == 1 } {
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
  set describe [GetHogDescribe $sha]
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
  Msg Info "Skipping synthesis (and IP handling)..."
}

############### IMPL ###################

if {$do_implementation == 1 } {

  Msg Info "Starting implementation flow..."
  if { $reset == 1 } {
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
  set describe [GetHogDescribe $sha]
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

Msg Info "All done."
cd $old_path
