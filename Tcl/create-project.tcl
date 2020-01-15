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

#IMPLEMENT SETTINGS NAMESPACE
set tcl_path         [file normalize "[file dirname [info script]]"]
source $tcl_path/hog.tcl

#this path_repo should be done better
set globalSettings::path_repo $::path_repo

set globalSettings::FPGA $::FPGA

set globalSettings::SYNTH_STRATEGY $::SYNTH_STRATEGY
if {[info exists ::FAMILY]} {
	set globalSettings::FAMILY $::FAMILY
}
set globalSettings::SYNTH_FLOW $::SYNTH_FLOW
set globalSettings::IMPL_STRATEGY $::IMPL_STRATEGY
set globalSettings::IMPL_FLOW $::IMPL_FLOW
set globalSettings::DESIGN $::DESIGN


if {[info exist ::bin_file]} { 
    set globalSettings::bin_file $::bin_file
} else {
   set globalSettings::bin_file 0
}
if {[info exists ::PROPERTIES]} {
	set globalSettings::PROPERTIES $::PROPERTIES
}

#Derived varibles from now on...
set globalSettings::pre_synth_file   "pre-synthesis.tcl"
set globalSettings::post_synth_file  ""
set globalSettings::post_impl_file   "post-implementation.tcl"
set globalSettings::post_bit_file    "post-bitstream.tcl"
set globalSettings::tcl_path         [file normalize "[file dirname [info script]]"]
set globalSettings::repo_path        [file normalize "$globalSettings::tcl_path/../../"]
set globalSettings::top_path         "$globalSettings::repo_path/Top/$DESIGN"
set globalSettings::list_path        "$globalSettings::top_path/list"
set globalSettings::BUILD_DIR        "$globalSettings::repo_path/Project/$DESIGN"
set globalSettings::modelsim_path    "$globalSettings::repo_path/ModelsimLib"
set globalSettings::top_name          [file root $globalSettings::DESIGN]
set globalSettings::synth_top_module "top_$globalSettings::top_name"
set globalSettings::synth_top_file   "$globalSettings::top_path/top_$globalSettings::DESIGN"
set globalSettings::user_ip_repo     "$globalSettings::repo_path/IP_repository"


set globalSettings::pre_synth  [file normalize "$globalSettings::tcl_path/integrated/$globalSettings::pre_synth_file"]
set globalSettings::post_synth [file normalize "$globalSettings::tcl_path/integrated/$globalSettings::post_synth_file"]
set globalSettings::post_impl  [file normalize "$globalSettings::tcl_path/integrated/$globalSettings::post_impl_file"]
set globalSettings::post_bit   [file normalize "$globalSettings::tcl_path/integrated/$globalSettings::post_bit_file"]


CreateProject

configureSynth
configureImpl
configureSimulation
configureProperties
upgradeIP

##############
#    RUNS    #
##############

Msg Info "Project $DESIGN created succesfully"
