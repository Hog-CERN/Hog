#   Copyright 2018-2020 The University of Birmingham
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




proc LaunchQuartus {} {
  #parsing command options
  if { [catch {package require cmdline} ERROR] } {
    puts "$ERROR\n If you are running this script on tclsh, you can fix this by installing 'tcllib'"
    return 1
  }
  set parameters{\
    {NJOBS.arg  4 "Number of jobs. Default: 4"}\
    {synth        "Run Analysis & Synthesis for the current project"}\
    {impl         "Run Place & Route for the current project"}\
    {gen_bit      "Run Generate bitstream for the current project"}\
    {add          "Run synthesys for the current project"}
  }

  set usage   "USAGE: $::argv0 <project>"
  set path [file normalize "[file dirname [info script]]/.."]

  set old_path [pwd]
  cd $path
  source ./hog.tcl

  if {[catch {array set options [cmdline::getoptions ::argv $parameters $usage]}] || $::argc eq 0 } {
    Msg Info [cmdline::usage $parameters $usage]
    cd $old_path
    return 1
  } else {
    set project [lindex $argv 0]
    set project_path [file normalize "$path/../../QuartusProject/$project/"]
    cd $project_path
  }

  # Open the project
  if { [catch {package require ::quartus::project} ERROR] } {
    puts "$ERROR\n Can not find package ::quartus::project"
    cd $old_path
    return 1
  }  
  if { [catch {project_open $project } ERROR] } 
  {
    puts "$ERROR\n Can not find open project ../../QuartusProject/$project/$project.qpf"
    cd $old_path
    return 1
  }

  Msg Info "Number of jobs set to $options(NJOBS)."
  set_global_assignment -name NUM_PARALLEL_PROCESSORS $options(NJOBS)

  load_package flow 

  # keep track of the current revision and of the top level entity name
  set top_level_name [ get_global_assignment -name TOP_LEVEL_ENTITY ]
  set original_revision [get_current_revision]
  # do stuff foreach revision
  foreach revision [get_project_revisions] 
  {
    set_current_revision $revision 
    #Analysis and Synthesis
    if{ $options(synth) || $options(impl)  || $options(gen_bit)  }{
      if {[catch {execute_module -tool map -args "--parallel"} result]} {
        puts "\nResult: $result\n"
        puts "ERROR: Analysis & Synthesis failed. See the report file.\n"
      } else {
        puts "\nINFO: Analysis & Synthesis was successful for revision $revision.\n"
      }
    }
    #Analysis and Synthesis
    if{ $options(impl) || $options(gen_bit) }{
      if {[catch {execute_module -tool fit} result]} {
        puts "\nResult: $result\n"
        puts "ERROR: Place & Route failed. See the report file.\n"
      } else {
        puts "\nINFO: Place & Route was successful for revision $revision.\n"
      } 
    }
    #Generate bitstream
    if{ $options(gen_bit) }{
      if {[catch {execute_module -tool asm} result]} {
        puts "\nResult: $result\n"
        puts "ERROR: Generate bitstream failed. See the report file.\n"
      } else {
        puts "\nINFO: Generate bitstream was successful for revision $revision.\n"
      } 
    }
    #Additional tools to be run on the project
    if{ $options(add) }{
      if {[catch {execute_module -tool sta} result]} {
        puts "\nResult: $result\n"
        puts "ERROR: Time Quest failed. See the report file.\n"
      } else {
        puts "\nINFO: Time Quest was successfully run for revision $revision.\n"
      } 

      if {[catch {execute_module -tool eda} result]} {
        puts "\nResult: $result\n"
        puts "ERROR: EDA Netlist Writer failed. See the report file.\n"
      } else {
        puts "\nINFO: EDA Netlist Writer was successfully run for revision $revision.\n"
      } 

    }

  } 
  set_current_revision $original_revision 
  # close project
  project_close

  Msg Info "All done."
  cd $old_path
  return 0
}
