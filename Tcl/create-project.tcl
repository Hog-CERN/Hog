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
CreateProject $DESIGN $FPGA


##############
#    RUNS    #
##############

### SYNTH ###

proc configureSynth {} {

	if {[info commands send_msg_id] != ""} {
		#VIVADO ONLY
		## Create 'synthesis ' run (if not found)
		if {[string equal [get_runs -quiet synth_1] ""]} {
			create_run -name synth_1 -part $FPGA -flow $SYNTH_FLOW -strategy $SYNTH_STRATEGY -constrset constrs_1
		} else {
			set_property strategy $SYNTH_STRATEGY [get_runs synth_1]
			set_property flow $SYNTH_FLOW [get_runs synth_1]
		}

		set obj [get_runs synth_1]
		set_property "part" $FPGA $obj
	}

	## set pre synthesis script
	if {$pre_synth_file ne ""} { 
		if {[info commands send_msg_id] != ""} {
			#Vivado Only
			set_property STEPS.SYNTH_DESIGN.TCL.PRE $pre_synth $obj
		} else if {[info commands project_new] != ""} {
			#QUARTUS only
			set_global_assignment -name PRE_FLOW_SCRIPT_FILE quartus_sh:$pre_synth

		} else {
			Msg info "Configuring $pre_synth script before syntesis"
		}
	}

	## set post synthesis script
	if {$post_synth_file ne ""} { 
		if {[info commands send_msg_id] != ""} {
			#Vivado Only
			set_property STEPS.SYNTH_DESIGN.TCL.POST $post_synth $obj
		} else if {[info commands project_new] != ""} {
			#QUARTUS only
			set_global_assignment -name POST_MODULE_SCRIPT_FILE quartus_sh:$post_synth

		} else {
			Msg info "Configuring $post_synth script after syntesis"
		}
	} 

	
	if {[info commands send_msg_id] != ""} {
		#VIVADO ONLY
		## set the current synth run
		current_run -synthesis $obj

		## Report Strategy
		if {[string equal [get_property -quiet report_strategy $obj] ""]} {
			# No report strategy needed
			Msg Info "No report strategy needed for syntesis"
			
		} else {
			# Report strategy needed since version 2017.3
			set_property -name "report_strategy" -value "Vivado Synthesis Default Reports" -objects $obj

			set reports [get_report_configs -of_objects $obj]
			if { [llength $reports ] > 0 } {
			delete_report_config [get_report_configs -of_objects $obj]
			}
		}
	} else if {[info commands project_new] != ""} {
		#QUARTUS only
		#TO BE DONE

	} else {
		Msg info "Reporting strategy for syntesis"
	}
} 

proc configureImpl {} {
	if {[info commands send_msg_id] != ""} {
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
	}

	## set post routing script
	if {$post_impl_file ne ""} { 
		if {[info commands send_msg_id] != ""} {
			#Vivado Only
			set_property STEPS.ROUTE_DESIGN.TCL.POST $post_impl $obj
		} else if {[info commands project_new] != ""} {
			#QUARTUS only
			set_global_assignment -name POST_MODULE_SCRIPT_FILE quartus_sh:$post_impl

		} else {
			Msg info "Configuring $post_impl script after implementation"
		}
	} 

	## set post write bitstream script
	if {$post_bit_file ne ""} { 
		if {[info commands send_msg_id] != ""} {
			#Vivado Only
			set_property STEPS.WRITE_BITSTREAM.TCL.POST $post_bit $obj
		} else if {[info commands project_new] != ""} {
			#QUARTUS only
			set_global_assignment -name POST_FLOW_SCRIPT_FILE quartus_sh:$post_bit

		} else {
			Msg info "Configuring $post_bit script after bitfile generation"
		}
	}

	CreateReportStrategy $DESIGN $obj
}





if {[info commands send_msg_id] != ""} {

	##############
	# SIMULATION #
	##############
	Msg Info "Setting load_glbl parameter to false for every fileset..."
	foreach f [get_filesets -quiet *_sim] {
		set_property -name {xsim.elaborate.load_glbl} -value {false} -objects $f
	}

	##################
	# RUN PROPERTIES #
	##################
	if [info exists PROPERTIES] {
		foreach run [get_runs -quiet] {
		if [dict exists $PROPERTIES $run] {
			Msg Info "Setting properties for run: $run..."
			set run_props [dict get $PROPERTIES $run]
			dict for {prop_name prop_val} $run_props {
			Msg Info "Setting $prop_name = $prop_val"
			set_property $prop_name $prop_val $run
			}
		}
		}
	}




	# set the current impl run
	current_run -implementation [get_runs impl_1]


	##############
	# UPGRADE IP #
	##############
	Msg Info "Upgrading IPs if any..."
	set ips [get_ips *]
	if {$ips != ""} {
		upgrade_ip $ips
	}
}

Msg Info "Project $DESIGN created succesfully"
