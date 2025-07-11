#   Copyright 2018-2025 The University of Birmingham
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


##nagelfar variable quartus

## @namespace globalSettings
# @brief Namespace of all the project settings
#
# Variables in upper case are expected to be passed by the caller.
# Variables lower case are evaluated in the script defined in create_project.tcl
#
namespace eval globalSettings {
  #The project name (including flavour if any)
  variable DESIGN

  variable PART

  # Quartus only
  variable FAMILY
  # Libero only
  variable DIE
  variable PACKAGE
  variable ADV_OPTIONS
  variable SPEED
  variable LIBERO_MANDATORY_VARIABLES
  # Diamond only
  variable DEVICE

  variable PROPERTIES
  variable HOG_EXTERNAL_PATH
  variable HOG_IP_PATH
  variable TARGET_SIMULATOR

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
  variable simlib_path
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
proc InitProject {} {
  if {[IsXilinx]} {
    if {[IsVivado]} {
      # Suppress unnecessary warnings
      # tclint-disable-next-line line-length
      set_msg_config -suppress -regexp -string {".*The IP file '.*' has been moved from its original location, as a result the outputs for this IP will now be generated in '.*'. Alternatively a copy of the IP can be imported into the project using one of the 'import_ip' or 'import_files' commands..*"}
      set_msg_config -suppress -regexp -string {".*File '.*.xci' referenced by design '.*' could not be found..*"}

      # File inside .bd
      set_msg_config -suppress -id {IP_Flow 19-3664}
      # This is due to simulations in project with NoC
      # tclint-disable-next-line line-length
      set_msg_config -suppress -id {Vivado 12-23660} -string {{ERROR: [Vivado 12-23660] Simulation is not supported for the target language VHDL when design contains NoC (Network-on-Chip) blocks} }
    }
    # Create project
    create_project -force [file tail $globalSettings::DESIGN] $globalSettings::build_dir -part $globalSettings::PART
    file mkdir "$globalSettings::build_dir/[file tail $globalSettings::DESIGN].gen/sources_1"
    if {[IsVersal $globalSettings::PART]} {
      Msg Info "This project uses a Versal device."
    }

    ## Set project properties
    set obj [get_projects [file tail $globalSettings::DESIGN]]
    set_property "target_language" "VHDL" $obj

    if {[IsVivado]} {
      set_property "simulator_language" "Mixed" $obj
      foreach simulator [GetSimulators] {
        set_property "compxlib.${simulator}_compiled_library_dir" $globalSettings::simlib_path $obj
      }
      set_property "default_lib" "xil_defaultlib" $obj
      ## Enable VHDL 2008
      set_param project.enableVHDL2008 1
      set_property "enable_vhdl_2008" 1 $obj
      ## Enable Automatic compile order mode, otherwise we cannot find the right top module...
      set_property source_mgmt_mode All [current_project]
      # Set PART Immediately
      Msg Debug "Setting PART = $globalSettings::PART"
      set_property PART $globalSettings::PART [current_project]
    }

    ConfigureProperties
  } elseif {[IsQuartus]} {
    package require ::quartus::project
    #QUARTUS_ONLY
    if {[string equal $globalSettings::FAMILY "quartus_only"]} {
      Msg Error "You must specify a device Family for Quartus"
    } else {
      file mkdir $globalSettings::build_dir
      cd $globalSettings::build_dir
      if {[is_project_open]} {
        project_close
      }

      file delete {*}[glob -nocomplain $globalSettings::DESIGN.q*]

      project_new -family $globalSettings::FAMILY -overwrite -part $globalSettings::PART $globalSettings::DESIGN
      set_global_assignment -name PROJECT_OUTPUT_DIRECTORY output_files

      ConfigureProperties
    }
  } elseif {[IsLibero]} {
    if {[file exists $globalSettings::build_dir]} {
      file delete -force $globalSettings::build_dir
    }
    new_project -location $globalSettings::build_dir \
                -name [file tail $globalSettings::DESIGN] \
                -die $globalSettings::DIE \
                -package $globalSettings::PACKAGE \
                -family $globalSettings::FAMILY \
                -hdl VHDL
  } elseif {[IsDiamond]} {
    if {[file exists $globalSettings::build_dir]} {
      file delete -force $globalSettings::build_dir
    }
    set old_dir [pwd]
    file mkdir $globalSettings::build_dir
    cd $globalSettings::build_dir
    prj_project new -name [file tail $globalSettings::DESIGN] -dev $globalSettings::DEVICE -synthesis $globalSettings::SYNTHESIS_TOOL
    cd $old_dir
    ConfigureProperties
  } else {
    puts "Creating project for $globalSettings::DESIGN part $globalSettings::PART"
    puts "Configuring project settings:"
    puts "  - simulator_language: Mixed"
    puts "  - target_language: VHDL"
    puts "  - simulator: QuestaSim"
    puts "Adding IP directory \"$globalSettings::user_ip_repo\" to the project "
  }
}

proc AddProjectFiles {} {
  if {[IsXilinx]} {
    #VIVADO_ONLY
    ## Create fileset src
    if {[string equal [get_filesets -quiet sources_1] ""]} {
      create_fileset -srcset sources_1
    }
    set sources "sources_1"
  } else {
    set sources 0
  }


  ###############
  # CONSTRAINTS #
  ###############
  if {[IsXilinx]} {
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

  if {[file isdirectory $globalSettings::list_path]} {
    set list_files [glob -directory $globalSettings::list_path "*"]
  } else {
    Msg Error "No list directory found at  $globalSettings::list_path"
  }

  if {[IsISE]} {
    source $globalSettings::tcl_path/utils/cmdline.tcl
  }

  # Add first .src, .sim, and .ext list files
  AddHogFiles {*}[GetHogFiles -list_files {.src,.sim,.ext} -ext_path $globalSettings::HOG_EXTERNAL_PATH $globalSettings::list_path $globalSettings::repo_path]

  ## Set synthesis TOP
  SetTopProperty $globalSettings::synth_top_module $sources

  # Libero needs the top files to be set before adding the constraints
  AddHogFiles {*}[GetHogFiles -list_files {.con} -ext_path $globalSettings::HOG_EXTERNAL_PATH $globalSettings::list_path $globalSettings::repo_path]
  ## Set simulation Properties

  ## Libero Properties must be set after that root has been defined
  if {[IsLibero]} {
    ConfigureProperties
  }
}


## @brief Set Vivado Report strategy for implementation
#
#  @param[in] obj the project object
#
proc CreateReportStrategy {obj} {
  #TODO: Add ReportStrategy for Quartus/Libero and Diamond

  if {[IsVivado]} {
    ## Vivado Report Strategy
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
      if {[string equal [get_report_configs -of_objects [get_runs impl_1] impl_1_place_report_utilization_0] ""]} {
        create_report_config -report_name impl_1_place_report_utilization_0 -report_type report_utilization:1.0 -steps place_design -runs impl_1
      }
      set obj [get_report_configs -of_objects [get_runs impl_1] impl_1_place_report_utilization_0]
      if {$obj != ""} {

      }

      # Create 'impl_1_route_report_drc_0' report (if not found)
      if {[string equal [get_report_configs -of_objects [get_runs impl_1] impl_1_route_report_drc_0] ""]} {
        create_report_config -report_name impl_1_route_report_drc_0 -report_type report_drc:1.0 -steps route_design -runs impl_1
      }
      set obj [get_report_configs -of_objects [get_runs impl_1] impl_1_route_report_drc_0]
      if {$obj != ""} {

      }

      # Create 'impl_1_route_report_power_0' report (if not found)
      if {[string equal [get_report_configs -of_objects [get_runs impl_1] impl_1_route_report_power_0] ""]} {
        create_report_config -report_name impl_1_route_report_power_0 -report_type report_power:1.0 -steps route_design -runs impl_1
      }
      set obj [get_report_configs -of_objects [get_runs impl_1] impl_1_route_report_power_0]
      if {$obj != ""} {

      }

      # Create 'impl_1_route_report_timing_summary' report (if not found)
      if {[string equal [get_report_configs -of_objects [get_runs impl_1] impl_1_route_report_timing_summary] ""]} {
        create_report_config -report_name impl_1_route_report_timing_summary -report_type report_timing_summary:1.0 -steps route_design -runs impl_1
      }
      set obj [get_report_configs -of_objects [get_runs impl_1] impl_1_route_report_timing_summary]
      if {$obj != ""} {
        Msg Info "Report timing created successfully"
      }

      # Create 'impl_1_route_report_utilization' report (if not found)
      if {[string equal [get_report_configs -of_objects [get_runs impl_1] impl_1_route_report_utilization] ""]} {
        create_report_config -report_name impl_1_route_report_utilization -report_type report_utilization:1.0 -steps route_design -runs impl_1
      }
      set obj [get_report_configs -of_objects [get_runs impl_1] impl_1_route_report_utilization]
      if {$obj != ""} {
        Msg Info "Report utilization created successfully"
      }


      # Create 'impl_1_post_route_phys_opt_report_timing_summary_0' report (if not found)
      if {[string equal [get_report_configs -of_objects [get_runs impl_1] impl_1_post_route_phys_opt_report_timing_summary_0] ""]} {
        create_report_config -report_name impl_1_post_route_phys_opt_report_timing_summary_0 \
          -report_type report_timing_summary:1.0 \
          -steps post_route_phys_opt_design -runs impl_1
      }
      set obj [get_report_configs -of_objects [get_runs impl_1] impl_1_post_route_phys_opt_report_timing_summary_0]
      if {$obj != ""} {
        set_property -name "options.max_paths" -value "10" -objects $obj
        set_property -name "options.warn_on_violation" -value "1" -objects $obj
      }
    }
  } else {
    Msg Info "Won't create any report strategy, not in Vivado"
  }
}


## @brief configure synthesis.
#
# The method uses the content of globalSettings::SYNTH_FLOW and globalSettings::SYNTH_STRATEGY to set the implementation strategy and flow.
# The function also sets Hog specific pre and post synthesis scripts
#
proc ConfigureSynthesis {} {
  if {[IsXilinx]} {
    #VIVADO ONLY
    ## Create 'synthesis ' run (if not found)
    if {[string equal [get_runs -quiet synth_1] ""]} {
      create_run -name synth_1 -part $globalSettings::PART -constrset constrs_1
    } else {

    }

    set obj [get_runs synth_1]
    set_property "part" $globalSettings::PART $obj
  }

  ## set pre synthesis script
  if {$globalSettings::pre_synth_file ne ""} {
    if {[IsXilinx]} {
      #Vivado Only
      if {[IsVivado]} {
        if {[get_filesets -quiet utils_1] != ""} {
          AddFile $globalSettings::pre_synth [get_filesets -quiet utils_1]
        }
        set_property STEPS.SYNTH_DESIGN.TCL.PRE $globalSettings::pre_synth $obj
      }
    } elseif {[IsQuartus]} {
      #QUARTUS only
      set_global_assignment -name PRE_FLOW_SCRIPT_FILE quartus_sh:$globalSettings::pre_synth
    } elseif {[IsLibero]} {
      configure_tool -name {SYNTHESIZE} -params SYNPLIFY_TCL_FILE:$globalSettings::pre_synth
    } elseif {[IsDiamond]} {
      prj_impl pre_script "syn" $globalSettings::pre_synth
    }

    Msg Debug "Setting $globalSettings::pre_synth to be run before synthesis"
  }

  ## set post synthesis script
  if {$globalSettings::post_synth_file ne ""} {
    if {[IsXilinx]} {
      #Vivado Only
      if {[IsVivado]} {
        if {[get_filesets -quiet utils_1] != ""} {
          AddFile $globalSettings::post_synth [get_filesets -quiet utils_1]
        }
        set_property STEPS.SYNTH_DESIGN.TCL.POST $globalSettings::post_synth $obj
      }
    } elseif {[IsQuartus]} {
      #QUARTUS only
      set_global_assignment -name POST_MODULE_SCRIPT_FILE quartus_sh:$globalSettings::quartus_post_module
    } elseif {[IsDiamond]} {
      prj_impl post_script "syn" $globalSettings::post_synth
    }
    Msg Debug "Setting $globalSettings::post_synth to be run after synthesis"
  }


  if {[IsXilinx]} {
    #VIVADO ONLY
    ## set the current synth run
    current_run -synthesis $obj

    ## Report Strategy
    if {[string equal [get_property -quiet report_strategy $obj] ""]} {
      # No report strategy needed
      Msg Debug "No report strategy needed for synthesis"
    } else {
      # Report strategy needed since version 2017.3
      set_property set_report_strategy_name 1 $obj
      set_property report_strategy {Vivado Synthesis Default Reports} $obj
      set_property set_report_strategy_name 0 $obj
      # Create 'synth_1_synth_report_utilization_0' report (if not found)
      if {[string equal [get_report_configs -of_objects [get_runs synth_1] synth_1_synth_report_utilization_0] ""]} {
        create_report_config -report_name synth_1_synth_report_utilization_0 -report_type report_utilization:1.0 -steps synth_design -runs synth_1
      }
      set reports [get_report_configs -of_objects [get_runs synth_1] synth_1_synth_report_utilization_0]
    }
  } elseif {[IsQuartus]} {
    #QUARTUS only
    #TO BE DONE
  } elseif {[IsLibero]} {
    #TODO: LIBERO
  } elseif {[IsDiamond]} {
    #TODO: Diamond
  } else {
    Msg info "Reporting strategy for synthesis"
  }
}

## @brief configure implementation.
#
# The configuration is based on the content of globalSettings::IMPL_FLOW and globalSettings::IMPL_STRATEGY
# The function also sets Hog specific pre- and- post implementation and, pre- and post- implementation  scripts
#
proc ConfigureImplementation {} {
  set obj ""
  if {[IsXilinx]} {
    # Create 'impl_1' run (if not found)
    if {[string equal [get_runs -quiet impl_1] ""]} {
      create_run -name impl_1 -part $globalSettings::PART -constrset constrs_1 -parent_run synth_1
    }

    set obj [get_runs impl_1]
    set_property "part" $globalSettings::PART $obj

    set_property "steps.[BinaryStepName $globalSettings::PART].args.readback_file" "0" $obj
    set_property "steps.[BinaryStepName $globalSettings::PART].args.verbose" "0" $obj
  } elseif {[IsQuartus]} {
    #QUARTUS only
    set obj ""
  }


  ## set pre implementation script
  if {$globalSettings::pre_impl_file ne ""} {
    if {[IsXilinx]} {
      #Vivado Only
      if {[IsVivado]} {
        if {[get_filesets -quiet utils_1] != ""} {
          AddFile $globalSettings::pre_impl [get_filesets -quiet utils_1]
        }
        set_property STEPS.INIT_DESIGN.TCL.POST $globalSettings::pre_impl $obj
      }
    } elseif {[IsQuartus]} {
      #QUARTUS only
      #set_global_assignment -name PRE_FLOW_SCRIPT_FILE quartus_sh:$globalSettings::pre_impl
    } elseif {[IsDiamond]} {
      prj_impl pre_script "par" $globalSettings::pre_impl
    }
    Msg Debug "Setting $globalSettings::pre_impl to be run after implementation"
  }


  ## set post routing script
  if {$globalSettings::post_impl_file ne ""} {
    if {[IsXilinx]} {
      #Vivado Only
      if {[IsVivado]} {
        if {[get_filesets -quiet utils_1] != ""} {
          AddFile $globalSettings::post_impl [get_filesets -quiet utils_1]
        }
        set_property STEPS.ROUTE_DESIGN.TCL.POST $globalSettings::post_impl $obj
      }
    } elseif {[IsQuartus]} {
      #QUARTUS only
      set_global_assignment -name POST_MODULE_SCRIPT_FILE quartus_sh:$globalSettings::quartus_post_module
    } elseif {[IsDiamond]} {
      prj_impl post_script "par" $globalSettings::post_impl
    }
    Msg Debug "Setting $globalSettings::post_impl to be run after implementation"
  }

  ## set pre write bitstream script
  if {$globalSettings::pre_bit_file ne ""} {
    if {[IsXilinx]} {
      #Vivado Only
      if {[IsVivado]} {
        if {[get_filesets -quiet utils_1] != ""} {
          AddFile $globalSettings::pre_bit [get_filesets -quiet utils_1]
        }
        set_property STEPS.[BinaryStepName $globalSettings::PART].TCL.PRE $globalSettings::pre_bit $obj
      }
    } elseif {[IsQuartus]} {
      #QUARTUS only
      #set_global_assignment -name PRE_FLOW_SCRIPT_FILE quartus_sh:$globalSettings::pre_bit
    } elseif {[IsDiamond]} {
      prj_impl pre_script "export" $globalSettings::pre_bit
    }
    Msg Debug "Setting $globalSettings::pre_bit to be run after bitfile generation"
  }

  ## set post write bitstream script
  if {$globalSettings::post_bit_file ne ""} {
    if {[IsXilinx]} {
      #Vivado Only
      if {[IsVivado]} {
        if {[get_filesets -quiet utils_1] != ""} {
          AddFile $globalSettings::post_bit [get_filesets -quiet utils_1]
        }
        set_property STEPS.[BinaryStepName $globalSettings::PART].TCL.POST $globalSettings::post_bit $obj
      }
    } elseif {[IsQuartus]} {
      #QUARTUS only
      set_global_assignment -name POST_MODULE_SCRIPT_FILE quartus_sh:$globalSettings::quartus_post_module
    } elseif {[IsDiamond]} {
      prj_impl post_script "export" $globalSettings::post_bit
    }
    Msg Debug "Setting $globalSettings::post_bit to be run after bitfile generation"
  }

  CreateReportStrategy $obj
}


## @brief configure simulation
#
proc ConfigureSimulation {} {
  set simsets_dict [GetSimSets "$globalSettings::group_name/$globalSettings::DESIGN" $globalSettings::repo_path]

  if {[IsXilinx]} {
    ##############
    # SIMULATION #
    ##############
    Msg Debug "Setting load_glbl parameter to true for every fileset..."
    foreach simset [get_filesets -quiet] {
      if {[get_property FILESET_TYPE $simset] != "SimulationSrcs"} {
        continue
      }
      if {[IsVivado]} {
        set_property -name {xsim.elaborate.load_glbl} -value {true} -objects [get_filesets $simset]
      }
      # Setting Simulation Properties
      set sim_dict [DictGet $simsets_dict $simset]
      set sim_props [DictGet $sim_dict "properties"]

      if {$sim_props != ""} {
        Msg Info "Setting properties for simulation set: $simset..."
        dict for {prop_name prop_val} $sim_props {
          set prop_name [string toupper $prop_name]
          if {$prop_name == "ACTIVE" && $prop_val == 1} {
            Msg Info "Setting $simset as active simulation set..."
            current_fileset -simset [get_filesets $simset]
          } else {
            Msg Debug "Setting $prop_name = $prop_val"
            if {[IsInList [string toupper $prop_name] [VIVADO_PATH_PROPERTIES] 1]} {
              # Check that the file exists before setting these properties
              if {[file exists $globalSettings::repo_path/$prop_val]} {
                set_property $prop_name $globalSettings::repo_path/$prop_val [get_filesets $simset]
              } else {
                Msg Warning "Impossible to set property $prop_name to $prop_val. File is missing"
              }
            } else {
              set_property $prop_name $prop_val [get_filesets $simset]
            }
          }
        }
      }
    }
  }
}

## @brief uses the content of globalSettings::PROPERTIES to set additional project properties
#
proc ConfigureProperties {} {
  set cur_dir [pwd]
  cd $globalSettings::repo_path
  if {[IsXilinx]} {
    set user_repo "0"
    # Setting Main Properties
    if {[info exists globalSettings::PROPERTIES]} {
      if {[dict exists $globalSettings::PROPERTIES main]} {
        Msg Info "Setting project-wide properties..."
        set proj_props [dict get $globalSettings::PROPERTIES main]
        dict for {prop_name prop_val} $proj_props {
          if {[string tolower $prop_name] != "ip_repo_paths"} {
            if {[string tolower $prop_name] != "part"} {
              # Part is already set
              Msg Debug "Setting $prop_name = $prop_val"
              set_property $prop_name $prop_val [current_project]
            }
          } else {
            set ip_repo_list [regsub -all {\s+} $prop_val " $globalSettings::repo_path/"]
            set ip_repo_list $globalSettings::repo_path/$ip_repo_list
            set user_repo "1"
            Msg Info "Setting $ip_repo_list as user IP repository..."
            if {[IsISE]} {
              set_property ip_repo_paths "$ip_repo_list" [current_fileset]
            } else {
              set_property ip_repo_paths "$ip_repo_list" [current_project]
            }
            update_ip_catalog
          }
        }
      }
      # Setting Run Properties
      foreach run [get_runs -quiet] {
        if {[dict exists $globalSettings::PROPERTIES $run]} {
          Msg Info "Setting properties for run: $run..."
          set run_props [dict get $globalSettings::PROPERTIES $run]
          #set_property -dict $run_props $run
          set stragety_str "STRATEGY strategy Strategy"
          Msg Debug "Setting Strategy and Flow for run $run (if specified in hog.conf)"
          foreach s $stragety_str {
            if {[dict exists $run_props $s]} {
              set prop [dict get $run_props $s]
              set_property $s $prop $run
              set run_props [dict remove $run_props $s]
              Msg Warning "A strategy for run $run has been defined inside hog.conf. This prevents Hog to compare the project properties. \
              Please regenerate your hog.conf file using the dedicated Hog button."
              Msg Info "Setting $s = $prop"
            }
          }

          dict for {prop_name prop_val} $run_props {
            Msg Debug "Setting $prop_name = $prop_val"
            if {[string trim $prop_val] == ""} {
              Msg Warning "Property $prop_name has empty value. Skipping..."
              continue
            }
            if {[IsInList [string toupper $prop_name] [VIVADO_PATH_PROPERTIES] 1]} {
              # Check that the file exists before setting these properties
              set utility_file $globalSettings::repo_path/$prop_val
              if {[file exists $utility_file]} {
                lassign [GetHogFiles -ext_path $globalSettings::HOG_EXTERNAL_PATH $globalSettings::list_path $globalSettings::repo_path] lib prop dummy
                foreach {l f} $lib {
                  foreach ff $f {
                    lappend hog_files $ff
                  }
                }
                if {[lsearch $hog_files $utility_file] < 0} {
                  Msg CriticalWarning "The file: $utility_file is set as a property in hog.conf, \
                  but is not added to the project in any list file. Hog cannot track it."
                } else {
                  #Add file tu utils_1 to avoid warning
                  AddFile $globalSettings::repo_path/$prop_val [get_filesets -quiet utils_1]
                }
                set_property $prop_name $utility_file $run
              } else {
                Msg Warning "Impossible to set property $prop_name to $prop_val. File is missing"
              }
            } else {
              set_property $prop_name $prop_val $run
            }
          }
        }
      }
    }
  } elseif {[IsQuartus]} {
    #QUARTUS only
    #TO BE DONE
  } elseif {[IsLibero]} {
    # Setting Properties
    if {[info exists globalSettings::PROPERTIES]} {
      # Device Properties
      if {[dict exists $globalSettings::PROPERTIES main]} {
        Msg Info "Setting device properties..."
        set dev_props [dict get $globalSettings::PROPERTIES main]
        dict for {prop_name prop_val} $dev_props {
          if {!([string toupper $prop_name] in $globalSettings::LIBERO_MANDATORY_VARIABLES)} {
            Msg Debug "Setting $prop_name = $prop_val"
            set_device -[string tolower $prop_name] $prop_val
          }
        }
      }
      # Project Properties
      if {[dict exists $globalSettings::PROPERTIES project]} {
        Msg Info "Setting project-wide properties..."
        set dev_props [dict get $globalSettings::PROPERTIES project]
        dict for {prop_name prop_val} $dev_props {
          Msg Debug "Setting $prop_name = $prop_val"
          project_settings -[string tolower $prop_name] $prop_val
        }
      }
      # Synthesis Properties
      if {[dict exists $globalSettings::PROPERTIES synth]} {
        Msg Info "Setting Synthesis properties..."
        set synth_props [dict get $globalSettings::PROPERTIES synth]
        dict for {prop_name prop_val} $synth_props {
          Msg Debug "Setting $prop_name = $prop_val"
          configure_tool -name {SYNTHESIZE} -params "[string toupper $prop_name]:$prop_val"
        }
      }
      # Implementation Properties
      if {[dict exists $globalSettings::PROPERTIES impl]} {
        Msg Info "Setting Implementation properties..."
        set impl_props [dict get $globalSettings::PROPERTIES impl]
        dict for {prop_name prop_val} $impl_props {
          Msg Debug "Setting $prop_name = $prop_val"
          configure_tool -name {PLACEROUTE} -params "[string toupper $prop_name]:$prop_val"
        }
      }

      # Bitstream Properties
      if {[dict exists $globalSettings::PROPERTIES bitstream]} {
        Msg Info "Setting Bitstream properties..."
        set impl_props [dict get $globalSettings::PROPERTIES impl]
        dict for {prop_name prop_val} $impl_props {
          Msg Debug "Setting $prop_name = $prop_val"
          configure_tool -name {GENERATEPROGRAMMINGFILE} -params "[string toupper $prop_name]:$prop_val"
        }
      }
      # Configure VERIFYTIMING tool to generate a txt file report
      configure_tool -name {VERIFYTIMING} -params {FORMAT:TEXT}
    }
  } elseif {[IsDiamond]} {
    if {[info exists globalSettings::PROPERTIES]} {
      # Project (main) Properties
      if {[dict exists $globalSettings::PROPERTIES main]} {
        Msg Info "Setting project-wide properties..."
        set dev_props [dict get $globalSettings::PROPERTIES main]
        dict for {prop_name prop_val} $dev_props {
          # Device is already set
          if {[string toupper $prop_name] != "DEVICE"} {
            Msg Debug "Setting $prop_name = $prop_val"
            prj_project option $prop_name $prop_val
          }
        }
      }
      # Implementation properties
      if {[dict exists $globalSettings::PROPERTIES impl]} {
        Msg Info "Setting Implementation properties..."
        set dev_props [dict get $globalSettings::PROPERTIES impl]
        dict for {prop_name prop_val} $dev_props {
          # Device is already set
          Msg Debug "Setting $prop_name = $prop_val"
          prj_impl option $prop_name $prop_val
        }
      }
    }
  } else {
    Msg info "Configuring Properties"
  }
  cd $cur_dir
}

## @brief upgrade IPs in the project and copy them from HOG_IP_PATH if defined
#
proc ManageIPs {} {
  # set the current impl run
  current_run -implementation [get_runs impl_1]

  ##############
  # UPGRADE IP #
  ##############
  set ips [get_ips *]

  Msg Info "Running report_ip_status, before upgrading and handling IPs..."
  report_ip_status

  #Pull ips from repo
  if {$globalSettings::HOG_IP_PATH != ""} {
    set ip_repo_path $globalSettings::HOG_IP_PATH
    Msg Info "HOG_IP_PATH is set, will pull/push synthesised IPs from/to $ip_repo_path."
    foreach ip $ips {
      HandleIP pull [get_property IP_FILE $ip] $ip_repo_path $globalSettings::repo_path [get_property IP_OUTPUT_DIR $ip]
    }
  } else {
    Msg Info "HOG_IP_PATH not set, will not push/pull synthesised IPs."
  }
}

proc SetGlobalVar {var {default_value HOG_NONE}} {
  ##nagelfar ignore
  if {[info exists ::$var]} {
    Msg Debug "Setting $var to [subst $[subst ::$var]]"
    ##nagelfar ignore
    set globalSettings::$var [subst $[subst ::$var]]
  } elseif {$default_value == "HOG_NONE"} {
    Msg Error "Mandatory variable $var was not defined. Please define it in hog.conf or in project tcl script."
  } else {
    Msg Info "Setting $var to default value: \"$default_value\""
    ##nagelfar ignore
    set globalSettings::$var $default_value
  }
}

################################################################################################################################################################

proc CreateProject {args} {
  #  set tcl_path [file normalize "[file dirname [info script]]"]
  #  set repo_path [file normalize $tcl_path/../..]

  if {[catch {package require cmdline} ERROR]} {
    puts "ERROR: If you are running this script on tclsh, you can fix this by installing 'tcllib'"
    return
  }
  set parameters {
    {simlib_path.arg  "" "Path of simulation libs"}
    {verbose "If set, launch the script in verbose mode."}
  }

  set usage "Create Vivado/ISE/Quartus/Libero/Diamond project.\nUsage: CreateProject \[OPTIONS\] <project> <repository path>\n Options:"

  if {[catch {array set options [cmdline::getoptions args $parameters $usage]}] || [llength $args] < 2 || [lindex $args 0] eq ""} {
    Msg Info [cmdline::usage $parameters $usage]
    return 1
  }

  set globalSettings::DESIGN [lindex $args 0]
  if {[file exists [lindex $args 1]]} {
    set globalSettings::repo_path [file normalize [lindex $args 1]]
  } else {
    Msg Error "The second argument, [lindex $args 1], should be the repository path."
  }
  set globalSettings::tcl_path $globalSettings::repo_path/Hog/Tcl


  if {$options(verbose) == 1} {
    variable ::DEBUG_MODE 1
  }

  if {[IsVivado]} {
    if {$options(simlib_path) != ""} {
      if {[IsRelativePath $options(simlib_path)] == 0} {
        set globalSettings::simlib_path "$options(simlib_path)"
      } else {
        set globalSettings::simlib_path "$globalSettings::repo_path/$options(simlib_path)"
      }
      Msg Info "Simulation library path set to $options(simlib_path)"
    } else {
      set globalSettings::simlib_path "$globalSettings::repo_path/SimulationLib"
      Msg Info "Simulation library path set to default $globalSettings::repo_path/SimulationLib"
    }
  }


  set proj_dir [file normalize $globalSettings::repo_path/Top/$globalSettings::DESIGN]
  lassign [GetConfFiles $proj_dir] conf_file sim_file pre_file post_file

  set user_repo 0
  if {[file exists $conf_file]} {
    Msg Info "Parsing configuration file $conf_file..."
    SetGlobalVar PROPERTIES [ReadConf $conf_file]

    #Checking Vivado/Quartus/ISE/Libero version
    set actual_version [GetIDEVersion]
    lassign [GetIDEFromConf $conf_file] ide conf_version
    if {$conf_version != "0.0.0"} {
      set a_v [split $actual_version "."]
      set c_v [split $conf_version "."]

      if {[llength $a_v] < 2} {
        Msg Error "Couldn't parse IDE version: $actual_version."
      } elseif {[llength $a_v] == 2} {
        lappend a_v 0
      }
      if {[llength $c_v] < 2} {
        Msg Error "Wrong version format in hog.conf: $conf_version."
      } elseif {[llength $c_v] == 2} {
        lappend c_v 0
      }

      set comp [CompareVersions $a_v $c_v]
      if {$comp == 0} {
        Msg Info "Project version and $ide version match: $conf_version."
      } elseif {$comp == 1} {
        Msg CriticalWarning "The $ide version in use is $actual_version, that is newer than $conf_version, as specified in the first line of $conf_file.\n\
        If you want update this project to version $actual_version, please update the configuration file."
      } else {
        # tclint-disable-next-line line-length
        Msg Error "The $ide version in use is $actual_version, that is older than $conf_version as specified in $conf_file. The project will not be created.\nIf you absolutely want to create this project that was meant for version $conf_version with $ide version $actual_version, you can change the version from the first line of $conf_file.\nThis is HIGHLY discouraged as there could be unrecognised properties in the configuration file and IPs created with a newer $ide version cannot be downgraded."
      }
    } else {
      Msg CriticalWarning "No version found in the first line of $conf_file. \
      It is HIGHLY recommended to replace the first line of $conf_file with: \#$ide $actual_version"
    }
    if {[dict exists $globalSettings::PROPERTIES main]} {
      set main [dict get $globalSettings::PROPERTIES main]
      dict for {p v} $main {
        # notice the dollar in front of p: creates new variables and fill them with the value
        Msg Info "Main property $p set to $v"
        ##nagelfar ignore
        set ::$p $v
      }
    } else {
      Msg Error "No main section found in $conf_file, make sure it has a section called \[main\] containing the mandatory properties."
    }
  } else {
    Msg Error "$conf_file was not found in your project directory, please create one."
  }


  if {[IsXilinx] || [IsQuartus]} {
    SetGlobalVar PART
  }
  #Family is needed in quartus and libero only
  if {[IsQuartus] || [IsLibero]} {
    #Quartus only
    SetGlobalVar FAMILY
    if {[IsLibero]} {
      SetGlobalVar DIE
      SetGlobalVar PACKAGE
    }
  }

  if {[IsDiamond]} {
    SetGlobalVar DEVICE
    SetGlobalVar SYNTHESIS_TOOL "lse"
  }

  if {[IsVivado]} {
    SetGlobalVar TARGET_SIMULATOR "XSim"
  }

  if {[info exists env(HOG_EXTERNAL_PATH)]} {
    set globalSettings::HOG_EXTERNAL_PATH $env(HOG_EXTERNAL_PATH)
  } else {
    set globalSettings::HOG_EXTERNAL_PATH ""
  }

  #Derived variables from now on...

  set build_dir_name "Projects"
  set globalSettings::group_name [file dirname $globalSettings::DESIGN]
  set globalSettings::pre_synth_file "pre-synthesis.tcl"
  set globalSettings::post_synth_file "post-synthesis.tcl"
  set globalSettings::pre_impl_file "pre-implementation.tcl"
  set globalSettings::post_impl_file "post-implementation.tcl"
  set globalSettings::pre_bit_file "pre-bitstream.tcl"
  set globalSettings::post_bit_file "post-bitstream.tcl"
  set globalSettings::quartus_post_module_file "quartus-post-module.tcl"
  set globalSettings::top_path "$globalSettings::repo_path/Top/$globalSettings::DESIGN"
  set globalSettings::list_path "$globalSettings::top_path/list"
  set globalSettings::build_dir "$globalSettings::repo_path/$build_dir_name/$globalSettings::DESIGN"
  set globalSettings::DESIGN [file tail $globalSettings::DESIGN]
  set globalSettings::top_name [file tail $globalSettings::DESIGN]
  set globalSettings::top_name [file rootname $globalSettings::top_name]
  set globalSettings::synth_top_module "top_$globalSettings::top_name"
  set globalSettings::user_ip_repo ""

  set globalSettings::pre_synth [file normalize "$globalSettings::tcl_path/integrated/$globalSettings::pre_synth_file"]
  set globalSettings::post_synth [file normalize "$globalSettings::tcl_path/integrated/$globalSettings::post_synth_file"]
  set globalSettings::pre_impl [file normalize "$globalSettings::tcl_path/integrated/$globalSettings::pre_impl_file"]
  set globalSettings::post_impl [file normalize "$globalSettings::tcl_path/integrated/$globalSettings::post_impl_file"]
  set globalSettings::pre_bit [file normalize "$globalSettings::tcl_path/integrated/$globalSettings::pre_bit_file"]
  set globalSettings::post_bit [file normalize "$globalSettings::tcl_path/integrated/$globalSettings::post_bit_file"]
  set globalSettings::quartus_post_module [file normalize "$globalSettings::tcl_path/integrated/$globalSettings::quartus_post_module_file"]
  set globalSettings::LIBERO_MANDATORY_VARIABLES {"FAMILY" "PACKAGE" "DIE" }

  set user_hog_file "$globalSettings::repo_path/Top/hog.tcl"
  if {[file exists $user_hog_file]} {
    Msg Info "Sourcing user hog.tcl file..."
    source $user_hog_file
  }

  if {[file exists $pre_file]} {
    Msg Info "Found pre-creation Tcl script $pre_file, executing it..."
    source $pre_file
  }

  if {[info exists env(HOG_IP_PATH)]} {
    set globalSettings::HOG_IP_PATH $env(HOG_IP_PATH)
  } else {
    set globalSettings::HOG_IP_PATH ""
  }

  InitProject
  AddProjectFiles
  ConfigureSynthesis
  ConfigureImplementation
  ConfigureSimulation

  if {[IsVivado]} {
    # Use HandleIP to pull IPs from HOG_IP_PATH if specified
    ManageIPs
  }

  if {[IsQuartus]} {
    set fileName_old [file normalize "./hogTmp/.hogQsys.md5"]
    set fileDir [file normalize "$globalSettings::build_dir/.hog/"]
    file mkdir $fileDir
    set fileName_new [file normalize "$fileDir/.hogQsys.md5"]
    if {[file exists $fileName_new]} {
      file delete $fileName_new
    }
    if {[file exists $fileName_old]} {
      file rename -force $fileName_old $fileName_new
      file delete -force -- "./hogTmp"
    }
  }

  if {[file exists $post_file]} {
    Msg Info "Found post-creation Tcl script $post_file, executing it..."
    source $post_file
    if {[IsLibero]} {
      # Regenerate the hierarchy in case a new file has been added
      build_design_hierarchy
    }
  }

  # Check extra IPs
  # Get project libraries and properties from list files
  lassign [GetHogFiles \
    -ext_path "$globalSettings::HOG_EXTERNAL_PATH" \
    -list_files ".src,.ext" \
    "$globalSettings::repo_path/Top/$globalSettings::group_name/$globalSettings::DESIGN/list/" \
    $globalSettings::repo_path] \
    listLibraries listProperties listSrcSets
  # Get project constraints and properties from list files
  lassign [GetHogFiles \
    -ext_path "$globalSettings::HOG_EXTERNAL_PATH" \
    -list_files ".con" \
    "$globalSettings::repo_path/Top/$globalSettings::group_name/$globalSettings::DESIGN/list/" \
    $globalSettings::repo_path] \
    listConstraints listConProperties listConSets

  lassign [GetHogFiles \
    -ext_path "$globalSettings::HOG_EXTERNAL_PATH" \
    -list_files ".sim" \
    "$globalSettings::repo_path/Top/$globalSettings::group_name/$globalSettings::DESIGN/list/" \
    $globalSettings::repo_path] \
    listSimLibraries listSimProperties listSimSets

  set old_path [pwd]
  cd $globalSettings::build_dir
  CheckExtraFiles $listLibraries $listConstraints $listSimLibraries
  cd $old_path

  if {[IsXilinx]} {
    set old_path [pwd]
    cd $globalSettings::repo_path
    set flavour [GetProjectFlavour $globalSettings::DESIGN]
    # Getting all the versions and SHAs of the repository
    lassign [GetRepoVersions \
      [file normalize $globalSettings::repo_path/Top/$globalSettings::group_name/$globalSettings::DESIGN] \
      $globalSettings::repo_path \
      $globalSettings::HOG_EXTERNAL_PATH \
    ] commit version hog_hash hog_ver top_hash top_ver libs hashes vers cons_ver cons_hash ext_names ext_hashes \
      xml_hash xml_ver user_ip_repos user_ip_hashes user_ip_vers

    set this_commit [GetSHA]

    if {$commit == 0} {
      set commit $this_commit
    }

    if {$xml_hash != ""} {
      set use_ipbus 1
    } else {
      set use_ipbus 0
    }


    lassign [GetDateAndTime $commit] date timee
    WriteGenerics "create" \
      $globalSettings::repo_path \
      $globalSettings::group_name/$globalSettings::DESIGN \
      $date $timee $commit $version \
      $top_hash $top_ver $hog_hash $hog_ver \
      $cons_ver $cons_hash $libs $vers $hashes \
      $ext_names $ext_hashes $user_ip_repos $user_ip_vers \
      $user_ip_hashes $flavour $xml_ver $xml_hash
    cd $old_path
  }

  if {[IsLibero]} {
    save_project
  }

  if {[IsDiamond]} {
    prj_project save
  }

  Msg Info "Project $globalSettings::DESIGN created successfully in [Relative $globalSettings::repo_path $globalSettings::build_dir]."
}
