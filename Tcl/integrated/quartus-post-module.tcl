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


# @file quartus-pre-flow.tcl
# The pre synthesis flow checks the status of your git repository and stores into a set of variables that are fed as genereics to the HDL project.
# This script is automatically integrated into the Vivado/Quartus workflow by the Create Project script.
#

set tcl_path  [file normalize "[file dirname [info script]]/.."]
if {[info procs Msg] == "" } {
  source $tcl_path/hog.tcl
}

set stage [lindex $quartus(args) 0]

if { [string compare $stage "quartus_map"] == 0 || [string compare $stage "quartus_syn"] == 0 } {
  set script_path [file normalize "$tcl_path/integrated/post-synthesis.tcl"]
} elseif { [string compare $stage "quartus_fit"] == 0 } {
  set script_path [file normalize "$tcl_path/integrated/post-implementation.tcl"]
} elseif { [string compare $stage "quartus_asm"] == 0 } {
  set script_path [file normalize "$tcl_path/integrated/post-bitstream.tcl"]
} else {
  Msg Info "Unsupported step: $stage"
  return 0
}

if [file exists $script_path] {
  source $script_path
} 


