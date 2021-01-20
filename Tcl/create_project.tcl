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

## @file create_project.tcl
#  @brief contains all functions needed to create a new project
#  @todo This file will need to be fully documented
#
# Define the following variables before sourcing this script:
#
# set BIN_FILE 1
#
# ## FPGA and Vivado strategies and flows
# set FPGA xc7vx550tffg1927-2
# set SYNTH_STRATEGY "Vivado Synthesis Defaults"
# set SYNTH_FLOW {Vivado Synthesis 2016}
# set IMPL_STRATEGY "Vivado Implementation Defaults"
# set IMPL_FLOW {Vivado Implementation 2016}
# set PROPERTIES [dict create synth_1 [dict create opt_speed true opt_area false] impl_1 [dict create keep_registers true retiming true]]

## @namespace globalSettings
# @brief Namespace of all the project settings
#
# Variables with capital letters are expected to be passed by the caller.
# Variables with samll letters are evaluated in the script defined in create_project.tcl
#
namespace eval globalSettings {
  variable FPGA

  variable SYNTH_STRATEGY
  variable FAMILY
  variable SYNTH_FLOW
  variable IMPL_STRATEGY
  variable IMPL_FLOW
  variable DESIGN
  variable PROPERTIES
  variable PATH_REPO
  variable BIN_FILE
  variable HOG_EXTERNAL_PATH
  variable SIMULATOR

  variable pre_synth_file
  variable post_synth_file
  variable pre_impl_file
  variable post_impl_file
  variable pre_bit_file
  variable post_bit_file
  variable quartus_post_module_file
  variable tcl_path
  variable repo_path
  variable top_path
  variable list_path
  variable build_dir
  variable modelsim_path
  variable top_name
  variable synth_top_module
  variable user_ip_repo

  variable pre_synth
  variable post_synth
  variable pre_impl
  variable post_impl
  variable pre_bit
  variable post_bit
  variable quartus_post_module
}

################# FUNCTIONS ################################
proc CreateProject {} {
  if {[info commands create_project] != ""} {

    #VIVADO_ONLY
    if {$globalSettings::top_name != $globalSettings::DESIGN} {
      Msg Info "This project has got a flavour, the top module name ($globalSettings::top_name) differs from the project name ($globalSettings::DESIGN)."
    }
    create_project -force $globalSettings::DESIGN $globalSettings::build_dir -part $globalSettings::FPGA

    ## Set project properties
    set obj [get_projects $globalSettings::DESIGN]
    set_property "target_language" "VHDL" $obj
    if { [string first PlanAhead [version] ] != 0} {
        set_property "simulator_language" "Mixed" $obj
        set_property "compxlib.modelsim_compiled_library_dir" $globalSettings::modelsim_path $obj
        set_property "compxlib.questa_compiled_library_dir" $globalSettings::modelsim_path $obj
        set_property "default_lib" "xil_defaultlib" $obj
        set_property "target_simulator" $globalSettings::SIMULATOR $obj
    }

        ## Enable VHDL 2008
    if { [string first PlanAhead [version] ] != 0} {
      set_param project.enableVHDL2008 1
      set_property "enable_vhdl_2008" 1 $obj
    }

    ## Setting user IP repository to default Hog directory
    if [file exists $globalSettings::user_ip_repo] {
      Msg Info "Found directory $globalSettings::user_ip_repo, setting it as user IP repository..."
      if { [string first PlanAhead [version]]==0 } {
        set_property  ip_repo_paths $globalSettings::user_ip_repo [current_fileset]
      } else  {
        set_property  ip_repo_paths $globalSettings::user_ip_repo [current_project]
      }
    } else {
      Msg Info "$globalSettings::user_ip_repo not found, no user IP repository will be set."
    }
  } elseif {[info commands project_new] != ""} {
    package require ::quartus::project
        #QUARTUS_ONLY
    if {[string equal $globalSettings::FAMILY "quartus_only"]} {
      Msg Error "You must specify a device Familty for Quartus"
    } else {
      file mkdir $globalSettings::build_dir
      cd $globalSettings::build_dir
      if {[is_project_open]} {
        project_close
      }

      file delete {*}[glob -nocomplain $globalSettings::DESIGN.q*]

      project_new -family $globalSettings::FAMILY -overwrite -part $globalSettings::FPGA  $globalSettings::DESIGN
      set_global_assignment -name ERROR_CHECK_FREQUENCY_DIVISOR 256
      set_global_assignment -name EDA_DESIGN_ENTRY_SYNTHESIS_TOOL "Precision Synthesis"
      set_global_assignment -name EDA_LMF_FILE mentor.lmf -section_id eda_design_synthesis
      set_global_assignment -name EDA_INPUT_DATA_FORMAT VQM -section_id eda_design_synthesis
      set_global_assignment -name EDA_SIMULATION_TOOL "QuestaSim (Verilog)"
      set_global_assignment -name EDA_TIME_SCALE "1 ps" -section_id eda_simulation
      set_global_assignment -name EDA_OUTPUT_DATA_FORMAT "VERILOG HDL" -section_id eda_simulation
      set_global_assignment -name VHDL_INPUT_VERSION VHDL_2008
      set_global_assignment -name PROJECT_OUTPUT_DIRECTORY output_files
    }
  } else {
    puts "Creating project for $globalSettings::DESIGN part $globalSettings::FPGA"
    puts "Configuring project settings:"
    puts "  - simulator_language: Mixed"
    puts "  - target_language: VHDL"
    puts "  - simulator: QuestaSim"
    puts "Adding IP directory \"$globalSettings::user_ip_repo\" to the project "
  }


    #ADD PROJECT FILES
  if {[info commands create_fileset] != ""} {
        #VIVADO_ONLY
        ## Create fileset src
    if {[string equal [get_filesets -quiet sources_1] ""]} {
      create_fileset -srcset sources_1
    }
    set sources [get_filesets sources_1]
  } else {
    set sources 0
  }


    ###############
    # CONSTRAINTS #
    ###############
  if {[info commands launch_chipscope_analyzer] != ""} {
        #VIVADO_ONLY
        # Create 'constrs_1' fileset (if not found)
    if {[string equal [get_filesets -quiet constrs_1] ""]} {
      create_fileset -constrset constrs_1
    }

        # Set 'constrs_1' fileset object
    set constraints [get_filesets constrs_1]
  }

    ##############
    # READ FILES #
    ##############
  set list_files [glob -directory $globalSettings::list_path "*"]

  if {[info commands create_fileset] != ""} {
  if { [string first PlanAhead [version]] == 0 } {
    set tcl_path         [file normalize "[file dirname [info script]]"]
    source $tcl_path/utils/cmdline.tcl
  }
}
  AddHogFiles {*}[GetHogFiles -ext_path $globalSettings::HOG_EXTERNAL_PATH -verbose $globalSettings::list_path]

  ## Set synthesis TOP
  SetTopProperty $globalSettings::synth_top_module $sources
}


## @brief Set Vivado Report strategy for implementation
#
#  @param[in] obj tghe projet object
#
proc CreateReportStrategy {obj} {
  if {[info commands create_report_config] != ""} {
  ## Viavado Report Strategy
    if {[string equal [get_property -quiet report_strategy $obj] ""]} {
      # No report strategy needed
      Msg Info "No report strategy needed for implementation"
    } else {
      # Report strategy needed since version 2017.3
      set_property set_report_strategy_name 1 $obj
      set_property report_strategy {Vivado Implementation Default Reports} $obj
      set_property set_report_strategy_name 0 $obj

      set reports [get_report_configs -of_objects $obj]
      # Create 'impl_1_place_report_utilization_0' report (if not found)
      if { [ string equal [get_report_configs -of_objects [get_runs impl_1] $globalSettings::DESIGN\_impl_1_place_report_utilization_0] "" ] } {
        create_report_config -report_name $globalSettings::DESIGN\_impl_1_place_report_utilization_0 -report_type report_utilization:1.0 -steps place_design -runs impl_1
      }
      set obj [get_report_configs -of_objects [get_runs impl_1] $globalSettings::DESIGN\_impl_1_place_report_utilization_0]
      if { $obj != "" } {

      }

      # Create 'impl_1_route_report_drc_0' report (if not found)
      if { [ string equal [get_report_configs -of_objects [get_runs impl_1] $globalSettings::DESIGN\_impl_1_route_report_drc_0] "" ] } {
        create_report_config -report_name $globalSettings::DESIGN\_impl_1_route_report_drc_0 -report_type report_drc:1.0 -steps route_design -runs impl_1
      }
      set obj [get_report_configs -of_objects [get_runs impl_1] $globalSettings::DESIGN\_impl_1_route_report_drc_0]
      if { $obj != "" } {

      }

      # Create 'impl_1_route_report_power_0' report (if not found)
      if { [ string equal [get_report_configs -of_objects [get_runs impl_1] $globalSettings::DESIGN\_impl_1_route_report_power_0] "" ] } {
        create_report_config -report_name $globalSettings::DESIGN\_impl_1_route_report_power_0 -report_type report_power:1.0 -steps route_design -runs impl_1
      }
      set obj [get_report_configs -of_objects [get_runs impl_1] $globalSettings::DESIGN\_impl_1_route_report_power_0]
      if { $obj != "" } {

      }

      # Create 'impl_1_route_report_timing_summary' report (if not found)
      if { [ string equal [get_report_configs -of_objects [get_runs impl_1] $globalSettings::DESIGN\_impl_1_route_report_timing_summary] "" ] } {
        create_report_config -report_name $globalSettings::DESIGN\_impl_1_route_report_timing_summary -report_type report_timing_summary:1.0 -steps route_design -runs impl_1
      }
      set obj [get_report_configs -of_objects [get_runs impl_1] $globalSettings::DESIGN\_impl_1_route_report_timing_summary]
      if { $obj != "" } {
        Msg Info "Report timing created successfully"
      }

      # Create 'impl_1_route_report_utilization' report (if not found)
      if { [ string equal [get_report_configs -of_objects [get_runs impl_1] $globalSettings::DESIGN\_impl_1_route_report_utilization] "" ] } {
        create_report_config -report_name $globalSettings::DESIGN\_impl_1_route_report_utilization -report_type report_utilization:1.0 -steps route_design -runs impl_1
      }
      set obj [get_report_configs -of_objects [get_runs impl_1] $globalSettings::DESIGN\_impl_1_route_report_utilization]
      if { $obj != "" } {
        Msg Info "Report utilization created successfully"
      }


      # Create 'impl_1_post_route_phys_opt_report_timing_summary_0' report (if not found)
      if { [ string equal [get_report_configs -of_objects [get_runs impl_1] $globalSettings::DESIGN\_impl_1_post_route_phys_opt_report_timing_summary_0] "" ] } {
        create_report_config -report_name $globalSettings::DESIGN\_impl_1_post_route_phys_opt_report_timing_summary_0 -report_type report_timing_summary:1.0 -steps post_route_phys_opt_design -runs impl_1
      }
      set obj [get_report_configs -of_objects [get_runs impl_1] $globalSettings::DESIGN\_impl_1_post_route_phys_opt_report_timing_summary_0]
      if { $obj != "" } {
        set_property -name "options.max_paths" -value "10" -objects $obj
        set_property -name "options.warn_on_violation" -value "1" -objects $obj
      }

    }
  } else {
    puts "Won't create any report strategy, not in Vivado"
  }
}


## @brief configure synthesis.
#
# The method uses the content of globalSettings::SYNTH_FLOW and globalSettings::SYNTH_STRATEGY to set the implementation strategy and flow.
# The function also sets Hog specific pre and post synthesis scripts
#
proc ConfigureSynthesis {} {
  if {[info commands send_msg_id] != ""} {
        #VIVADO ONLY
        ## Create 'synthesis ' run (if not found)
    if {[string equal [get_runs -quiet synth_1] ""]} {
      create_run -name synth_1 -part $globalSettings::FPGA -flow $globalSettings::SYNTH_FLOW -strategy $globalSettings::SYNTH_STRATEGY -constrset constrs_1
    } else {
      set_property strategy $globalSettings::SYNTH_STRATEGY [get_runs synth_1]
      set_property flow $globalSettings::SYNTH_FLOW [get_runs synth_1]
    }

    set obj [get_runs synth_1]
    set_property "part" $globalSettings::FPGA $obj
  }

    ## set pre synthesis script
  if {$globalSettings::pre_synth_file ne ""} {
    if {[info commands send_msg_id] != ""} {
            #Vivado Only
        if { [string first PlanAhead [version] ] != 0 } {
	  if {[get_filesets -quiet utils_1] != ""} {
	    AddFile $globalSettings::pre_synth [get_filesets -quiet utils_1]
	  }
	  set_property STEPS.SYNTH_DESIGN.TCL.PRE $globalSettings::pre_synth $obj
        }
    } elseif {[info commands project_new] != ""} {
            #QUARTUS only
      set_global_assignment -name PRE_FLOW_SCRIPT_FILE quartus_sh:$globalSettings::pre_synth

    }

    Msg Info "Setting $globalSettings::pre_synth to be run before synthesis"
  }

    ## set post synthesis script
  if {$globalSettings::post_synth_file ne ""} {
    if {[info commands send_msg_id] != ""} {
        #Vivado Only
        if { [string first PlanAhead [version] ] !=0 } {
	  if {[get_filesets -quiet utils_1] != ""} {
	    AddFile $globalSettings::post_synth [get_filesets -quiet utils_1]
	  }
	  set_property STEPS.SYNTH_DESIGN.TCL.POST $globalSettings::post_synth $obj
        }
    } elseif {[info commands project_new] != ""} {
      #QUARTUS only
      set_global_assignment -name POST_MODULE_SCRIPT_FILE quartus_sh:$globalSettings::quartus_post_module

    }
    Msg Info "Setting $globalSettings::post_synth to be run after synthesis"
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
      set_property set_report_strategy_name 1 $obj
      set_property report_strategy {Vivado Synthesis Default Reports} $obj
      set_property set_report_strategy_name 0 $obj
            # Create 'synth_1_synth_report_utilization_0' report (if not found)
      if { [ string equal [get_report_configs -of_objects [get_runs synth_1] synth_1_synth_report_utilization_0] "" ] } {
        create_report_config -report_name synth_1_synth_report_utilization_0 -report_type report_utilization:1.0 -steps synth_design -runs synth_1
      }
      set reports [get_report_configs -of_objects [get_runs synth_1] synth_1_synth_report_utilization_0]
    }
  } elseif {[info commands project_new] != ""} {
        #QUARTUS only
        #TO BE DONE

  } else {
    Msg info "Reporting strategy for syntesis"
  }
}

## @brief configure implementation.
#
# The configuration is based on the content of globalSettings::IMPL_FLOW and globalSettings::IMPL_STRATEGY
# The function also stes Hog spoecific pre and post implementation and, pre and post implementation  scripts
#
proc ConfigureImplementation {} {
  if {[info commands send_msg_id] != ""} {
        # Create 'impl_1' run (if not found)
    if {[string equal [get_runs -quiet impl_1] ""]} {
      create_run -name impl_1 -part $globalSettings::FPGA -flow $globalSettings::IMPL_FLOW -strategy $globalSettings::IMPL_STRATEGY -constrset constrs_1 -parent_run synth_1
    } else {
      set_property strategy $globalSettings::IMPL_STRATEGY [get_runs impl_1]
      set_property flow $globalSettings::IMPL_FLOW [get_runs impl_1]
    }

    set obj [get_runs impl_1]
    set_property "part" $globalSettings::FPGA $obj

    set_property "steps.write_bitstream.args.readback_file" "0" $obj
    set_property "steps.write_bitstream.args.verbose" "0" $obj

    ## set binfile production
    if { [string first PlanAhead [version] ] !=0 } {
        if {$globalSettings::BIN_FILE == 1} {
            set_property "steps.write_bitstream.args.BIN_FILE" "1" $obj
        } else {
            set_property "steps.write_bitstream.args.BIN_FILE" "0" $obj
        }
    }
  } elseif {[info commands project_new] != ""} {
            #QUARTUS only
    set obj ""
  }


	## set pre implementation script
  if {$globalSettings::pre_impl_file ne ""} {
    if {[info commands send_msg_id] != ""} {
      #Vivado Only
      if { [string first PlanAhead [version] ] != 0 } {
	if {[get_filesets -quiet utils_1] != ""} {
	  AddFile $globalSettings::pre_impl [get_filesets -quiet utils_1]
	}
	set_property STEPS.INIT_DESIGN.TCL.POST $globalSettings::pre_impl $obj
      }
    } elseif {[info commands project_new] != ""} {
      #QUARTUS only
      #set_global_assignment -name PRE_FLOW_SCRIPT_FILE quartus_sh:$globalSettings::pre_impl

    }
    Msg info "Setting $globalSettings::pre_impl to be run after implementation"
  }


  ## set post routing script
  if {$globalSettings::post_impl_file ne ""} {
    if {[info commands send_msg_id] != ""} {
      #Vivado Only
      if { [string first PlanAhead [version] ] != 0} {
	if {[get_filesets -quiet utils_1] != ""} {
	  AddFile $globalSettings::post_impl [get_filesets -quiet utils_1]
	}
	set_property STEPS.ROUTE_DESIGN.TCL.POST $globalSettings::post_impl $obj
      }
    } elseif {[info commands project_new] != ""} {
      #QUARTUS only
      set_global_assignment -name POST_MODULE_SCRIPT_FILE quartus_sh:$globalSettings::quartus_post_module
    }
    Msg info "Setting $globalSettings::post_impl to be run after implementation"
  }

	## set pre write bitstream script
  if {$globalSettings::pre_bit_file ne ""} {
    if {[info commands send_msg_id] != ""} {
      #Vivado Only
      if { [string first PlanAhead [version] ] != 0} {
	if {[get_filesets -quiet utils_1] != ""} {
	  AddFile $globalSettings::pre_bit [get_filesets -quiet utils_1]
	}
        set_property STEPS.WRITE_BITSTREAM.TCL.PRE $globalSettings::pre_bit $obj
      }
    } elseif {[info commands project_new] != ""} {
      #QUARTUS only
      #set_global_assignment -name PRE_FLOW_SCRIPT_FILE quartus_sh:$globalSettings::pre_bit

    }
    Msg info "Setting $globalSettings::pre_bit to be run after bitfile generation"
  }

    ## set post write bitstream script
  if {$globalSettings::post_bit_file ne ""} {
    if {[info commands send_msg_id] != ""} {
            #Vivado Only
      if { [string first PlanAhead [version] ] != 0 } {
	if {[get_filesets -quiet utils_1] != ""} {
	  AddFile $globalSettings::post_bit [get_filesets -quiet utils_1]
	}
	set_property STEPS.WRITE_BITSTREAM.TCL.POST $globalSettings::post_bit $obj
      }
    } elseif {[info commands project_new] != ""} {
      #QUARTUS only
      set_global_assignment -name POST_MODULE_SCRIPT_FILE quartus_sh:$globalSettings::quartus_post_module
    }
    Msg info "Setting $globalSettings::post_bit to be run after bitfile generation"
  }

  CreateReportStrategy $obj
}


## @brief configure simulation
#
proc ConfigureSimulation {} {
  if {[info commands send_msg_id] != ""} {

        ##############
        # SIMULATION #
        ##############
    Msg Info "Setting load_glbl parameter to true for every fileset..."
    foreach f [get_filesets -quiet *_sim] {
      set_property -name {xsim.elaborate.load_glbl} -value {true} -objects $f
    }
  }  elseif {[info commands project_new] != ""} {
            #QUARTUS only
            #TO BE DONE

  } else {
    Msg info "Configuring simulation"
  }
}

## @brief uses the content of globalSettings::PROPERTIES to set additional project properties
#
proc ConfigureProperties {} {
  if {[info commands send_msg_id] != ""} {
        ##################
        # RUN PROPERTIES #
        ##################
    if [info exists globalSettings::PROPERTIES] {
      foreach run [get_runs -quiet] {
        if [dict exists $globalSettings::PROPERTIES $run] {
          Msg Info "Setting properties for run: $run..."
          set run_props [dict get $globalSettings::PROPERTIES $run]
          dict for {prop_name prop_val} $run_props {
            Msg Info "Setting $prop_name = $prop_val"
            set_property $prop_name $prop_val $run
          }
        }
      }
    }
  }  elseif {[info commands project_new] != ""} {
        #QUARTUS only
        #TO BE DONE
  } else {
    Msg info "Configuring Properties"
  }
}

## @brief upgrade IPs in the project
#
proc UpgradeIP {} {
  if {[info commands send_msg_id] != ""} {
    # set the current impl run
    current_run -implementation [get_runs impl_1]


        ##############
        # UPGRADE IP #
        ##############
    Msg Info "Upgrading IPs if any..."
    set ips [get_ips *]
    if {$ips != ""} {
      upgrade_ip -quiet $ips
    }
  } elseif {[info commands project_new] != ""} {
            #QUARTUS only
            #TO BE DONE

  } else {
    Msg info "Upgrading IPs"
  }
}

###########################################################################################################################################################################################


#IMPLEMENT SETTINGS NAMESPACE
set tcl_path         [file normalize "[file dirname [info script]]"]
source $tcl_path/hog.tcl

#this PATH_REPO should be done better
set globalSettings::PATH_REPO $::PATH_REPO

set globalSettings::FPGA $::FPGA

set globalSettings::SYNTH_STRATEGY $::SYNTH_STRATEGY
if {[info exists ::FAMILY]} {
  set globalSettings::FAMILY $::FAMILY
}
set globalSettings::SYNTH_FLOW $::SYNTH_FLOW
set globalSettings::IMPL_STRATEGY $::IMPL_STRATEGY
set globalSettings::IMPL_FLOW $::IMPL_FLOW
set globalSettings::DESIGN $::DESIGN
if {[info exists ::SIMULATOR]} {
  set globalSettings::SIMULATOR $::SIMULATOR
} else {
  set globalSettings::SIMULATOR "ModelSim"
}

if {[info exists env(HOG_EXTERNAL_PATH)]} {
  set globalSettings::HOG_EXTERNAL_PATH $env(HOG_EXTERNAL_PATH)
} else {
  set globalSettings::HOG_EXTERNAL_PATH ""
}

if {[info exist ::BIN_FILE]} {
  set globalSettings::BIN_FILE $::BIN_FILE
} else {
  set globalSettings::BIN_FILE 0
}
if {[info exists ::PROPERTIES]} {
  set globalSettings::PROPERTIES $::PROPERTIES
}

set build_dir_name "Projects"

#Derived varibles from now on...
set globalSettings::pre_synth_file              "pre-synthesis.tcl"
set globalSettings::post_synth_file             ""
set globalSettings::pre_impl_file               "pre-implementation.tcl"
set globalSettings::post_impl_file              "post-implementation.tcl"
set globalSettings::pre_bit_file                "pre-bitstream.tcl"
set globalSettings::post_bit_file               "post-bitstream.tcl"
set globalSettings::quartus_post_module_file    "quartus-post-module.tcl"
set globalSettings::tcl_path                    [file normalize "[file dirname [info script]]"]
set globalSettings::repo_path                   [file normalize "$globalSettings::tcl_path/../../"]
set globalSettings::top_path                    "$globalSettings::repo_path/Top/$DESIGN"
set globalSettings::list_path                   "$globalSettings::top_path/list"
set globalSettings::build_dir                   "$globalSettings::repo_path/$build_dir_name/$DESIGN"
set globalSettings::modelsim_path               "$globalSettings::repo_path/SimulationLib"
set globalSettings::top_name                    [file root $globalSettings::DESIGN]
set globalSettings::synth_top_module            "top_$globalSettings::top_name"
set globalSettings::user_ip_repo                "$globalSettings::repo_path/IP_repository"

set globalSettings::pre_synth           [file normalize "$globalSettings::tcl_path/integrated/$globalSettings::pre_synth_file"]
set globalSettings::post_synth          [file normalize "$globalSettings::tcl_path/integrated/$globalSettings::post_synth_file"]
set globalSettings::pre_impl            [file normalize "$globalSettings::tcl_path/integrated/$globalSettings::pre_impl_file"]
set globalSettings::post_impl           [file normalize "$globalSettings::tcl_path/integrated/$globalSettings::post_impl_file"]
set globalSettings::pre_bit             [file normalize "$globalSettings::tcl_path/integrated/$globalSettings::pre_bit_file"]
set globalSettings::post_bit            [file normalize "$globalSettings::tcl_path/integrated/$globalSettings::post_bit_file"]
set globalSettings::quartus_post_module [file normalize "$globalSettings::tcl_path/integrated/$globalSettings::quartus_post_module_file"]

CreateProject
ConfigureSynthesis
ConfigureImplementation
ConfigureSimulation
ConfigureProperties
UpgradeIP

##############
#    RUNS    #
##############

Msg Info "Project $DESIGN created succesfully"
