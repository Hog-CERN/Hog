#quartus

#   Copyright 2018-2021 The University of Birmingham
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


############# modify these to match project ################

### FPGA
set FPGA <device_code>
set FAMILY <device_family>

#Simulation setup
#Simulator indicates the default simulator to be used to run the simulation sets.
#It can be either "questa" or "modelsim"
set SIMULATOR <default_simulator>

set BIN_FILE 0

### Vivado strategies and flows: to be left empty for Quartus projects
set SYNTH_STRATEGY ""
set SYNTH_FLOW ""
set IMPL_STRATEGY ""
set IMPL_FLOW ""

### Project name and repository path
set DESIGN    "[file rootname [file tail [info script]]]"
set PATH_REPO "[file normalize [file dirname [info script]]]/../../"

#launch project creation
source $PATH_REPO/Hog/Tcl/create_project.tcl
