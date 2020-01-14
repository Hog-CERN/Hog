## Define the following variables before sourcing this script:
#
# set bin_file 1
# set use_questa_simulator 1
# 
# ## FPGA and Vivado strategies and flows
# set FPGA xc7vx550tffg1927-2
# set SYNTH_STRATEGY "Vivado Synthesis Defaults" 
# set SYNTH_FLOW {Vivado Synthesis 2016}
# set IMPL_STRATEGY "Vivado Implementation Defaults"
# set IMPL_FLOW {Vivado Implementation 2016}
# set PROPERTIES [dict create synth_1 [dict create opt_speed true opt_area false] impl_1 [dict create keep_registers true retiming true]]

############################################################

#####################
# DERIVED VARIABLES #
#####################

set tcl_path         [file normalize "[file dirname [info script]]"]
source $tcl_path/hog.tcl

DeriveVariables $DESIGN
if {[info exists FAMILY]} {
    CreateProject $DESIGN $FPGA $FAMILY
} else {
    CreateProject $DESIGN $FPGA
}

configureSynth $DESIGN
configureImpl $DESIGN
configureSimulation $DESIGN
configureProperties $DESIGN
upgradeIP $DESIGN
##############
#    RUNS    #
##############

Msg Info "Project $DESIGN created succesfully"
