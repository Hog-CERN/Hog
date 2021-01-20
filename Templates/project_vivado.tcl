#vivado

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
set BIN_FILE 1
### FPGA
set FPGA <device_code>
set FAMILY <device_family>
### Vivado strategies and flows
set SYNTH_STRATEGY "Flow_AreaOptimized_High"
set SYNTH_FLOW "Vivado Synthesis 2018"
set IMPL_STRATEGY "Performance_ExplorePostRoutePhysOpt"
set IMPL_FLOW "Vivado Implementation 2018"
### Set Vivado Runs Properties ###
#
# ATTENTION: The \ character must be the last one of each line
#
# The default Vivado run names are: synth_1 for synthesis and impl_1 for implementation.
#
# To find out the exact name and value of the property, use Vivado GUI to click on the checkbox you like.
# This will make Vivado run the set_property command in the Tcl console.
# Then copy and paste the name and the values from the Vivado Tcl console into the lines below.
set PROPERTIES [dict create \
		    synth_1 [dict create \
				] \
		    impl_1 [dict create \
			       ]\
		   ]
### Project name and repository path
set DESIGN    "[file rootname [file tail [info script]]]"
set PATH_REPO "[file normalize [file dirname [info script]]]/../../"

source $PATH_REPO/Hog/Tcl/create_project.tcl
