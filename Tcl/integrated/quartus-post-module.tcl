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

set tcl_path [file normalize "[file dirname [info script]]/.."]
set rev_name  [lindex $quartus(args) 2]
set proj_name [lindex $quartus(args) 1]
set stage     [lindex $quartus(args) 0]

if stage == "compile" {
  quartus_sh -t "$tcl_path/integrated/post-bitstream.tcl" stage proj_name rev_name
}
