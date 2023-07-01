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

##nagelfar variable quartus
#parsing command options
set parameters {\
  {no_bitstream    "If set, the bitstream file will not be produced."}
  {synth_only      "If set, only the synthesis will be performed."}
  {impl_only       "If set, only the implementation will be performed. This assumes synthesis should was already done."}
  {recreate        "If set, the project will not be re created if it already exists."}
  {check_syntax    "If set, the HDL syntax will be checked at the beginning of the workflow."}
  {project.arg     "" "The project name"}
  {njobs.arg 4     "Number of jobs. Default: 4"}
  {verbose         "If set, launch the script in verbose mode"}
}

set usage   "- USAGE: $::argv0 \[OPTIONS\] -project <project> \n  Options:"
set tcl_path [file normalize "[file dirname [info script]]/.."]

source $tcl_path/hog.tcl

if {[IsQuartus]} {
  load_package report
  set argv $quartus(args)
}

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
    Msg Info "All done."
  }
  exit $ret
}

cd $tcl_path

if { [catch {package require cmdline} ERROR] } {
  puts "$ERROR\n If you are running this script on tclsh, you can fix this by installing 'tcllib'"
  return 1
}
if { [ catch {array set options [cmdline::getoptions quartus(args) $parameters $usage] } ] || $::argc eq 0 } {
  Msg Info [cmdline::usage $parameters $usage]
  cd $old_path
  return 1
} else {

  set project_path [file normalize "$repo_path/Projects/$project_name/"]
  set do_compile 1
  set do_synthesis 1
  set do_implementation 1
  set do_bitstream 1
  set recreate 0
  set reset 0
  set check_syntax 0
  set ip_path ""
  set ext_path ""
}

set argv ""

if { $options(no_bitstream) == 1 } {
  set do_compile 0
  set do_bitstream 0
}

if { $options(recreate) == 1 } {
  set recreate 1
}

if { $options(synth_only) == 1 } {
  set do_compile 0
  set do_implementation 0
}

if { $options(impl_only) == 1 } {
  set do_compile 0
  set do_synthesis 0
}

if { $options(check_syntax) == 1 } {
  set check_syntax 1
}

if { $options(verbose) == 1 } {
  variable ::DEBUG_MODE 1
}

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

if { $proj_found == 0 || $recreate == 1 } {
  Msg Info "Creating (possibly replacing) the project $project_name..."
  lassign [GetConfFiles $repo_path/Top/$project_name] conf sim pre post tcl_file

  if {[file exists $conf]} {
    CreateProject $project_name

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
set describe [GetHogDescribe $sha]
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

    #if {[catch {execute_module -tool eda} result]} {
    #   Msg Error "Result: $result\n"
    #   Msg Error "EDA Netlist Writer failed. See the report file.\n"
    # } else {
    #   Msg Info "EDA Netlist Writer was successfully run for revision $revision.\n"
    # }
  }
}

# close project
project_close

Msg Info "All done."
cd $old_path
return 0
