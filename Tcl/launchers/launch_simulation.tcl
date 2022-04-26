#   Copyright 2018-2022 The University of Birmingham
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


# @file
# Launch all the simulations in a vivado project in text mode

#parsing command options
if {[catch {package require cmdline} ERROR]} {
  puts "$ERROR\n If you are running this script on tclsh, you can fix this by installing 'tcllib'"
  return
}

set parameters {
  {lib_path.arg ""   "Compiled simulation library path"}
  {simset.arg  ""   "Simulation sets, separated by commas, to be run."}
  {recreate        "If set, the project will be re-created if it already exists."}
  {quiet             "Simulation sets, separated by commas, to be run."}  
}

set usage "- USAGE: $::argv0 \[OPTIONS\] <project> \n. Options:"

set path [file normalize "[file dirname [info script]]/.."]
set repo_path [file normalize "$path/../.."]

set old_path [pwd]
cd $path
source ./hog.tcl


if { $::argc eq 0 } {
  Msg Info [cmdline::usage $parameters $usage]
  exit 1
} elseif {[IsXilinx] && [catch {array set options [cmdline::getoptions ::argv $parameters $usage]}] } {
  Msg Info [cmdline::usage $parameters $usage]
  exit 1
} elseif {[IsQuartus] && [ catch {array set options [cmdline::getoptions quartus(args) $parameters $usage] } ] || $::argc eq 0 } {
  Msg Info [cmdline::usage $parameters $usage]
  exit 1
} else {
  set project [lindex $argv 0]
  set group_name [file dirname $project]
  set project [file tail $project]
  if { $group_name != "." } {
    set project_name "$group_name/$project"
  } else {
    set project_name "$project"
  }
  set main_folder [file normalize "$repo_path/Projects/$project_name/$project.sim/"]

  if {$options(lib_path)!= ""} {
    cd $old_path 
    set lib_path [file normalize $options(lib_path)]
    set workflow_simlib_path [file normalize $options(lib_path)]
    cd $path
  } else {
    set lib_path [file normalize "$repo_path/SimulationLib"]
  }
  set recreate 0
}

Msg Info "Simulation library path is set to $lib_path."
set simlib_ok 1
if !([file exists $lib_path]) {
  Msg Warning "Could not find simulation library path: $lib_path, Modelsim/Questasim simulation will not work."
  set simlib_ok 0
}
set simsets_todo ""
if {$options(simset)!= ""} {
  set simsets_todo [split $options(simset) ","]
  Msg Info "Will run only the following simsets (if they exist): $simsets_todo"
}

set verbose 1
if {$options(quiet) == 1} {
  set verbose 0 
  Msg Info "Will run in quiet mode"
}

if { $options(recreate) == 1 } {
  set recreate 1
}


############# CREATE or OPEN project ############
if {[IsISE]} {
  set project_file [file normalize $repo_path/Projects/$project_name/$project.ppr]
} else {
  set project_file [file normalize $repo_path/Projects/$project_name/$project.xpr]
}

if {[file exists $project_file] && $recreate == 0} {
  Msg Info "Found project file $project_file for $project_name..."
  open_project $project_file
} else {
  Msg Info "Creating (possibly replacing) the project $project_name..."

  lassign [GetConfFiles $repo_path/Top/$project_name] conf sim pre post tcl_file

  if {[file exists $conf]} {
    set DESIGN $project_name
    source ./create_project.tcl
    cd $path
  } elseif {[file exists $tcl_file]} {
    source $repo_path/Top/$project_name/$project.tcl
  } else {
    Msg Error "Project $project_name is incomplete: not Tcl file or Properties.conf file found."
  }
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
    if {!($s eq "sim_1")} {
      set filename [string range $s 0 [expr {[string last "_sim" $s] -1 }]]
      set fp [open "../../Top/$project_name/list/$filename.sim" r]
      set file_data [read $fp]
      close $fp
      set data [split $file_data "\n"]
      set n [llength $data]
      Msg Info "$n lines read from $filename"

      set firstline [lindex $data 0]
      #find simulator
      if { [regexp {^ *\#Simulator} $firstline] } {
        set simulator_prop [regexp -all -inline {\S+} $firstline]
        set simulator [lindex $simulator_prop 1]
      } else {
        set simulator "modelsim"
      }
      if {$simulator eq "skip_simulation"} {
        Msg Info "Skipping simulation for $s"
        continue
      }
      set_property "target_simulator" $simulator [current_project]
      Msg Info "Creating simulation scripts for $s..."
      current_fileset -simset $s
      set sim_dir $main_folder/$s/behav
      if { ([string tolower $simulator] eq "xsim") } {
        set sim_name "xsim:$s"		
        if { [catch { launch_simulation -simset [get_filesets $s] } log] } {
          Msg CriticalWarning "Simulation failed for $s, error info: $::errorInfo"
          lappend failed $sim_name
        } else {
          lappend success $sim_name
        }
      } else {
        if {$simlib_ok == 1} {
          set_property "compxlib.${simulator}_compiled_library_dir" [file normalize $lib_path] [current_project]
          launch_simulation -scripts_only -simset [get_filesets $s]
          set top_name [get_property TOP $s]
          set sim_script  [file normalize $sim_dir/$simulator/]
          Msg Info "Adding simulation script location $sim_script for $s..."
          lappend sim_scripts $sim_script
          dict append sim_dic $sim_script $s
        } else {
          Msg Error "Cannot run $simulator simulations witouth a valid library path"
          exit -1
        }
      }
    }
  }
}

if [info exists sim_scripts] { #Only for modelsim/questasim
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
    if {$verbose == 1} {
      Msg Info "###################### Compilation log starts ######################"
      Msg Status "\n\n$log\n\n"
      Msg Info "######################  Compilation log ends  ######################"
    }

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
      if {$verbose == 1} {
        Msg Info "###################### Elaboration log starts ######################"
        Msg Status "\n\n$log\n\n"
        Msg Info "######################  Elaboration log ends  ######################"
      }
    }
    set cmd ./simulate.sh
    Msg Info " ************* Simulating: $s  ************* "  
    lassign [ExecuteRet $cmd] ret log
    set sim_name "sim:[dict get $sim_dic $s]"  
    if {$ret != 0} {
      Msg CriticalWarning "Simulation failed for $s, error info: $::errorInfo"
      lappend failed $sim_name
    } else {
      lappend success $sim_name
    }
    if {$verbose == 1} {
      Msg Info "###################### Simulation log starts ######################"
      Msg Status "\n\n$log\n\n"
      Msg Info "######################  Simulation log ends  ######################"
    }
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
} else {
  Msg Info "All the [llength $success] compilations, elaborations and simulations were successful."
}

Msg Info "All done."
