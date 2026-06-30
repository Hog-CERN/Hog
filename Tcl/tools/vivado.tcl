namespace eval Tools::Vivado {

  variable Manifest {
    name    "Vivado"
    vendor  "AMD/Xilinx"
    Flows {
      @CREATE         {CreateProject}
      @SYNTH          {@CREATE  Synthesize}
      @IMPL           {@SYNTH   Implement}
      @WORKFLOW       {@IMPL    GenerateBitstream}
      @SIMULATE       {@CREATE  Simulate}
      @CHECKSYNTAX    {@CREATE  CheckSyntax}
      @RTL            {@CREATE  RtlAnalysis}
    }

    Supports {
      Synthesis       1
      Implementation  1
      Bitstream       1
      Simulation      1
      CheckSyntax     1
    }
  }

  proc IsActive {} {
    if {[info commands version] eq ""} { return 0 }
    set v [version]
    return [expr {
      [string first "Vivado"    $v] == 0 ||
      [string first "PlanAhead" $v] == 0
    }]
  }


  proc Launch {} {
    # Each tool should define how it passes context from tclsh to itself
    # I think most can just pass the entire context dict as a tclarg, but
    # something like vitis_unified will probably need to manpulate it to
    # pass to python env.

    set script [Context::Get launch_script]
    set before_tcl_script " -nojournal -nolog -mode batch -notrace -source "
    exec -ignorestderr vivado -nojournal -nolog -mode batch -notrace -source $script -tclargs "-context"  "[Context::GetFullContext]" >@ stdout
  }

  proc Initialize {args} {
    # Again, each tool will need to define how it processes the context passed from tclsh.
    if {[llength $args] < 1} {
      puts "Vivado::InitializeTool requires at least 1 argument (the context dict)"
      return
    }
    if {[lindex $args 0] eq "-context"} {
      DataStore::Deserialize [lindex $args 1]
    } else {
      puts "Vivado::InitializeTool requires -context argument"
      return
    }

    set project_name [HogProject::Get project_name]
    set repo_path    [Repo::Get repo_path]
    set top_path     [Repo::Get top_path]

    HogProject::Set project_file [file normalize [file join [HogProject::Get build_dir] [HogProject::Get project].xpr]]

    set_msg_config -suppress -regexp -string {".*The IP file '.*' has been moved from its original location, as a result the outputs for this IP will now be \
    generated in '.*'. Alternatively a copy of the IP can be imported into the project using one of the 'import_ip' or 'import_files' commands..*"}
    set_msg_config -suppress -regexp -string {".*File '.*.xci' referenced by design '.*' could not be found..*"}

    # File inside .bd
    set_msg_config -suppress -id {IP_Flow 19-3664}
    # This is due to simulations in project with NoC
    # tclint-disable-next-line line-length
    set_msg_config -suppress -id {Vivado 12-23660} -string {{ERROR: [Vivado 12-23660] Simulation is not supported for the target language VHDL when design \
    contains NoC (Network-on-Chip) blocks} }


    if {[info exists env(HOG_EXTERNAL_PATH)]} {
      HogProject::Set HOG_EXTERNAL_PATH $env(HOG_EXTERNAL_PATH)
    } else {
      HogProject::Set HOG_EXTERNAL_PATH ""
    }


    HogProject::Set LIBERO_MANDATORY_VARIABLES {"FAMILY" "PACKAGE" "DIE" }
    set proj_dir [file normalize "${repo_path}/Top/${project_name}"]


    lassign [GetConfFiles $proj_dir] conf_file sim_file pre_file post_file pre_rtl_file
    set user_repo 0
    if {[file exists $conf_file]} {
      Msg Info "Parsing configuration file $conf_file..."
      set PROPERTIES [ReadConf $conf_file]
    }

    # if {[Launcher::Get options lib] != ""} {
    #   if {[IsRelativePath [Launcher::Get options lib]] == 0} {
    #     HogProject::Set simlib_path "[Launcher::Get options lib]"
    #   } else {
    #     HogProject::Set simlib_path "${repo_path}/[Launcher::Get options lib]"
    #   }
    #   Msg Info "Simulation library path set to [HogProject::Get simlib_path]"
    # } else {
    #   HogProject::Set simlib_path "${repo_path}/SimulationLib"
    #   Msg Info "Simulation library path set to default [HogProject::Get simlib_path]"
    # }

    HogProject::Set config ""
    if {[dict exists $PROPERTIES main]} {
      dict for {section content} $PROPERTIES {
        dict for {p v} $content {
          Msg Debug "Setting property $p to $v for section $section"
          HogProject::Set config $section $p $v
        }
      }
    }
  }

  proc CreateProject {} {
    set project_name [Context::Get LaunchSettings project_name]
    set top_path     [Context::Get LaunchSettings top_path]
    Msg Info "Creating Vivado project \"$project_name\" from $top_path"
  }


  proc AddProjectFiles {} {
    FlowControl::RequireOr PROJECT_CREATED {
      puts "Didn't find a project, creating it first..."

    }
    if {[string equal [get_filesets -quiet sources_1] ""]} {
      create_fileset -srcset sources_1
    }
    set sources "sources_1"

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

    if {[file isdirectory [HogProject::Get list_path]]} {
      set list_files [glob -directory [HogProject::Get list_path] "*"]
    } else {
      Msg Error "No list directory found at  [HogProject::Get list_path]"
    }

    if {[IsISE]} {
      source [HogProject::Get config tcl_path]/utils/cmdline.tcl
    }

    # Add first .src, .sim, and .ext list files
    AddHogFiles {*}[GetHogFiles -list_files {.src,.sim,.ext} -ext_path [HogProject::Get HOG_EXTERNAL_PATH] [HogProject::Get list_path] [Repo::Get repo_path]]

    ## Set synthesis TOP
    SetTopProperty [HogProject::Get synth_top_module] $sources

    AddHogFiles {*}[GetHogFiles -list_files {.con} -ext_path [HogProject::Get HOG_EXTERNAL_PATH] [HogProject::Get list_path] [Repo::Get repo_path]]

  }

  ## @brief configure synthesis.
  #
  # The method uses the content of globalSettings::SYNTH_FLOW and globalSettings::SYNTH_STRATEGY to set the implementation strategy and flow.
  # The function also sets Hog specific pre and post synthesis scripts
  #
  proc ConfigureSynthesis {} {
    ## Create 'synthesis ' run (if not found)
    if {[string equal [get_runs -quiet synth_1] ""]} {
      puts "create_run -name synth_1 -part [HogProject::Get config main PART] -constrset constrs_1"
      create_run -name synth_1 -part [HogProject::Get config main PART] -constrset constrs_1
    }

    set obj [get_runs synth_1]
    set_property "part" [HogProject::Get config main PART] $obj

    ## set pre synthesis script
    if {[Repo::Get pre_synth] ne ""} {
      if {[IsVivado]} {
        if {[get_filesets -quiet utils_1] != ""} {
          AddFile [ Repo::Get pre_synth] [get_filesets -quiet utils_1]
        }
        set_property STEPS.SYNTH_DESIGN.TCL.PRE [ Repo::Get pre_synth] $obj
      }
      Msg Debug "Setting [ Repo::Get pre_synth] to be run before synthesis"
    }

    ## set post synthesis script
    if {[Repo::Get post_synth] ne ""} {
      if {[IsVivado]} {
        if {[get_filesets -quiet utils_1] != ""} {
          AddFile [ Repo::Get post_synth] [get_filesets -quiet utils_1]
        }
        set_property STEPS.SYNTH_DESIGN.TCL.POST [ Repo::Get post_synth] $obj
      }
      Msg Debug "Setting [ Repo::Get post_synth] to be run after synthesis"
    }


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
  }

  ## @brief configure implementation.
  #
  # The configuration is based on the content of globalSettings::IMPL_FLOW and globalSettings::IMPL_STRATEGY
  # The function also sets Hog specific pre- and- post implementation and, pre- and post- implementation  scripts
  #
  proc ConfigureImplementation {} {
    set obj ""
    if {[string equal [get_runs -quiet impl_1] ""]} {
      puts "create_run -name impl_1 -part [ HogProject::Get config main PART] -constrset constrs_1 -parent_run synth_1"
      create_run -name impl_1 -part [ HogProject::Get config main PART] -constrset constrs_1 -parent_run synth_1
    }

    set obj [get_runs impl_1]
    set_property "part" [ HogProject::Get config main PART] $obj

    set_property "steps.[BinaryStepName [ HogProject::Get config main PART]].args.readback_file" "0" $obj
    set_property "steps.[BinaryStepName [ HogProject::Get config main PART]].args.verbose" "0" $obj

    ## set pre implementation script
    if {[ Repo::Get pre_impl] ne ""} {
      if {[IsVivado]} {
        if {[get_filesets -quiet utils_1] != ""} {
          AddFile [ Repo::Get pre_impl] [get_filesets -quiet utils_1]
        }
        set_property STEPS.INIT_DESIGN.TCL.POST [ Repo::Get pre_impl] $obj
      }
      Msg Debug "Setting [ Repo::Get pre_impl] to be run after implementation"
    }


    ## set post routing script
    if {[ Repo::Get post_impl] ne ""} {
      #Vivado Only
      if {[IsVivado]} {
        if {[get_filesets -quiet utils_1] != ""} {
          AddFile [ Repo::Get post_impl] [get_filesets -quiet utils_1]
        }
        set_property STEPS.ROUTE_DESIGN.TCL.POST [ Repo::Get post_impl] $obj
      }
      Msg Debug "Setting [ Repo::Get post_impl] to be run after implementation"
    }

    ## set pre write bitstream script
    if {[ Repo::Get pre_bit] ne ""} {
      #Vivado Only
      if {[IsVivado]} {
        if {[get_filesets -quiet utils_1] != ""} {
          AddFile [ Repo::Get pre_bit] [get_filesets -quiet utils_1]
        }
        set_property STEPS.[BinaryStepName [ HogProject::Get config main PART]].TCL.PRE [ Repo::Get pre_bit] $obj
      }
      Msg Debug "Setting [ Repo::Get pre_bit] to be run before bitfile generation"
    }

    ## set post write bitstream script
    if {[ Repo::Get post_bit] ne ""} {
      if {[IsVivado]} {
        if {[get_filesets -quiet utils_1] != ""} {
          AddFile [ Repo::Get post_bit] [get_filesets -quiet utils_1]
        }
        set_property STEPS.[BinaryStepName [ HogProject::Get config main PART]].TCL.POST [ Repo::Get post_bit] $obj
      }
      Msg Debug "Setting [ Repo::Get post_bit] to be run after bitfile generation"
    }
    CreateReportStrategy $obj
  }


  ## @brief configure simulation
  #
  proc ConfigureSimulation {} {
    set simsets_dict [GetSimSets "[HogProject::Get group_name]/[HogProject::Get DESIGN]" [Repo::Get repo_path]]

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
              if {[file exists [Repo::Get repo_path]/$prop_val]} {
                set_property -name $prop_name -value [Repo::Get repo_path]/$prop_val -objects [get_filesets $simset]
              } else {
                Msg Warning "Impossible to set property $prop_name to $prop_val. File is missing"
              }
            } else {
              set_property -name $prop_name -value $prop_val -objects [get_filesets $simset]
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
    cd [Repo::Get repo_path]
    set user_repo "0"
    # Setting Main Properties
    if {[HogProject::Exists PROPERTIES]} {
      if {[dict exists [ HogProject::Get PROPERTIES] main]} {
        Msg Info "Setting project-wide properties..."
        set proj_props [dict get [ HogProject::Get PROPERTIES] main]
        dict for {prop_name prop_val} $proj_props {
          if {[string tolower $prop_name] != "ip_repo_paths"} {
            if {[string tolower $prop_name] != "part"} {
              # Part is already set
              Msg Debug "Setting $prop_name = $prop_val"
              set_property -name $prop_name -value $prop_val -objects [current_project]
            }
          } else {
            set ip_repo_list [regsub -all {\s+} $prop_val " [Repo::Get repo_path]/"]
            set ip_repo_list [Repo::Get repo_path]/$ip_repo_list
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
        if {[HogProject::Exists config $run]} {
          Msg Info "Setting properties for run: $run..."
          set run_props [dict get [ HogProject::Get config] $run]
          #set_property -dict $run_props $run
          set stragety_str "STRATEGY strategy Strategy"
          Msg Debug "Setting Strategy and Flow for run $run (if specified in hog.conf)"
          foreach s $stragety_str {
            if {[dict exists $run_props $s]} {
              set prop [dict get $run_props $s]
              set_property -name $s -value $prop -objects $run
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
              set utility_file [Repo::Get repo_path]/$prop_val
              if {[file exists $utility_file]} {
                lassign [GetHogFiles -ext_path [HogProject::Get config HOG_EXTERNAL_PATH] [Repo::Get list_path] [Repo::Get repo_path]] lib prop dummy
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
                  AddFile [Repo::Get repo_path]/$prop_val [get_filesets -quiet utils_1]
                }
                set_property -name $prop_name -value $utility_file -objects $run
              } else {
                Msg Warning "Impossible to set property $prop_name to $prop_val. File is missing"
              }
            } else {
              set_property -name $prop_name -value $prop_val -objects $run
            }
          }
        }
      }
    }
    cd $cur_dir
  }



  proc Synthesize {} {
    Msg Info "Running synthesis..."
    return "Done"
  }

  proc Implement {} {
    Msg Info "Running implementation..."
  }

  proc GenerateBitstream {} {
    Msg Info "Generating bitstream..."
  }

  proc Simulate {} {
    Msg Info "Running simulation..."
  }

  proc CheckSyntax {} {
    Msg Info "Checking syntax..."
  }

  proc RtlAnalysis {} {
    Msg Info "Running RTL analysis..."
  }

}
