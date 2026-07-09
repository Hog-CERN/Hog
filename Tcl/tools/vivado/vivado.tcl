namespace eval Tools::Vivado {

  variable Manifest {
    name        "Vivado"
    vendor      "AMD/Xilinx"
    description "AMD/Xilinx Vivado (and Vivado-Vitis classic + legacy PlanAhead) FPGA design suite."
    ref_names   {vivado vivado_vitis_classic planahead}
    Flows {
      CREATE {
        aliases {C}
        description "Create the project, replace it if already existing."
        options {
          {ext_path.arg   "" "Sets the absolute path for the external libraries."}
          {lib.arg        "" "Simulation library path, compiled or to be compiled"}
          {vivado_only       "If set, and project is vivado-vitis, vitis project will not be created."}
          {vitis_only        "If set, and project is vivado-vitis create only vitis project. If an xsa is not given, a pre-synth xsa will be created."}
          {verbose           "If set, launch the script in verbose mode"}
        }
        stages  {
          CreateProject
        }
      }

      SYNTHESIS {
        aliases {synth synthesize}
        stages  {@CREATE Synthesize}
        description "Run synthesis only, create the project if not existing."
        options {
          {recreate        "If set, the project will be re-created if it already exists."}
          {check_syntax    "If set, the HDL syntax will be checked at the beginning of the workflow."}
          {njobs.arg 4     "Number of jobs."}
          {no_reset        "If set, runs (synthesis and implementation) won't be reset before launching them."}
        }
      }

      IMPLEMENTATION {
        aliases {i impl implement}
        description "Runs only the implementation, the project must already exist and be synthesised."
        stages  {@SYNTHESIS Implement}
        options {
          {no_bitstream    "If set, the bitstream file will not be produced."}
        }
      }

      WORKFLOW {
        aliases {w work cw}
        description "Runs the full workflow, creates the project if not existing."
        options {
          {bitstream_only  "If set, only the bitstream will be produced. This assumes implementation was already done. For a Vivado-Vitis\
                            project this command can be used to generate the boot artifacts including the ELF file(s) without running the\
                            full Vivado workflow."}
          {synth_only      "If set, only the synthesis will be performed."}
          {impl_only       "If set, only the implementation will be performed. This assumes synthesis was already done."}
        }
        stages  {@IMPLEMENTATION GenerateBitstream}
      }
    }


  }


  #Add vivado-only commands
  source [file join [file dirname [info script]] commands.tcl]

  proc IsActive {} {
    if {[info commands version] eq ""} { return 0 }
    set v [version]
    return [expr {
      [string first "Vivado"    $v] == 0 ||
      [string first "PlanAhead" $v] == 0
    }]
  }

  proc Launch {} {
    set script [Launcher::Get script]
    puts "Launching vivado: \n    vivado -nojournal -nolog -mode batch -notrace -source $script -tclargs {*}$::argv"
    exec -ignorestderr vivado -nojournal -nolog -mode batch -notrace -source $script -tclargs {*}$::argv >@ stdout
  }

  proc Initialize {} {
    # Tool-specific setup — DataStores are already populated by _ConfigureEnvironment
    set repo_path    [Repo::Get repo_path]
    set top_path     [Repo::Get top_path]


    set_msg_config -suppress -regexp -string {".*The IP file '.*' has been moved from its original location, as a result the outputs for this IP will now be generated in '.*'. Alternatively a copy of the IP can be imported into the project using one of the 'import_ip' or 'import_files' commands..*"}
    set_msg_config -suppress -regexp -string {".*File '.*.xci' referenced by design '.*' could not be found..*"}

    # File inside .bd
    set_msg_config -suppress -id {IP_Flow 19-3664}
    # This is due to simulations in project with NoC
    # tclint-disable-next-line line-length
    set_msg_config -suppress -id {Vivado 12-23660} -string {{ERROR: [Vivado 12-23660] Simulation is not supported for the target language VHDL when design contains NoC (Network-on-Chip) blocks} }


    if {[info exists env(HOG_EXTERNAL_PATH)]} {
      CurrentProject::Set HOG_EXTERNAL_PATH $env(HOG_EXTERNAL_PATH)
    } else {
      CurrentProject::Set HOG_EXTERNAL_PATH ""
    }

    if {[CurrentProject::Exists project_name] == 0} {
      FlowControl::Produce VIVADO_INITIALIZED
      return
    }

    set project_name [CurrentProject::Get project_name]
    CurrentProject::Set project_file [file normalize [file join [CurrentProject::Get build_dir] [CurrentProject::Get project].xpr]]
    CurrentProject::Set LIBERO_MANDATORY_VARIABLES {"FAMILY" "PACKAGE" "DIE" }
    set proj_dir [file normalize "${repo_path}/Top/${project_name}"]


    if {[Launcher::GetOr options lib ""] != ""} {
      if {[IsRelativePath [Launcher::Get options lib]] == 0} {
        CurrentProject::Set simlib_path "[Launcher::Get options lib]"
      } else {
        CurrentProject::Set simlib_path "${repo_path}/[Launcher::Get options lib]"
      }
      Msg Info "Simulation library path set to [CurrentProject::Get simlib_path]"
    } else {
      CurrentProject::Set simlib_path "${repo_path}/simlib"
      Msg Info "Simulation library path set to default [CurrentProject::Get simlib_path]"
    }



    FlowControl::Produce VIVADO_INITIALIZED
  }

  proc CreateProject {} {

    FlowControl::Require VIVADO_INITIALIZED

    CurrentProject::SaveJsonToFile [Repo::Get repo_path]/last_run.json 1

    if {[file exists [CurrentProject::Get project_file]] && [Launcher::GetOr options recreate 1] == 0} {
      Msg Info "Project file found at [CurrentProject::Get project_file], opening project..."
      #file mkdir "[CurrentProject::Get project_file]/[CurrentProject::Get project_name].gen/sources_1"
      OpenProject [CurrentProject::Get project_file] [Repo::Get repo_path]
      FlowControl::Produce PROJECT_CREATED
      return
    }


    Msg Info "Creating project with part: [CurrentProject::Get config main PART] at [CurrentProject::Get project_file]"
    if {[catch {
    create_project -force [file tail [CurrentProject::Get design]] [CurrentProject::Get build_dir] -part [CurrentProject::Get config main PART]
    } _err _opts ]} {
      Msg Error "Failed to create project: $_err with options: $_opts"
      Msg Warning "Failed to Create Project"
    } else {
      FlowControl::Produce PROJECT_CREATED
    }

    set obj [get_projects [file tail [CurrentProject::Get design]]]
    set_property "target_language" "VHDL" $obj

      set_property "simulator_language" "Mixed" $obj
      foreach simulator [GetSimulators] {
        set_property "compxlib.${simulator}_compiled_library_dir" [CurrentProject::Get simlib_path] $obj
      }
      set_property "default_lib" "xil_defaultlib" $obj
      ## Enable VHDL 2008
      set_param project.enableVHDL2008 1
      set_property "enable_vhdl_2008" 1 $obj
      ## Enable Automatic compile order mode, otherwise we cannot find the right top module...
      set_property source_mgmt_mode All [current_project]
      # Set PART Immediately
      Msg Info "Setting PART = [CurrentProject::Get config main PART]"
      set_property PART [CurrentProject::Get config main PART] [current_project]


    ConfigureProperties
    Msg Info "Project created at [CurrentProject::Get project_file]"
    AddProjectFiles
    Msg Info "Project files added to [CurrentProject::Get project_file]"
    ConfigureSynthesis
    ConfigureImplementation
    ConfigureSimulation
  }


  proc ConfigureProperties {} {
    FlowControl::Require PROJECT_CREATED
    set user_repo "0"
    Msg Info "Setting project-wide properties..."
    set proj_props [CurrentProject::Get config main]
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
    if {[CurrentProject::Exists config $run]} {
      Msg Info "Setting properties for run: $run..."
      set run_props [CurrentProject::Get config $run]
      set stragety_str "STRATEGY strategy Strategy"
      Msg Debug "Setting Strategy and Flow for run $run (if specified in hog.conf)"
      foreach s $stragety_str {
        if {[tdict exists $run_props $s]} {
          set prop [tdict getval $run_props $s]
          set_property -name $s -value $prop -objects $run
          set run_props [tdict remove $run_props $s]
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
            lassign [GetHogFiles -ext_path [CurrentProject::Get HOG_EXTERNAL_PATH] [CurrentProject::Get list_path] [Repo::Get repo_path]] lib prop dummy
            foreach {l f} $lib {
              foreach ff $f {
                lappend hog_files $ff:
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


  proc AddProjectFiles {} {
    FlowControl::RequireOr PROJECT_CREATED {
      Msg Info "Project not found; creating it first..."
    }

    if {[get_filesets -quiet sources_1] eq ""} { create_fileset -srcset    sources_1 }
    if {[get_filesets -quiet constrs_1] eq ""} { create_fileset -constrset constrs_1 }

    # Create any non-standard filesets (simulation sets).
    tlist foreachval fs [CurrentProject::Get filesets] {
      if {$fs in {sources_1 constrs_1}} { continue }
      if {[get_filesets -quiet $fs] eq ""} {
        create_fileset -simset $fs
        current_fileset -simset [get_filesets $fs]
        set sim [get_filesets $fs]
        foreach simulator [GetSimulators] {
          set_property -name "$simulator.compile.vhdl_syntax" -value 2008 -objects $sim
        }
        set_property SOURCE_SET sources_1 $sim
      }
    }

    # Add files fileset by fileset (batch add, then apply per-file properties).
    # IPs are added last within each fileset to respect tool dependency order.
    set proj_ds [CurrentProject::GetProjectObj]

    Msg Info "Modifying Added Files"
    tlist foreachval fs [CurrentProject::Get filesets] {
      # Get all files for this fileset, excluding Vitis app libraries.
      set all_fs [Projects::GetProjectFiles $proj_ds -fileset "^${fs}$" -as tdict]
      set all_fs [ListFile::HogFileObj::Filter $all_fs -library {^(?!app_)}]

      if {[llength [tdict keys $all_fs]] == 0} { continue }

      # Batch-add paths: regular sources first, IPs last (tool dependency order).
      set regular  [ListFile::HogFileObj::Filter $all_fs -library {^(?!ips\.src$)}]
      set ip_files [ListFile::HogFileObj::Filter $all_fs -library {^ips\.src$}]
      puts "Adding [llength [tdict keys $all_fs]] files and [llength [tdict keys $ip_files]] IPs to fileset $fs"
      add_files -norecurse -fileset $fs [concat [tdict keys $regular] [tdict keys $ip_files]]


      # Apply per-file properties.
      tdict for {path fobj} $all_fs {
        set ext     [tdict getval $fobj ext]
        set lib     [tlist getval [tdict get $fobj libraries] 0]
        set rootlib [file rootname [file tail $lib]]
        set file_obj [get_files -of_objects [get_filesets $fs] [list "*$path"]]

        if {$ext in {.vhd .vhdl}} {
          set_property -name library -value $rootlib -objects $file_obj
        }

        if {$ext eq ".bd"} {
          Msg Info "Generating Target for [file tail $path]"
          generate_target all [get_files $path]
        }

        tdict for {key val} [tdict get $fobj props] {
          set v [tnative $val]
          switch -- $key {
            std {
              if {$ext in {.vhd .vhdl}} {
                switch -- $v {
                  93      { Msg Debug "VHDL 93 for $path" }
                  2019    {
                    if {[GetIDEVersion] >= 2023.2} {
                      set_property -name file_type -value "VHDL 2019" -objects $file_obj
                    } else {
                      Msg CriticalWarning "VHDL 2019 requires Vivado >= 2023.2; using 2008 for $path"
                      set_property -name file_type -value "VHDL 2008" -objects $file_obj
                    }
                  }
                  default { set_property -name file_type -value "VHDL 2008" -objects $file_obj }
                }
              }
            }
            SystemVerilog    { set_property -name file_type -value SystemVerilog       -objects $file_obj }
            verilog_header   { set_property file_type {Verilog Header}   [get_files $path] }
            verilog_template { set_property file_type {Verilog Template} [get_files $path] }
            verilog          { set_property file_type Verilog            [get_files $path] }
            nosynth          { set_property -name used_in_synthesis      -value false -objects $file_obj }
            noimpl           { set_property -name used_in_implementation -value false -objects $file_obj }
            nosim            { set_property -name used_in_simulation     -value false -objects $file_obj }
            top {
              Msg Info "Setting $v as top module for fileset $fs"
              CurrentProject::Set synth_top_module $v
            }
            locked {
              if {$ext eq ".ip"} {
                Msg Info "Locking IP $path"
                set_property IS_MANAGED 0 [get_files $path]
              }
            }
            source {
              if {$ext eq ".tcl"} {
                Msg Info "Sourcing $path (excluded from synth/impl/sim)"
                source $path
                set_property -name used_in_synthesis      -value false -objects $file_obj
                set_property -name used_in_implementation -value false -objects $file_obj
                set_property -name used_in_simulation     -value false -objects $file_obj
              }
            }
            scoped_to_ref   { set_property SCOPED_TO_REF   $v $file_obj }
            scoped_to_cells { set_property SCOPED_TO_CELLS $v $file_obj }
            topsim   { Msg Warning "topsim is deprecated; use sim.conf top=$v" }
            runtime  { Msg Warning "runtime is deprecated; use sim.conf <sim>.simulate.runtime=$v" }
            wavefile { Msg Warning "wavefile is deprecated; use sim.conf <sim>.simulate.custom_wave_do=$v" }
            dofile   { Msg Warning "dofile is deprecated; use sim.conf <sim>.simulate.custom_do=$v" }
          }
        }
      }
    }

    if {[get_filesets -quiet sim_1] ne "" \
        && [llength [get_files -quiet -of_objects [get_filesets sim_1]]] == 0} {
      delete_fileset -quiet [get_filesets sim_1]
    }

    SetTopProperty [CurrentProject::Get synth_top_module] sources_1
  }
  
  ## @brief configure synthesis.
  #
  # The method uses the content of globalSettings::SYNTH_FLOW and globalSettings::SYNTH_STRATEGY to set the implementation strategy and flow.
  # The function also sets Hog specific pre and post synthesis scripts
  #
  proc ConfigureSynthesis {} {
    ## Create 'synthesis ' run (if not found)
    if {[string equal [get_runs -quiet synth_1] ""]} {
      puts "create_run -name synth_1 -part [CurrentProject::Get config main PART] -constrset constrs_1"
      create_run -name synth_1 -part [CurrentProject::Get config main PART] -constrset constrs_1
    } 

    set obj [get_runs synth_1]
    set_property "part" [CurrentProject::Get config main PART] $obj

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
      puts "create_run -name impl_1 -part [ CurrentProject::Get config main PART] -constrset constrs_1 -parent_run synth_1"
      create_run -name impl_1 -part [ CurrentProject::Get config main PART] -constrset constrs_1 -parent_run synth_1
    }

    set obj [get_runs impl_1]
    set_property "part" [ CurrentProject::Get config main PART] $obj

    set_property "steps.[BinaryStepName [ CurrentProject::Get config main PART]].args.readback_file" "0" $obj
    set_property "steps.[BinaryStepName [ CurrentProject::Get config main PART]].args.verbose" "0" $obj

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
        set_property STEPS.[BinaryStepName [ CurrentProject::Get config main PART]].TCL.PRE [ Repo::Get pre_bit] $obj
      }
      Msg Debug "Setting [ Repo::Get pre_bit] to be run before bitfile generation"
    }

    ## set post write bitstream script
    if {[ Repo::Get post_bit] ne ""} {
      if {[IsVivado]} {
        if {[get_filesets -quiet utils_1] != ""} {
          AddFile [ Repo::Get post_bit] [get_filesets -quiet utils_1]
        }
        set_property STEPS.[BinaryStepName [ CurrentProject::Get config main PART]].TCL.POST [ Repo::Get post_bit] $obj
      }
      Msg Debug "Setting [ Repo::Get post_bit] to be run after bitfile generation"
    }
    CreateReportStrategy $obj
  }


  ## @brief configure simulation
  #
  proc ConfigureSimulation {} {
    set simsets_dict [GetSimSets "[CurrentProject::Get group_name]/[CurrentProject::Get design]" [Repo::Get repo_path]]
    
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
    if {[CurrentProject::Exists PROPERTIES]} {
      if {[dict exists [ CurrentProject::Get PROPERTIES] main]} {
        Msg Info "Setting project-wide properties..."
        set proj_props [dict get [ CurrentProject::Get PROPERTIES] main]
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
        if {[CurrentProject::Exists config $run]} {
          Msg Info "Setting properties for run: $run..."
          set run_props [dict get [ CurrentProject::Get config] $run]
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
                lassign [GetHogFiles -ext_path [CurrentProject::Get config HOG_EXTERNAL_PATH] [Repo::Get list_path] [Repo::Get repo_path]] lib prop dummy
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
    set no_reset     [Launcher::Get options no_reset    ]
    set do_create    [Launcher::Get options recreate    ]
    set njobs        [Launcher::Get options njobs       ]
    set project      [CurrentProject::Get project           ]
    set project_name [CurrentProject::Get project_name      ]
    set repo_path    [Repo::Get repo_path               ]
    set build_dir    [CurrentProject::Get build_dir               ]
    set run_folder   "$build_dir/$project.runs/"

    if {$no_reset == 0} {
      Msg Info "Resetting run before launching synthesis..."
      reset_run synth_1
    }

    set prog [get_property PROGRESS [get_runs synth_1]]
    set status [get_property STATUS [get_runs synth_1]]
    if {$prog eq "100%"} {
      Msg Info "Run: synth_1 progress: $prog, status : $status"
      Msg Info "Synthesis already completed, skipping synthesis step..."
      FlowControl::Produce SYNTHESIS_DONE
      return
    }

    if {[IsISE]} {
      source [CurrentProject::Get config pre_synth]
    }

    launch_runs synth_1 -jobs $njobs -dir $run_folder
    wait_on_run synth_1
    set prog [get_property PROGRESS [get_runs synth_1]]
    set status [get_property STATUS [get_runs synth_1]]
    Msg Info "Run: synth_1 progress: $prog, status : $status"
    # Copy IP reports in bin/
    set ips [get_ips *]

    #go to repository path
    cd $repo_path

    set describe [GetHogDescribe [file normalize ./Top/$project_name] $repo_path]
    Msg Info "Git describe set to $describe"

    foreach ip $ips {
      set xci_file [get_property IP_FILE $ip]

      set xci_path [file dirname $xci_file]
      set xci_ip_name [file rootname [file tail $xci_file]]
      foreach rptfile [glob -nocomplain -directory $xci_path *.rpt] {
        file copy $rptfile $repo_path/bin/$project_name-$describe/reports
      }
    }

    if {$prog ne "100%"} {
      Msg Error "Synthesis error, status is: $status"
    }
    FlowControl::Produce SYNTHESIS_DONE

  }

  proc Implement {} {
    FlowControl::Require SYNTHESIS_DONE PROJECT_CREATED
    Msg Info "Starting implementation flow..."

    set no_reset     [Launcher::Get options no_reset     ]
    set do_create    [Launcher::Get options recreate     ]
    set njobs        [Launcher::Get options njobs        ]
    set no_bitstream [Launcher::Get options no_bitstream ]
    set project      [CurrentProject::Get project        ]
    set project_name [CurrentProject::Get project_name   ]
    set repo_path    [Repo::Get repo_path            ]
    set build_dir    [CurrentProject::Get build_dir      ]
    set run_folder   "$build_dir/$project.runs/"



    if {$no_reset == 0} {
      Msg Info "Resetting run before launching implementation..."
      reset_run impl_1
    }

    set prog [get_property PROGRESS [get_runs impl_1]]
    set status [get_property STATUS [get_runs impl_1]]
    if {$prog eq "100%" } {
      Msg Info "Run: impl_1 progress: $prog, status : $status"
      Msg Info "Implementation already completed, skipping implementation step..."
      FlowControl::Produce IMPLEMENTATION_DONE
      return
    }


    if {[IsISE]} {
      source $repo_path/Hog/Tcl/integrated/pre-implementation.tcl
    }

    if {$no_bitstream == 0} {
      launch_runs impl_1 -to_step [BinaryStepName [get_property PART [current_project]]] -jobs $njobs -dir $run_folder
    } else {
      launch_runs impl_1 -jobs $njobs -dir $run_folder
    }
    wait_on_run impl_1

    if {[IsISE]} {
      Msg Info "running post-implementation"
      source $repo_path/Hog/Tcl/integrated/post-implementation.tcl
      if {$no_bitstream == 0} {
        Msg Info "running pre-bitstream"
        source $repo_path/Hog/Tcl/integrated/pre-bitstream.tcl
        Msg Info "running post-bitstream"
        source $repo_path/Hog/Tcl/integrated/post-bitstream.tcl
      }
    }

    set prog [get_property PROGRESS [get_runs impl_1]]
    set status [get_property STATUS [get_runs impl_1]]
    Msg Info "Run: impl_1 progress: $prog, status : $status"

    # Check timing
    if {[IsISE]} {
      set status_file [open "$run_folder/timing.txt" "w"]
      puts $status_file "## $project_name Timing summary"

      set f [open [lindex [glob "$run_folder/impl_1/*.twr" 0]]]
      set errs -1
      while {[gets $f line] >= 0} {
        if {[string match "Timing summary:" $line]} {
          while {[gets $f line] >= 0} {
            if {[string match "Timing errors:*" $line]} {
              set errs [regexp -inline -- {[0-9]+} $line]
            }
            if {[string match "*Footnotes*" $line]} {
              break
            }
            puts $status_file "$line"
          }
        }
      }

      close $f
      close $status_file

      if {$errs == 0} {
        Msg Info "Time requirements are met"
        file rename -force "$run_folder/timing.txt" "$run_folder/timing_ok.txt"
        set timing_ok 1
      } else {
        Msg CriticalWarning "Time requirements are NOT met"
        file rename -force "$run_folder/timing.txt" "$run_folder/timing_error.txt"
        set timing_ok 0
      }
    }

    if {[IsVivado]} {
      set wns [get_property STATS.WNS [get_runs [current_run]]]
      set tns [get_property STATS.TNS [get_runs [current_run]]]
      set whs [get_property STATS.WHS [get_runs [current_run]]]
      set ths [get_property STATS.THS [get_runs [current_run]]]
      set tpws [get_property STATS.TPWS [get_runs [current_run]]]

      if {$wns >= 0 && $whs >= 0 && $tpws >= 0} {
        Msg Info "Time requirements are met"
        set status_file [open "$run_folder/timing_ok.txt" "w"]
        set timing_ok 1
      } else {
        Msg CriticalWarning "Time requirements are NOT met"
        set status_file [open "$run_folder/timing_error.txt" "w"]
        set timing_ok 0
      }

      Msg Status "*** Timing summary ***"
      Msg Status "WNS: $wns"
      Msg Status "TNS: $tns"
      Msg Status "WHS: $whs"
      Msg Status "THS: $ths"
      Msg Status "TPWS: $tpws"

      struct::matrix m
      m add columns 5
      m add row

      puts $status_file "## $project_name Timing summary"

      m add row "| **Parameter** | \"**value (ns)**\" |"
      m add row "| --- | --- |"
      m add row "|  WNS:  |  $wns  |"
      m add row "|  TNS:  |  $tns  |"
      m add row "|  WHS:  |  $whs  |"
      m add row "|  THS:  |  $ths  |"
      m add row "|  TPWS: |  $tpws  |"

      puts $status_file [m format 2string]
      puts $status_file "\n"
      if {$timing_ok == 1} {
        puts $status_file " Time requirements are met."
      } else {
        puts $status_file "Time requirements are **NOT** met."
      }
      puts $status_file "\n\n"
      close $status_file
    }

    if {$prog ne "100%"} {
      Msg Error "Implementation error"
    }

    #Go to repository path
    cd $repo_path
    set describe [GetHogDescribe [file normalize ./Top/$project_name] $repo_path]
    Msg Info "Git describe set to $describe"

    set dst_dir [file normalize "$repo_path/bin/$project_name\-$describe"]

    file mkdir $dst_dir

    #Version table
    if {[file exists $run_folder/versions.txt]} {
      file copy -force $run_folder/versions.txt $dst_dir
    } else {
      Msg Warning "No versions file found in $run_folder/versions.txt"
    }
    #Timing file
    set timing_files [glob -nocomplain "$run_folder/timing_*.txt"]
    set timing_file [file normalize [lindex $timing_files 0]]

    if {[file exists $timing_file]} {
      file copy -force $timing_file $dst_dir/
    } else {
      Msg Warning "No timing file found, not a problem if running locally"
    }

    #### XSA here only for Versal Segmented Configuration
    if {[IsVersal [get_property part [current_project]]]} {
      if {[get_property segmented_configuration [current_project]] == 1} {
        Msg Info "Versal Segmented configuration detected: exporting XSA file..."
        set xsa_name "$dst_dir/[file tail $project_name]\-$describe.xsa"
        write_hw_platform -fixed -force -file $xsa_name
      }
    }
    FlowControl::Produce IMPLEMENTATION_DONE
  }

  proc GenerateBitstream {} {
    Msg Info "Generating bitstream..."

    puts "Current Flow state:"
    puts "[tobj tojson $FlowControl::_state -pretty]"
    puts "Datastores:"
    puts "[tobj tojson [DataStore::Serialize] -pretty]"
  }

  proc Simulate {} {

    if {[FlowControl::Has SYNTH] && ![FlowControl::Has IMPL]} {
      Msg Info "Running post-synthesis simulation..."
    } elseif {[FlowControl::Has IMPL]} {
      Msg Info "Running post-implementation simulation..."
    } else {
      Msg Info "Running RTL simulation..."
      FlowControl::Produce PRE_SYNTH_SIM
    }

  }

  proc CheckSyntax {} {
    Msg Info "Checking syntax..."
  }

  proc RtlAnalysis {} {
    Msg Info "Running RTL analysis..."
  }

}
