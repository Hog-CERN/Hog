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

#vivado

############# modify these to match project ################
set bin_file 1
set use_questa_simulator 0
### FPGA
set FPGA <device_code>
set FAMILY <device_family>
### Vivado strategies and flows
set SYNTH_STRATEGY "Flow_AreaOptimized_High"
set SYNTH_FLOW "Vivado Synthesis 2018"
set IMPL_STRATEGY "Performance_ExplorePostRoutePhysOpt"
set IMPL_FLOW "Vivado Implementation 2018"
### Project name and repository path
set DESIGN    "[file rootname [file tail [info script]]]"
set path_repo "[file normalize [file dirname [info script]]]/../../"
source $path_repo/HOG/Tcl/create_project.tcl
