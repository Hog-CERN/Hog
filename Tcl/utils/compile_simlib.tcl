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
# Compiles Simulation libraries

if {[catch {package require cmdline} ERROR]} {
  puts "$ERROR\n If you are running this script on tclsh, you can fix this by installing 'tcllib'"
  return
}

set parameters {
  {simulator.arg  "Target simulator, for which you want to compile the simulation libraries."}
  {output_dir.arg "Output directory for the compiled simulation libraries."}
}

set usage "Compile the simulation libraries for the target simulator - USAGE: compile_simlib.tcl \[options\]"

if {[catch {array set options [cmdline::getoptions ::argv $parameters $usage]}]} {
  Msg Info [cmdline::usage $parameters $usage]
  exit 1
}

if { $options(simulator) != "" } {
  set simulator $options(simulator)
} else {
  Msg Error "No simulator has been selected. Exiting..."
  exit 1
}

if { $options(output_dir) != "" } {
  set output_dir $options(output_dir)
} else {
  Msg Info "No output_dir has been defined. Using default: SimulationLib/"
  set output_dir "SimulationLib"
}

set repo_path [pwd]
cd $repo_path/..
compile_simlib -simulator $simulator -family all -language all -library all -dir $output_dir