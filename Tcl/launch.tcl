#!/usr/bin/env tclsh
# @file
#   Copyright 2018-2026 The University of Birmingham
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


# Launch Xilinx Vivado or ISE implementation and possibly write bitstream in text mode

# Developers Tip for new commands
# Add a hashtag sign # after the curly brake (e.g. \^C(REATE)?$ {# ...}) if the command requires a project name as an argument

set tcl_path [file normalize "[file dirname [info script]]"]
source $tcl_path/hog.tcl
source $tcl_path/create_project.tcl
source $tcl_path/commands.tcl

# Initialize Vitis flags before InitLauncher so IsTclsh correctly returns 1
set globalSettings::vitis_unified 0
set globalSettings::vitis_classic 0

# Check if we're already running in xsct (Vitis Classic)
# This must be done early, before InitLauncher, to prevent launching Vivado
if {[info commands platform] != ""} {
  set globalSettings::vitis_classic 1
  set globalSettings::vitis_unified 0
}

# Quartus needs extra packages and treats the argv in a different way
if {[IsQuartus]} {
  load_package report
  set argv $quartus(args)
}

# Msg Debug "s: $::argv0 a: $argv"

### CUSTOM COMMANDS ###
set commands_path [file normalize "$tcl_path/../../hog-commands/"]
set custom_commands [GetCustomCommands $parameters $commands_path ]

lassign [InitLauncher $::argv0 $tcl_path $parameters $default_commands $argv $custom_commands] \
directive project project_name group_name repo_path old_path bin_dir top_path usage short_usage cmd ide list_of_options

array set options $list_of_options

if {$options(verbose) == 1} {
  setDebugMode 1
}
Msg Debug "Returned by InitLauncher: \n\
  - project: $project \n\
  - project_name $project_name \n\
  - group_name $group_name \n\
  - repo_path $repo_path \n\
  - old_path $old_path \n\
  - bin_dir $bin_dir \n\
  - top_path $top_path \n\
  - cmd $cmd"

set ext_path ""
if {$options(ext_path) != ""} {
  set ext_path $options(ext_path)
}
set lib_path ""
if {$options(lib) != ""} {
  set lib_path [file normalize $options(lib)]
} else {
  if {[info exists env(HOG_SIMULATION_LIB_PATH)]} {
    set lib_path $env(HOG_SIMULATION_LIB_PATH)
  } else {
    if {[file exists "$repo_path/SimulationLib"]} {
      set lib_path [file normalize "$repo_path/SimulationLib"]
    } else {
      set lib_path ""
    }
  }
}


if {$options(verbose) == 1} {
  setDebugMode 1
  # Set environment variable for Vitis Unified Python scripts to enable debug output
  set env(HOG_DEBUG_MODE) "1"
}

# printDebugMode
# Msg Info "Number of jobs set to $options(njobs)."
set output_path ""
if {$options(output) != ""} {
  set output_path $options(output)
}

set light_hierarchy $options(light)
set ignored_hierarchy $options(ignore)
set top_module $options(top)
set compile_order $options(compile_order)
set include_ieee $options(include_ieee)
set include_gen_prods $options(include_gen_prods)

######## DEFAULTS #########
set do_rtl 0
set do_checkproj_env 0; set do_check_ci_env 0; set do_checkproj_ver 0;
set do_implementation 0; set do_synthesis 0; set do_bitstream 0
set do_create 0; set do_compile 0; set do_simulation 0; set recreate 0
set do_reset 1; set do_list_all 2; set do_check_syntax 0; set do_vitis_build 0;
set scripts_only 0; set compile_only 0
set ide_name ""
set allow_empty_proj 0
### Hog stand-alone directives ###
# The following directives are used WITHOUT ever calling the IDE, they are run in tclsh
# A place holder called new_directive can be followed to add new commands

set do_ipbus_xml 0
set do_list_file_parse 0
set do_check_yaml_ref 0
set do_buttons 0
set do_check_list_files 0
set do_compile_lib 0
set do_sigasi 0
set do_vhdl_ls 0
set do_cocotb 0
set do_hierarchy 0
set do_version 0

set NO_DIRECTIVE_FOUND 0
Msg Debug "Looking for a $directive in : $default_commands"
switch -regexp -- $directive $default_commands

if {$NO_DIRECTIVE_FOUND == 1} {
  Msg Debug "No directive found in default commands, looking in custom commands..."
  if {[string length $custom_commands] > 0 && [dict exists $custom_commands $directive]} {
    Msg Debug "Directive $directive found in custom commands."
    if {$cmd == "custom_tcl"} {
      eval [dict get $custom_commands $directive SCRIPT]
      exit
    } else {
      if {[IsTclsh]} {
        Msg Info "Launching command: $cmd..."

        # Check if the IDE is actually in the path...
        set ret [catch {exec which $ide}]
        if {$ret != 0} {
          Msg Error "$ide not found in your system. Make sure to add $ide to your PATH enviromental variable."
          exit $ret
        }

        if {[string first libero $cmd] >= 0} {
          # The SCRIPT_ARGS: flag of libero makes tcl crazy...
          # Let's pipe the command into a shell script and remove it later
          set libero_script [open "launch-libero-hog.sh" w]
          puts $libero_script "#!/bin/sh"
          puts $libero_script $cmd
          close $libero_script
          set cmd "sh launch-libero-hog.sh"
        }

        set ret [catch {exec -ignorestderr {*}$cmd >@ stdout} result]

        if {$ret != 0} {
          Msg Error "IDE returned an error state."
        } else {
          Msg Info "All done."
          exit 0
        }

        if {[string first libero $cmd] >= 0} {
          file delete "launch-libero-hog.sh"
        }

        exit $ret
      }

      eval [dict get $custom_commands $directive SCRIPT]

      set no_exit [dict get $custom_commands $directive NO_EXIT]
      if {$no_exit == 0} {
        exit
      }
    }
  } else {
      Msg Info "No directive found, pre ide exiting..."
      Msg Status "ERROR: Unknown directive $directive.\n\n"
      puts $usage
      exit
  }
}

if {$options(all) == 1} {
  set do_list_all 1
} else {
  set do_list_all 2
}

if {$options(dst_dir) == "" && ($do_ipbus_xml == 1 || $do_check_list_files == 1) && $project != ""} {
  # Getting all the versions and SHAs of the repository
  lassign [GetRepoVersions [file normalize $repo_path/Top/$group_name/$project] \
    $repo_path $ext_path] commit version hog_hash hog_ver top_hash top_ver libs hashes vers \
    cons_ver cons_hash ext_names ext_hashes xml_hash xml_ver user_ip_repos \
    user_ip_hashes user_ip_vers
  cd $repo_path

  set describe [GetHogDescribe [file normalize $repo_path/Top/$group_name/$project] $repo_path]
  set dst_dir [file normalize "$repo_path/bin/$group_name/$project\-$describe"]
}

if {$cmd == -1} {
  # This is if the project was not found
  Msg Status "\n\nPossible projects are:"
  ListProjects $repo_path $do_list_all
  Msg Status "\n"
  exit 1
} elseif {$cmd == -2} {
  # Project not given but needed
  Msg Status "ERROR: You must specify a project with directive $directive."
  # \n\n[cmdline::usage $parameters $usage]"
  Msg Status "Possible projects are:"
  ListProjects $repo_path $do_list_all
  exit 1
} elseif {$cmd == 0} {
  #This script was launched within the IDE,: Vivado, Quartus, etc
  Msg Info "$::argv0 was launched from the IDE."
} else {
  # This script was launched with Tclsh, we need to check the arguments
  # and if everything is right launch the IDE on this script and return
  #### Directives to be handled in tclsh should be here ###
  ### IMPORTANT: Each if block should either end with "exit 0" or
  ### set both $ide and $cmd to be executed when this script is run again
  if {$do_checkproj_env == 1} {
    CheckEnv $project_name $ide
    exit 0
  }

  if {$do_checkproj_ver == 1} {
    if {$project_name eq ""} {
      set projects [ListProjects $repo_path 1 0 1]
      foreach p $projects {
	CheckProjVer $repo_path $p $options(simcheck) $options(ext_path)
      }
    } else {
      CheckProjVer $repo_path $project_name $options(simcheck) $options(ext_path)
    }
    exit 0
      
  }

  if {$do_check_ci_env == 1} {
    CheckCIEnv
    exit 0
  }


  if {$do_ipbus_xml == 1} {
    if {[llength $project_name]  == 0} {
      Msg Error "XML option needs a project name."
      exit
    }
    Msg Info "Handling IPbus XMLs for $project_name..."

    set proj_dir $repo_path/Top/$project_name

    if {$options(generate) == 1} {
      set xml_gen 1
    } else {
      set xml_gen 0
    }

    if {$options(dst_dir) != ""} {
      set dst_dir $options(dst_dir)
    } else {
      if {![info exists dst_dir]} {
	set dst_dir ""
      }

    }
    set xml_dst "$dst_dir/xml"


    if {[llength [glob -nocomplain $proj_dir/list/*.ipb]] > 0} {
      if {![file exists $xml_dst]} {
        Msg Info "$xml_dst directory not found, creating it..."
        file mkdir $xml_dst
      }
    } else {
      Msg Error "No .ipb files found in $proj_dir/list/"
      exit
    }

    set ret [GetRepoVersions $proj_dir $repo_path ""]
    set sha [lindex $ret 13]
    set hex_ver [lindex $ret 14]

    set ver [HexVersionToString $hex_ver]
    CopyIPbusXMLs $proj_dir $repo_path $xml_dst $ver $sha 1 $xml_gen

    exit 0
  }

  if {$do_list_file_parse == 1} {
    set proj_dir $repo_path/Top/$project_name
    set proj_list_dir $repo_path/Top/$project_name/list
    GetHogFiles -print_log -list_files {.src,.con,.sim,.ext,.ipb} $proj_list_dir $repo_path
    Msg Status "  "
    Msg Info "All Done."
    exit 0
  }

  if {$do_hierarchy == 1} {
    source $tcl_path/utils/hierarchy.tcl
    set proj_dir $repo_path/Top/$project_name
    set proj_list_dir $repo_path/Top/$project_name/list
    lassign [GetHogFiles -ext_path $ext_path \
        -list_files ".src,.ext" $proj_list_dir $repo_path]\
        listLibraries listProperties listSrcSets
    set hierarchy_result [Hierarchy $listProperties $listLibraries $repo_path $output_path $compile_order \
    $light_hierarchy $top_module $ignored_hierarchy $include_ieee $include_gen_prods]
    puts $hierarchy_result
    exit 0
  }
  if {$do_sigasi == 1} {
    cd $repo_path
    Msg Info "Creating Sigasi CSV files for project $project_name..."
    set proj_dir $repo_path/Top/$project_name
    set proj_list_dir $repo_path/Top/$project_name/list
    set project [file tail $project_name]
    lassign [GetHogFiles -list_files {.src} $proj_list_dir $repo_path] libraries
    set csv_file [open "sigasi_$project.csv" w]
    foreach lib $libraries {
      set source_files [DictGet $libraries $lib]
      foreach source_file $source_files {
        if {[file extension $source_file] == ".vhd" ||
            [file extension $source_file] == ".vhdl" ||
            [file extension $source_file] == ".sv" ||
            [file extension $source_file] == ".v" } {
          puts $csv_file [ concat  [file rootname $lib] "," $source_file ]
        }
      }
    }
    close $csv_file
    Msg Info "Sigasi CSV file created: sigasi_$project.csv"
    Msg Info "You can use the python script provided by Sigasi to convert the generated csv file into a Sigasi project."
    Msg Info "More info at: https://www.sigasi.com/knowledge/how_tos/generating-sigasi-project-vivado-project/#2-generate-the-sigasi-project-files-from-the-csv-file"
    exit 0
  }

  if {$do_vhdl_ls == 1} {
    cd $repo_path
    Msg Info "Creating VHDL-LS configuration file for project $project_name..."
    set proj_dir $repo_path/Top/$project_name
    set proj_list_dir $repo_path/Top/$project_name/list
    set project [file tail $project_name]
    lassign [GetHogFiles -list_files {.src} $proj_list_dir $repo_path] libraries
    set toml_file [open "vhdl_ls_$project.toml" w]
    puts $toml_file "\[libraries\]"
    dict for {lib source_files} $libraries {
      puts $toml_file "[file rootname $lib].files = \["
      foreach source_file $source_files {
        if {[file extension $source_file] == ".vhd" ||
            [file extension $source_file] == ".vhdl"
            } {
                # puts [Relative $repo_path $source_file ]
                puts $toml_file "\'[Relative $repo_path $source_file ]\',"
            }
        }
      puts $toml_file "\]\n"
    }
    close $toml_file
    Msg Info "VHDL-LS TOML File created: vhdl_ls_$project.toml"
    Msg Info "You can copy the content of this file into your VHDL-LS configuration vhdl_ls.toml, to import all Hog libraries."
    exit 0
  }

  if {$do_cocotb == 1} {
    source $tcl_path/utils/cocotb.tcl
    source $tcl_path/utils/hierarchy.tcl
    WriteCocoTbTemplate $project_name $repo_path $lib_path $ext_path
    exit 0
  }

  if {$do_check_yaml_ref == 1} {
    Msg Info "Checking if \"ref\" in .gitlab-ci.yml actually matches the included yml file in Hog submodule"
    CheckYmlRef $repo_path false
    exit 0
  }

  if {$do_buttons == 1} {
    Msg Info "Adding Hog buttons to Vivado bar (will use the vivado currently in PATH)..."
    set ide vivado
    set cmd "vivado -mode batch -notrace -source $repo_path/Hog/Tcl/utils/add_hog_custom_button.tcl"
  }

  if {$do_compile_lib == 1} {
    if {$project eq ""} {
      Msg Error "You need to specify a simulator as first argument."
      exit 1
    } else {
      set simulator $project
      Msg Info "Selecting $simulator simulator..."
    }
    if {$options(dst_dir) != ""} {
      set output_dir $options(dst_dir)
    } else {
      Msg Info "No destination directory defined. Using default: SimulationLib/"
      set output_dir "SimulationLib"
    }

    set ide vivado
    set cmd "vivado -mode batch -notrace -source $repo_path/Hog/Tcl/utils/compile_simlib.tcl  -tclargs -simulator $simulator -output_dir $output_dir"
  }

  set simsets ""
  if {$do_simulation == 1} {
    # Filter out HLS simsets (csim:*/cosim:*) -- GHDL only needs HDL simsets
    set hdl_simsets_pre [list]
    if {$options(simset) ne ""} {
      foreach s $options(simset) {
        if {![regexp {^(csim|cosim):} $s]} {
          lappend hdl_simsets_pre $s
        }
      }
    }

    # Get all simsets in the project that run with GHDL
    set ghdl_simsets [GetSimSets $project_name $repo_path "$hdl_simsets_pre" 1]
    set ghdl_import 0
    dict for {simset_name simset_dict} $ghdl_simsets {
      if {$ghdl_import == 0} {
        ImportGHDL $project_name $repo_path $simset_name $simset_dict $ext_path
        set ghdl_import 1
      }
      LaunchGHDL $project_name $repo_path $simset_name $simset_dict $ext_path
    }
    set ide_simsets [GetSimSets $project_name $repo_path $hdl_simsets_pre 0 1]

    if {[dict size $ide_simsets] == 0} {
      # Check if there are HLS simsets to run before exiting
      set has_hls [expr {$options(simset) eq ""}]
      if {!$has_hls} {
        foreach s $options(simset) {
          if {[regexp {^(csim|cosim):} $s]} {
            set has_hls 1
            break
          }
        }
      }
      if {!$has_hls} {
        Msg Info "All simulations have been run, exiting..."
        exit 0
      }
    }
  }

  if {$do_version == 1} {
      cd $repo_path
      set proj_dir $repo_path/Top/$project_name
      lassign [GetRepoVersions $proj_dir $repo_path $ext_path] sha ver
      if {$options(describe) == 1} {
        puts [GetHogDescribe $proj_dir $repo_path]
      } else {
        puts "v[HexVersionToString $ver]"
      }
      exit 0
    }
  # if {$do_new_directive ==1 } {
  #
  # # Do things here
  #
  # exit 0
  #}

  #### END of tclsh commands ####
  Msg Info "Launching command: $cmd..."

  # Check if the IDE is actually in the path...
  set ret [catch {exec which $ide}]
  if {$ret != 0} {
      if {[string match "*vitis_unified*" $ide_name]} {
        Msg Error "This is a '$ide_name' project: make sure to add both Vivado and Vitis to your PATH environment variable."
        } else {
        Msg Error "$ide not found in your system. Make sure to add $ide to your PATH environment variable."
        }
    exit $ret
  }

  if {[string first libero $cmd] >= 0} {
    # The SCRIPT_ARGS: flag of libero makes tcl crazy...
    # Let's pipe the command into a shell script and remove it later
    set libero_script [open "launch-libero-hog.sh" w]
    puts $libero_script "#!/bin/sh"
    puts $libero_script $cmd
    close $libero_script
    set cmd "sh launch-libero-hog.sh"
  }

  set ret [catch {exec -ignorestderr {*}$cmd >@ stdout} result]

  if {$ret != 0} {
    Msg Error "IDE returned an error state."
  } else {
    Msg Info "All done."
    exit 0
  }

  if {[string first libero $cmd] >= 0} {
    file delete "launch-libero-hog.sh"
  }

  exit $ret
}

#After this line, we are in the IDE
##################################################################################


# We need to Import tcllib if we are using Libero
if {[IsLibero] || [IsDiamond]} {
  if {[info exists env(HOG_TCLLIB_PATH)]} {
    lappend auto_path $env(HOG_TCLLIB_PATH)
  } else {
    puts "ERROR: To run Hog with Microsemi Libero SoC or Lattice Diamond,\
    you need to define the HOG_TCLLIB_PATH variable."
    return
  }
}

if {[catch {package require cmdline} ERROR] || [catch {package require struct::matrix} ERROR]} {
  puts "$ERROR\n Tcllib not found. If you are running this script on tclsh for debuggin purpose ONLY, you can fix this by installing 'tcllib'"
  exit 1
}

set run_folder [file normalize "$repo_path/Projects/$project_name/$project.runs/"]
if {[IsLibero]} {
  set run_folder [file normalize "$repo_path/Projects/$project_name/"]
}

# Only for quartus, not used otherwise
set project_path [file normalize "$repo_path/Projects/$project_name/"]

# Get IDE name from project config file
if {$allow_empty_proj == 0 || $project_name ne ""} {
  set proj_conf [ProjectExists $project_name $repo_path]
} else {
  set proj_conf ""
}
set ide_name_and_ver [string tolower [GetIDEFromConf $proj_conf]]
set ide_name [lindex [regexp -all -inline {\S+} $ide_name_and_ver] 0]

# Validate IDE name
set supported_ides [list vivado vivado_vitis_classic vivado_vitis_unified vitis_classic vitis_unified quartus planahead libero diamond ghdl]
if {$ide_name ni $supported_ides} {
  if {$ide_name eq "vitis"} {
    Msg Error "The IDE set in hog.conf ('vitis') is not supported. Did you mean 'vitis_unified' or 'vitis_classic'? Supported IDEs: [join $supported_ides {, }]"
  } else {
    Msg Error "The IDE set in hog.conf ('$ide_name') is not supported. Supported IDEs: [join $supported_ides {, }]"
  }
  exit 1
}

# Vitis IDE detection
if {([string tolower $ide_name] eq "vivado_vitis_classic" || [string tolower $ide_name] eq "vitis_classic") && ($options(vivado_only) != 1)} {
  set globalSettings::vitis_classic 1
  set globalSettings::vitis_unified 0
} elseif {([string tolower $ide_name] eq "vivado_vitis_unified" || [string tolower $ide_name] eq "vitis_unified") && ($options(vivado_only) != 1)} {
  set globalSettings::vitis_classic 0
  set globalSettings::vitis_unified 1
  if {[auto_execok vitis] eq ""} {
    Msg Error "Vitis Unified IDE is required for project $project_name but 'vitis' was not found in PATH. Please source Vitis settings first."
  }
} else {
  set globalSettings::vitis_classic 0
  set globalSettings::vitis_unified 0
}

# Standalone vitis_unified / vitis_classic projects are implicitly vitis-only
if {$ide_name eq "vitis_unified" || $ide_name eq "vitis_classic"} {
  set options(vitis_only) 1
}

set is_vitis_ide [expr {$globalSettings::vitis_classic == 1 || $globalSettings::vitis_unified == 1}]
set is_build_step [expr {$do_synthesis == 1 || $do_implementation == 1 || $do_compile == 1}]
if {$is_vitis_ide && $options(vitis_only) == 1 && $is_build_step} {
  set do_vitis_build 1
}


if {$options(no_bitstream) == 1} {
  set do_bitstream 0
  set do_compile 0
}

if {$options(recreate) == 1} {
  set recreate 1
}

if {$options(synth_only) == 1} {
  set do_implementation 0
  set do_synthesis 1
  set do_bitstream 0
  set do_create 1
  set do_compile 1
}

if {$options(impl_only) == 1} {
  set do_implementation 1
  set do_synthesis 0
  set do_bitstream 0
  set do_create 0
  set do_compile 1
}

if {$options(vitis_only) == 1 || $ide_name eq "vitis_classic" || $ide_name eq "vitis_unified"} {
  set do_implementation 0
  set do_synthesis 0
  set do_bitstream 0
  set do_compile 0
}

if {$options(bitstream_only) == 1} {
  set do_bitstream_only 1
  set do_bitstream 0
  set do_implementation 0
  set do_synthesis 0
  set do_create 0
  set do_compile 0
} else {
  set do_bitstream_only 0
}

if {$options(no_reset) == 1} {
  set do_reset 0
}

if {$options(check_syntax) == 1} {
  set do_check_syntax 1
}

if {$options(scripts_only) == 1} {
  set scripts_only 1
}

if {$options(compile_only) == 1} {
  set compile_only 1
}





Msg Info "Number of jobs set to $options(njobs)."

############## Quartus ########################
set argv ""

############# CREATE or OPEN project ############
if {$options(vitis_only) == 1 && ($ide_name eq "vitis_unified" || $ide_name eq "vivado_vitis_unified")} {
  cd $tcl_path
  set project_file [file normalize $repo_path/Projects/$project_name/vitis_unified/_ide/settings.json]
  Msg Info "Setting project file for Vitis Unified project $project_name to $project_file"
} elseif {$options(vitis_only) == 1 && ($ide_name eq "vitis_classic" || $ide_name eq "vivado_vitis_classic")} {
  cd $tcl_path
  set project_file [file normalize $repo_path/Projects/$project_name/vitis_classic/.metadata/]
  Msg Info "Setting project file for Vitis Classic project $project_name to $project_file"
} elseif {[IsISE]} {
  cd $tcl_path
  set project_file [file normalize $repo_path/Projects/$project_name/$project.ppr]
} elseif {[IsVivado]} {
  cd $tcl_path
  set project_file [file normalize $repo_path/Projects/$project_name/$project.xpr]
} elseif {[IsVitisClassic]} {
  cd $tcl_path
  set project_file [file normalize $repo_path/Projects/$project_name/vitis_classic/.metadata/]
  Msg Info "Setting project file for Vitis Classic project $project_name to $project_file"
} elseif {[IsVitisUnified]} {
  cd $tcl_path
  set project_file [file normalize $repo_path/Projects/$project_name/vitis_unified/_ide/settings.json]
  Msg Info "Setting project file for Vitis Unified project $project_name to $project_file"
} elseif {[IsQuartus]} {
  if {[catch {package require ::quartus::project} ERROR]} {
    Msg Error "$ERROR\n Can not find package ::quartus::project"
    cd $old_path
    return 1
  } else {
    Msg Info "Loaded package ::quartus::project"
    load_package flow
  }
  set project_file "$project_path/$project.qpf"
} elseif {[IsLibero]} {
  set project_file [file normalize $repo_path/Projects/$project_name/$project.prjx]
} elseif {[IsDiamond]} {
  sys_install version
  set project_file [file normalize $repo_path/Projects/$project_name/$project.ldf]
}

if {[file exists $project_file]} {
  Msg Info "Found project file $project_file for $project_name."
  set proj_found 1
} else {
  # Path from InitLauncher may resolve to a different mount for the same repo.
  # Discover repo root and use first path where project exists (file or, for Vitis Unified, project dir).
  set repo_norm [file normalize $repo_path]
  set rel [string trimleft [string range $project_file [string length $repo_norm] end] "/"]
  set proj_found 0
  foreach start_dir [list [file dirname [info script]] [pwd]] {
    set repo_candidate [FindRepoRoot $start_dir]
    Msg Debug "FindRepoRoot([list $start_dir]) => [list $repo_candidate]"
    if {$repo_candidate ne ""} {
      set project_file_alt [file join $repo_candidate $rel]
      set found 0
      if {[file exists $project_file_alt]} {
        set found 1
      } elseif {$options(vitis_only) == 1 && [string match "*vitis_unified*" $rel]} {
        set ide_dir [file join $repo_candidate Projects $project_name vitis_unified _ide]
        if {[file exists $ide_dir]} {
          set found 1
        }
      }
      if {$options(vitis_only) == 1 && [string match "*vitis_unified*" $rel]} {
        Msg Debug "Checking file [list $project_file_alt] exists=[file exists $project_file_alt]; _ide dir [list $ide_dir] exists=[file exists $ide_dir]"
      } else {
        Msg Debug "Checking [list $project_file_alt] exists=[file exists $project_file_alt]"
      }
      if {$found} {
        set project_file $project_file_alt
        set repo_path $repo_candidate
        Msg Info "Found project file $project_file for $project_name."
        set proj_found 1
        break
      }
    }
  }
  if {!$proj_found} {
      Msg Info "Project file not found for $project_name."
  }
}

if {($proj_found == 0 || $recreate == 1)} {
  set do_create 1
  Msg Info "Creating (possibly replacing) the project $project_name..."
  Msg Debug "launch.tcl: calling GetConfFiles with $repo_path/Top/$project_name"
  lassign [GetConfFiles $repo_path/Top/$project_name] conf sim pre post pre_rtl post_rtl

  if {[file exists $conf]} {
    set globalSettings::vitis_only_pass $options(vitis_only)
    if {$options(vivado_only) == 1} {
      CreateProject -simlib_path $lib_path -xsa $options(xsa) -vivado_only $project_name $repo_path
    } elseif {$options(vitis_only) == 1} {
      CreateProject -simlib_path $lib_path -xsa $options(xsa) -vitis_only $project_name $repo_path
    } else {
      CreateProject -simlib_path $lib_path -xsa $options(xsa) $project_name $repo_path
    }
    Msg Info "Done creating project $project_name."
    if {$options(vitis_only) == 1 && ($ide_name eq "vitis_unified" || $ide_name eq "vivado_vitis_unified")} {
      set project_file [file join $repo_path Projects $project_name vitis_unified _ide settings.json]
    }
  } else {
    Msg Error "Project $project_name is incomplete: no hog.conf file found, please create one..."
  }
} elseif {$proj_found == 0} {
  Msg Error "Project $project_name not found. Please create it first using the 'CREATE' or 'C' directive."
  exit 1
} else {
  Msg Info "Opening existing project file $project_file..."
  if {$options(vitis_only) == 1 && ($ide_name eq "vitis_unified" || $ide_name eq "vivado_vitis_unified")} {
    set vitis_workspace [file normalize $repo_path/Projects/$project_name/vitis_unified/]
    Msg Info "Setting Vitis Unified workspace to $vitis_workspace"
  } elseif {[IsXilinx]} {
    file mkdir "$repo_path/Projects/$project_name/$project.gen/sources_1"
    OpenProject $project_file $repo_path
  } elseif {[IsVitisClassic]} {
    set vitis_workspace [file normalize $repo_path/Projects/$project_name/vitis_classic/]
    Msg Info "Setting workspace to $vitis_workspace"
  } elseif {[IsVitisUnified]} {
    set vitis_workspace [file normalize $repo_path/Projects/$project_name/vitis_unified/]
    Msg Info "Setting workspace to $vitis_workspace"
  } else {
    OpenProject $project_file $repo_path
  }
}



########## CHECK SYNTAX ###########
if {$do_check_syntax == 1} {
  if {$ide_name eq "vitis_unified" || $ide_name eq "vitis_classic"} {
    Msg Info "Skipping syntax check for $project_name: pure Vitis project has no HDL syntax to check"
  } else {
    Msg Info "Checking syntax for project $project_name..."
    CheckSyntax $project_name $repo_path $project_file
  }
}

######### RTL ANALYSIS ########
if {$do_rtl == 1} {
  lassign [GetConfFiles $repo_path/Top/$project_name] conf sim pre post pre_rtl post_rtl
  LaunchRTLAnalysis $repo_path $pre_rtl $post_rtl
}

if {$do_vitis_build == 1} {
  if {[IsVitisClassic] || [IsVitisUnified]} {
    # Check for HLS components and build them
    set conf_file_path [file normalize "$repo_path/Top/$project_name/hog.conf"]
    if {[file exists $conf_file_path]} {
      set proj_properties [ReadConf $conf_file_path]
      set hls_components [dict filter $proj_properties key {hls:*}]
      if {[dict size $hls_components] > 0} {
        Msg Info "Found [dict size $hls_components] HLS component(s), launching HLS build..."
        LaunchHlsBuild $project_name $repo_path
      }
      # Build apps/platforms if any exist
      set has_apps [expr {[dict size [dict filter $proj_properties key {app:*}]] > 0}]
      if {$has_apps} {
        LaunchVitisBuild $project_name $repo_path
      }
    } else {
      LaunchVitisBuild $project_name $repo_path
    }
  } else {
    Msg Error "Vitis build is not supported for $ide_name (only Vitis Classic and Vitis Unified are supported)"
    exit 1
  }
}

######### LaunchSynthesis ########
if {$do_synthesis == 1} {
  LaunchSynthesis $do_reset $do_create $run_folder $project_name $repo_path $ext_path $options(njobs)
}

if {$do_implementation == 1} {
  LaunchImplementation $do_reset $do_create $run_folder $project_name $repo_path $options(njobs) $do_bitstream
}

if {$do_bitstream_only == 1 && [IsXilinx]} {
  GenerateBitstreamOnly $project_name $repo_path
} elseif {$do_bitstream_only == 1 && ![IsXilinx]} {
  Msg Error "Bitstream only option is not supported for this IDE."
}

if {$do_bitstream == 1 && ![IsXilinx]} {
  GenerateBitstream $run_folder $repo_path $options(njobs)
}

if {$do_simulation == 1} {
  # Separate HLS simsets (csim:*/cosim:*) from HDL simsets
  set hdl_simsets [list]
  set hls_simsets [list]
  if {$options(simset) ne ""} {
    foreach s $options(simset) {
      if {[regexp {^(csim|cosim):} $s]} {
        lappend hls_simsets $s
      } else {
        lappend hdl_simsets $s
      }
    }
  }
  set run_hdl [expr {[llength $hdl_simsets] > 0 || $options(simset) eq ""}]
  set run_hls [expr {[llength $hls_simsets] > 0 || $options(simset) eq ""}]

  # Run HDL simulations
  if {$run_hdl} {
    set simsets [GetSimSets $project_name $repo_path $hdl_simsets]
    if {[dict size $simsets] > 0} {
      LaunchSimulation $project_name $lib_path $simsets $repo_path $scripts_only $compile_only
    }
  }

  # Run HLS simulations (csim/cosim)
  if {$run_hls} {
    LaunchHlsSimulation $project_name $repo_path $hls_simsets
  }
}


if {$do_check_list_files} {
  Msg Info "Running list file checker..."

  #if {![file exists $dst_dir]} {
  #   Msg Info "$dst_dir directory not found, creating it..."
  #   file mkdir $dst_dir
  # }


  set argv0 check_list_files
  if {$ext_path ne ""} {
    set argv [list "-ext_path" "$ext_path" "-outDir" "$dst_dir" "-pedantic"]
  } else {
    set argv [list "-outDir" "$dst_dir" "-pedantic"]
  }

  source $tcl_path/utils/check_list_files.tcl
}
## CLOSE Project
CloseProject

Msg Info "All done."
cd $old_path
