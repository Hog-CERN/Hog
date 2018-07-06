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

############################################################

#####################
# DERIVED VARIABLES #
#####################

set pre_synth_file  "pre-synthesis.tcl"
set post_synth_file ""
set post_impl_file  ""
set post_bit_file   "post-bitstream.tcl"

set tcl_path         [file normalize [file dirname [info script]]]
set repo_path        [file normalize "$tcl_path/../../"]
set top_path         "$repo_path/Top/$DESIGN"
set list_path        "$top_path/list"
set BUILD_DIR        "$repo_path/VivadoProject/$DESIGN"
set modelsim_path    "$repo_path/ModelsimLib"
set synth_top_module "top_$DESIGN"
set synth_top_file   "$top_path/top_$DESIGN.vhd"

set pre_synth  [file normalize "$tcl_path/$pre_synth_file"]
set post_synth [file normalize "$tcl_path/$post_synth_file"]
set post_impl  [file normalize "$tcl_path/$post_impl_file"]
set post_bit   [file normalize "$tcl_path/$post_bit_file"]

source $tcl_path/hog.tcl

## Create Project
create_project -force $DESIGN $BUILD_DIR -part $FPGA

## Set project properties
set obj [get_projects $DESIGN]
set_property "simulator_language" "Mixed" $obj
set_property "target_language" "VHDL" $obj
set_property "compxlib.modelsim_compiled_library_dir" $modelsim_path $obj
set_property "default_lib" "xil_defaultlib" $obj
if {$use_questa_simulator == 1} { 
    set_property "target_simulator" "ModelSim" $obj
}
## Enable VHDL 2008
set_param project.enableVHDL2008 1
set_property "enable_vhdl_2008" 1 $obj

##############
# SYNTHESIS  #
##############
## Create fileset src
if {[string equal [get_filesets -quiet sources_1] ""]} {
  create_fileset -srcset sources_1
}
set sources [get_filesets sources_1]

## Set synthesis TOP
add_files -norecurse -fileset $sources $synth_top_file
set_property "top" $synth_top_module $sources


###############
# CONSTRAINTS #
###############
# Create 'constrs_1' fileset (if not found)
if {[string equal [get_filesets -quiet constrs_1] ""]} {
  create_fileset -constrset constrs_1
}

# Set 'constrs_1' fileset object
set constraints [get_filesets constrs_1]


##############
# READ FILES #
##############
set list_files [glob -directory $list_path "*"]
foreach f $list_files {
    SmartListFile $f $top_path
}


##############
#    RUNS    #
##############

### SYNTH ###

## Create 'synthesis ' run (if not found)
if {[string equal [get_runs -quiet synth_1] ""]} {
    create_run -name synth_1 -part $FPGA -flow $SYNTH_FLOW -strategy $SYNTH_STRATEGY -constrset constrs_1
} else {
    set_property strategy $SYNTH_STRATEGY [get_runs synth_1]
    set_property flow $SYNTH_FLOW [get_runs synth_1]
}

set obj [get_runs synth_1]
set_property "part" $FPGA $obj
## set pre synthesis script
if {$pre_synth_file ne ""} { 
    set_property STEPS.SYNTH_DESIGN.TCL.PRE $pre_synth $obj
}
## set post synthesis script
if {$post_synth_file ne ""} { 
    set_property STEPS.SYNTH_DESIGN.TCL.POST $post_synth $obj
}
## set the current synth run
current_run -synthesis $obj

## Report Strategy (Uncomment for a post synthesis utilization report)
#if {[string equal [get_property -quiet report_strategy $obj] ""]} {
#    # No report strategy needed
#    Info CreateProject 0 "No report strategy needed for syntesis"
#    
#} else {
#    # Report strategy needed since version 2017.3
#    set_property -name "report_strategy" -value "Vivado Synthesis Default Reports" -objects $obj
#
#    set reports [get_report_configs -of_objects $obj]
#    if { [llength $reports ] > 0 } {
#	delete_report_config [get_report_configs -of_objects $obj]
#    }
#    # Create 'synthesis_synth_report_utilization_0' report (if not found)
#    if { [ string equal [get_report_configs -of_objects [get_runs synth_1] synth_1_synth_report_utilization_0] "" ] } {
#	create_report_config -report_name synth_1_synth_report_utilization_0 -report_type report_utilization:1.0 -steps synth_design -runs synth_1
#    }
#    set obj [get_report_configs -of_objects [get_runs synth_1] synth_1_synth_report_utilization_0]
#    if { $obj != "" } {
#	
#    }
#}

### IMPL_1 ###
# Create 'impl_1' run (if not found)
if {[string equal [get_runs -quiet impl_1] ""]} {
    create_run -name impl_1 -part $FPGA -flow $IMPL_FLOW -strategy $IMPL_STRATEGY -constrset constrs_1 -parent_run synth_1
} else {
    set_property strategy $IMPL_STRATEGY [get_runs impl_1]
    set_property flow $IMPL_FLOW [get_runs impl_1]
}

set obj [get_runs impl_1]
set_property "part" $FPGA $obj

set_property "steps.write_bitstream.args.readback_file" "0" $obj
set_property "steps.write_bitstream.args.verbose" "0" $obj

## set binfile production
if {$bin_file == 1} {
    set_property "steps.write_bitstream.args.bin_file" "1" $obj
} else {
   set_property "steps.write_bitstream.args.bin_file" "0" $obj
}

## set post routing script
if {$post_impl_file ne ""} { 
    set_property STEPS.ROUTE_DESIGN.TCL.POST $post_impl $obj
}
## set post write bitstream script
if {$post_bit_file ne ""} { 
    set_property STEPS.WRITE_BITSTREAM.TCL.POST $post_bit $obj
}
## Report Strategy
if {[string equal [get_property -quiet report_strategy $obj] ""]} {
    # No report strategy needed
    Info CreateProject 1 "No report strategy needed for implementation"
    
} else {
    # Report strategy needed since version 2017.3
    set_property -name "report_strategy" -value "Vivado Implementation Default Reports" -objects $obj

    set reports [get_report_configs -of_objects $obj]
    if { [llength $reports ] > 0 } {
	delete_report_config [get_report_configs -of_objects $obj]
    }

    # Create 'impl_1_post_route_phys_opt_report_utilization_0' report (if not found)                                                                                            
    if { [ string equal [get_report_configs -of_objects [get_runs impl_1] impl_1_post_route_phys_opt_report_utilization_0] "" ] } {
	create_report_config -report_name impl_1_post_route_phys_opt_report_utilization_0 -report_type report_utilization:1.0 -steps post_route_phys_opt_design -runs impl_1
    }
    set obj [get_report_configs -of_objects [get_runs impl_1] impl_1_post_route_phys_opt_report_utilization_0]
    if { $obj != "" } {                                                                                                                                                       
	Info CreateProject 1 "Report utilization created successfully"
    }

    # Create 'impl_1_post_route_phys_opt_report_timing_summary_0' report (if not found)
    if { [ string equal [get_report_configs -of_objects [get_runs impl_1] impl_1_post_route_phys_opt_report_timing_summary_0] "" ] } {
	create_report_config -report_name impl_1_post_route_phys_opt_report_timing_summary_0 -report_type report_timing_summary:1.0 -steps post_route_phys_opt_design -runs impl_1
    }
    set obj [get_report_configs -of_objects [get_runs impl_1] impl_1_post_route_phys_opt_report_timing_summary_0]
    if { $obj != "" } {
	Info CreateProject 1 "Report timing summary created successfully"
    }
}

# set the current impl run
current_run -implementation [get_runs impl_1]

Info CreateProject 3 "Project $DESIGN created succesfully"
