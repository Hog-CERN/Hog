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
