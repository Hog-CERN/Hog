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

## @file hog.tcl

#### GLOBAL CONSTANTS
set CI_STAGES {"generate_project" "simulate_project"}
set CI_PROPS {"-synth_only"}

#### FUNCTIONS

## @brief Add a new file to a fileset in Vivado
#
# @param[in] file    The name of the file to add. NOTE: directories are not supported.
# @param[in] fileset The fileset name
#
proc AddFile {file fileset} {
  if {[IsXilinx]} {
    add_files -norecurse -fileset $fileset $file
  }
}

## @brief  Add libraries, properties and filesets to the project
#
# @param[in] libraries has library name as keys and a list of filenames as values
# @param[in] properties has as file names as keys and a list of properties as values
# @param[in] filesets has fileset name as keys and a list of libraries as values
#
proc AddHogFiles { libraries properties filesets } {
  Msg Info "Adding source files to project..."
  Msg Debug "Filesets: $filesets"
  Msg Debug "Libraries: $libraries"
  Msg Debug "Properties: $properties"

  if {[IsLibero]} {
    set synth_conf_command "organize_tool_files -tool {SYNTHESIZE} -input_type {constraint}"
    set synth_conf 0
    set timing_conf_command "organize_tool_files -tool {VERIFYTIMING} -input_type {constraint}"
    set timing_conf 0
    set place_conf_command "organize_tool_files -tool {PLACEROUTE} -input_type {constraint}"
    set place_conf 0
  }

  foreach fileset [dict keys $filesets] {
    Msg Debug "Fileset: $fileset"
    # Create fileset if it doesn't exist yet
    if {[IsVivado]} {
      if {[string equal [get_filesets -quiet $fileset] ""]} {
        # Simulation list files supported only by Vivado
        create_fileset -simset $fileset
        # Set active when creating, by default it will be the latest simset to be created, unless is specified in the sim.conf
        current_fileset -simset [ get_filesets $fileset ]
        set simulation [get_filesets $fileset]
        foreach simulator [GetSimulators] {
          set_property -name {$simulator.compile.vhdl_syntax} -value {2008} -objects $simulation
        }
        set_property SOURCE_SET sources_1 $simulation
      }
    }
    # Check if ips.src is in $fileset
    set libs_in_fileset [DictGet $filesets $fileset]
    if { [IsInList "ips.src" $libs_in_fileset] } {
      set libs_in_fileset [MoveElementToEnd $libs_in_fileset "ips.src"]
    }

    # Loop over libraries in fileset
    foreach lib $libs_in_fileset {
      Msg Debug "lib: $lib \n"
      set lib_files [DictGet $libraries $lib]
      Msg Debug "Files in $lib: $lib_files"
      set rootlib [file rootname [file tail $lib]]
      set ext [file extension $lib]
      Msg Debug "lib: $lib ext: $ext fileset: $fileset"
      # ADD NOW LISTS TO VIVADO PROJECT
      if {[IsXilinx]} {
        Msg Debug "Adding $lib to $fileset"
        add_files -norecurse -fileset $fileset $lib_files
        # Add Properties
        foreach f $lib_files {
          set file_obj [get_files -of_objects [get_filesets $fileset] [list "*$f"]]
          #ADDING LIBRARY
          if {[file extension $f] == ".vhd" || [file extension $f] == ".vhdl"} {
            set_property -name "library" -value $rootlib -objects $file_obj
          }

          # ADDING FILE PROPERTIES
          set props [DictGet $properties $f]
          if {[file extension $f] == ".vhd" || [file extension $f] == ".vhdl"} {
            # VHDL 93 property
            if {[lsearch -inline -regexp $props "93"] < 0} {
              # ISE does not support vhdl2008
              if {[IsVivado]} {
		if {[lsearch -inline -regexp $props "2008"] >= 0} {
		  set vhdl_year "VHDL 2008"
		} elseif {[lsearch -inline -regexp $props "2019"] >= 0} {
		  if { [GetIDEVersion] >= 2023.2 } {
		    set vhdl_year "VHDL 2019"
		  } else {
		    Msg CriticalWarning "VHDL 2019 is not supported in Vivado version older than 2023.2, using vhdl 2008, but this might not work."
		    set vhdl_year "VHDL 2008"
		  }
		} else {
		  # The default VHDL year is 2008
		  set vhdl_year "VHDL 2008"
		}
		Msg Debug "File type for $f is $vhdl_year"
                set_property -name "file_type" -value $vhdl_year -objects $file_obj
              }
            } else {
              Msg Debug "Filetype is VHDL 93 for $f"
            }
          }

          # SystemVerilog property
          if {[lsearch -inline -regexp $props "SystemVerilog"] > 0 } {
            # ISE does not support SystemVerilog
            if {[IsVivado]} {
              set_property -name "file_type" -value "SystemVerilog" -objects $file_obj
              Msg Debug "Filetype is SystemVerilog for $f"
            } else {
              Msg Warning "Xilinx PlanAhead/ISE does not support SystemVerilog. Property not set for $f"
            }
          }

          # Top synthesis module
          set top [lindex [regexp -inline {top\s*=\s*(.+?)\y.*} $props] 1]
          if { $top != "" } {
            Msg Info "Setting $top as top module for file set $fileset..."
            set globalSettings::synth_top_module $top
          }


          # Verilog headers
          if {[lsearch -inline -regexp $props "verilog_header"] >= 0} {
            Msg Debug "Setting verilog header type for $f..."
            set_property file_type {Verilog Header} [get_files $f]
          } elseif {[lsearch -inline -regexp $props "verilog_template"] >= 0} {
            # Verilog Template
            Msg Debug "Setting verilog template type for $f..."
            set_property file_type {Verilog Template} [get_files $f]
          } elseif {[lsearch -inline -regexp $props "verilog"] >= 0} {
            # Normal Verilog
            Msg Debug "Setting verilog type for $f..."
            set_property file_type {Verilog} [get_files $f]
          }

          # Not used in synthesis
          if {[lsearch -inline -regexp $props "nosynth"] >= 0} {
            Msg Debug "Setting not used in synthesis for $f..."
            set_property -name "used_in_synthesis" -value "false" -objects $file_obj
          }

          # Not used in implementation
          if {[lsearch -inline -regexp $props "noimpl"] >= 0} {
            Msg Debug "Setting not used in implementation for $f..."
            set_property -name "used_in_implementation" -value "false" -objects $file_obj
          }

          # Not used in simulation
          if {[lsearch -inline -regexp $props "nosim"] >= 0} {
            Msg Debug "Setting not used in simulation for $f..."
            set_property -name "used_in_simulation" -value "false" -objects $file_obj
          }

          ## Simulation properties
          # Top simulation module
          set top_sim [lindex [regexp -inline {topsim\s*=\s*(.+?)\y.*} $props] 1]
          if { $top_sim != "" } {
            Msg Warning "Setting the simulation top module from simulation list files is now deprecated. Please set this property in the sim.conf file, by adding the following line under the \[$fileset\] section.\ntop=$top_sim"
          }

          # Simulation runtime
          set sim_runtime [lindex [regexp -inline {runtime\s*=\s*(.+?)\y.*} $props] 1]
          if { $sim_runtime != "" } {
            Msg Warning "Setting the simulation runtime from simulation list files is now deprecated. Please set this property in the sim.conf file, by adding the following line under the \[$fileset\] section.\n<simulator_name>.simulate.runtime=$sim_runtime"
            # set_property -name {xsim.simulate.runtime} -value $sim_runtime -objects [get_filesets $fileset]
            # foreach simulator [GetSimulators] {
            #   set_property $simulator.simulate.runtime  $sim_runtime  [get_filesets $fileset]
            # }
          }

          # Wave do file
          if {[lsearch -inline -regexp $props "wavefile"] >= 0} {
            Msg Warning "Setting a wave do file from simulation list files is now deprecated. Set this property in the sim.conf file, by adding the following line under the \[$fileset\] section.\n<simulator_name>.simulate.custom_wave_do=[file tail $f]"

            # Msg Debug "Setting $f as wave do file for simulation file set $fileset..."

            # # check if file exists...
            # if {[file exists $f]} {
            #   foreach simulator [GetSimulators] {
            #     set_property "$simulator.simulate.custom_wave_do" [file tail $f] [get_filesets $fileset]
            #   }
            # } else {
            #   Msg Warning "File $f was not found."
            # }
          }

          #Do file
          if {[lsearch -inline -regexp $props "dofile"] >= 0} {
            Msg Warning "Setting a custom do file from simulation list files is now deprecated. Set this property in the sim.conf file, by adding the following line under the \[$fileset\] section.\n<simulator_name>.simulate.custom_do=[file tail $f]"
            # Msg Debug "Setting $f as do file for simulation file set $fileset..."

            # if {[file exists $f]} {
            #   foreach simulator [GetSimulators] {
            #     set_property "$simulator.simulate.custom_udo" [file tail $f] [get_filesets $fileset]
            #   }
            # } else {
            #   Msg Warning "File $f was not found."
            # }
          }

          # Lock the IP
          if {[lsearch -inline -regexp $props "locked"] >= 0 && $ext == ".ip"} {
            Msg Info "Locking IP $f..."
            set_property IS_MANAGED 0 [get_files $f]
          }

          # Generating Target for BD File
          if {[file extension $f] == ".bd"} {
            Msg Info "Generating Target for [file tail $f], please remember to commit the (possible) changed file."
            generate_target all [get_files $f]
          }


          # Tcl
          if {[file extension $f] == ".tcl" && $ext != ".con"} {
            if { [lsearch -inline -regexp $props "source"] >= 0} {
              Msg Info "Sourcing Tcl script $f, and setting it not used in synthesis, implementation and simulation..."
              source $f
              set_property -name "used_in_synthesis" -value "false" -objects $file_obj
              set_property -name "used_in_implementation" -value "false" -objects $file_obj
              set_property -name "used_in_simulation" -value "false" -objects $file_obj
            }
          }

          # Constraint Properties
          set ref [lindex [regexp -inline {scoped_to_ref\s*=\s*(.+?)\y.*} $props] 1]
          set cell [lindex [regexp -inline {scoped_to_cells\s*=\s*(.+?)\y.*} $props] 1]
          if {([file extension $f] == ".tcl" || [file extension $f] == ".xdc") && $ext == ".con"} {
            if {$ref != ""} {
              set_property SCOPED_TO_REF $ref $file_obj
            }
            if {$cell != ""} {
              set_property SCOPED_TO_CELLS $cell $file_obj
            }
          }

        }
        Msg Info "[llength $lib_files] file/s added to library $rootlib..."
      } elseif {[IsQuartus] } {
        #QUARTUS ONLY
        if { $ext == ".sim"} {
          Msg Warning "Simulation files not supported in Quartus Prime mode... Skipping $lib"
        } else {
          if {! [is_project_open] } {
            Msg Error "Project is closed"
          }
          foreach cur_file $lib_files {
            set file_type [FindFileType $cur_file]

            #ADDING FILE PROPERTIES
            set props [DictGet $properties $cur_file]

            # Top synthesis module
            set top [lindex [regexp -inline {top\s*=\s*(.+?)\y.*} $props] 1]
            if { $top != "" } {
              Msg Info "Setting $top as top module for file set $fileset..."
              set globalSettings::synth_top_module $top
            }
            # VHDL file properties
            if {[string first "VHDL" $file_type] != -1 } {
              if {[string first "1987" $props] != -1 } {
                set hdl_version "VHDL_1987"
              } elseif {[string first "1993" $props] != -1 } {
                set hdl_version "VHDL_1993"
              } elseif {[string first "2008" $props] != -1 } {
                set hdl_version "VHDL_2008"
              } else {
                set hdl_version "default"
              }
              if { $hdl_version == "default" } {
                set_global_assignment -name $file_type $cur_file -library $rootlib
              } else {
                set_global_assignment -name $file_type $cur_file -hdl_version $hdl_version -library $rootlib
              }
            } elseif {[string first "SYSTEMVERILOG" $file_type] != -1 } {
              # SystemVerilog file properties
              if {[string first "2005" $props] != -1 } {
                set hdl_version "systemverilog_2005"
              } elseif {[string first "2009" $props] != -1 } {
                set hdl_version "systemverilog_2009"
              } else {
                set hdl_version "default"
              }
              if { $hdl_version == "default" } {
                set_global_assignment -name $file_type $cur_file
              } else {
                set_global_assignment -name $file_type $cur_file -hdl_version $hdl_version
              }
            } elseif {[string first "VERILOG" $file_type] != -1 } {
              # Verilog file properties
              if {[string first "1995" $props] != -1 } {
                set hdl_version "verilog_1995"
              } elseif {[string first "2001" $props] != -1 } {
                set hdl_version "verilog_2001"
              } else {
                set hdl_version "default"
              }
              if { $hdl_version == "default" } {
                set_global_assignment -name $file_type $cur_file
              } else {
                set_global_assignment -name $file_type $cur_file -hdl_version $hdl_version
              }
            } elseif {[string first "SOURCE" $file_type] != -1 || [string first "COMMAND_MACRO" $file_type] != -1 } {
              set_global_assignment  -name $file_type $cur_file
              if { $ext == ".con"} {
                source $cur_file
              } elseif { $ext == ".src"} {
                # If this is a Platform Designer file then generate the system
                if {[string first "qsys" $props] != -1 } {
                  # remove qsys from options since we used it
                  set emptyString ""
                  regsub -all {\{||qsys||\}} $props $emptyString props

                  set qsysPath [file dirname $cur_file]
                  set qsysName "[file rootname [file tail $cur_file]].qsys"
                  set qsysFile "$qsysPath/$qsysName"
                  set qsysLogFile "$qsysPath/[file rootname [file tail $cur_file]].qsys-script.log"

                  set qsys_rootdir ""
                  if {! [info exists ::env(QSYS_ROOTDIR)] } {
                    if {[info exists ::env(QUARTUS_ROOTDIR)] } {
                      set qsys_rootdir "$::env(QUARTUS_ROOTDIR)/sopc_builder/bin"
                      Msg Warning "The QSYS_ROOTDIR environment variable is not set! I will use $qsys_rootdir"
                    } else {
                      Msg CriticalWarning "The QUARTUS_ROOTDIR environment variable is not set! Assuming all quartus executables are contained in your PATH!"
                    }
                  } else {
                    set qsys_rootdir $::env(QSYS_ROOTDIR)
                  }

                  set cmd "$qsys_rootdir/qsys-script"
                  set cmd_options " --script=$cur_file"
                  if {![catch {"exec $cmd -version"}] || [lindex $::errorCode 0] eq "NONE"} {
                    Msg Info "Executing: $cmd $cmd_options"
                    Msg Info "Saving logfile in: $qsysLogFile"
                    if { [ catch {eval exec -ignorestderr "$cmd $cmd_options >>& $qsysLogFile"} ret opt ]} {
                      set makeRet [lindex [dict get $opt -errorcode] end]
                      Msg CriticalWarning "$cmd returned with $makeRet"
                    }
                  } else {
                    Msg Error " Could not execute command $cmd"
                    exit 1
                  }
                  # Check the system is generated correctly and move file to correct directory
                  if { [file exists $qsysName] != 0} {
                    file rename -force $qsysName $qsysFile
                    # Write checksum to file
                    set qsysMd5Sum [Md5Sum $qsysFile]
                    # open file for writing
                    set fileDir [file normalize "./hogTmp"]
                    set fileName "$fileDir/.hogQsys.md5"
                    if {![file exists $fileDir]} {
                      file mkdir $fileDir
                    }
                    set hogQsysFile [open $fileName "a"]
                    set fileEntry "$qsysFile\t$qsysMd5Sum"
                    puts $hogQsysFile $fileEntry
                    close $hogQsysFile
                  } else {
                    Msg ERROR "Error while moving the generated qsys file to final location: $qsysName not found!";
                  }
                  if { [file exists $qsysFile] != 0} {
                    if {[string first "noadd" $props] == -1} {
                      set qsysFileType [FindFileType $qsysFile]
                      set_global_assignment  -name $qsysFileType $qsysFile
                    } else {
                      regsub -all {noadd} $props $emptyString props
                    }
                    if {[string first "nogenerate" $props] == -1} {
                      GenerateQsysSystem $qsysFile $props
                    }

                  } else {
                    Msg ERROR "Error while generating ip variations from qsys: $qsysFile not found!";
                  }
                }
              }
            } elseif { [string first "QSYS" $file_type] != -1 } {
              set emptyString ""
              regsub -all {\{||\}} $props $emptyString props
              if {[string first "noadd" $props] == -1} {
                set_global_assignment  -name $file_type $cur_file
              } else {
                regsub -all {noadd} $props $emptyString props
              }

              #Generate IPs
              if {[string first "nogenerate" $props] == -1} {
                GenerateQsysSystem $cur_file $props
              }
            } else {
              set_global_assignment -name $file_type $cur_file -library $rootlib
            }
          }
        }
      } elseif {[IsLibero] } {
        if {$ext == ".con"} {
          set vld_exts {.sdc .pin .dcf .gcf .pdc .ndc .fdc .crt .vcd }
          foreach con_file $lib_files {
            # Check for valid constrain files
            set con_ext [file extension $con_file]
            if {[IsInList [file extension $con_file]  $vld_exts ]} {
              set option [string map {. -} $con_ext]
              set option [string map {fdc net_fdc} $option]
              set option [string map {pdc io_pdc} $option]
              create_links -convert_EDN_to_HDL 0 -library {work} $option $con_file

              set props [DictGet $properties $con_file]

              if {$con_ext == ".sdc"} {
                if { [lsearch $props "notiming"] >= 0 } {
                  Msg Info "Excluding $con_file from timing verification..."
                } else {
                  Msg Info "Adding $con_file to time verification"
                  append timing_conf_command " -file $con_file"
                  set timing_conf 1
                }

                if { [lsearch $props "nosynth"] >= 0 } {
                  Msg Info "Excluding $con_file from synthesis..."
                } else {
                  Msg Info "Adding $con_file to synthesis"
                  append synth_conf_command " -file $con_file"
                  set synth_conf 1
                }
              }

              if {$con_ext == ".pdc" || $con_ext == ".sdc"} {
                if { [lsearch $props "noplace"] >= 0 } {
                  Msg Info "Excluding $con_file from place and route..."
                } else {
                  Msg Info "Adding $con_file to place and route"
                  append place_conf_command " -file $con_file"
                  set place_conf 1
                }
              }

            } else {
              Msg CriticalWarning "Constraint file $con_file does not have a valid extension. Allowed extensions are: \n $vld_exts"
            }
          }
        } elseif {$ext == ".src"} {
          foreach f $lib_files {
            Msg Debug "Adding source $f to library $rootlib..."
            create_links -library $rootlib -hdl_source $f
          }
        } elseif {$ext == ".sim"} {
          Msg Debug "Adding stimulus file $f to library..."
          create_links -library $rootlib -stimulus $f
        }
        build_design_hierarchy
        foreach cur_file $lib_files {
          set file_type [FindFileType $cur_file]

          #ADDING FILE PROPERTIES
          set props [DictGet $properties $cur_file]

          # Top synthesis module
          set top [lindex [regexp -inline {top\s*=\s*(.+?)\y.*} $props] 1]
          if { $top != "" } {
            Msg Info "Setting $top as top module for file set $rootlib..."
            set globalSettings::synth_top_module "${top}::$rootlib"
          }
        }
      # Closing IDE if cascade
      } elseif {[IsDiamond]} {
        if {$ext == ".src" || $ext == ".con" || $ext == ".ext"} {
          foreach f $lib_files {
            Msg Debug "Diamond: adding source file $f to library $rootlib..."
            prj_src add -work $rootlib $f
            set props [DictGet $properties $f]
            # Top synthesis module
            set top [lindex [regexp -inline {top\s*=\s*(.+?)\y.*} $props] 1]
            if { $top != "" } {
              Msg Info "Setting $top as top module for the project..."
              set globalSettings::synth_top_module $top
            }
          }
        } elseif {$ext == ".sim"} {
          foreach f $lib_files {
            Msg Debug "Diamond Adding simulation file $f to library $rootlib..."
            prj_src add -work $rootlib -simulate_only $f
          }
        }


      }
    # Closing library loop
    }
  # Closing fileset loop
  }

  if {[IsVivado]} {
    if {[DictGet $filesets "sim_1"] == ""} {
      delete_fileset -quiet [get_filesets -quiet "sim_1" ]
    }
  }

  # Add constraints to workflow in Libero
  if {[IsLibero]} {
    if {$synth_conf == 1} {
      Msg Info $synth_conf_command
      eval $synth_conf_command
    }
    if {$timing_conf == 1} {
      Msg Info $timing_conf_command
      eval $timing_conf_command
    }
    if {$place_conf == 1} {
      Msg Info $place_conf_command
      eval $place_conf_command
    }
  }
}

## @brief Returns a dictionary for the allowed properties for each file type
proc ALLOWED_PROPS {} {
  return [dict create ".vhd" [list "93" "nosynth" "noimpl" "nosim" "1987" "1993" "2008" "2019"]\
    ".vhdl" [list "93" "nosynth" "noimpl" "nosim" "1987" "1993" "2008" "2019"]\
    ".v" [list "SystemVerilog" "verilog_header" "nosynth" "noimpl" "nosim" "1995" "2001"]\
    ".sv" [list "verilog" "verilog_header" "nosynth" "noimpl" "nosim" "2005" "2009"]\
    ".do" [list "nosim"]\
    ".udo" [list "nosim"]\
    ".xci" [list "nosynth" "noimpl" "nosim" "locked"]\
    ".xdc" [list "nosynth" "noimpl" ]\
    ".tcl" [list "nosynth" "noimpl" "nosim" "source" "qsys" "noadd" "--block-symbol-file" "--clear-output-directory" "--example-design" "--export-qsys-script" "--family" "--greybox" "--ipxact" "--jvm-max-heap-size" "--parallel" "--part" "--search-path" "--simulation" "--synthesis" "--testbench" "--testbench-simulation" "--upgrade-ip-cores" "--upgrade-variation-file"]\
    ".qsys" [list "nogenerate" "noadd" "--block-symbol-file" "--clear-output-directory" "--example-design" "--export-qsys-script" "--family" "--greybox" "--ipxact" "--jvm-max-heap-size" "--parallel" "--part" "--search-path" "--simulation" "--synthesis" "--testbench" "--testbench-simulation" "--upgrade-ip-cores" "--upgrade-variation-file"]\
    ".sdc" [list "notiming" "nosynth" "noplace"]\
    ".pdc" [list "nosynth" "noplace"]]\
}

## @brief # Returns the step name for the stage that produces the binary file
#
# Projects using Versal chips have a different step for producing the
# binary file, we use this function to take that into account
#
# @param[out] 1 if it's Versal 0 if it's not
# @param[in]  part  The FPGA part
#
proc BinaryStepName {part} {
  if {[IsVersal $part]} {
    return "WRITE_DEVICE_IMAGE"
  } else {
    return "WRITE_BITSTREAM"
  }
}

# @brief Check the syntax of the source files in the
#
# @param[in] project_name the name of the project
# @param[in] repo_path    The main path of the git repository
# @param[in] project_file The project file (for Libero)
proc CheckSyntax { project_name repo_path {project_file ""}} {
  if {[IsVivado]} {
    set syntax [check_syntax -return_string]
    if {[string first "CRITICAL" $syntax ] != -1} {
      check_syntax
      exit 1
    }
  } elseif {[IsQuartus]} {
    lassign [GetHogFiles -list_files "*.src" "$repo_path/Top/$project_name/list/" $repo_path] src_files dummy
    dict for {lib files} $src_files {
      foreach f $files {
        set file_extension [file extension $f]
        if { $file_extension == ".vhd" || $file_extension == ".vhdl" || $file_extension == ".v" ||  $file_extension == ".sv" } {
          if { [catch {execute_module -tool map -args "--analyze_file=$f"} result]} {
            Msg Error "\nResult: $result\n"
            Msg Error "Check syntax failed.\n"
          } else {
            if { $result == "" } {
              Msg Info "Check syntax was successful for $f.\n"
            } else {
              Msg Warning "Found syntax error in file $f:\n $result\n"
            }
          }
        }
      }
    }
  } elseif {[IsLibero]} {
    lassign [GetProjectFiles $project_file] prjLibraries prjProperties prjSimLibraries prjConstraints prjSrcSets prjSimSets prjConSets
    dict for {lib sources} $prjLibraries {
      if {[file extension $lib] == ".src"} {
        foreach f $sources {
          Msg Info "Checking Syntax of $f"
          check_hdl -file $f
        }
      }
    }
  } else {
    Msg Info "The Checking Syntax is not supported by this IDE. Skipping..."
  }
}

# @brief Close the open project (does nothing for Xilinx and Libero)
proc CloseProject {} {
  if {[IsXilinx]} {

  } elseif {[IsQuartus]} {
    project_close
  } elseif {[IsLibero]} {

  } elseif {[IsDiamond]} {
    prj_project save
    prj_project close
  }
}

## @brief Compare two semantic versions
#
# @param[in] ver1 a list of 3 numbers M m p
# @param[in] ver2 a list of 3 numbers M m p
#
# In case the ver1 or ver2 are in the format vX.Y.Z rather than a list, they will be converted.
# If one of the tags is an empty string it will be considered as 0.0.0
#
# @return Returns 1 ver1 is greater than ver2, 0 if they are equal, and -1 if ver2 is greater than ver1
proc CompareVersions {ver1 ver2} {
  if {$ver1 eq ""} {
    set ver1 v0.0.0
  }

  if {$ver2 eq ""} {
    set ver2 v0.0.0
  }

  if {[regexp {v(\d+)\.(\d+)\.(\d+)} $ver1 - x y z]} {
    set ver1 [list $x $y $z]
  }
  if {[regexp {v(\d+)\.(\d+)\.(\d+)} $ver2 - x y z]} {
    set ver2 [list $x $y $z]
  }

  # Add 1 in front to avoid crazy Tcl behaviour with leading 0 being octal...
  set v1 [join $ver1 ""]
  set v1 "1$v1"
  set v2 [join $ver2 ""]
  set v2 "1$v2"

  if {[string is integer $v1] && [string is integer $v2]} {

    set ver1 [expr {[scan [lindex $ver1 0] %d]*1000000 + [scan [lindex $ver1 1] %d]*1000 + [scan [lindex $ver1 2] %d]}]
    set ver2 [expr {[scan [lindex $ver2 0] %d]*1000000 + [scan [lindex $ver2 1] %d]*1000 + [scan [lindex $ver2 2] %d]}]

    if {$ver1 > $ver2 } {
      set ret 1
    } elseif {$ver1 == $ver2} {
      set ret 0
    } else {
      set ret -1
    }

  } else {
    Msg Warning "Version is not numeric: $ver1, $ver2"
    set ret 0
  }
  return [expr {$ret}]
}

# @brief Function searching for extra IP/BD files added at creation time using user scripts, and writing the list in
# Project/proj/.hog/extra.files, with the correspondent md5sum
#
# @param[in] libraries The Hog libraries
proc CheckExtraFiles {libraries} {
  ### CHECK NOW FOR IP OUTSIDE OF LIST FILE (Vivado only!)
  if {[IsVivado]} {
    lassign [GetProjectFiles] prjLibraries prjProperties prjSimLibraries prjConstraints
    set prjLibraries [MergeDict $prjLibraries $prjSimLibraries]
    set prjLibraries [MergeDict $prjLibraries $prjConstraints]
    set prj_dir [get_property DIRECTORY [current_project]]
    file mkdir "$prj_dir/.hog"
    set extra_file_name "$prj_dir/.hog/extra.files"
    set new_extra_file [open $extra_file_name "w"]

    dict for {prjLib prjFiles} $prjLibraries {
      foreach prjFile $prjFiles {
        if {[file extension $prjFile] == ".xcix"} {
          Msg Warning "IP $prjFile is packed in a .xcix core container. This files are not suitable for version control systems. We recommend to use .xci files instead."
          continue
        }
        if {[file extension $prjFile] == ".xci" && [get_property CORE_CONTAINER [get_files $prjFile]] != ""} {
          Msg Info "$prjFile is a virtual IP file in a core container. Ignoring it..."
          continue
        }

        if {[IsInList $prjFile [DictGet $libraries $prjLib]]==0} {
          if { [file extension $prjFile] == ".bd"} {
            # Generating BD products to save md5sum of already modified BD
            Msg Info "Generating targets of $prjFile..."
            generate_target all [get_files $prjFile]
          }
          puts $new_extra_file "$prjFile [Md5Sum $prjFile]"
          Msg Info "$prjFile (lib: $prjLib) has been generated by an external script. Adding to $extra_file_name..."
        }
      }
    }
    close $new_extra_file
  }
}

# @brief Check if the running Hog version is the latest stable release
#
# @param[in] repo_path The main path of the git repository
proc CheckLatestHogRelease {{repo_path .}} {
  set old_path [pwd]
  cd $repo_path/Hog
  set current_ver [Git {describe --always}]
  Msg Debug "Current version: $current_ver"
  set current_sha [Git "log $current_ver -1 --format=format:%H"]
  Msg Debug "Current SHA: $current_sha"

  #We should find a proper way of checking for timeout using wait, this'll do for now
  if {[OS] == "windows" } {
    Msg Info "On windows we cannot set a timeout on 'git fetch', hopefully nothing will go wrong..."
    Git fetch
  } else {
    Msg Info "Checking for latest Hog release, can take up to 5 seconds..."
    ExecuteRet timeout 5s git fetch
  }
  set master_ver [Git "describe origin/master"]
  Msg Debug "Master version: $master_ver"
  set master_sha [Git "log $master_ver -1 --format=format:%H"]
  Msg Debug "Master SHA: $master_sha"
  set merge_base [Git "merge-base $current_sha $master_sha"]
  Msg Debug "merge base: $merge_base"


  if {$merge_base != $master_sha} {
    # If master_sha is NOT an ancestor of current_sha
    Msg Info "Version $master_ver has been released (https://gitlab.com/hog-cern/Hog/-/releases/$master_ver)"
    Msg Status "You should consider updating Hog submodule with the following instructions:"
    Msg Status ""
    Msg Status "cd Hog && git checkout master && git pull"
    Msg Status ""
    Msg Status "Also update the ref: in your .gitlab-ci.yml to $master_ver"
    Msg Status ""
  } else {

    # If it is
    Msg Info "Latest official version is $master_ver, nothing to do."
  }

  cd $old_path

}


## @brief Checks that "ref" in .gitlab-ci.yml actually matches the hog.yml file in the
#
#  @param[in] repo_path path to the repository root
#  @param[in] allow_failure if true throws CriticalWarnings instead of Errors
#
proc CheckYmlRef {repo_path allow_failure} {

  if {$allow_failure} {
    set MSG_TYPE CriticalWarning
  } else {
    set MSG_TYPE Error
  }

  if { [catch {package require yaml 0.3.3} YAMLPACKAGE]} {
    Msg CriticalWarning "Cannot find package YAML, skipping consistency check of \"ref\" in gilab-ci.yaml file.\n Error message: $YAMLPACKAGE
    You can fix this by installing package \"tcllib\""
    return
  }

  set thisPath [pwd]

  # Go to repository path
  cd "$repo_path"
  if {[file exists .gitlab-ci.yml]} {
    #get .gitlab-ci ref
    set YML_REF ""
    set YML_NAME ""
    if { [file exists .gitlab-ci.yml] } {
      set fp [open ".gitlab-ci.yml" r]
      set file_data [read $fp]
      close $fp
    } else {
      Msg $MSG_TYPE "Cannot open file .gitlab-ci.yml"
      cd $thisPath
      return
    }
    set file_data "\n$file_data\n\n"

    if { [catch {::yaml::yaml2dict -stream $file_data}  yamlDict]} {
      Msg $MSG_TYPE "Parsing $repo_path/.gitlab-ci.yml failed. To fix this, check that yaml syntax is respected, remember not to use tabs."
      cd $thisPath
      return
    } else {
      dict for {dictKey dictValue} $yamlDict {
        #looking for Hog include in .gitlab-ci.yml
        if {"$dictKey" == "include" && ([lsearch [split $dictValue " {}"] "/hog.yml" ] != "-1" || [lsearch [split $dictValue " {}"] "/hog-dynamic.yml" ] != "-1")} {
          set YML_REF [lindex [split $dictValue " {}"]  [expr {[lsearch -dictionary [split $dictValue " {}"] "ref"]+1} ] ]
          set YML_NAME [lindex [split $dictValue " {}"]  [expr {[lsearch -dictionary [split $dictValue " {}"] "file"]+1} ] ]
        }
      }
    }
    if {$YML_REF == ""} {
      Msg Warning "Hog version not specified in the .gitlab-ci.yml. Assuming that master branch is used."
      cd Hog
      set YML_REF_F [Git {name-rev --tags --name-only origin/master}]
      cd ..
    } else {
      set YML_REF_F [regsub -all "'" $YML_REF ""]
    }

    if {$YML_NAME == ""} {
      Msg $MSG_TYPE "Hog included yml file not specified, assuming hog.yml"
      set YML_NAME_F hog.yml
    } else {
      set YML_NAME_F [regsub -all "^/" $YML_NAME ""]
    }

    lappend YML_FILES $YML_NAME_F

    #getting Hog repository tag and commit
    cd "Hog"

    #check if the yml file includes other files
    if { [catch {::yaml::yaml2dict -file $YML_NAME_F}  yamlDict]} {
      Msg $MSG_TYPE "Parsing $YML_NAME_F failed."
      cd $thisPath
      return
    } else {
      dict for {dictKey dictValue} $yamlDict {
        #looking for included files
        if {"$dictKey" == "include"} {
          foreach v $dictValue {
            lappend YML_FILES [lindex [split $v " "]  [expr {[lsearch -dictionary [split $v " "] "local"]+1} ] ]
          }
        }
      }
    }

    Msg Info "Found the following yml files: $YML_FILES"

    set HOGYML_SHA [GetSHA $YML_FILES]
    lassign [GitRet "log --format=%h -1 --abbrev=7 $YML_REF_F" $YML_FILES] ret EXPECTEDYML_SHA
    if {$ret != 0} {
      lassign [GitRet "log --format=%h -1 --abbrev=7 origin/$YML_REF_F" $YML_FILES] ret EXPECTEDYML_SHA
      if {$ret != 0} {
        Msg $MSG_TYPE "Error in project .gitlab-ci.yml. ref: $YML_REF not found"
        set EXPECTEDYML_SHA ""
      }
    }
    if  {!($EXPECTEDYML_SHA eq "")} {
      if {$HOGYML_SHA == $EXPECTEDYML_SHA} {
        Msg Info "Hog included file $YML_FILES matches with $YML_REF in .gitlab-ci.yml."

      } else {
        Msg $MSG_TYPE "HOG $YML_FILES SHA mismatch.
        From Hog submodule: $HOGYML_SHA
        From ref in .gitlab-ci.yml: $EXPECTEDYML_SHA
        You can fix this in 2 ways: by changing the ref in your repository or by changing the Hog submodule commit"
      }
    } else {
      Msg $MSG_TYPE "One or more of the following files could not be found $YML_FILES in Hog at $YML_REF"
    }
  } else {
    Msg Info ".gitlab-ci.yml not found in $repo_path. Skipping this step"
  }

  cd "$thisPath"
}


## @brief Compare the contents of two dictionaries
#
# @param[in] proj_libs  The dictionary of libraries in the project
# @param[in] list_libs  The dictionary of libraries in list files
# @param[in] proj_sets  The dictionary of filesets in the project
# @param[in] list_sets  The dictionary of filesets in list files
# @param[in] proj_props The dictionary of file properties in the project
# @param[in] list_props The dictionary of file pproperties in list files
# @param[in] severity   The severity of  the message in case a file is not found (Default: CriticalWarning)
# @param[in] outFile    The output log file, to write the messages (Default "")
# @param[in] extraFiles The dictionary of extra files generated a creation time (Default "")
#
# @return n_diffs The number of differences
# @return extra_files Remaining list of extra files

proc CompareLibDicts {proj_libs list_libs proj_sets list_sets proj_props list_props {severity "CriticalWarning"} {outFile ""} {extraFiles ""} } {
  set extra_files $extraFiles
  set n_diffs 0
  set out_prjlibs $proj_libs
  set out_prjprops $proj_props
  # Loop over filesets in project
  dict for {prjSet prjLibraries} $proj_sets {
    # Check if sets is also in list files
    if {[IsInList $prjSet $list_sets]} {
      set listLibraries [DictGet $list_sets $prjSet]
      # Loop over libraries in fileset
      foreach prjLib $prjLibraries {
        set prjFiles [DictGet $proj_libs $prjLib]
        # Check if library exists in list files
        if {[IsInList $prjLib $listLibraries]} {
          # Loop over files in library
          set listFiles [DictGet $list_libs $prjLib]
          foreach prjFile $prjFiles {
            set idx [lsearch -exact $listFiles $prjFile]
            set listFiles [lreplace $listFiles $idx $idx]
            if {$idx < 0} {
              # File is in project but not in list libraries, check if it was generated at creation time...
              if { [dict exists $extra_files $prjFile] } {
                # File was generated at creation time, checking the md5sum
                # Removing the file from the prjFiles list
                set idx2 [lsearch -exact $prjFiles $prjFile]
                set prjFiles [lreplace $prjFiles $idx2 $idx2]
                set new_md5sum [Md5Sum $prjFile]
                set old_md5sum [DictGet $extra_files $prjFile]
                if {$new_md5sum != $old_md5sum} {
                  MsgAndLog "$prjFile in project has been modified from creation time. Please update the script you used to create the file and regenerate the project, or save the file outside the Projects/ directory and add it to a project list file" $severity $outFile
                  incr n_diffs
                }
                set extra_files [dict remove $extra_files $prjFile]
              } else {
                # File is neither in list files nor in extra_files
                MsgAndLog "$prjFile was found in project but not in list files or .hog/extra.files" $severity $outFile
                incr n_diffs
              }
            } else {
              # File is both in list files and project, checking properties...
              set prjProps  [DictGet $proj_props $prjFile]
              set listProps [DictGet $list_props $prjFile]
              # Check if it is a potential sourced file
              if {[IsInList "nosynth" $prjProps] && [IsInList "noimpl" $prjProps] && [IsInList "nosim" $prjProps]} {
                # Check if it is sourced
                set idx_source [lsearch -exact $listProps "source"]
                if {$idx_source >= 0 } {
                  # It is sourced, let's replace the individual properties with source
                  set idx [lsearch -exact $prjProps "noimpl"]
                  set prjProps [lreplace $prjProps $idx $idx]
                  set idx [lsearch -exact $prjProps "nosynth"]
                  set prjProps [lreplace $prjProps $idx $idx]
                  set idx [lsearch -exact $prjProps "nosim"]
                  set prjProps [lreplace $prjProps $idx $idx]
                  lappend prjProps "source"
                }
              }

              foreach prjProp $prjProps {
                set idx [lsearch -exact $listProps $prjProp]
                set listProps [lreplace $listProps $idx $idx]
                if {$idx < 0} {
                  MsgAndLog "Property $prjProp of $prjFile was set in project but not in list files" $severity $outFile
                  incr n_diffs
                }
              }

              foreach listProp $listProps {
                if {[string first $listProp "topsim="] == -1} {
                  MsgAndLog "Property $listProp of $prjFile was found in list files but not set in project." $severity $outFile
                  incr n_diffs
                }
              }

              # Update project prjProps
              dict set out_prjprops $prjFile $prjProps
            }
          }
          # Loop over remaining files in list libraries
          foreach listFile $listFiles {
            MsgAndLog "$listFile was found in list files but not in project." $severity $outFile
            incr n_diffs
          }
        } else {
          # Check extra files again...
          foreach prjFile $prjFiles {
            if { [dict exists $extra_files $prjFile] } {
              # File was generated at creation time, checking the md5sum
              # Removing the file from the prjFiles list
              set idx2 [lsearch -exact $prjFiles $prjFile]
              set prjFiles [lreplace $prjFiles $idx2 $idx2]
              set new_md5sum [Md5Sum $prjFile]
              set old_md5sum [DictGet $extra_files $prjFile]
              if {$new_md5sum != $old_md5sum} {
                MsgAndLog "$prjFile in project has been modified from creation time. Please update the script you used to create the file and regenerate the project, or save the file outside the Projects/ directory and add it to a project list file" $severity $outFile
                incr n_diffs
              }
              set extra_files [dict remove $extra_files $prjFile]
            } else {
              # File is neither in list files nor in extra_files
              MsgAndLog "$prjFile was found in project but not in list files or .hog/extra.files" $severity $outFile
              incr n_diffs
            }
          }
        }
        # Update prjLibraries
        dict set out_prjlibs $prjLib $prjFiles
      }
    } else {
      MsgAndLog "Fileset $prjSet found in project but not in list files" $severity $outFile
      incr n_diffs
    }
  }

  return [list $n_diffs $extra_files $out_prjlibs $out_prjprops]
}

## @brief Compare two VHDL files ignoring spaces and comments
#
# @param[in] file1  the first file
# @param[in] file2  the second file
#
# @ return A string with the diff of the files
#
proc CompareVHDL {file1 file2} {
  set a  [open $file1 r]
  set b  [open $file2 r]

  while {[gets $a line] != -1} {
    set line [regsub {^[\t\s]*(.*)?\s*} $line "\\1"]
    if {![regexp {^$} $line] & ![regexp {^--} $line] } {
      #Exclude empty lines and comments
      lappend f1 $line
    }
  }

  while {[gets $b line] != -1} {
    set line [regsub {^[\t\s]*(.*)?\s*} $line "\\1"]
    if {![regexp {^$} $line] & ![regexp {^--} $line] } {
      #Exclude empty lines and comments
      lappend f2 $line
    }
  }

  close $a
  close $b
  set diff {}
  foreach x $f1 y $f2 {
    if {$x != $y} {
      lappend diff "> $x\n< $y\n\n"
    }
  }

  return $diff
}

##
## Copy a file or folder into a new path, not throwing an error if the final path is not empty
##
## @param      i_dirs  The directory or file to copy
## @param      o_dir  The final destination
##
proc Copy {i_dirs o_dir} {
  foreach i_dir $i_dirs {
    if {[file isdirectory $i_dir] && [file isdirectory $o_dir]} {
      if {([file tail $i_dir] == [file tail $o_dir]) || ([file exists $o_dir/[file tail $i_dir]] && [file isdirectory $o_dir/[file tail $i_dir]])} {
        file delete -force $o_dir/[file tail $i_dir]
      }
    }

    file copy -force $i_dir $o_dir
  }
}

## @brief Read a XML list file and copy files to destination
#
# Additional information is provided with text separated from the file name with one or more spaces
#
# @param[in] proj_dir     project path, path containing the ./list directory containing at least a list file with .ipb extention
# @param[in] path         the path the XML files are referred to in the list file
# @param[in] dst          the path the XML files must be copied to
# @param[in] xml_version  the M.m.p version to be used to replace the __VERSION__ placeholder in any of the xml files
# @param[in] xml_sha      the Git-SHA to be used to replace the __GIT_SHA__ placeholder in any of the xml files
# @param[in] use_ipbus_sw if set to 1, use the IPbus sw to generate or check the vhdl files
# @param[in] generate     if set to 1, tells the function to generate the VHDL decode address files rather than check them
proc CopyIPbusXMLs {proj_dir path dst {xml_version "0.0.0"} {xml_sha "00000000"} {use_ipbus_sw 0} {generate 0} } {
  if {$use_ipbus_sw == 1} {
    lassign  [ExecuteRet python -c "from __future__ import print_function; from sys import path;print(':'.join(path\[1:\]))"] ret msg
    if {$ret == 0} {
      set ::env(PYTHONPATH) $msg
      lassign [ExecuteRet gen_ipbus_addr_decode -h] ret msg
      if {$ret != 0}  {
        set can_generate 0
      } else {
        set can_generate 1
      }
    } else {
      Msg CriticalWarning "Problem while trying to run python: $msg"
      set can_generate 0
    }
    set dst [file normalize $dst]
    if {$can_generate == 0} {
      if {$generate == 1} {
        Msg Error "Cannot generate IPbus address files, IPbus executable gen_ipbus_addr_decode not found or not working: $msg"
        return -1

      } else {
        Msg Warning "IPbus executable gen_ipbus_addr_decode not found or not working, will not verify IPbus address tables."
      }
    }
  } else {
    set can_generate 0
  }

  set ipb_files [glob -nocomplain $proj_dir/list/*.ipb]
  set n_ipb_files [llength $ipb_files]
  if {$n_ipb_files == 0} {
    Msg CriticalWarning "No files with .ipb extension found in $proj_dir/list."
    return
  }
  set libraries [dict create]
  set vhdl_dict [dict create]

  foreach ipb_file $ipb_files {
    lassign [ReadListFile {*}"$ipb_file $path"] l p fs
    set libraries [MergeDict $l $libraries]
    set vhdl_dict [MergeDict $p $vhdl_dict]
  }

  set xmlfiles [dict get $libraries "xml.ipb"]


  set xml_list_error 0
  foreach xmlfile $xmlfiles {

    if {[file isdirectory $xmlfile]} {
      Msg CriticalWarning "Directory $xmlfile listed in xml list file $list_file. Directories are not supported!"
      set xml_list_error 1
    }

    if {[file exists $xmlfile]} {
      if {[dict exists $vhdl_dict $xmlfile]} {
        set vhdl_file [file normalize [dict get $vhdl_dict $xmlfile]]
      } else {
        set vhdl_file ""
      }
      lappend vhdls $vhdl_file

      set xmlfile [file normalize $xmlfile]
      Msg Info "Copying $xmlfile to $dst and replacing place holders..."
      set in  [open $xmlfile r]
      set out [open $dst/[file tail $xmlfile] w]

      while {[gets $in line] != -1} {
        set new_line [regsub {(.*)__VERSION__(.*)} $line "\\1$xml_version\\2"]
        set new_line2 [regsub {(.*)__GIT_SHA__(.*)} $new_line "\\1$xml_sha\\2"]
        puts $out $new_line2
      }
      close $in
      close $out
      lappend xmls  [file tail $xmlfile]
    } else {
      Msg Warning "XML file $xmlfile not found"
    }
  }
  if {${xml_list_error}} {
    Msg Error "Invalid files added to $list_file!"
  }

  set cnt [llength $xmls]
  Msg Info "$cnt xml file/s copied"


  if {$can_generate == 1} {
    set old_dir [pwd]
    cd $dst
    file mkdir "address_decode"
    cd "address_decode"

    foreach x $xmls  v $vhdls {
      if {$v ne ""} {
        set x [file normalize ../$x]
        if {[file exists $x]} {
          lassign [ExecuteRet gen_ipbus_addr_decode $x 2>&1]  status log
          if {$status == 0} {
            set generated_vhdl ./ipbus_decode_[file rootname [file tail $x]].vhd
            if {$generate == 1} {
              Msg Info "Copying generated VHDL file $generated_vhdl into $v (replacing if necessary)"
              file copy -force -- $generated_vhdl $v
            } else {
              if {[file exists $v]} {
                set diff [CompareVHDL $generated_vhdl $v]
                set n [llength $diff]
                if {$n > 0} {
                  Msg CriticalWarning "$v does not correspond to its XML $x, [expr {$n/3}] line/s differ:"
                  Msg Status [join $diff "\n"]
                  set diff_file [open ../diff_[file rootname [file tail $x]].txt w]
                  puts $diff_file $diff
                  close $diff_file
                } else {
                  Msg Info "[file tail $x] and $v match."
                }
              } else {
                Msg Warning "VHDL address map file $v not found."
              }
            }
          } else {
            Msg Warning "Address map generation failed for [file tail $x]: $log"
          }
        } else {
          Msg Warning "Copied XML file $x not found."
        }
      } else {
        Msg Info "Skipped verification of [file tail $x] as no VHDL file was specified."
      }
    }
    cd ..
    file delete -force address_decode
    cd $old_dir
  }
}

## @brief Returns the description from the hog.conf file.
# The description is the comment in the second line stripped of the hashes
# If the description contains the word test, Test or TEST, then "test" is simply returned.
# This is used to avoid printing them in ListProjects unless -all is specified
#
# @param[in] conf_file  the path to the hog.conf file
#
proc DescriptionFromConf {conf_file} {
  set f [open $conf_file "r"]
  set lines [split [read $f] "\n"]
  close $f
  set second_line [lindex $lines 1]


  if {![regexp {\#+ *(.+)} $second_line - description]} {
    set description ""
  }

  if {[regexp -all {test|Test|TEST} $description]} {
    set description "test"
  }

  return $description
}

## @brief Returns the value in a Tcl dictionary corresponding to the chosen key
#
# @param[in] dictName the name of the dictionary
# @param[in] keyName  the name of the key
# @param[in] default  the default value to be returned if the key is not found (default "")
#
# @return             The value in the dictionary corresponding to the provided key
proc DictGet {dictName keyName {default ""}} {
  if {[dict exists $dictName $keyName]} {
    return [dict get $dictName $keyName]
  } else {
    return $default
  }
}

## @brief Checks the Doxygen version installed in this machine
#
# @param[in] target_version the version required by the current project
#
# @return Returns 1, if the system Doxygen version is greater or equal to the target
proc DoxygenVersion {target_version} {
  set ver [split $target_version "."]
  set v [Execute doxygen --version]
  Msg Info "Found Doxygen version: $v"
  set current_ver [split $v ". "]
  set target [expr {[lindex $ver 0]*100000 + [lindex $ver 1]*100 + [lindex $ver 2]}]
  set current [expr {[lindex $current_ver 0]*100000 + [lindex $current_ver 1]*100 + [lindex $current_ver 2]}]

  return [expr {$target <= $current}]
}

## @brief Handle eos commands
#
# It can be used with lassign like this: lassign [eos \<eos command\> ] ret result
#
#  @param[in] command: the EOS command to be run, e.g. ls, cp, mv, rm
#  @param[in] attempt: (default 0) how many times the command should be attempted in case of failure
#
#  @returns a list of 2 elements: the return value (0 if no error occurred) and the output of the EOS command
proc eos {command {attempt 1}}  {
  global env
  if {![info exists env(EOS_MGM_URL)]} {
    Msg Warning "Environment variable EOS_MGM_URL not set, setting it to default value root://eosuser.cern.ch"
    set ::env(EOS_MGM_URL) "root://eosuser.cern.ch"
  }
  if {$attempt < 1} {
    Msg Warning "The value of attempt should be 1 or more, not $attempt, setting it to 1 as default"
    set attempt 1
  }
  for {set i 0} {$i < $attempt} {incr i } {
    set ret [catch {exec -ignorestderr eos {*}$command} result]
    if {$ret == 0} {
      break
    } else {
      if {$attempt > 1} {
        set wait [expr {1+int(rand()*29)}]
        Msg Warning "Command $command failed ($i/$attempt): $result, trying again in $wait seconds..."
        after [expr {$wait*1000}]
      }
    }
  }
  return [list $ret $result]
}

## @brief Handle shell commands
#
# It can be used with lassign like this: lassign [Execute \<command\> ] ret result
#
#  @param[in] args: the shell command
#
#  @returns the output of the command
proc Execute {args}  {
  global env
  lassign [ExecuteRet {*}$args] ret result
  if {$ret != 0} {
    Msg Error "Command [join $args] returned error code: $ret"
  }

  return $result
}


## @brief Handle shell commands
#
# It can be used with lassign like this: lassign [ExecuteRet \<command\> ] ret result
#
#  @param[in] args: the shell command
#
#  @returns a list of 2 elements: the return value (0 if no error occurred) and the output of the command
proc ExecuteRet {args}  {
  global env
  if {[llength $args] == 0} {
    Msg CriticalWarning "No argument given"
    set ret -1
    set result ""
  } else {
    set ret [catch {exec -ignorestderr {*}$args} result]
  }

  return [list $ret $result]
}

## @brief Tags the repository with a new version calculated on the basis of the previous tags
#
# @param[in] tag  a tag in the Hog format: v$M.$m.$p or b$(mr)v$M.$m.$p-$n
#
# @return         a list containing: Major minor patch v.
#
proc ExtractVersionFromTag {tag} {
  if {[regexp {^(?:b(\d+))?v(\d+)\.(\d+).(\d+)(?:-\d+)?$} $tag -> mr M m p]} {
    if {$mr eq ""} {
      set mr 0
    }
  } else {
    Msg Warning "Repository tag $tag is not in a Hog-compatible format."
    set mr -1
    set M -1
    set m -1
    set p -1
  }
  return [list $M $m $p $mr]
}


## @brief Checks if file was committed into the repository
#
#
#  @param[in] File: file name
#
#  @returns 1 if file was committed and 0 if file was not committed
proc FileCommitted {File }  {
  set Ret 1
  set currentDir [pwd]
  cd [file dirname [file normalize $File]]
  set GitLog [Git ls-files [file tail $File]]
  if {$GitLog == ""} {
    Msg CriticalWarning "File [file normalize $File] is not in the git repository. Please add it with:\n git add [file normalize $File]\n"
    set Ret 0
  }
  cd $currentDir
  return $Ret
}

# @brief Returns the common child of two git commits
#
# @param[in] SHA1 The first commit
# @param[in] SHA2 The second commit
proc FindCommonGitChild {SHA1 SHA2} {
  # Get the list of all commits in the repository
  set commits [Git {log --oneline --merges}]
  set ancestor 0
  # Iterate over each commit
  foreach line [split $commits "\n"] {
    set commit [lindex [split $line] 0]

    # Check if both SHA1 and SHA2 are ancestors of the commit
    if {[IsCommitAncestor $SHA1 $commit] && [IsCommitAncestor $SHA2 $commit] } {
      set ancestor $commit
      break
    }
  }
  return $ancestor
}


# @brief Returns a list of files in a directory matching a pattern
#
# @param[in] basedir The directory to start looking in
# @param[in  pattern A pattern, as defined by the glob command, that the files must match
# Credit: https://stackexchange.com/users/14219/jackson
proc findFiles { basedir pattern } {

    # Fix the directory name, this ensures the directory name is in the
    # native format for the platform and contains a final directory seperator
  set basedir [string trimright [file join [file normalize $basedir] { }]]
  set fileList {}

    # Look in the current directory for matching files, -type {f r}
    # means ony readable normal files are looked at, -nocomplain stops
    # an error being thrown if the returned list is empty
  foreach fileName [glob -nocomplain -type {f r} -path $basedir $pattern] {
    lappend fileList $fileName
  }

    # Now look for any sub direcories in the current directory
  foreach dirName [glob -nocomplain -type {d  r} -path $basedir *] {
        # Recusively call the routine on the sub directory and append any
        # new files to the results
    set subDirList [findFiles $dirName $pattern]
    if { [llength $subDirList] > 0 } {
      foreach subDirFile $subDirList {
        lappend fileList $subDirFile
      }
    }
  }
  return $fileList
}

## @brief determine file type from extension
#  Used only for Quartus
#
## @return FILE_TYPE the file Type
proc FindFileType {file_name} {
  set extension [file extension $file_name]
  switch $extension {
    .stp {
      set file_extension "USE_SIGNALTAP_FILE"
    }
    .vhd {
      set file_extension "VHDL_FILE"
    }
    .vhdl {
      set file_extension "VHDL_FILE"
    }
    .v {
      set file_extension "VERILOG_FILE"
    }
    .sv {
      set file_extension "SYSTEMVERILOG_FILE"
    }
    .sdc {
      set file_extension "SDC_FILE"
    }
    .pdc {
      set file_extension "PDC_FILE"
    }
    .ndc {
      set file_extension "NDC_FILE"
    }
    .fdc {
      set file_extension "FDC_FILE"
    }
    .qsf {
      set file_extension "SOURCE_FILE"
    }
    .ip {
      set file_extension "IP_FILE"
    }
    .qsys {
      set file_extension "QSYS_FILE"
    }
    .qip {
      set file_extension "QIP_FILE"
    }
    .sip {
      set file_extension "SIP_FILE"
    }
    .bsf {
      set file_extension "BSF_FILE"
    }
    .bdf {
      set file_extension "BDF_FILE"
    }
    .tcl {
      set file_extension "COMMAND_MACRO_FILE"
    }
    .vdm {
      set file_extension "VQM_FILE"
    }
    default {
      set file_extension "ERROR"
      Msg Error "Unknown file extension $extension"
    }
  }
  return $file_extension
}


# @brief Returns the newest version in a list of versions
#
# @param[in] versions The list of versions
proc FindNewestVersion { versions } {
  set new_ver 00000000
  foreach ver $versions {
    ##nagelfar ignore
    if {[ expr 0x$ver > 0x$new_ver ] } {
      set new_ver $ver
    }
  }
  return $new_ver
}

## @brief Set VHDL version to 2008 for *.vhd files
#
# @param[in] file_name the name of the HDL file
#
# @return "-hdl_version VHDL_2008" if the file is a *.vhd files else ""
proc FindVhdlVersion {file_name} {
  set extension [file extension $file_name]
  switch $extension {
    .vhd {
      set vhdl_version "-hdl_version VHDL_2008"
    }
    .vhdl {
      set vhdl_version "-hdl_version VHDL_2008"
    }
    default {
      set vhdl_version ""
    }
  }

  return $vhdl_version
}

## @brief Format a generic to a 32 bit verilog style hex number, e.g.
#  take in ea8394c and return 32'h0ea8394c
#
#  @param[in]    unformatted generic
proc FormatGeneric {generic} {
  if {[string is integer "0x$generic"]} {
    return [format "32'h%08X" "0x$generic"]
  } else {
    # for non integers (e.g. blanks) just return 0
    return [format "32'h%08X" 0]
  }
}

# @brief Generate the bitstream
#
# @param[in] project_name The name of the project
# @param[in] run_folder   The path where to run the implementation
# @param[in] repo_path    The main path of the git repository
# @param[in] njobs        The number of CPU jobs to run in parallel
proc GenerateBitstream { {run_folder ""} {repo_path .} {njobs 1} } {
  Msg Info "Starting write bitstream flow..."
  if {[IsISE]} {
    # PlanAhead command
    Msg Info "running pre-bitstream"
    source  $repo_path/Hog/Tcl/integrated/pre-bitstream.tcl
    launch_runs impl_1 -to_step Bitgen $njobs -dir $run_folder
    wait_on_run impl_1
    Msg Info "running post-bitstream"
    source  $repo_path/Hog/Tcl/integrated/post-bitstream.tcl

    set prog [get_property PROGRESS [get_runs impl_1]]
    set status [get_property STATUS [get_runs impl_1]]
    Msg Info "Run: impl_1 progress: $prog, status : $status"

    if {$prog ne "100%"} {
      Msg Error "Write bitstream error, status is: $status"
    }

    set wns [get_property STATS.WNS [get_runs [current_run]]]
    set tns [get_property STATS.TNS [get_runs [current_run]]]
    set whs [get_property STATS.WHS [get_runs [current_run]]]
    set ths [get_property STATS.THS [get_runs [current_run]]]
    set tpws [get_property STATS.TPWS [get_runs [current_run]]]

  } elseif {[IsQuartus]} {
    set revision [get_current_revision]
    if {[catch {execute_module -tool asm} result]} {
      Msg Error "Result: $result\n"
      Msg Error "Generate bitstream failed. See the report file.\n"
    } else {
      Msg Info "Generate bitstream was successful for revision $revision.\n"
    }
  } elseif {[IsLibero]} {
      Msg Info "Run GENERATEPROGRAMMINGDATA ..."
      if {[catch {run_tool -name {GENERATEPROGRAMMINGDATA}  }] } {
        Msg Error "GENERATEPROGRAMMINGDATA FAILED!"
      } else {
        Msg Info "GENERATEPROGRAMMINGDATA PASSED."
      }
      Msg Info "Sourcing Hog/Tcl/integrated/post-bitstream.tcl"
      source $repo_path/Hog/Tcl/integrated/post-bitstream.tcl
  } elseif {[IsDiamond]} {
    prj_run Export -impl Implementation0 -task Bitgen
  }
}

## @brief Function used to generate a qsys system from a .qsys file.
#  The procedure adds the generated IPs to the project.
#
#  @param[in] qsysFile the Intel Platform Designed file (.qsys), containing the system to be generated
#  @param[in] commandOpts the command options to be used during system generation as they are in qsys-generate options
#
proc GenerateQsysSystem {qsysFile commandOpts} {
  if { [file exists $qsysFile] != 0} {
    set qsysPath [file dirname $qsysFile]
    set qsysName [file rootname [file tail $qsysFile] ]
    set qsysIPDir "$qsysPath/$qsysName"
    set qsysLogFile "$qsysPath/$qsysName.qsys-generate.log"

    set qsys_rootdir ""
    if {! [info exists ::env(QSYS_ROOTDIR)] } {
      if {[info exists ::env(QUARTUS_ROOTDIR)] } {
        set qsys_rootdir "$::env(QUARTUS_ROOTDIR)/sopc_builder/bin"
        Msg Warning "The QSYS_ROOTDIR environment variable is not set! I will use $qsys_rootdir"
      } else {
        Msg CriticalWarning "The QUARTUS_ROOTDIR environment variable is not set! Assuming all quartus executables are contained in your PATH!"
      }
    } else {
      set qsys_rootdir $::env(QSYS_ROOTDIR)
    }

    set cmd "$qsys_rootdir/qsys-generate"
    set cmd_options "$qsysFile --output-directory=$qsysIPDir $commandOpts"
    if {![catch {"exec $cmd -version"}] || [lindex $::errorCode 0] eq "NONE"} {
      Msg Info "Executing: $cmd $cmd_options"
      Msg Info "Saving logfile in: $qsysLogFile"
      if {[ catch {eval exec -ignorestderr "$cmd $cmd_options >>& $qsysLogFile"} ret opt]} {
        set makeRet [lindex [dict get $opt -errorcode] end]
        Msg CriticalWarning "$cmd returned with $makeRet"
      }
    } else {
      Msg Error " Could not execute command $cmd"
      exit 1
    }
    #Add generated IPs to project
    set qsysIPFileList  [concat [glob -nocomplain -directory $qsysIPDir -types f *.ip *.qip ] [glob -nocomplain -directory "$qsysIPDir/synthesis" -types f *.ip *.qip *.vhd *.vhdl ] ]
    foreach qsysIPFile $qsysIPFileList {
      if { [file exists $qsysIPFile] != 0} {
        set qsysIPFileType [FindFileType $qsysIPFile]
        set_global_assignment -name $qsysIPFileType $qsysIPFile
        # Write checksum to file
        set IpMd5Sum [Md5Sum $qsysIPFile]
        # open file for writing
        set fileDir [file normalize "./hogTmp"]
        set fileName "$fileDir/.hogQsys.md5"
        if {![file exists $fileDir]} {
          file mkdir $fileDir
        }
        set hogQsysFile [open $fileName "a"]
        set fileEntry "$qsysIPFile\t$IpMd5Sum"
        puts $hogQsysFile $fileEntry
        close $hogQsysFile
      }
    }
  } else {
    Msg ERROR "Error while generating ip variations from qsys: $qsysFile not found!"
  }
}


## Format generics from conf file to string that simulators accepts
#
# @param[in]              dict containing generics from conf file
# @param[in] target:      software target(vivado, questa)
#                         defines the output format of the string
proc GenericToSimulatorString {prop_dict target} {
  set prj_generics ""
  dict for {theKey theValue} $prop_dict {
    set valueHexFull ""
    set valueNumBits ""
    set valueHexFlag ""
    set valueHex ""
    set valueIntFull ""
    set ValueInt ""
    set valueStrFull ""
    set ValueStr ""
    regexp {([0-9]*)('h)([0-9a-fA-F]*)} $theValue valueHexFull valueNumBits valueHexFlag valueHex
    regexp {^([0-9]*)$} $theValue valueIntFull ValueInt
    regexp {(?!^\d+$)^.+$} $theValue valueStrFull ValueStr
    if { [string tolower $target] == "vivado" || [string tolower $target] == "xsim" } {
      if {$valueNumBits != "" && $valueHexFlag != "" && $valueHex != ""} {
        set prj_generics "$prj_generics $theKey=$valueHexFull"
      } elseif { $valueIntFull != "" && $ValueInt != "" } {
        set prj_generics "$prj_generics $theKey=$ValueInt"
      } elseif { $valueStrFull != "" && $ValueStr != "" } {
        set prj_generics "$prj_generics $theKey=\"$ValueStr\""
      } else {
        set prj_generics "$prj_generics $theKey=\"$theValue\""
      }
    } elseif { [lsearch -exact [GetSimulators] [string tolower $target] ] >= 0 } {
      if {$valueNumBits != "" && $valueHexFlag != "" && $valueHex != ""} {
        set numBits 0
        scan $valueNumBits %d numBits
        set numHex 0
        scan $valueHex %x numHex
        binary scan [binary format "I" $numHex] "B*" binval
        set numBits [expr {$numBits-1}]
        set numBin [string range $binval end-$numBits end]
        set prj_generics "$prj_generics $theKey=\"$numBin\""

      } elseif { $valueIntFull != "" && $ValueInt != "" } {
        set prj_generics "$prj_generics $theKey=$ValueInt"
      } elseif { $valueStrFull != "" && $ValueStr != "" } {
        set prj_generics "$prj_generics {$theKey=\"$ValueStr\"}"

      } else {
        set prj_generics "$prj_generics {$theKey=\"$theValue\"}"
      }
    } else {
      Msg Warning "Target : $target not implemented"
    }
  }
  return $prj_generics
}

## Get the configuration files to create a Hog project
#
#  @param[in] proj_dir: The project directory containing the conf file or the the tcl file
#
#  @return[in] a list containing the full path of the hog.conf, sim.conf, pre-creation.tcl, post-creation.tcl and proj.tcl files
proc GetConfFiles {proj_dir} {
  if {![file isdirectory $proj_dir]} {
    Msg Error "$proj_dir is supposed to be the top project directory"
    return -1
  }
  set conf_file [file normalize $proj_dir/hog.conf]
  set sim_file [file normalize $proj_dir/sim.conf]
  set pre_tcl [file normalize $proj_dir/pre-creation.tcl]
  set post_tcl [file normalize $proj_dir/post-creation.tcl]

  return [list $conf_file $sim_file $pre_tcl $post_tcl]
}


# Searches directory for tcl scripts to add as custom commands to launch.tcl
# Returns string of tcl scripts formatted as usage or switch statement
#
# @param[in] directory    The directory where to look for custom tcl scripts (Default .)
# @param[in] ret_commands if 1 returns commands as switch statement string instead of usage (Default 0)
proc GetCustomCommands {{directory .} {ret_commands 0}} {
  set commands_dict [dict create]
  set commands_files [glob -nocomplain $directory/*.tcl ]
  set commands_string ""

  if {[llength $commands_files] == 0} {
    return ""
  }

  if {$ret_commands == 0} {
   append commands_string "\n** Custom Commands:\n"
  }

  foreach file $commands_files {
    set base_name [string toupper [file rootname [file tail $file]]]
    if {$ret_commands == 1} {
      append commands_string "
      \\^$base_name\$ {
        Msg Info \"Running custom script: $file\"
        source \"$file\"
        Msg Info \"Done running custom script...\"
        exit
      }
      "
    } else {
      set f [open $file r]
      set first_line [gets $f]
      close $f
      if {[regexp -nocase "^#\s*$base_name:\s*(.*)" $first_line full_match script_des]} {
        append commands_string "- $base_name: $script_des\n"
      } else {
        append commands_string "- $base_name: runs $file\n"
      }
    }
  }
  return $commands_string
}

## Get the Date and time of a commit (or current time if Git < 2.9.3)
#
#  @param[in]    commit The commit
proc GetDateAndTime {commit} {
  set clock_seconds [clock seconds]

  if {[GitVersion 2.9.3]} {
    set date [Git "log -1 --format=%cd --date=format:%d%m%Y $commit"]
    set timee [Git "log -1 --format=%cd --date=format:00%H%M%S $commit"]
  } else {
    Msg Warning "Found Git version older than 2.9.3. Using current date and time instead of commit time."
    set date [clock format $clock_seconds  -format {%d%m%Y}]
    set timee [clock format $clock_seconds -format {00%H%M%S}]
  }
  return [list $date $timee]
}

## @brief Gets a list of files contained in the current fileset that match a file name (passed as parameter)
#
# The file name is matched against the input parameter.
#
#  @param[in] file name (or part of it)
#  @param[in] fileset name
#
#  @return    a list of files matching the parameter in the chosen fileset
#
proc GetFile {file fileset} {
  if {[IsXilinx]} {
    # Vivado
    set Files [get_files -all $file -of_object [get_filesets $fileset]]
    set f [lindex $Files 0]

    return $f

  } elseif {[IsQuartus]} {
    # Quartus
    return ""
  } else {
    # Tcl Shell
    puts "***DEBUG Hog:GetFile $file"
    return "DEBUG_file"
  }
}

## @brief Extract the generics from a file
#
# @param[in] filename The file from which to extract the generics
# @param[in] entity   The entity in the file from which to extract the generics (default "")
proc GetFileGenerics {filename {entity ""}} {
  set file_type [FindFileType $filename]
  if {[string equal $file_type "VERILOG_FILE"] || [string equal $file_type "SYSTEMVERILOG_FILE"]} {
    return [GetVerilogGenerics $filename]
  } elseif {[string equal $file_type "VHDL_FILE"]} {
    return [GetVhdlGenerics $filename $entity]
  } else {
    Msg CriticalWarning "Could not determine extension of top level file."
  }
}

## @brief Gets custom generics from hog|sim.conf
#
# @param[in] proj_dir:    the top folder of the project
# @return dict with generics
#
proc GetGenericsFromConf {proj_dir {sim 0}} {
  set generics_dict [dict create]
  set top_dir "Top/$proj_dir"
  set conf_file "$top_dir/hog.conf"
  set conf_index 0
  if {$sim == 1} {
    set conf_file "$top_dir/sim.conf"
    set conf_index 1
  }

  if {[file exists $conf_file]} {
    set properties [ReadConf [lindex [GetConfFiles $top_dir] $conf_index]]
    if {[dict exists $properties generics]} {
      set generics_dict [dict get $properties generics]
    }
  } else {
    Msg Warning "File $conf_file not found."
  }
  return $generics_dict
}

## @brief Gets all custom <simset>:generics from sim.conf
#
# @param[in] proj_dir:    the top folder of the project
# @return nested dict with all <simset>:generics
#
proc GetSimsetGenericsFromConf {proj_dir} {
  set simsets_generics_dict [dict create]
  set top_dir "Top/$proj_dir"
  set conf_file "$top_dir/sim.conf"
  set conf_index 1

  if {[file exists $conf_file]} {
    set properties [ReadConf [lindex [GetConfFiles $top_dir] $conf_index]]
    # Filter the dictionary for keys ending with ":generics"
    set simsets_generics_dict [dict filter $properties key *:generics]
  } else {
    Msg Warning "File $conf_file not found."
  }
  return $simsets_generics_dict
}


## Returns the group name from the project directory
#
#  @param[in]    proj_dir project directory
#  @param[in]    repo_dir repository directory
#
#  @return       the group name without initial and final slashes
#
proc GetGroupName {proj_dir repo_dir} {
  if {[regexp {^(.*)/(Top|Projects)/+(.*?)/*$} $proj_dir dummy possible_repo_dir proj_or_top dir]} {
    # The Top or Project folder is in the root of a the git repository
    if {[file normalize $repo_dir] eq [file normalize $possible_repo_dir]} {
      set group [file dir $dir]
      if { $group == "." } {
        set group ""
      }
    } else {
    # The Top or Project folder is NOT in the root of a git repository
      Msg Warning "Project directory $proj_dir seems to be in $possible_repo_dir which is not a the main Git repository $repo_dir."
    }
  } else {
    Msg Warning "Could not parse project directory $proj_dir"
    set group ""
  }
  return $group
}

## Get custom Hog describe of a specific SHA
#
#  @param[in] sha         the git sha of the commit you want to calculate the describe of
#  @param[in] repo_path   the main path of the repository
#
#  @return            the Hog describe of the sha or the current one if the sha is 0
#
proc GetHogDescribe {sha {repo_path .}} {
  if {$sha == 0 } {
    # in case the repo is dirty, we use the last committed sha and add a -dirty suffix
    set new_sha "[string toupper [GetSHA]]"
    set suffix "-dirty"
  } else {
    set new_sha [string toupper $sha]
    set suffix ""
  }
  set describe "v[HexVersionToString [GetVerFromSHA $new_sha $repo_path]]-$new_sha$suffix"
  return $describe
}

## @brief Extract files, libraries and properties from the project's list files
#
# @param[in] args The arguments are \<list_path\> \<repository path\>[options]
# * list_path path to the list file directory
# Options:
# * -list_files \<List files\> the file wildcard, if not specified all Hog list files will be looked for
# * -sha_mode forwarded to ReadListFile, see there for info
# * -ext_path \<external path\> path for external libraries forwarded to ReadListFile
#
# @return a list of 3 dictionaries: libraries and properties
# - libraries has library name as keys and a list of filenames as values
# - properties has as file names as keys and a list of properties as values
# - filesets has the fileset name as keys and the correspondent list of libraries as values (significant only for simulations)
proc GetHogFiles args {

  if {[IsQuartus]} {
    load_package report
    if { [catch {package require cmdline} ERROR] } {
      puts "$ERROR\n If you are running this script on tclsh, you can fix this by installing 'tcllib'"
      return 1
    }
  }


  set parameters {
    {list_files.arg ""  "The file wildcard, if not specified all Hog list files will be looked for."}
    {sha_mode "Forwarded to ReadListFile, see there for info."}
    {ext_path.arg "" "Path for the external libraries forwarded to ReadListFile."}
  }
  set usage "USAGE: GetHogFiles \[options\] <list path> <repository path>"
  if {[catch {array set options [cmdline::getoptions args $parameters $usage]}] ||  [llength $args] != 2 } {
    Msg CriticalWarning [cmdline::usage $parameters $usage]
    return
  }
  set list_path [lindex $args 0]
  set repo_path [lindex $args 1]

  set list_files $options(list_files)
  set sha_mode $options(sha_mode)
  set ext_path $options(ext_path)


  if { $sha_mode == 1 } {
    set sha_mode_opt "-sha_mode"
  } else {
    set sha_mode_opt ""
  }

  if { $list_files == "" } {
    set list_files {.src,.con,.sim,.ext}
  }
  set libraries [dict create]
  set properties [dict create]
  set list_files [glob -nocomplain -directory $list_path "*{$list_files}"]
  set filesets [dict create]

  foreach f $list_files {
    set ext [file extension $f]
    if {$ext == ".ext"} {
      lassign [ReadListFile {*}"$sha_mode_opt  $f $ext_path"] l p fs
    } else {
      lassign [ReadListFile {*}"$sha_mode_opt  $f $repo_path"] l p fs
    }
    set libraries [MergeDict $l $libraries]
    set properties [MergeDict $p $properties]
    Msg Debug "list file $f, filesets: $fs"
    set filesets [MergeDict $fs $filesets]
    Msg Debug "Merged filesets $filesets"
  }
  return [list $libraries $properties $filesets]
}

# @brief Get the IDE of a Hog project and returns the correct argument for the IDE cli command
#
# @param[in] proj_conf The project hog.conf file
proc GetIDECommand {proj_conf} {
  # GetConfFiles returns a list, the first element is hog.conf
  if {[file exists $proj_conf]} {
    set ide_name_and_ver [string tolower [GetIDEFromConf $proj_conf]]
    set ide_name [lindex [regexp -all -inline {\S+} $ide_name_and_ver ] 0]

    if {$ide_name eq "vivado"} {
      set command "vivado"
      # A space ater the before_tcl_script is important
      set before_tcl_script " -nojournal -nolog -mode batch -notrace -source "
      set after_tcl_script " -tclargs "
      set end_marker ""

    } elseif {$ide_name eq "planahead"} {
      set command "planAhead"
      # A space ater the before_tcl_script is important
      set before_tcl_script " -nojournal -nolog -mode batch -notrace -source "
      set after_tcl_script " -tclargs "
      set end_marker ""

    } elseif {$ide_name eq "quartus"} {
      set command "quartus_sh"
      # A space after the before_tcl_script is important
      set before_tcl_script " -t "
      set after_tcl_script " "
      set end_marker ""

    } elseif {$ide_name eq "libero"} {
      #I think we need quotes for libero, not sure...

      set command "libero"
      set before_tcl_script "SCRIPT:"
      set after_tcl_script " SCRIPT_ARGS:\""
      set end_marker "\""
    } elseif {$ide_name eq "diamond"} {
      set command "diamondc"
      set before_tcl_script " "
      set after_tcl_script " "
      set end_marker ""
    } else {
      Msg Error "IDE: $ide_name not known."
    }

  } else {
    Msg Error "Configuration file $proj_conf not found."
  }

  return [list $command $before_tcl_script $after_tcl_script $end_marker]
}

## Get the IDE (Vivado,Quartus,PlanAhead,Libero) version from the conf file she-bang
#
#  @param[in]    conf_file The hog.conf file
proc GetIDEFromConf {conf_file} {
  set f [open $conf_file "r"]
  set line [gets $f]
  close $f
  if {[regexp -all {^\# *(\w*) *(\d+\.\d+(?:\.\d+)?(?:\.\d+)?)?(_.*)? *$} $line dummy ide version patch]} {
    if {[info exists version] && $version != ""} {
      set ver $version
    } else {
      set ver 0.0.0
    }
    # what shall we do with $patch? ignored for the time being
    set ret [list $ide $ver]
  } else {
    Msg CriticalWarning "The first line of hog.conf should be \#<IDE name> <version>, where <IDE name>. is quartus, vivado, planahead and <version> the tool version, e.g. \#vivado 2020.2. Will assume vivado."
    set ret [list "vivado" "0.0.0"]
  }

  return $ret
}

# @brief Returns the name of the running IDE
proc GetIDEName {} {
  if {[IsISE]} {
    return "ISE/PlanAhead"
  } elseif {[IsVivado]} {
    return "Vivado"
  } elseif {[IsQuartus]} {
    return "Quartus"
  } elseif {[IsLibero]} {
    return "Libero"
  } elseif {[IsDiamond]} {
    return "Diamond"
  } else {
    return ""
  }
}

## Returns the version of the IDE (Vivado,Quartus,PlanAhead,Libero) in use
#
#  @return       the version in string format, e.g. 2020.2
#
proc GetIDEVersion {} {
  if {[IsXilinx]} {
    #Vivado or planAhead
    regexp {\d+\.\d+(\.\d+)?} [version -short] ver
    # This regex will cut away anything after the numbers, useful for patched version 2020.1_AR75210

  } elseif {[IsQuartus]} {
    # Quartus
    global quartus
    regexp {[\.0-9]+} $quartus(version) ver
  } elseif {[IsLibero]} {
    # Libero
    set ver [get_libero_version]
  } elseif {[IsDiamond]} {
    regexp {\d+\.\d+(\.\d+)?} [sys_install version] ver
  }
  return $ver
}



## @brief Returns the real file linked by a soft link
#
# If the provided file is not a soft link, it will give a Warning and return an empty string.
# If the link is broken, will give a warning but still return the linked file
#
# @param[in] link_file The soft link file
proc GetLinkedFile {link_file} {
  if {[file type $link_file] eq "link"} {
    if {[OS] == "windows" } {
        #on windows we need to use readlink because Tcl is broken
      lassign  [ExecuteRet realpath $link_file] ret msg
      lassign  [ExecuteRet cygpath -m $msg] ret2 msg2
      if {$ret == 0 && $ret2 == 0} {
        set real_file $msg2
        Msg Debug "Found link file $link_file on Windows, the linked file is: $real_file"
      } else {
        Msg CriticalWarning "[file normalize $link_file] is a soft link. Soft link are not supported on Windows and readlink.exe or cygpath.exe did not work: readlink=$ret: $msg, cygpath=$ret2: $msg2."
        set real_file $link_file
      }
    } else {
      #on linux Tcl just works
      set linked_file [file link $link_file]
      set real_file [file normalize [file dirname $link_file]/$linked_file]
    }

    if {![file exists $real_file]} {
      Msg Warning "$link_file is a broken link, because the linked file: $real_file does not exist."
    }
  } else {
    Msg Warning "$link file is not a soft link"
    set real_file $link_file
  }
  return $real_file
}

## @brief Gets MAX number of Threads property from property.conf file in Top/$proj_name directory.
#
# If property is not set returns default = 1
#
# @param[in] proj_dir:   the top folder of the project
#
# @return 1 if property is not set else the value of MaxThreads
#
proc GetMaxThreads {proj_dir} {
  set maxThreads 1
  if {[file exists $proj_dir/hog.conf]} {
    set properties [ReadConf [lindex [GetConfFiles $proj_dir] 0]]
    if {[dict exists $properties parameters]} {
      set propDict [dict get $properties parameters]
      if {[dict exists $propDict MAX_THREADS]} {
        set maxThreads [dict get $propDict MAX_THREADS]
      }
    }
  } else {
    Msg Warning "File $proj_dir/hog.conf not found. Max threads will be set to default value 1"
  }
  return $maxThreads
}


## @brief Get a list of all modified the files matching then pattern
#
# @param[in] repo_path the path of the git repository
# @param[in] pattern the pattern with wildcards that files should match
#
# @return    a list of all modified files matching the pattern
#
proc GetModifiedFiles {{repo_path "."} {pattern "."}} {
  set old_path [pwd]
  cd $repo_path
  set ret [Git "ls-files --modified $pattern"]
  cd $old_path
  return $ret
}

# @brief Gets the command argv list and returns a list of
#        options and arguments
# @param[in] argv       The command input arguments
# @param[in] parameters The command input parameters
proc GetOptions {argv parameters} {
  # Get Options from argv
  set arg_list [list]
  set param_list [list]
  set option_list [list]

  foreach p $parameters {
    lappend param_list [lindex $p 0]
  }

  set index 0
  while {$index < [llength $argv]} {
    set arg [lindex $argv $index]
    if {[string first - $arg] == 0} {
      set option [string trimleft $arg "-"]
      incr index
      lappend option_list $arg
      if {[lsearch $param_list ${option}*] >= 0 && [string first ".arg" [lsearch -inline $param_list ${option}*]] >= 0} {
        lappend option_list [lindex $argv $index]
        incr index
      }
    } else {
      lappend arg_list $arg
      incr index
    }
  }
  Msg Debug "Argv: $argv"
  Msg Debug "Options: $option_list"
  Msg Debug "Arguments: $arg_list"
  return [list $option_list $arg_list]
}

# return [list $libraries $properties $simlibraries $constraints $srcsets $simsets $consets]
## @ brief Returns a list of 7 dictionaries: libraries, properties, constraints, and filesets for sources and simulations
#
#   The returned dictionaries are libraries, properties, simlibraries, constraints, srcsets, simsets, consets
# - libraries and simlibraries have the library name as keys and a list of filenames as values
# - properties has as file names as keys and a list of properties as values
# - constraints is a dictionary with a single key (sources.con) and a list of constraint files as value
# - srcsets is a dictionary with a fileset name as a key (e.g. sources_1) and a list of libraries as value
# - simsets is a dictionary with a simset name as a key (e.g. sim_1) and a list of libraries as value
# - consets is a dictionary with a constraints file sets name as a key (e.g. constr_1) and a list of constraint "libraries" (sources.con)
#
# Files, libraries and properties are extracted from the current project
#
# @param[in] project_file The project file (for Libero and Diamond)
# @return A list of 7 dictionaries: libraries, properties, constraints, and filesets for sources and simulations
proc GetProjectFiles {{project_file ""}} {

  set libraries [dict create]
  set simlibraries [dict create]
  set constraints [dict create]
  set properties [dict create]
  set consets [dict create]
  set srcsets [dict create]
  set simsets [dict create]

  if {[IsVivado]} {
    set all_filesets [get_filesets]
    set simulator [get_property target_simulator [current_project]]
    set top [get_property "top"  [current_fileset]]
    set topfile [GetTopFile]
    dict lappend properties $topfile "top=$top"

    foreach fs $all_filesets {
      if {$fs == "utils_1"} {
        # Skipping utility fileset
        continue
      }

      set all_files [get_files -quiet -of_objects [get_filesets $fs]]
      set fs_type [get_property FILESET_TYPE [get_filesets $fs]]

      if {$fs_type == "BlockSrcs"} {
        # Vivado creates for each ip a blockset... Let's redirect to sources_1
        set dict_fs "sources_1"
      } else {
        set dict_fs $fs
      }
      foreach f $all_files {
        # Ignore files that are part of the vivado/planahead project but would not be reflected
        # in list files (e.g. generated products from ip cores)
        set ignore 0
        # Generated files point to a parent composite file;
        # planahead does not have an IS_GENERATED property
        if { [IsInList "IS_GENERATED" [list_property [GetFile $f $fs]]]} {
          if { [lindex [get_property  IS_GENERATED [GetFile $f $fs]] 0] != 0} {
            set ignore 1
          }
        }

        if {[get_property FILE_TYPE [GetFile $f $fs]] == "Configuration Files"} {
          set ignore 1
        }


        if { [IsInList "CORE_CONTAINER" [list_property [GetFile $f $fs]]]} {
          if {[get_property CORE_CONTAINER [GetFile $f $fs]] != ""} {
            if { [file extension $f] == ".xcix"} {
              set f [get_property CORE_CONTAINER [GetFile $f $fs]]
            } else {
              set ignore 1
            }
          }
        }

        if {[IsInList "SCOPED_TO_REF" [list_property [GetFile $f $fs]]]} {
          if {[get_property SCOPED_TO_REF [GetFile $f $fs]] != ""} {
            dict lappend properties $f "scoped_to_ref=[get_property SCOPED_TO_REF [GetFile $f $fs]]"
          }
        }

        if {[IsInList "SCOPED_TO_CELLS" [list_property [GetFile $f $fs]]]} {
          if {[get_property SCOPED_TO_CELLS [GetFile $f $fs]] != ""} {
            dict lappend properties $f "scoped_to_cells=[get_property SCOPED_TO_CELLS [GetFile $f $fs]]"
          }
        }

        if {[IsInList "PARENT_COMPOSITE_FILE" [list_property [GetFile $f $fs]]]} {
          set ignore 1
        }

        # Ignore nocattrs.dat for Versal
        if {[file tail $f] == "nocattrs.dat"} {
          set ignore 1
        }

        if {!$ignore} {
          if {[file extension $f] != ".coe"} {
            set f [file normalize $f]
          }
          lappend files $f
          set type  [get_property FILE_TYPE [GetFile $f $fs]]
          # Added a -quiet because some files (.v, .sv) don't have a library
          set lib [get_property -quiet LIBRARY [GetFile $f $fs]]

          # Type can be complex like VHDL 2008, in that case we want the second part to be a property
          Msg Debug "File $f Extension [file extension $f] Type [lindex $type 0]"

          if {[string equal [lindex $type 0] "VHDL"] && [llength $type] == 1} {
            set prop "93"
          } elseif  {[string equal [lindex $type 0] "Block"] && [string equal [lindex $type 1] "Designs"]} {
            set type "IP"
            set prop ""
          } elseif {[string equal $type "SystemVerilog"] && [file extension $f] != ".sv"} {
            set prop "SystemVerilog"
          } elseif {[string equal [lindex $type 0] "XDC"] && [file extension $f] != ".xdc"} {
            set prop "XDC"
          } elseif {[string equal $type "Verilog Header"] && [file extension $f] != ".vh" && [file extension $f] != ".svh"} {
            set prop "verilog_header"
          } elseif {[string equal $type "Verilog Template"] && [file extension $f] == ".v" && [file extension $f] != ".sv"} {
            set prop "verilog_template"
          } else {
            set type [lindex $type 0]
            set prop ""
          }
          #If type is "VHDL 2008" we will keep only VHDL
          if {![string equal $prop ""]} {
            dict lappend properties $f $prop
          }
          # check where the file is used and add it to prop
          if {[string equal $fs_type "SimulationSrcs"]} {
            # Simulation sources
            if {[string equal $type "VHDL"] } {
              set library "${lib}.sim"
            } else {
              set library "others.sim"
            }

            if {[IsInList $library [DictGet $simsets $dict_fs]]==0} {
              dict lappend simsets $dict_fs $library
            }

            dict lappend simlibraries $library $f

          } elseif {[string equal $type "VHDL"] } {
            # VHDL files (both 2008 and 93)
            if {[IsInList "${lib}.src" [DictGet $srcsets $dict_fs]]==0} {
              dict lappend srcsets $dict_fs "${lib}.src"
            }
            dict lappend libraries "${lib}.src" $f
          } elseif {[string first "IP" $type] != -1} {
            # IPs
            if {[IsInList "ips.src" [DictGet $srcsets $dict_fs]]==0} {
              dict lappend srcsets $dict_fs "ips.src"
            }
            dict lappend libraries "ips.src" $f
            Msg Debug "Appending $f to ips.src"
          } elseif {[string equal $fs_type "Constrs"]} {
            # Constraints
            if {[IsInList "sources.con" [DictGet $consets $dict_fs]]==0} {
              dict lappend consets $dict_fs "sources.con"
            }
            dict lappend constraints "sources.con" $f
          } else {
            # Verilog and other files
            if {[IsInList "others.src" [DictGet $srcsets $dict_fs]]==0} {
              dict lappend srcsets $dict_fs "others.src"
            }
            dict lappend libraries "others.src" $f
            Msg Debug "Appending $f to others.src"
          }

          if {[lindex [get_property -quiet used_in_synthesis  [GetFile $f $fs]] 0] == 0} {
            dict lappend properties $f "nosynth"
          }
          if {[lindex [get_property -quiet used_in_implementation  [GetFile $f $fs]] 0] == 0} {
            dict lappend properties $f "noimpl"
          }
          if {[lindex [get_property -quiet used_in_simulation  [GetFile $f $fs]] 0] == 0} {
            dict lappend properties $f "nosim"
          }
          if {[lindex [get_property -quiet IS_MANAGED [GetFile $f $fs]] 0] == 0 && [file extension $f] != ".xcix" } {
            dict lappend properties $f "locked"
          }
        }
      }
    }

    dict lappend properties "Simulator" [get_property target_simulator [current_project]]
  } elseif {[IsLibero] || [IsSynplify]} {

    # Open the project file
    set file [open $project_file r]
    set in_file_manager 0
    set top ""
    while {[gets $file line] >= 0} {
      # Detect the ActiveRoot (Top) module
      if {[regexp {^KEY ActiveRoot \"([^\"]+)\"} $line -> value]} {
        set top [string range $value 0 [expr {[string first "::" $value] - 1}]]
      }

      # Detect the start of the FileManager section
      if {[regexp {^LIST FileManager} $line]} {
        set in_file_manager 1
        continue
      }

      # Detect the end of the FileManager section
      if {$in_file_manager && [regexp {^ENDLIST} $line]} {
        break
      }

      # Extract file paths from the VALUE entries
      if {$in_file_manager && [regexp {^VALUE \"([^\"]+)} $line -> value]} {
        # lappend source_files [remove_after_comma $filepath]
        # set file_path ""
        lassign [split $value ,] file_path file_type
        # Extract file properties
        set parent_file ""
        set library "others"
        while {[gets $file line] >= 0} {
          if {$line == "ENDFILE"} {
            break
          }
          regexp {^LIBRARY=\"([^\"]+)} $line -> library
          regexp {^PARENT=\"([^\"]+)} $line -> parent_file
        }
        Msg Debug "Found file ${file_path} in project.."
        if {$parent_file == ""} {
          if {$file_type == "hdl"} {
            # VHDL files (both 2008 and 93)
            if {[IsInList "${library}.src" [DictGet $srcsets "sources_1"]]==0} {
              dict lappend srcsets "sources_1" "${library}.src"
            }
            dict lappend libraries "${library}.src" $file_path
            # Check if file is top_module in project
            Msg Debug "File $file_path module [GetModuleName $file_path]"

            if {[GetModuleName $file_path] == [string tolower $top] && $top != ""} {
              Msg Debug "Found top module $top in $file_path"
              dict lappend properties $file_path "top=$top"
            }

          } elseif {$file_type == "tb_hdl"} {
            if {[IsInList "${library}.sim" [DictGet $simsets "sim_1"]]==0} {
              dict lappend simsets "sim_1" "${library}.sim"
            }
            dict lappend simlibraries "${library}.sim" $file_path
          } elseif {$file_type == "io_pdc" || $file_type == "sdc"} {
            if {[IsInList "sources.con" [DictGet $consets "constrs_1"]]==0} {
              dict lappend consets "constrs_1" "sources.con"
            }
            dict lappend constraints "sources.con" $file_path
          }
        }
      }
    }
  } elseif {[IsDiamond]} {
    # Open the Diamond XML project file content
    set fileData [read [open $project_file]]

    set project_path [file dirname $project_file]

    # Remove XML declaration
    regsub {<\?xml.*\?>} $fileData "" fileData

    # Extract the Implementation block
    regexp {<Implementation.*?>(.*)</Implementation>} $fileData -> implementationContent

    # Extract each Source block one by one
    set sources {}
    set sourceRegex {<Source name="([^"]*?)" type="([^"]*?)" type_short="([^"]*?)".*?>(.*?)</Source>}

    set optionsRegex {<Options(.*?)\/>}
    regexp $optionsRegex $implementationContent -> prj_options
    foreach option $prj_options {
      if {[regexp {^top=\"([^\"]+)\"} $option match result]} {
        set top $result
      }
    }

    while {[regexp $sourceRegex $implementationContent match name type type_short optionsContent]} {
      Msg Debug "Found file ${name} in project..."
      set file_path [file normalize $project_path/$name]
      # Extract the Options attributes
      set optionsRegex {<Options(.*?)\/>}
      regexp $optionsRegex $optionsContent -> options
      set library "others"
      set isSV 0
      foreach option $options {
        if {[string first "System Verilog" $option]} {
          set isSV 1
        }
        if {[regexp {^lib=\"([^\"]+)\"} $option match1 result]} {
          set library $result
        }
      }
      set ext ".src"
      if {[regexp {syn_sim="([^"]*?)"} $match match_sim simonly]} {
        set ext ".sim"
      }        

      # Append VHDL files
      if { $type_short == "VHDL" || $type_short == "Verilog" || $type_short == "IPX"} {
        if { $ext == ".src"} {
          if {[IsInList "${library}${ext}" [DictGet $srcsets "sources_1"]]==0} {
            dict lappend srcsets "sources_1" "${library}${ext}"
          }
          dict lappend libraries "${library}${ext}" $file_path
        } elseif { $ext == ".sim"} {
          if {[IsInList "${library}.sim" [DictGet $simsets "sim_1"]]==0} {
            dict lappend simsets "sim_1" "${library}.sim"
          }
          dict lappend simlibraries "${library}.sim" $file_path
        }
        # Check if file is top_module in project
        Msg Debug "File $file_path module [GetModuleName $file_path]"

        if {[GetModuleName $file_path] == [string tolower $top] && $top != ""} {
          Msg Debug "Found top module $top in $file_path"
          dict lappend properties $file_path "top=$top"
        }
      } elseif { $type_short == "SDC"} {
        if {[IsInList "sources.con" [DictGet $consets "constrs_1"]]==0} {
          dict lappend consets "constrs_1" "sources.con"
        }
        dict lappend constraints "sources.con" $file_path
      }

      # Remove the processed Source block from the implementation content
      regsub -- $match $implementationContent "" implementationContent
    }
  }
  return [list $libraries $properties $simlibraries $constraints $srcsets $simsets $consets]
}

## Get the Project flavour
#
#  @param[in]    proj_name The project name
proc GetProjectFlavour {proj_name} {
  # Calculating flavour if any
  set flavour [string map {. ""} [file extension $proj_name]]
  if {$flavour != ""} {
    if {[string is integer $flavour]} {
      Msg Info "Project $proj_name has flavour = $flavour, the generic variable FLAVOUR will be set to $flavour"
    } else {
      Msg Warning "Project name has a unexpected non numeric extension, flavour will be set to -1"
      set flavour -1
    }

  } else {
    set flavour -1
  }
  return $flavour
}

## Get the project version
#
#  @param[in] proj_dir: The top folder of the project of which all the version must be calculated
#  @param[in] repo_path: The top folder of the repository
#  @param[in] ext_path: path for external libraries
#  @param[in] sim: if enabled, check the version also for the simulation files
#
#  @return  returns the project version
proc GetProjectVersion {proj_dir repo_path {ext_path ""} {sim 0}} {
  if { ![file exists $proj_dir] } {
    Msg CriticalWarning "$proj_dir not found"
    return -1
  }
  set old_dir [pwd]
  cd $proj_dir

  #The latest version the repository
  set v_last [ExtractVersionFromTag [Git {describe --abbrev=0 --match "v*"}]]
  lassign [GetRepoVersions $proj_dir $repo_path $ext_path $sim] sha ver
  if {$sha == 0} {
    Msg Warning "Repository is not clean"
    cd $old_dir
    return -1
  }

  #The project version
  set v_proj [ExtractVersionFromTag v[HexVersionToString $ver]]
  set comp [CompareVersions $v_proj $v_last]
  Msg Debug "Project version $v_proj, latest tag $v_last"
  if {$comp == 1} {
    Msg Info "The specified project was modified since official version."
    set ret 0
  } else {
    set ret v[HexVersionToString $ver]
  }

  if {$comp == 0} {
    Msg Info "The specified project was modified in the latest official version $ret"
  } elseif {$comp == -1} {
    Msg Info "The specified project was modified in a past official version $ret"
  }

  cd $old_dir
  return $ret
}

## Get the versions for all libraries, submodules, etc. for a given project
#
#  @param[in] proj_dir: The project directory containing the conf file or the the tcl file
#  @param[in] repo_path: top path of the repository
#  @param[in] ext_path: path for external libraries
#  @param[in] sim: if enabled, check the version also for the simulation files
#
#  @return  a list containing all the versions: global, top (hog.conf, pre and post tcl scripts, etc.), constraints, libraries, submodules, external, ipbus xml, user ip repos
proc GetRepoVersions {proj_dir repo_path {ext_path ""} {sim 0}} {
  if { [catch {package require cmdline} ERROR] } {
    puts "$ERROR\n If you are running this script on tclsh, you can fix this by installing 'tcllib'"
    return 1
  }

  set old_path [pwd]
  set conf_files [GetConfFiles $proj_dir]

  # This will be the list of all the SHAs of this project, the most recent will be picked up as GLOBAL SHA
  set SHAs ""
  set versions ""

  # Hog submodule
  cd $repo_path

  # Append the SHA in which Hog submodule was changed, not the submodule SHA
  lappend SHAs [GetSHA {Hog}]
  lappend versions [GetVerFromSHA $SHAs $repo_path]

  cd "$repo_path/Hog"
  if {[Git {status --untracked-files=no  --porcelain}] eq ""} {
    Msg Info "Hog submodule [pwd] clean."
    lassign [GetVer ./] hog_ver hog_hash
  } else {
    Msg CriticalWarning "Hog submodule [pwd] not clean, commit hash will be set to 0."
    set hog_hash "0000000"
    set hog_ver "00000000"
  }

  cd $proj_dir

  if {[Git {status --untracked-files=no  --porcelain}] eq ""} {
    Msg Info "Git working directory [pwd] clean."
    set clean 1
  } else {
    Msg CriticalWarning "Git working directory [pwd] not clean, commit hash, and version will be set to 0."
    set clean 0
  }

  # Top project directory
  lassign [GetVer [join $conf_files]] top_ver top_hash
  lappend SHAs $top_hash
  lappend versions $top_ver

  # Read list files
  set libs ""
  set vers ""
  set hashes ""
  # Specify sha_mode 1 for GetHogFiles to get all the files, including the list-files themselves
  lassign [GetHogFiles -list_files "*.src" -sha_mode "./list/" $repo_path] src_files dummy
  dict for {f files} $src_files {
    # library names have a .src extension in values returned by GetHogFiles
    set name [file rootname [file tail $f]]
    if {[file ext $f] == ".oth"} {
      set name "OTHERS"
    }
    lassign [GetVer $files] ver hash
    # Msg Info "Found source list file $f, version: $ver commit SHA: $hash"
    lappend libs $name
    lappend versions $ver
    lappend vers $ver
    lappend hashes $hash
    lappend SHAs $hash
  }

  # Read constraint list files
  set cons_hashes ""
  # Specify sha_mode 1 for GetHogFiles to get all the files, including the list-files themselves
  lassign [GetHogFiles  -list_files "*.con" -sha_mode "./list/" $repo_path] cons_files dummy
  dict for {f files} $cons_files {
    #library names have a .con extension in values returned by GetHogFiles
    set name [file rootname [file tail $f]]
    lassign [GetVer  $files] ver hash
    #Msg Info "Found constraint list file $f, version: $ver commit SHA: $hash"
    if {$hash eq ""} {
      Msg CriticalWarning "Constraints file $f not found in Git."
    }
    lappend cons_hashes $hash
    lappend SHAs $hash
    lappend versions $ver
  }

  # Read simulation list files
  if {$sim == 1} {
    set sim_hashes ""
    # Specify sha_mode 1 for GetHogFiles to get all the files, including the list-files themselves
    lassign [GetHogFiles  -list_files "*.sim" -sha_mode "./list/" $repo_path] sim_files dummy
    dict for {f files} $sim_files {
      #library names have a .sim extension in values returned by GetHogFiles
      set name [file rootname [file tail $f]]
      lassign [GetVer  $files] ver hash
      #Msg Info "Found simulation list file $f, version: $ver commit SHA: $hash"
      lappend sim_hashes $hash
      lappend SHAs $hash
      lappend versions $ver
    }
  }


  #Of all the constraints we get the most recent
  if {"{}" eq $cons_hashes} {
    #" Fake comment for Visual Code Studio
    Msg CriticalWarning "No hashes found for constraints files (not in git)"
    set cons_hash ""
  } else {
    set cons_hash [string tolower [Git "log --format=%h -1 $cons_hashes"]]
  }
  set cons_ver [GetVerFromSHA $cons_hash $repo_path]
  #Msg Info "Among all the constraint list files, if more than one, the most recent version was chosen: $cons_ver commit SHA: $cons_hash"

  # Read external library files
  set ext_hashes ""
  set ext_files [glob -nocomplain "./list/*.ext"]
  set ext_names ""

  foreach f $ext_files {
    set name [file rootname [file tail $f]]
    set hash [GetSHA $f]
    #Msg Info "Found source file $f, commit SHA: $hash"
    lappend ext_names $name
    lappend ext_hashes $hash
    lappend SHAs $hash
    set ext_ver [GetVerFromSHA $hash $repo_path]
    lappend versions $ext_ver

    set fp [open $f r]
    set file_data [read $fp]
    close $fp
    set data [split $file_data "\n"]
    #Msg Info "Checking checksums of external library files in $f"
    foreach line $data {
      if {![regexp {^ *$} $line] & ![regexp {^ *\#} $line] } {
        #Exclude empty lines and comments
        set file_and_prop [regexp -all -inline {\S+} $line]
        set hdlfile [lindex $file_and_prop 0]
        set hdlfile $ext_path/$hdlfile
        if { [file exists $hdlfile] } {
          set hash [lindex $file_and_prop 1]
          set current_hash [Md5Sum $hdlfile]
          if {[string first $hash $current_hash] == -1} {
            Msg CriticalWarning "File $hdlfile has a wrong hash. Current checksum: $current_hash, expected: $hash"
          }
        }
      }
    }
  }

  # Ipbus XML
  if {[llength [glob -nocomplain ./list/*.ipb]] > 0 } {
    #Msg Info "Found IPbus XML list file, evaluating version and SHA of listed files..."
    lassign [GetHogFiles  -list_files "*.ipb" -sha_mode "./list/" $repo_path] xml_files dummy
    lassign [GetVer  [dict get $xml_files "xml.ipb"] ] xml_ver xml_hash
    lappend SHAs $xml_hash
    lappend versions $xml_ver

    #Msg Info "Found IPbus XML SHA: $xml_hash and version: $xml_ver."

  } else {
    Msg Info "This project does not use IPbus XMLs"
    set xml_ver  ""
    set xml_hash ""
  }

  set user_ip_repos ""
  set user_ip_repo_hashes ""
  set user_ip_repo_vers ""
  # User IP Repository (Vivado only, hog.conf only)
  if {[file exists [lindex $conf_files 0]]} {
    set PROPERTIES [ReadConf [lindex $conf_files 0]]
    if {[dict exists $PROPERTIES main]} {
      set main [dict get $PROPERTIES main]
      dict for {p v} $main {
        if { [ string tolower $p ] == "ip_repo_paths" } {
          foreach repo $v {
            lappend user_ip_repos "$repo_path/$repo"
          }
        }
      }
    }

    # For each defined IP repository get hash and version if directory exists and not empty
    foreach repo $user_ip_repos {
      if {[file isdirectory $repo]} {
        set repo_file_list [glob -nocomplain "$repo/*"]
        if {[llength $repo_file_list] != 0} {
          lassign [GetVer $repo] ver sha
          lappend user_ip_repo_hashes $sha
          lappend user_ip_repo_vers $ver
          lappend versions $ver
        } else {
          Msg Warning "IP_REPO_PATHS property set to $repo in hog.conf but directory is empty."
        }
      } else {
        Msg Warning "IP_REPO_PATHS property set to $repo in hog.conf but directory does not exist."
      }
    }
  }


  #The global SHA and ver is the most recent among everything
  if {$clean == 1} {
    set found 0
    while {$found == 0} {
      set global_commit [Git "log --format=%h -1 --abbrev=7 $SHAs"]
      foreach sha $SHAs {
      set found 1
      if {![IsCommitAncestor $sha $global_commit]} {
        set common_child  [FindCommonGitChild $global_commit $sha]
        if {$common_child == 0} {
          Msg CriticalWarning "The commit $sha is not an ancestor of the global commit $global_commit, which is OK. But $sha and $global_commit do not have any common child, which is NOT OK. This is probably do to a REBASE that is forbidden in Hog methodology as it changes git history. Hog cannot guarantee the accuracy of the SHAs. A way to fix this is to make a commit that touches all the projects in the repositories (e.g. change the Hog version) but please do not rebase in the official branches in the future."
        } else {
                Msg Info "The commit $sha is not an ancestor of the global commit $global_commit, adding the first common child $common_child instead..."
          lappend SHAs $common_child
        }
        set found 0

        break
      }
      }
    }
    set global_version [FindNewestVersion $versions]
  } else {
    set global_commit  "0000000"
    set global_version "00000000"
  }

  cd $old_path

  set top_hash [format %+07s $top_hash]
  set cons_hash [format %+07s $cons_hash]
  return [list $global_commit $global_version  $hog_hash $hog_ver  $top_hash $top_ver  $libs $hashes $vers  $cons_ver $cons_hash  $ext_names $ext_hashes  $xml_hash $xml_ver $user_ip_repos $user_ip_repo_hashes $user_ip_repo_vers ]
}

## @brief Get git SHA of a subset of list file
#
# @param[in] path the file/path or list of files/path the git SHA should be evaluated from. If is not set, use the current path
#
# @return         the value of the desired SHA
#
proc GetSHA {{path ""}} {
  if {$path == ""} {
    lassign [GitRet {log --format=%h --abbrev=7 -1}] status result
    if {$status == 0} {
      return [string tolower $result]
    } else {
      Msg Error "Something went wrong while finding the latest SHA. Does the repository have a commit?"
      exit 1
    }
  }

  # Get repository top level
  set repo_path [lindex [Git {rev-parse --show-toplevel}] 0]
  set paths {}
  # Retrieve the list of submodules in the repository
  foreach f $path {
    set file_in_module 0
    if {[file exists $repo_path/.gitmodules]} {
      lassign [GitRet "config --file $repo_path/.gitmodules --get-regexp path"] status result
      if {$status == 0} {
        set submodules [split $result "\n"]
      } else {
        set submodules ""
        Msg Warning "Something went wrong while trying to find submodules: $result"
      }

      foreach mod $submodules {
        set module [lindex $mod 1]
        if {[string first "$repo_path/$module" $f] == 0} {
          # File is in a submodule. Append
          set file_in_module 1
          lappend paths "$repo_path/$module"
          break
        }
      }

    }
    if {$file_in_module == 0} {
      #File is not in a submodule
      lappend paths $f
    }
  }

  lassign [GitRet {log --format=%h --abbrev=7 -1} $paths] status result
  if {$status == 0} {
    return [string tolower $result]
  } else {
    Msg Error "Something went wrong while finding the latest SHA. Does the repository have a commit?"
    exit 1
  }
  return [string tolower $result]
}

## @brief Returns the list of Simulators supported by Vivado
proc GetSimulators {} {
  set SIMULATORS [list "modelsim" "questa" "riviera" "activehdl" "ies" "vcs"]
  return $SIMULATORS
}

## @brief Return the path to the active top file
proc GetTopFile {} {
  if {[IsVivado]} {
    set compile_order_prop [get_property source_mgmt_mode [current_project]]
    if {$compile_order_prop ne "All"} {
      Msg CriticalWarning "Compile order is not set to automatic, setting it now..."
      set_property source_mgmt_mode All [current_project]
      update_compile_order -fileset sources_1
    }
    return [lindex [get_files -quiet -compile_order sources -used_in synthesis -filter {FILE_TYPE =~ "VHDL*" || FILE_TYPE =~ "*Verilog*" } ] end]
  } elseif {[IsISE]} {
    debug::design_graph_mgr -create [current_fileset]
    debug::design_graph -add_fileset [current_fileset]
    debug::design_graph -update_all
    return [lindex [debug::design_graph -get_compile_order] end]
  } else {
    Msg Error "GetTopFile not yet implemented for this IDE"
  }
}

## @brief Return the name of the active top module
proc GetTopModule {} {
  if {[IsXilinx]} {
    return [get_property top [current_fileset]]
  } else {
    Msg Error "GetTopModule not yet implemented for this IDE"
  }
}

## @brief Get git version and commit hash of a subset of files
#
# @param[in] path list file or path containing the subset of files whose latest commit hash will be returned
#
# @return  a list: the git SHA, the version in hex format
#
proc GetVer {path {force_develop 0}} {
  set SHA [GetSHA $path]
  #oldest tag containing SHA
  if {$SHA eq ""} {
    Msg CriticalWarning "Empty SHA found for ${path}. Commit to Git to resolve this warning."
  }
  set old_path [pwd]
  set p [lindex $path 0]
  if {[file isdirectory $p]} {
    cd $p
  } else {
    cd [file dirname $p]
  }
  set repo_path [Git {rev-parse --show-toplevel}]
  cd $old_path

  return [list [GetVerFromSHA $SHA $repo_path $force_develop] $SHA]
}

## @brief Get git version and commit hash of a specific commit give the SHA
#
# @param[in] SHA the git SHA of the commit
# @param[in] repo_path the path of the repository, this is used to open the Top/repo.conf file
# @param[in] force_develop Force a tag for the develop branch (increase m)
#
# @return  a list: the git SHA, the version in hex format
#
proc GetVerFromSHA {SHA repo_path {force_develop 0}} {
  if { $SHA eq ""} {
    Msg CriticalWarning "Empty SHA found"
    set ver "v0.0.0"
  } else {
    lassign [GitRet "tag --sort=creatordate --contain $SHA -l v*.*.* -l b*v*.*.*" ] status result

    if {$status == 0} {
      if {[regexp {^ *$} $result]} {
        # We do not want the most recent tag, we want the biggest value
        lassign [GitRet "log --oneline --pretty=\"%d\""] status2 tag_list
        #Msg Status "List of all tags including $SHA: $tag_list."
        #cleanup the list and get only the tags
        set pattern {tag: v\d+\.\d+\.\d+}
        set real_tag_list {}
        foreach x $tag_list {
        set x_untrimmed [regexp -all -inline $pattern $x]
        regsub "tag: " $x_untrimmed "" x_trimmed
        set tt [lindex $x_trimmed 0]
        if {![string equal $tt ""]} {
          lappend real_tag_list $tt
          #puts "<$tt>"
        }
        }
        Msg Debug "Cleaned up list: $real_tag_list."
        # Sort the tags in version order
        set sorted_tags [lsort -decreasing -command CompareVersions $real_tag_list]

        Msg Debug "Sorted Tag list: $sorted_tags"
        # Select the newest tag in terms of number, not time
        set tag [lindex $sorted_tags 0]

        # Msg Debug "Chosen Tag $tag"
        set pattern {v\d+\.\d+\.\d+}
          if {![regexp $pattern $tag]} {
            Msg CriticalWarning "No Hog version tags found in this repository."
            set ver v0.0.0
          } else {

          lassign [ExtractVersionFromTag $tag] M m p mr
          # Open repo.conf and check prefixes
          set repo_conf $repo_path/Top/repo.conf

          # Check if the develop/master scheme is used and where is the merge directed to
          # Default values
          set hotfix_prefix "hotfix/"
          set minor_prefix "minor_version/"
          set major_prefix "major_version/"
          set is_hotfix 0
          set enable_develop_branch $force_develop

          set branch_name [Git {rev-parse --abbrev-ref HEAD}]

          if {[file exists $repo_conf]} {
            set PROPERTIES [ReadConf $repo_conf]
            # [main] section
            if {[dict exists $PROPERTIES main]} {
              set mainDict [dict get $PROPERTIES main]

              # ENABLE_DEVELOP_ BRANCH property
              if {[dict exists $mainDict ENABLE_DEVELOP_BRANCH]} {
                set enable_develop_branch [dict get $mainDict ENABLE_DEVELOP_BRANCH]
              }
                # More properties in [main] here ...

            }

            # [prefixes] section
            if {[dict exists $PROPERTIES prefixes]} {
              set prefixDict [dict get $PROPERTIES prefixes]

              if {[dict exists $prefixDict HOTFIX]} {
                set hotfix_prefix [dict get $prefixDict HOTFIX]
              }
              if {[dict exists $prefixDict MINOR_VERSION]} {
                set minor_prefix [dict get $prefixDict MINOR_VERSION]
              }
              if {[dict exists $prefixDict MAJOR_VERSION]} {
                set major_prefix [dict get $prefixDict MAJOR_VERSION]
              }
              # More properties in [prefixes] here ...
            }
          }

          if {$enable_develop_branch == 1 } {
            if {[string match "$hotfix_prefix*" $branch_name]} {
              set is_hotfix 1
            }
          }

          if {[string match "$major_prefix*" $branch_name]} {
            # If major prefix is used, we increase M regardless of anything else
            set version_level major
          } elseif {[string match "$minor_prefix*" $branch_name] || ($enable_develop_branch == 1 && $is_hotfix == 0)} {
            # This is tricky. We increase m if the minor prefix is used or if we are in develop mode and this IS NOT a hotfix
            set version_level minor
          } else {
            # This is even trickier... We increase p if no prefix is used AND we are not in develop mode or if we are in develop mode this IS a Hotfix
            set version_level patch
          }

          #Let's keep this for a while, more bugs may come soon
          #Msg Info "******** $repo_path HF: $hotfix_prefix, M: $major_prefix, m: $minor_prefix, is_hotfix: $is_hotfix: VL: $version_level, BRANCH: $branch_name"


          if {$M == -1} {
            Msg CriticalWarning "Tag $tag does not contain a Hog compatible version in this repository."
            exit
            #set ver v0.0.0
          } elseif {$mr == 0} {
            #Msg Info "No tag contains $SHA, will use most recent tag $tag. As this is an official tag, patch will be incremented to $p."
            switch $version_level {
              minor {
                incr m
                set p 0
              }
              major {
                incr M
                set m 0
                set p 0
              }
              default {
                incr p
              }
            }

          } else {
            Msg Info "No tag contains $SHA, will use most recent tag $tag. As this is a candidate tag, the patch level will be kept at $p."
          }
          set ver v$M.$m.$p
        }
      } else {
        #The tag in $result contains the current SHA
        set vers [split $result "\n"]
        set ver [lindex $vers 0]
        foreach v $vers {
          if {[regexp {^v.*$} $v]} {
            set un_ver $ver
            set ver $v
            break
          }
        }
      }
    } else {
      Msg CriticalWarning "Error while trying to find tag for $SHA"
      set ver "v0.0.0"
    }
  }
  lassign [ExtractVersionFromTag $ver] M m c mr

  if {$mr > -1} {
    # Candidate tab
    set M [format %02X $M]
    set m [format %02X $m]
    set c [format %04X $c]

  } elseif { $M > -1 } {
    # official tag
    set M [format %02X $M]
    set m [format %02X $m]
    set c [format %04X $c]

  } else {
    Msg Warning "Tag does not contain a properly formatted version: $ver"
    set M [format %02X 0]
    set m [format %02X 0]
    set c [format %04X 0]
  }

  return $M$m$c
}

## @brief Handle git commands
#
#
#  @param[in] command: the git command to be run including refs (branch, tags, sha, etc.), except files.
#  @param[in] files: files given to git as argument. They will always be separated with -- to avoid weird accidents
#
#  @returns the output of the git command
proc Git {command {files ""}}  {
  lassign [GitRet $command $files] ret result
  if {$ret != 0} {
    Msg Error "Code $ret returned by git running: $command -- $files"
  }

  return $result
}


# @brief Get the name of the module in a HDL file. If module is not found, it returns an empty string
#
# @param[in] filename The name of the hdl file

proc GetModuleName {filename} {
  # Check if the file exists
  if {![file exists $filename]} {
    Msg CriticalWarning "Error: File $filename does not exist."
    return ""
  }

  # Open the file for reading
  set fileId [open $filename r]

  # Read the content of the file
  set file_content [read $fileId]

  # Close the file
  close $fileId


  if {[file extension $filename] == ".vhd" || [file extension $filename] == ".vhdl"} {
    # Convert the file content to lowercase for case-insensitive matching
    set file_content [string tolower $file_content]
    # Regular expression to match the entity name after the 'entity' keyword
    set pattern {(?m)^\s*entity\s+(\S+)\s+is}
  } elseif {[file extension $filename] == ".v" || [file extension $filename] == ".sv"} {
    # Regular expression to match the module name after the 'module' keyword
    set pattern {^\s*module\s+(\S+)}
  } else {
    Msg Debug "File is neither VHDL nor Verilog... Returning empty string..."
    return "'"
  }

  # Search for the module name using the regular expression
  if {[regexp $pattern $file_content match module_name]} {
    return $module_name
  } else {
    Msg Debug "No module was found in $filename. Returning an empty string..."
    return ""
  }
}

## Get a dictionary of verilog generics with their types for a given file
#
#  @param[in] file File to read Generics from
proc GetVerilogGenerics {file} {
  set fp [open $file r]
  set data [read $fp]
  close $fp
  set lines []

  # read in the verilog file and remove comments
  foreach line [split $data "\n"] {
    regsub "^\\s*\/\/.*" $line "" line
    regsub "(.*)\/\/.*" $line {\1} line
    if {![string equal $line ""]} {
      append lines $line " "
    }
  }

  # remove block comments also /* */
  regsub -all {/\*.*\*/} $lines "" lines

  # create a list of characters to split for tokenizing
  set punctuation [list]
  foreach char [list "(" ")" ";" "," " " "!" "<=" ":=" "=" "\[" "\]"] {
    lappend punctuation $char "\000$char\000"
  }

  # split the file into tokens
  set tokens [split [string map $punctuation $lines] \000]

  set parameters [dict create]

  set PARAM_NAME 1
  set PARAM_VALUE 2
  set LEXING 3
  set PARAM_WIDTH 4
  set state $LEXING

  # loop over the generic lines
  foreach token $tokens {
    set token [string trim $token]
    if {![string equal "" $token]} {
      if {[string equal [string tolower $token] "parameter"]} {
        set state $PARAM_NAME
      } elseif {[string equal $token ")"] || [string equal $token ";"]} {
        set state $LEXING
      } elseif {$state == $PARAM_WIDTH} {
        if {[string equal $token "\]"]} {
          set state $PARAM_NAME
        }
      } elseif {$state == $PARAM_VALUE} {
        if {[string equal $token ","]} {
          set state $PARAM_NAME
        } elseif {[string equal $token ";"]} {
          set state $LEXING
        } else {
        }
      } elseif {$state == $PARAM_NAME} {

        if {[string equal $token "="]} {
          set state $PARAM_VALUE
        } elseif {[string equal $token "\["]} {
          set state $PARAM_WIDTH
        } elseif {[string equal $token ","]} {
          set state $PARAM_NAME
        } elseif {[string equal $token ";"]} {
          set state $LEXING
        } elseif {[string equal $token ")"]} {
          set state $LEXING
        } else {
          dict set parameters $token "integer"
        }
      }
    }
  }

  return $parameters
}

## Get a dictionary of VHDL generics with their types for a given file
#
#  @param[in] file File to read Generics from
#  @param[in] entity The entity from which extracting the generics
proc GetVhdlGenerics {file {entity ""} } {
  set fp [open $file r]
  set data [read $fp]
  close $fp
  set lines []

    # read in the vhdl file and remove comments
  foreach line [split $data "\n"] {
    regsub "^\\s*--.*" $line "" line
    regsub "(.*)--.*" $line {\1} line
    if {![string equal $line ""]} {
      append lines $line " "
    }
  }

  # extract the generic block
  set generic_block ""
  set generics [dict create]

  if {1==[string equal $entity ""]} {
    regexp {(?i).*entity\s+([^\s]+)\s+is} $lines _ entity
  }

  set generics_regexp "(?i).*entity\\s+$entity\\s+is\\s+generic\\s*\\((.*)\\)\\s*;\\s*port.*end.*$entity"

  if {[regexp $generics_regexp $lines _ generic_block]} {
    # loop over the generic lines
    foreach line [split $generic_block ";"]  {
      # split the line into the generic + the type
      regexp {(.*):\s*([A-Za-z0-9_]+).*} $line _ generic type

      # one line can have multiple generics of the same type, so loop over them
      set splits [split $generic ","]
      foreach split $splits {
        dict set generics [string trim $split] [string trim $type]
      }
    }
  }
  return $generics
}

## @brief Handle git commands without causing an error if ret is not 0
#
# It can be used with lassign like this: lassign [GitRet \<git command\> \<possibly files\> ] ret result
#
#  @param[in] command: the git command to be run including refs (branch, tags, sha, etc.), except files.
#  @param[in] files: files given to git as argument. They will always be separated with -- to avoid weird accidents
# Sometimes you need to remove the --. To do that just set files to " "
#
#  @returns a list of 2 elements: the return value (0 if no error occurred) and the output of the git command
proc GitRet {command {files ""}}  {
  global env
  if {$files eq ""} {
    set ret [catch {exec -ignorestderr git {*}$command} result]
  } else {
    set ret [catch {exec -ignorestderr git {*}$command -- {*}$files} result]
  }


  return [list $ret $result]
}

## @brief Check git version installed in this machine
#
# @param[in] target_version the version required by the current project
#
# @return Returns 1, if the system git version is greater or equal to the target
proc GitVersion {target_version} {
  set ver [split $target_version "."]
  set v [Git --version]
  #Msg Info "Found Git version: $v"
  set current_ver [split [lindex $v 2] "."]
  set target [expr {[lindex $ver 0]*100000 + [lindex $ver 1]*100 + [lindex $ver 2]}]
  set current [expr {[lindex $current_ver 0]*100000 + [lindex $current_ver 1]*100 + [lindex $current_ver 2]}]
  return [expr {$target <= $current}]
}

## @brief Copy IP generated files from/to a remote o local directory (possibly EOS)
#
# @param[in] what_to_do: can be "push", if you want to copy the local IP synth result to the remote directory or "pull" if you want to copy the files from thre remote directory to your local repository
# @param[in] xci_file: the .xci file of the IP you want to handle
# @param[in] ip_path: the path of the directory you want the IP to be saved (possibly EOS)
# @param[in] repo_path: the main path of your repository
# @param[in] gen_dir: the directory where generated files are placed, by default the files are placed in the same folder as the .xci
# @param[in] force: if not set to 0, will copy the IP to the remote directory even if it is already present
#
proc HandleIP {what_to_do xci_file ip_path repo_path {gen_dir "."} {force 0}} {
  if {!($what_to_do eq "push") && !($what_to_do eq "pull")} {
    Msg Error "You must specify push or pull as first argument."
  }

  if { [catch {package require tar} TARPACKAGE]} {
    Msg CriticalWarning "Cannot find package tar. You can fix this by installing package \"tcllib\""
    return -1
  }

  set old_path [pwd]

  cd $repo_path


  if {[string first "/eos/" $ip_path] == 0} {
    # IP Path is on EOS
    set on_eos 1
  } else {
    set on_eos 0
  }

  if {$on_eos == 1} {
    lassign [eos  "ls $ip_path"] ret result
    if  {$ret != 0} {
      Msg CriticalWarning "Could not run ls for for EOS path: $ip_path (error: $result). Either the drectory does not exist or there are (temporary) problem with EOS."
      cd $old_path
      return -1
    } else {
      Msg Info "IP remote directory path, on EOS, is set to: $ip_path"
    }

  } else {
    file mkdir $ip_path
  }

  if {!([file exists $xci_file])} {
    Msg CriticalWarning "Could not find $xci_file."
    cd $old_path
    return -1
  }


  set xci_path [file dirname $xci_file]
  set xci_name [file tail $xci_file]
  set xci_ip_name [file rootname [file tail $xci_file]]
  set xci_dir_name [file tail $xci_path]
  set gen_path $gen_dir

  set hash [Md5Sum $xci_file]
  set file_name $xci_name\_$hash

  Msg Info "Preparing to $what_to_do IP: $xci_name..."

  if {$what_to_do eq "push"} {
    set will_copy 0
    set will_remove 0
    if {$on_eos == 1} {
      lassign [eos "ls $ip_path/$file_name.tar"] ret result
      if {$ret != 0} {
        set will_copy 1
      } else {
        if {$force == 0 } {
          Msg Info "IP already in the EOS repository, will not copy..."
        } else {
          Msg Info "IP already in the EOS repository, will forcefully replace..."
          set will_copy 1
          set will_remove 1
        }
      }
    } else {
      if {[file exists "$ip_path/$file_name.tar"]} {
        if {$force == 0 } {
          Msg Info "IP already in the local repository, will not copy..."
        } else {
          Msg Info "IP already in the local repository, will forcefully replace..."
          set will_copy 1
          set will_remove 1
        }
      } else {
        set will_copy 1
      }
    }

    if {$will_copy == 1} {
      # Check if there are files in the .gen directory first and copy them into the right place
      Msg Info "Looking for generated files in $gen_path..."
      set ip_gen_files [glob -nocomplain $gen_path/*]

      #here we should remove the .xci file from the list if it's there

      if {[llength $ip_gen_files] > 0} {
        Msg Info "Found some IP synthesised files matching $xci_ip_name"
        if {$will_remove == 1} {
          Msg Info "Removing old synthesised directory $ip_path/$file_name.tar..."
          if {$on_eos == 1} {
            eos "rm -rf $ip_path/$file_name.tar" 5
          } else {
            file delete -force "$ip_path/$file_name.tar"
          }
        }

        Msg Info "Creating local archive with IP generated files..."
        set first_file 0
        foreach f $ip_gen_files {
          if {$first_file == 0} {
            ::tar::create $file_name.tar "[Relative [file normalize $repo_path] $f]"
            set first_file 1
          } else {
            ::tar::add $file_name.tar "[Relative [file normalize $repo_path] $f]"
          }
        }

        Msg Info "Copying IP generated files for $xci_name..."
        if {$on_eos == 1} {
          lassign [ExecuteRet xrdcp -f -s $file_name.tar  $::env(EOS_MGM_URL)//$ip_path/] ret msg
          if {$ret != 0} {
            Msg CriticalWarning "Something went wrong when copying the IP files to EOS. Error message: $msg"
          }
        } else {
          Copy "$file_name.tar" "$ip_path/"
        }
        Msg Info "Removing local archive"
        file delete $file_name.tar

      } else {
        Msg Warning "Could not find synthesized files matching $gen_path/$file_name*"
      }
    }
  } elseif {$what_to_do eq "pull"} {
    if {$on_eos == 1} {
      lassign [eos "ls $ip_path/$file_name.tar"] ret result
      if  {$ret != 0} {
        Msg Info "Nothing for $xci_name was found in the EOS repository, cannot pull."
        cd $old_path
        return -1

      } else {
        set remote_tar "$::env(EOS_MGM_URL)//$ip_path/$file_name.tar"
        Msg Info "IP $xci_name found in the repository $remote_tar, copying it locally to $repo_path..."

        lassign [ExecuteRet xrdcp -f -r -s $remote_tar $repo_path] ret msg
        if {$ret != 0} {
          Msg CriticalWarning "Something went wrong when copying the IP files to EOS. Error message: $msg"
        }
      }
    } else {
      if {[file exists "$ip_path/$file_name.tar"]} {
        Msg Info "IP $xci_name found in local repository $ip_path/$file_name.tar, copying it locally to $repo_path..."
        Copy $ip_path/$file_name.tar $repo_path

      } else {
        Msg Info "Nothing for $xci_name was found in the local IP repository, cannot pull."
        cd $old_path
        return -1
      }

    }

    if {[file exists $file_name.tar]} {
      remove_files $xci_file
      Msg Info "Extracting IP files from archive to $repo_path..."
      ::tar::untar $file_name.tar -dir $repo_path -noperms
      Msg Info "Removing local archive"
      file delete $file_name.tar
      add_files -norecurse -fileset sources_1 $xci_file
    }
  }
  cd $old_path
  return 0
}

## Convert hex version to M.m.p string
#
#  @param[in] version the version (in 32-bit hexadecimal format 0xMMmmpppp) to be converted
#
#  @return            a string containing the version in M.m.p format
#
proc HexVersionToString {version} {
  scan [string range $version 0 1] %x M
  scan [string range $version 2 3] %x m
  scan [string range $version 4 7] %x c
  return "$M.$m.$c"
}

# @brief Import TCL Lib from an external installation for Libero, Synplify and Diamond
proc ImportTclLib {} {
  if {[IsLibero] || [IsDiamond] || [IsSynplify]} {
    if {[info exists env(HOG_TCLLIB_PATH)]} {
      lappend auto_path $env(HOG_TCLLIB_PATH)
      return 1
    } else {
      puts "ERROR: To run Hog with Microsemi Libero SoC or Lattice Diamond, you need to define the HOG_TCLLIB_PATH variable."
      return 0
    }
  }
}

# @brief Initialise the Launcher and returns a list of project parameters: directive project project_name group_name repo_path old_path bin_dir top_path commands_path cmd ide
#
# @param[in] script     The launch.tcl script
# @param[in] tcl_path   The launch.tcl script path
# @param[in] parameters The allowed parameters for launch.tcl
# @param[in] usage      The usage snippet for launch.tcl
# @param[in] argv       The input arguments passed to launch.tcl
proc InitLauncher {script tcl_path parameters usage argv} {
  set repo_path [file normalize "$tcl_path/../.."]
  set old_path [pwd]
  set bin_path [file normalize "$tcl_path/../../bin"]
  set top_path [file normalize "$tcl_path/../../Top"]
  set commands_path [file normalize "$tcl_path/../../hog-commands/"]

  if {[IsTclsh]} {
    #Just display the logo the first time, not when the scripot is run in the IDE
    Logo $repo_path
  }

  if {[catch {package require cmdline} ERROR]} {
    Msg Debug "The cmdline Tcl package was not found, sourcing it from Hog..."
    source $tcl_path/utils/cmdline.tcl
  }

  append usage [GetCustomCommands $commands_path]
  append usage "\n** Options:"

  lassign [GetOptions $argv $parameters] option_list arg_list

  if { [IsInList "-help" $option_list] || [IsInList "-?" $option_list] || [IsInList "-h" $option_list] } {
    Msg Info [cmdline::usage $parameters $usage]
    exit 0
  }

  if { [IsInList "-all" $option_list] } {
    set list_all 1
  } else {
    set list_all 2
  }

  #option_list will be emptied by the next instruction
  if {[catch {array set options [cmdline::getoptions option_list $parameters $usage]} err] } {
    Msg Status "\nERROR: Syntax error, probably unknown option.\n\n USAGE: $err"
    exit 1
  }
  # Argv here is modified and the options are removed
  set directive [string toupper [lindex $arg_list 0]]

  if { [llength $arg_list] == 1 && ($directive == "L" || $directive == "LIST")} {

    Msg Status "\n** The projects in this repository are:"
    ListProjects $repo_path $list_all
    Msg Status "\n"
    exit 0

  } elseif { [llength $arg_list] == 0 || [llength $arg_list] > 2} {
    Msg Status "\nERROR: Wrong number of arguments: [llength $argv].\n\n"
    Msg Status "USAGE: [cmdline::usage $parameters $usage]"
    exit 1
  }

  set project  [lindex $arg_list 1]
  # Remove leading Top/ or ./Top/ if in project_name
  regsub "^(\./)?Top/" $project "" project
  # Remove trailing / and spaces if in project_name
  regsub "/? *\$" $project "" project
  set proj_conf [ProjectExists $project $repo_path]

  Msg Debug "Option list:"
  foreach {key value} [array get options] {
    Msg Debug "$key => $value"
  }

  set cmd ""

  if {[IsTclsh]} {
    # command is filled with the IDE exectuable when this function is called by Tcl scrpt
    if {$proj_conf != 0} {
      CheckLatestHogRelease $repo_path

      lassign [GetIDECommand $proj_conf] cmd before_tcl_script after_tcl_script end_marker
      Msg Info "Project $project uses $cmd IDE"

      ## The following is the IDE command to launch:
      set command "$cmd $before_tcl_script$script$after_tcl_script$argv$end_marker"

    } else {
      if {$project != ""} {
        #Project not given
        set command -1
      } else {
        #Project not found
        set command -2
      }
    }
  } else {
    # When the launcher is executed from within an IDE, command is set to 0
    set command 0
  }

  set project_group [file dirname $project]
  set project [file tail $project]
  if { $project_group != "." } {
    set project_name "$project_group/$project"
  } else {
    set project_name "$project"
  }

  if { $options(generate) == 1 } {
    set xml_gen 1
  } else {
    set xml_gen 0
  }

  if { $options(xml_dir) != "" } {
    set xml_dst $options(xml_dir)
  } else {
    set xml_dst ""
  }

  return [list $directive $project $project_name $project_group $repo_path $old_path $bin_path $top_path $commands_path $command $cmd [array get options]]
}

# @brief Returns 1 if a commit is an ancestor of another, otherwise 0
#
# @param[in] ancestor The potential ancestor commit
# @param[in] commit   The potential descendant commit
proc IsCommitAncestor {ancestor commit} {
  lassign [GitRet "merge-base --is-ancestor $ancestor $commit"] status result
  if {$status == 0 } {
    return 1
  } else {
    return 0
  }
}

proc IsDiamond {} {
  return [expr {[info commands sys_install] != ""}]
}

## @brief Returns true if the IDE is MicroSemi Libero
proc IsLibero {} {
  return [expr {[info commands get_libero_version] != ""}]
}

# @brief Returns 1 if an element is a list, 0 otherwise
#
# @param[in] element The element to search
# @param[in] list    The list to search into
# @param[in] regex   An optional regex to match. If 0, the element should match exactly an object in the list
proc IsInList {element list {regex 0}} {
  foreach x $list {
    if {$regex == 1 &&  [regexp $x $element] } {
      return 1
    } elseif { $regex == 0 && $x eq $element } {
      return 1
    }
  }
  return 0
}


## @brief Returns true, if the IDE is ISE/PlanAhead
proc IsISE {} {
  if {[IsXilinx]} {
    return [expr {[string first PlanAhead [version]] == 0}]
  } else {
    return 0
  }
}

## @brief Returns true, if IDE is Quartus
proc IsQuartus {} {
  return [expr {[info commands project_new] != ""}]
}

## Check if a path is absolute or relative
#
#  @param[in]    the path to check
#
proc IsRelativePath {path} {
  if {[string index $path 0] == "/" || [string index $path 0] == "~"} {
    return 0
  } else {
    return 1
  }
}

## @brief Returns true if the Synthesis tool is Synplify
proc IsSynplify {} {
  return [expr {[info commands program_version] != ""}]
}

## @brief Returns true, if we are in tclsh
proc IsTclsh {} {
  return [expr {![IsQuartus] && ![IsXilinx] && ![IsLibero] && ![IsSynplify] && ![IsDiamond]}]
}

## @brief Find out if the given Xilinx part is a Vesal chip
#
# @param[out] 1 if it's Versal 0 if it's not
# @param[in]  part  The FPGA part
#
proc IsVersal {part} {
  if { [regexp {^(xcvp|xcvm|xcve|xcvc|xqvc|xqvm).*} $part] } {
    return 1
  } else {
    return 0
  }
}

## @brief Returns true, if the IDE is Vivado
proc IsVivado {} {
  if {[IsXilinx]} {
    return [expr {[string first Vivado [version]] == 0}]
  } else {
    return 0
  }
}

## @brief Return true, if the IDE is Xilinx (Vivado or ISE)
proc IsXilinx {} {
  return [expr {[info commands get_property] != ""}]
}

## @brief Find out if the given Xilinx part is a Vesal chip
#
# @param[out] 1 if it's Zynq 0 if it's not
# @param[in]  part  The FPGA part
#
proc IsZynq {part} {
  if { [regexp {^(xc7z|xczu).*} $part] } {
    return 1
  } else {
    return 0
  }
}

# @brief Launch the Implementation, for the current IDE and project
#
# @param[in] reset        Reset the Implementation run
# @param[in] do_create    Recreate the project
# @param[in] run_folder   The folder where to store the run results
# @param[in] project_name The name of the project
# @param[in] repo_path    The main path of the git repository (Default .)
# @param[in] njobs        The number of parallel CPU jobs for the Implementation (Default 4)
proc LaunchImplementation {reset do_create run_folder project_name {repo_path .} {njobs 4} {do_bitstream 0}} {
  Msg Info "Starting implementation flow..."
  if {[IsXilinx]} {
    if { $reset == 1 && $do_create == 0} {
      Msg Info "Resetting run before launching implementation..."
      reset_run impl_1
    }

    if {[IsISE]} {
      source $repo_path/Hog/Tcl/integrated/pre-implementation.tcl
    }

    if {[IsVivado] && $do_bitstream == 1} {
      launch_runs impl_1 -to_step [BinaryStepName [get_property PART [current_project]]] $njobs -dir $run_folder
    } else {
      launch_runs impl_1 -jobs $njobs -dir $run_folder
    }
    wait_on_run impl_1

    if {[IsISE]} {
      source $repo_path/Hog/Tcl/integrated/post-implementation.tcl
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
        if { [string match "Timing summary:" $line] } {
          while {[gets $f line] >= 0} {
            if { [string match "Timing errors:*" $line] } {
              set errs [regexp -inline -- {[0-9]+} $line]
            }
            if { [string match "*Footnotes*" $line ] } {
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

      m add row  "| **Parameter** | \"**value (ns)**\" |"
      m add row  "| --- | --- |"
      m add row  "|  WNS:  |  $wns  |"
      m add row  "|  TNS:  |  $tns  |"
      m add row  "|  WHS:  |  $whs  |"
      m add row  "|  THS:  |  $ths  |"
      m add row  "|  TPWS: |  $tpws  |"

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
    lassign [GetRepoVersions [file normalize ./Top/$project_name] $repo_path] sha
    set describe [GetHogDescribe $sha $repo_path]
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
    set timing_files [ glob -nocomplain "$run_folder/timing_*.txt" ]
    set timing_file [file normalize [lindex $timing_files 0]]

    if {[file exists $timing_file]} {
      file copy -force $timing_file $dst_dir/
    } else {
      Msg Warning "No timing file found, not a problem if running locally"
    }

  } elseif {[IsQuartus]} {
    set revision [get_current_revision]

    if {[catch {execute_module -tool fit} result]} {
      Msg Error "Result: $result\n"
      Msg Error "Place & Route failed. See the report file.\n"
    } else {
      Msg Info "\nINFO: Place & Route was successful for revision $revision.\n"
    }

    if {[catch {execute_module -tool sta -args "--do_report_timing"} result]} {
      Msg Error "Result: $result\n"
      Msg Error "Time Quest failed. See the report file.\n"
    } else {
      Msg Info "Time Quest was successfully run for revision $revision.\n"
      load_package report
      load_report
      set panel "Timing Analyzer||Timing Analyzer Summary"
      set device       [ get_report_panel_data -name $panel -col 1 -row_name "Device Name" ]
      set timing_model [ get_report_panel_data -name $panel -col 1 -row_name "Timing Models" ]
      set delay_model  [ get_report_panel_data -name $panel -col 1 -row_name "Delay Model" ]
      #set slack        [ get_timing_analysis_summary_results -slack ]
      Msg Info "*******************************************************************"
      Msg Info "Device: $device"
      Msg Info "Timing Models: $timing_model"
      Msg Info "Delay Model: $delay_model"
      Msg Info "Slack:"
      #Msg Info  $slack
      Msg Info "*******************************************************************"
    }
  } elseif {[IsLibero]} {
      Msg Info "Starting implementation flow..."
    if {[catch {run_tool -name {PLACEROUTE}  }] } {
      Msg Error "PLACEROUTE FAILED!"
    } else {
      Msg Info "PLACEROUTE PASSED."
    }

    # Check timing
    Msg Info "Run VERIFYTIMING ..."
    if {[catch {run_tool -name {VERIFYTIMING} -script {Hog/Tcl/integrated/libero_timing.tcl} }] } {
      Msg CriticalWarning "VERIFYTIMING FAILED!"
    } else {
      Msg Info "VERIFYTIMING PASSED \n"
    }

    #Go to repository path
    cd $repo_path

    lassign [GetRepoVersions [file normalize ./Top/$project_name] $repo_path] sha
    set describe [GetHogDescribe $sha $repo_path]
    Msg Info "Git describe set to $describe"

    set dst_dir [file normalize "$repo_path/bin/$project_name\-$describe"]
    file mkdir $dst_dir/reports

    #Version table
    if {[file exists $run_folder/versions.txt]} {
      file copy -force $run_folder/versions.txt $dst_dir
    } else {
      Msg Warning "No versions file found in $run_folder/versions.txt"
    }
    #Timing file
    set timing_file_path [file normalize "$repo_path/Projects/timing_libero.txt"]
    if {[file exists $timing_file_path]} {
      file copy -force $timing_file_path $dst_dir/reports/Timing.txt
      set timing_file [open $timing_file_path "r"]
      set status_file [open "$dst_dir/timing.txt" "w"]
      puts $status_file "## $project_name Timing summary\n\n"
      puts $status_file "|  |  |"
      puts $status_file "| --- | --- |"
      while {[gets $timing_file line] >= 0} {
        if { [string match "SUMMARY" $line] } {
          while {[gets $timing_file line] >= 0} {
            if { [string match "END SUMMARY" $line ] } {
              break
            }
            if {[string first ":" $line] == -1} {
              continue
            }
            set out_string "| [string map {: | } $line] |"
            puts $status_file "$out_string"
          }
        }
      }
    } else {
      Msg Warning "No timing file found, not a problem if running locally"
    }
  } elseif {[IsDiamond]} {
    set force_rst ""
    if {$reset == 1} {
      set force_rst "-forceOne"
    }
    prj_run Map $force_rst
    prj_run PAR $force_rst

    # TODO: Check Timing for Diamond
  }
}


# @brief Launch the simulation (Vivado only for the moment)
#
# @param[in] project_name The name of the project
# @param[in] lib_path     The path to the simulation libraries
# @param[in] simsets      The simulation sets to simulate
# @param[in] repo_path    The main path of the git repository
proc LaunchSimulation {project_name lib_path {simsets ""} {repo_path .}} {
  if {[IsVivado]} {
    ##################### SIMULATION #######################
    set project [file tail $project_name]
    set main_sim_folder [file normalize "$repo_path/Projects/$project_name/$project.sim/"]
    set simsets_todo ""
    if {$simsets != ""} {
      set simsets_todo [split $simsets ","]
      Msg Info "Will run only the following simsets (if they exist): $simsets_todo"
    }

    set failed []
    set success []
    set sim_dic [dict create]
    # Default behaviour, dont use simpass string
    set use_simpass_str 0

    # Get simulation properties from conf file
    set proj_dir [file normalize $repo_path/Top/$project_name]
    set sim_file [file normalize $proj_dir/sim.conf]
    if {[file exists $sim_file]} {
      Msg Info "Parsing simulation configuration file $sim_file..."
      SetGlobalVar SIM_PROPERTIES [ReadConf $sim_file]
    } else {
      SetGlobalVar SIM_PROPERTIES ""
    }

    # Get Hog specific simulation properties
    if {[dict exists $globalSettings::SIM_PROPERTIES hog]} {
      set hog_sim_props [dict get $globalSettings::SIM_PROPERTIES hog]
      dict for {prop_name prop_val} $hog_sim_props {
        # If HOG_SIMPASS_STR is set, use the HOG_SIMPASS_STR string to search for in logs, after simulation is done
        if { $prop_name == "HOG_SIMPASS_STR" && $prop_val != "" } {
          Msg Info "Setting simulation pass string as '$prop_val'"
          set use_simpass_str 1
          set simpass_str $prop_val
        }
      }
    }

    Msg Info "Retrieving list of simulation sets..."
    foreach s [get_filesets] {
      set type [get_property FILESET_TYPE $s]
      if {$type eq "SimulationSrcs"} {
        if {$simsets_todo != "" && $s ni $simsets_todo} {
          Msg Info "Skipping $s as it was not specified with the -simset option..."
          continue
        }
        if {[file exists "$repo_path/Top/$project_name/list/$s.sim"]} {
          set fp [open "$repo_path/Top/$project_name/list/$s.sim" r]
          set file_data [read $fp]
          close $fp
          set data [split $file_data "\n"]
          set n [llength $data]
          Msg Info "$n lines read from $s.sim"

          set firstline [lindex $data 0]
          # Find simulator
          if { [regexp {^ *\#Simulator} $firstline] } {
            set simulator_prop [regexp -all -inline {\S+} $firstline]
            set simulator [string tolower [lindex $simulator_prop 1]]
          } else {
            Msg Warning "Simulator not set in $s.sim. The first line of $s.sim should be #Simulator <SIMULATOR_NAME>, where <SIMULATOR_NAME> can be xsim, questa, modelsim, riviera, activehdl, ies, or vcs, e.g. #Simulator questa. Setting simulator by default as xsim."
            set simulator "xsim"
          }
          if {$simulator eq "skip_simulation"} {
            Msg Info "Skipping simulation for $s"
            continue
          }
          set_property "target_simulator" $simulator [current_project]
          Msg Info "Creating simulation scripts for $s..."
          if { [file exists $repo_path/Top/$project_name/pre-simulation.tcl] } {
            Msg Info "Running $repo_path/Top/$project_name/pre-simulation.tcl"
            source $repo_path/Top/$project_name/pre-simulation.tcl
          }
          if { [file exists $repo_path/Top/$project_name/pre-$s-simulation.tcl] } {
            Msg Info "Running $repo_path/Top/$project_name/pre-$s-simulation.tcl"
            source Running $repo_path/Top/$project_name/pre-$s-simulation.tcl
          }
          current_fileset -simset $s
          set sim_dir $main_sim_folder/$s/behav
          set sim_output_logfile $sim_dir/xsim/simulate.log
          if { ([string tolower $simulator] eq "xsim") } {
            set sim_name "xsim:$s"
            if { [catch { launch_simulation -simset [get_filesets $s] } log] } {
              # Explicitly close xsim simulation, without closing Vivado
              close_sim
              Msg CriticalWarning "Simulation failed for $s, error info: $::errorInfo"
              lappend failed $sim_name
            } else {
              # Explicitly close xsim simulation, without closing Vivado
              close_sim
              # If we use simpass_str, search for the string and update return code from simulation if the string is not found in simulation log
              if {$use_simpass_str == 1} {
                # Get the simulation output log
                # Note, xsim should always output simulation.log, hence no check for existence
                set file_desc [open $sim_output_logfile r]
                set log [read $file_desc]
                close $file_desc

                Msg Info "Searching for simulation pass string: '$simpass_str'"
                if {[string first $simpass_str $log] == -1} {
                  Msg CriticalWarning "Simulation failed for $s, error info: '$simpass_str' NOT found!"
                  lappend failed $sim_name
                } else {
                  # HOG_SIMPASS_STR found, success
                  lappend success $sim_name
                }
              } else { #Rely on simulator exit code
                lappend success $sim_name
              }
            }
          } else {
            Msg Info "Simulation library path is set to $lib_path."
            set simlib_ok 1
            if {!([file exists $lib_path])} {
              Msg Warning "Could not find simulation library path: $lib_path, $simulator simulation will not work."
              set simlib_ok 0
            }

            if {$simlib_ok == 1} {
              set_property "compxlib.${simulator}_compiled_library_dir" [file normalize $lib_path] [current_project]
              launch_simulation -scripts_only -simset [get_filesets $s]
              set top_name [get_property TOP $s]
              set sim_script  [file normalize $sim_dir/$simulator/]
              Msg Info "Adding simulation script location $sim_script for $s..."
              lappend sim_scripts $sim_script
              dict append sim_dic $sim_script $s
            } else {
              Msg Error "Cannot run $simulator simulations without a valid library path"
              exit -1
            }
          }
        }
      }
    }

    if {[info exists sim_scripts]} {
      # Only for modelsim/questasim
      Msg Info "Generating IP simulation targets, if any..."

      foreach ip [get_ips] {
        generate_target simulation -quiet $ip
      }


      Msg Status "\n\n"
      Msg Info "====== Starting simulations runs ======"
      Msg Status "\n\n"

      foreach s $sim_scripts {
        cd $s
        set cmd ./compile.sh
        Msg Info " ************* Compiling: $s  ************* "
        lassign [ExecuteRet $cmd] ret log
        set sim_name "comp:[dict get $sim_dic $s]"
        if {$ret != 0} {
          Msg CriticalWarning "Compilation failed for $s, error info: $::errorInfo"
          lappend failed $sim_name
        } else {
          lappend success $sim_name
        }
        Msg Info "###################### Compilation log starts ######################"
        Msg Info "\n\n$log\n\n"
        Msg Info "######################  Compilation log ends  ######################"


        if { [file exists "./elaborate.sh"] } {
          set cmd ./elaborate.sh
          Msg Info " ************* Elaborating: $s  ************* "
          lassign [ExecuteRet $cmd] ret log
          set sim_name "elab:[dict get $sim_dic $s]"
          if {$ret != 0} {
            Msg CriticalWarning "Elaboration failed for $s, error info: $::errorInfo"
            lappend failed $sim_name
          } else {
            lappend success $sim_name
          }
          Msg Info "###################### Elaboration log starts ######################"
          Msg Info "\n\n$log\n\n"
          Msg Info "######################  Elaboration log ends  ######################"
        }
        set cmd ./simulate.sh
        Msg Info " ************* Simulating: $s  ************* "
        lassign [ExecuteRet $cmd] ret log


        # If SIMPASS_STR is set, search log for the string
        if {$use_simpass_str == 1} {
          if {[string first $simpass_str $log] == -1} {
            set ret 1
          }
        } else {
          Msg Debug "Simulation pass string not set, relying on simulator exit code."
        }



        set sim_name "sim:[dict get $sim_dic $s]"
        if {$ret != 0} {
          Msg CriticalWarning "Simulation failed for $s, error info: $::errorInfo"
          lappend failed $sim_name
        } else {
          lappend success $sim_name
        }
        Msg Info "###################### Simulation log starts ######################"
        Msg Info "\n\n$log\n\n"
        Msg Info "######################  Simulation log ends  ######################"

      }
    }


    if {[llength $success] > 0} {
      set successes [join $success "\n"]
      Msg Info "The following simulation sets were successful:\n\n$successes\n\n"
    }

    if {[llength $failed] > 0} {
      set failures [join $failed "\n"]
      Msg Error "The following simulation sets have failed:\n\n$failures\n\n"
      exit -1
    } elseif {[llength $success] > 0} {
      Msg Info "All the [llength $success] compilations, elaborations and simulations were successful."
    }

    Msg Info "Simulation done."
  } else {
    Msg Warning "Simulation is not yet supported for [GetIDEName]."
  }
}

# @brief Launch the synthesis, for the current IDE and project
#
# @param[in] reset        Reset the Synthesis run
# @param[in] do_create    Recreate the project
# @param[in] run_folder   The folder where to store the run results
# @param[in] project_name The name of the project
# @param[in] repo_path    The main path of the git repository (Default .)
# @param[in] ext_path     The path of source files external to the git repo (Default "")
# @param[in] njobs        The number of parallel CPU jobs for the synthesis (Default 4)
proc LaunchSynthesis {reset do_create run_folder project_name {repo_path .} {ext_path ""} {njobs 4}} {
  if {[IsXilinx]} {
    if {$reset == 1 && $do_create == 0} {
      Msg Info "Resetting run before launching synthesis..."
      reset_run synth_1
    }
    if {[IsISE]} {
      source $repo_path/Hog/Tcl/integrated/pre-synthesis.tcl
    }
    launch_runs synth_1  -jobs $njobs -dir $run_folder
    wait_on_run synth_1
    set prog [get_property PROGRESS [get_runs synth_1]]
    set status [get_property STATUS [get_runs synth_1]]
    Msg Info "Run: synth_1 progress: $prog, status : $status"
    # Copy IP reports in bin/
    set ips [get_ips *]

    #go to repository path
    cd $repo_path

    lassign [GetRepoVersions [file normalize ./Top/$project_name] $repo_path $ext_path ] sha
    set describe [GetHogDescribe $sha $repo_path]
    Msg Info "Git describe set to $describe"

    foreach ip $ips {
      set xci_file [get_property IP_FILE $ip]

      set xci_path [file dirname $xci_file]
      set xci_ip_name [file rootname [file tail $xci_file]]
      foreach rptfile [glob -nocomplain -directory $xci_path *.rpt] {
        file copy $rptfile $repo_path/bin/$project_name-$describe/reports
      }

      # Let's leave the following commented part
      # We moved the Handle ip to the post-synthesis, in that case we can't use get_runs so to find out which IP was run, we loop over the directories enedind with _synth_1 in the .runs directory
      #
      #    ######### Copy IP to IP repository
      #    if {[IsVivado]} {
      #     set gen_path [get_property IP_OUTPUT_DIR $ip]
      #     if {($ip_path != "")} {
      #       # IP is not in the gitlab repo
      #       set force 0
      #       if [info exist runs] {
      #         if {[lsearch $runs $ip\_synth_1] != -1} {
      #           Msg Info "$ip was synthesized, will force the copy to the IP repository..."
      #           set force 1
      #         }
      #       }
      #       Msg Info "Copying synthesised IP $xci_ip_name ($xci_file) to $ip_path..."
      #       HandleIP push $xci_file $ip_path $repo_path $gen_path $force
      #     }
      #    }
    }

    if {$prog ne "100%"} {
      Msg Error "Synthesis error, status is: $status"
    }
  } elseif {[IsQuartus]} {
    # TODO: Missing reset
    set project [file tail [file rootname $project_name]]

    Msg Info "Number of jobs set to $njobs."
    set_global_assignment -name NUM_PARALLEL_PROCESSORS $njobs


    # keep track of the current revision and of the top level entity name
    lassign [GetRepoVersions [file normalize $repo_path/Top/$project_name] $repo_path ] sha
    set describe [GetHogDescribe $sha $repo_path]
    #set top_level_name [ get_global_assignment -name TOP_LEVEL_ENTITY ]
    set revision [get_current_revision]

    #run PRE_FLOW_SCRIPT by hand
    set tool_and_command [ split [get_global_assignment -name PRE_FLOW_SCRIPT_FILE] ":"]
    set tool [lindex $tool_and_command 0]
    set pre_flow_script [lindex $tool_and_command 1]
    set cmd "$tool -t $pre_flow_script quartus_map $project $revision"
    #Close project to avoid conflict with pre synthesis script
    project_close

    lassign [ExecuteRet {*}$cmd ] ret log
    if {$ret != 0} {
      Msg Warning "Can not execute command $cmd"
      Msg Warning "LOG: $log"
    } else {
      Msg Info "Pre flow script executed!"
    }

    # Re-open project
    if { ![is_project_open ] } {
      Msg Info "Re-opening project file $project_name..."
      project_open $project -current_revision
    }

    # Execute synthesis
    if {[catch {execute_module -tool map -args "--parallel"} result]} {
      Msg Error "Result: $result\n"
      Msg Error "Analysis & Synthesis failed. See the report file.\n"
    } else {
      Msg Info "Analysis & Synthesis was successful for revision $revision.\n"
    }
  } elseif {[IsLibero]} {
    # TODO: Missing Reset
    defvar_set -name RWNETLIST_32_64_MIXED_FLOW -value 0

    Msg Info "Run SYNTHESIS..."
    if {[catch {run_tool -name {SYNTHESIZE}  }] } {
      Msg Error "SYNTHESIZE FAILED!"
    } else {
      Msg Info "SYNTHESIZE PASSED!"
    }
  } elseif {[IsDiamond]} {
    # TODO: Missing Reset
    set force_rst ""
    if {$reset == 1} {
      set force_rst "-forceOne"
    }
    prj_run Synthesis $force_rst
    if {[prj_syn] == "synplify"} {
      prj_run Translate $force_rst
    }
  } else {
    Msg Error "Impossible condition. You need to run this in an IDE."
    exit 1
  }
}

# Returns the list of all the Hog Projects in the repository
#
# @param[in] repo_path  The main path of the git repository
# @param[in] print      if 1 print the list of projects in the repository, if 2 does not print test projects
# @param[in] ret_conf   if 1 returns conf file rather than list of project names

proc ListProjects {{repo_path .} {print 1} {ret_conf 0}} {
  set top_path [file normalize $repo_path/Top]
  set confs [findFiles [file normalize $top_path] hog.conf]
  set projects ""
  set confs [lsort $confs]
  set g ""

  foreach c $confs {
    set p [Relative $top_path [file dirname $c]]
    if {$print >= 1} {
      set description [DescriptionFromConf $c]
      if { $description eq "test"} {
	set description " - Test project"
      } elseif { $description ne ""} {
	set description " - $description"
      }

      if {$print == 1 || $description ne " - Test project"} {
	set old_g $g
	set g [file dirname $p]
	# Print a list of the projects with relative IDE and description (second line comment in hog.conf)
	if {$g ne $old_g} {
	  Msg Status ""
	}
	Msg Status "$p \([GetIDEFromConf $c]\)$description"
      }
    }
    lappend projects $p
  }

  if {$ret_conf == 0} {

    # Returns a list of project names
    return $projects
  } else {

    # Return the list of hog.conf with full path
    return $confs
  }
}


# @brief Print the Hog Logo
#
# @param[in] repo_path The main path of the git repository (default .)
proc Logo { {repo_path .} } {
  if {[info exists ::env(HOG_COLORED)] && [string match "ENABLED" $::env(HOG_COLORED)]} {
    set logo_file "$repo_path/Hog/images/hog_logo_color.txt"
  } else {
    set logo_file "$repo_path/Hog/images/hog_logo.txt"
  }

  set old_path [pwd]
  cd $repo_path/Hog
  set ver [Git {describe --always}]
  cd $old_path

  if {[file exists $logo_file]} {
    set f [open $logo_file "r"]
    set data [read $f]
    close $f
    set lines [split $data "\n"]
    foreach l $lines {
      Msg Status $l
    }

  } {
    Msg CriticalWarning "Logo file: $logo_file not found"
  }

  Msg Status "Version: $ver"
}

## @brief Evaluates the md5 sum of a file
#
#  @param[in] file_name: the name of the file of which you want to evaluate the md5 checksum
proc Md5Sum {file_name} {
  if {!([file exists $file_name])} {
    Msg Warning "Could not find $file_name."
    set file_hash -1
  }
  if {[catch {package require md5 2.0.7} result]} {
    Msg Warning "Tcl package md5 version 2.0.7 not found ($result), will use command line..."
    set hash [lindex [Execute md5sum $file_name] 0]
  } else {
    set file_hash [string tolower [md5::md5 -hex -file $file_name]]
  }
}

## @brief Merges two tcl dictionaries of lists
#
# If the dictionaries contain same keys, the list at the common key is a merging of the two
#
# @param[in] dict0 the name of the first dictionary
# @param[in] dict1 the name of the second dictionary
#
# @return  the merged dictionary
#
proc MergeDict {dict0 dict1} {
  set outdict [dict merge $dict1 $dict0]
  foreach key [dict keys $dict1 ] {
    if {[dict exists $dict0 $key]} {
      set temp_list [dict get $dict1 $key]
      foreach vhdfile $temp_list {
        # Avoid duplication
        if {[IsInList $vhdfile [DictGet $outdict $key]] == 0} {
          dict lappend outdict $key $vhdfile
        }
      }
    }
  }
  return $outdict
}

# @brief Move an element in the list to the end
#
# @param[in] inputList the list
# @param[in] element   the element to move to the end of the list
proc MoveElementToEnd {inputList element} {
  set index [lsearch $inputList $element]
  if {$index != -1} {
    set inputList [lreplace $inputList $index $index]
    lappend inputList $element
  }
  return $inputList
}

## @brief The Hog Printout Msg function
#
# @param[in] level The severity level (status, info, warning, critical, error, debug)
# @param[in] msg   The message to print
# @param[in] title The title string to be included in the header of the message [Hog:$title] (default "")
proc Msg {level msg {title ""}} {
  set level [string tolower $level]
  if {$title == ""} {set title [lindex [info level [expr {[info level]-1}]] 0]}
  if {$level == 0 || $level == "status" || $level == "extra_info"} {
    set vlevel {STATUS}
    set qlevel info
  } elseif {$level == 1 || $level == "info"} {
    set vlevel {INFO}
    set qlevel info
  } elseif {$level == 2 || $level == "warning"} {
    set vlevel {WARNING}
    set qlevel warning
  } elseif {$level == 3 || [string first "critical" $level] !=-1} {
    set vlevel {CRITICAL WARNING}
    set qlevel critical_warning
  } elseif {$level == 4 || $level == "error"} {
    set vlevel {ERROR}
    set qlevel error
  } elseif {$level == 5 || $level == "debug"} {
    if {([info exists ::DEBUG_MODE] && $::DEBUG_MODE == 1) || ([info exists ::env(HOG_DEBUG_MODE)] && $::env(HOG_DEBUG_MODE) == 1)} {
      set vlevel {STATUS}
      set qlevel extra_info
      set msg "DEBUG: \[Hog:$title\] $msg"
    } else {
      return
    }
  } else {
    puts "Hog Error: level $level not defined"
    exit -1
  }


  if {[IsXilinx]} {
    # Vivado
    set status [catch {send_msg_id Hog:$title-0 $vlevel $msg}]
    if {$status != 0} {
      exit $status
    }
  } elseif {[IsQuartus]} {
    # Quartus
    post_message -type $qlevel "Hog:$title $msg"
    if { $qlevel == "error"} {
      exit 1
    }
  } else {
    # Tcl Shell / Libero
    if {$vlevel != "STATUS"} {
      puts "$vlevel: \[Hog:$title\] $msg"
    } else {
      puts $msg
    }

    if {$qlevel == "error"} {
      exit 1
    }
  }
}

## @brief Prints a message with selected severity and optionally write into a log file
#
# @param[in] msg        The message to print
# @param[in] severity   The severity of the message
# @param[in] outFile    The path of the output logfile
#
proc MsgAndLog {msg {severity "CriticalWarning"} {outFile ""}} {
  Msg $severity $msg
  if {$outFile != ""} {
    set oF [open "$outFile" a+]
    puts $oF $msg
    close $oF
  }
}

# @brief Open the project with the corresponding IDE
#
# @param[in] project_file The project_file
# @param[in] repo_path    The main path of the git repository
proc OpenProject {project_file repo_path} {
  if {[IsXilinx]} {
    open_project $project_file
  } elseif {[IsQuartus]} {
    set project_folder [file dirname $project_file]
    set project [file tail [file rootname $project_file]]
    if {[file exists $project_folder]} {
      cd $project_folder
      if { ![is_project_open ] } {
        Msg Info "Opening existing project file $project_file..."
        project_open $project -current_revision
      }
    } else {
      Msg Error "Project directory not found for $project_file."
      return 1
    }
  } elseif {[IsLibero]} {
    Msg Info "Opening existing project file $project_file..."
    cd $repo_path
    open_project -file $project_file -do_backup_on_convert 1 -backup_file {./Projects/$project_file.zip}
  } elseif {[IsDiamond]} {
    Msg Info "Opening existing project file $project_file..."
    prj_project open $project_file
  } else {
    Msg Error "This IDE is currently not supported by Hog. Exiting!"
  }
}

## @brief Return the operative system name
proc OS {} {
  global tcl_platform
  return $tcl_platform(platform)
}

## @brief Parse JSON file
#
# @param[in] JSON_FILE  The JSON File to parse
# @param[in] JSON_KEY   The key to extract from the JSON file
#
# @returns  -1 in case of failure, JSON KEY VALUE in case of success
#
proc ParseJSON {JSON_FILE JSON_KEY} {
  set result [catch {package require Tcl 8.4} TclFound]
  if {"$result" != "0"} {
    Msg CriticalWarning "Cannot find Tcl package version equal or higher than 8.4.\n $TclFound\n Exiting"
    return -1
  }

  set result [catch {package require json} JsonFound]
  if {"$result" != "0"} {
    Msg CriticalWarning "Cannot find JSON package equal or higher than 1.0.\n $JsonFound\n Exiting"
    return -1
  }
  set JsonDict [json::json2dict  $JSON_FILE]
  set result [catch {dict get $JsonDict $JSON_KEY} RETURNVALUE]
  if {"$result" != "0"} {
    Msg CriticalWarning "Cannot find $JSON_KEY in $JSON_FILE\n Exiting"
    return -1
  } else {
    return $RETURNVALUE
  }
}

# @brief Check if a Hog project exists, and if it exists returns the conf file
# if it doesnt returns 0
#
# @brief project   The project name
# @brief repo_path The main path of the git repository
proc ProjectExists {project {repo_path .}} {
  set index [lsearch -exact [ListProjects $repo_path 0] $project]

  if {$index >= 0} {
    # if project exists we return the relative hog.conf file
    return [lindex [ListProjects $repo_path 0 1] $index]
  } else {
    return 0
  }
}

## Read a property configuration file and returns a dictionary
#
#  @param[in]    file_name the configuration file
#
#  @return       The dictionary
#
proc ReadConf {file_name} {

  if { [catch {package require inifile 0.2.3} ERROR] } {
    puts "$ERROR\n If you are running this script on tclsh, you can fix this by installing 'tcllib'"
    return 1
  }


  ::ini::commentchar "#"
  set f [::ini::open $file_name]
  set properties [dict create]
  foreach sec [::ini::sections $f] {
    set new_sec $sec
    set key_pairs [::ini::get $f $sec]

    #manipulate strings here:
    regsub -all {\{\"} $key_pairs "\{" key_pairs
    regsub -all {\"\}} $key_pairs "\}" key_pairs

    dict set properties $new_sec [dict create {*}$key_pairs]
  }

  ::ini::close $f

  return $properties
}

## @brief Function used to read the list of files generated at creation time by tcl scripts in Project/proj/.hog/extra.files
#
#  @param[in] extra_file_name the path to the extra.files file
#  @returns a dictionary with the full name of the files as key and a SHA as value
#
proc ReadExtraFileList { extra_file_name } {
  set extra_file_dict [dict create]
  if {[file exists $extra_file_name]} {
    set file [open $extra_file_name "r"]
    set file_data [read $file]
    close $file

    set data [split $file_data "\n"]
    foreach line $data {
      if {![regexp {^ *$} $line] & ![regexp {^ *\#} $line] } {
        set ip_and_md5 [regexp -all -inline {\S+} $line]
        dict lappend extra_file_dict "[lindex $ip_and_md5 0]" "[lindex $ip_and_md5 1]"
      }
    }
  }
  return $extra_file_dict
}

## @brief Read a list file and return a list of three dictionaries
#
# Additional information is provided with text separated from the file name with one or more spaces
#
# @param[in] args The arguments are \<list_file\> \<path\> [options]
#                 * list_file file containing vhdl list with optional properties
#                 * path      path the vhdl file are referred to in the list file
# Options:
#                 * -lib \<library\> name of the library files will be added to, if not given will be extracted from the file name
#                 * -sha_mode  if not set to 0, the list files will be added as well and the IPs will be added to the file rather than to the special ip library. The SHA mode should be used when you use the lists to calculate the git SHA, rather than to add the files to the project.
#
# @return              a list of 3 dictionaries: "libraries" has library name as keys and a list of filenames as values, "properties" has as file names as keys and a list of properties as values, "filesets" has the fileset' names as keys and the list of associated libraries as values.
proc ReadListFile args {

  if {[IsQuartus]} {
    load_package report
    if { [catch {package require cmdline} ERROR] } {
      puts "$ERROR\n If you are running this script on tclsh, you can fix this by installing 'tcllib'"
      return 1
    }
  }

  set parameters {
    {lib.arg ""  "The name of the library files will be added to, if not given will be extracted from the file name."}
    {fileset.arg "" "The name of the library, from the main list file"}
    {sha_mode "If set, the list files will be added as well and the IPs will be added to the file rather than to the special IP library. The SHA mode should be used when you use the lists to calculate the git SHA, rather than to add the files to the project."}
  }
  set usage "USAGE: ReadListFile \[options\] <list file> <path>"
  if {[catch {array set options [cmdline::getoptions args $parameters $usage]}] ||  [llength $args] != 2 } {
    Msg CriticalWarning "[cmdline::usage $parameters $usage]"
    return
  }
  set list_file [lindex $args 0]
  set path [lindex $args 1]
  set sha_mode $options(sha_mode)
  set lib $options(lib)
  set fileset $options(fileset)

  if { $sha_mode == 1} {
    set sha_mode_opt "-sha_mode"
  } else {
    set sha_mode_opt  ""
  }

  # if no library is given, work it out from the file name
  if {$lib eq ""} {
    set lib [file rootname [file tail $list_file]]
  }
  set fp [open $list_file r]
  set file_data [read $fp]
  close $fp
  set list_file_ext [file extension $list_file]
  switch $list_file_ext {
    .sim {
      if {$fileset eq ""} {
        # If fileset is empty, use the library name for .sim file
        set fileset "$lib"
      }
    }
    .con {
      set fileset "constrs_1"
    }
    default {
      set fileset "sources_1"
    }
  }

  set libraries [dict create]
  set filesets [dict create]
  set properties [dict create]
  #  Process data file
  set data [split $file_data "\n"]
  set n [llength $data]
  Msg Debug "$n lines read from $list_file."
  set cnt 0

  foreach line $data {
    # Exclude empty lines and comments
    if {![regexp {^ *$} $line] & ![regexp {^ *\#} $line] } {
      set file_and_prop [regexp -all -inline {\S+} $line]
      set srcfile [lindex $file_and_prop 0]
      set srcfile "$path/$srcfile"

      set srcfiles [glob -nocomplain $srcfile]

      # glob the file list for wildcards
      if {$srcfiles != $srcfile && ! [string equal $srcfiles "" ]} {
        Msg Debug "Wildcard source expanded from $srcfile to $srcfiles"
      } else {
        if {![file exists $srcfile]} {
          Msg CriticalWarning "File: $srcfile (from list file: $list_file) does not exist."
          continue
        }
      }

      foreach vhdlfile $srcfiles {
        if {[file exists $vhdlfile]} {
          set vhdlfile [file normalize $vhdlfile]
          set extension [file extension $vhdlfile]
          ### Set file properties
          set prop [lrange $file_and_prop 1 end]

          # The next lines should be inside the case for recursive list files, also we should check the allowed properties for the .src as well
          set library [lindex [regexp -inline {lib\s*=\s*(.+?)\y.*} $prop] 1]
          if { $library == "" } {
            set library $lib
          }

          if { $extension == $list_file_ext } {
            # Deal with recursive list files
            set ref_path [lindex [regexp -inline {path\s*=\s*(.+?)\y.*} $prop] 1]
            if { $ref_path eq "" } {
              set ref_path $path
            } else {
              set ref_path [file normalize $path/$ref_path]
            }
            Msg Debug "List file $vhdlfile found in list file, recursively opening it using path \"$ref_path\"..."
            lassign [ReadListFile {*}"-lib $library -fileset $fileset $sha_mode_opt $vhdlfile $ref_path"] l p fs
            set libraries [MergeDict $l $libraries]
            set properties [MergeDict $p $properties]
            set filesets [MergeDict $fs $filesets]
          } elseif {[lsearch {.src .sim .con ReadExtraFileList} $extension] >= 0 } {
            # Not supported extensions
            Msg Error "$vhdlfile cannot be included into $list_file, $extension files must be included into $extension files."
          } else {
            # Deal with single files
            regsub -all " *= *" $prop "=" prop
            # Fill property dictionary
            foreach p $prop {
              # No need to append the lib= property
              if { [string first "lib=" $p ] == -1} {
                # Get property name up to the = (for QSYS properties at the moment)
                set pos [string first "=" $p]
                if { $pos == -1 } {
                  set prop_name $p
                } else {
                  set prop_name [string range $p 0 [expr {$pos - 1}]]
                }
                if { [IsInList $prop_name [DictGet [ALLOWED_PROPS]  $extension ] ] || [string first "top" $p] == 0 || $list_file_ext eq ".ipb"} {
                  dict lappend properties $vhdlfile $p
                  Msg Debug "Adding property $p to $vhdlfile..."
                } elseif { $list_file_ext != ".ipb" } {
                  Msg Warning "Setting Property $p is not supported for file $vhdlfile or it is already its default. The allowed properties for this file type are \[ [DictGet [ALLOWED_PROPS] $extension ]\]"
                }
              }
            }
            if { [lsearch {.xci .ip .bd .xcix} $extension] >= 0} {
              # Adding IP library
              set lib_name "ips.src"
            } elseif { [IsInList $extension {.vhd .vhdl}] || $list_file_ext == ".sim"} {
              # VHDL files and simulation
              if { ![IsInList $extension {.vhd .vhdl}]} {
                set lib_name "others.sim"
              } else {
                set lib_name "$library$list_file_ext"
              }
            } elseif { $list_file_ext == ".con" } {
              set lib_name "sources.con"
            } elseif { $list_file_ext == ".ipb" } {
              set lib_name "xml.ipb"
            } else {
              # Other files are stored in the OTHER dictionary from vivado (no library assignment)
              set lib_name "others.src"
            }

            Msg Debug "Appending $vhdlfile to $lib_name list..."
            dict lappend libraries $lib_name $vhdlfile
            if { $sha_mode != 0 && [file type $vhdlfile] eq "link"} {
              #if the file is a link, also add the linked file in sha mode
              set real_file [GetLinkedFile $vhdlfile]
              dict lappend libraries $lib_name $real_file
              Msg Debug "File $vhdlfile is a soft link, also adding the real file: $real_file"
            }


            # Create the fileset (if not already) and append the library
            if {[dict exists $filesets $fileset] == 0} {
              # Fileset has not been defined yet, adding to dictionary...
              Msg Debug "Adding $fileset to the fileset dictionary..."
              Msg Debug "Adding library $lib_name to fileset $fileset..."
              dict set filesets $fileset $lib_name
            } else {
              # Fileset already exist in dictionary, append library to list, if not already there
              if {[IsInList $lib_name [DictGet $filesets $fileset]] == 0} {
                Msg Debug "Adding library $lib_name to fileset $fileset..."
                dict lappend filesets $fileset $lib_name
              }
            }
          }
          incr cnt
        } else {
          Msg CriticalWarning "File $vhdlfile not found."
        }
      }
    }
  }

  if {$sha_mode != 0} {
    #In SHA mode we also need to add the list file to the list
    if {$list_file_ext eq ".ipb"} {
      set sha_lib "xml.ipb"
    } else {
      set sha_lib $lib$list_file_ext
    }
    dict lappend libraries $sha_lib [file normalize $list_file]
    if {[file type $list_file] eq "link"} {
      #if the file is a link, also add the linked file
      set real_file [GetLinkedFile $list_file]
      dict lappend libraries $lib$list_file_ext $real_file
      Msg Debug "List file $list_file is a soft link, also adding the real file: $real_file"
    }
  }
  return [list $libraries $properties $filesets]
}

## @brief Returns the destination path relative to base
#
# @param[in] base   the path with respect to witch the dst path is calculated
# @param[in] dst    the path to be calculated with respect to base
#
proc Relative {base dst} {
  if {![string equal [file pathtype $base] [file pathtype $dst]]} {
    Msg CriticalWarning "Unable to compute relation for paths of different path types: [file pathtype $base] vs. [file pathtype $dst], ($base vs. $dst)"
    return ""
  }

  set base [file normalize [file join [pwd] $base]]
  set dst  [file normalize [file join [pwd] $dst]]

  set save $dst
  set base [file split $base]
  set dst  [file split $dst]

  while {[string equal [lindex $dst 0] [lindex $base 0]]} {
    set dst  [lrange $dst  1 end]
    set base [lrange $base 1 end]
    if {![llength $dst]} {break}
  }

  set dstlen  [llength $dst]
  set baselen [llength $base]

  if {($dstlen == 0) && ($baselen == 0)} {
    set dst .
  } else {
    while {$baselen > 0} {
      set dst [linsert $dst 0 ..]
      incr baselen -1
    }
    set dst [eval [linsert $dst 0 file join]]
  }

  return $dst
}

## @brief Returns the path of filePath relative to pathName
#
# @param[in] pathName   the path with respect to which the returned path is calculated
# @param[in] filePath   the path of filePath
#
proc RelativeLocal {pathName filePath} {
  if {[string first [file normalize $pathName] [file normalize $filePath]] != -1} {
    return [Relative $pathName $filePath]
  } else {
    return ""
  }
}

## @brief Remove duplicates in a dictionary
#
# @param[in] mydict the input dictionary
#
# @return the dictionary stripped of duplicates
proc RemoveDuplicates {mydict} {
  set new_dict [dict create]
  foreach key [dict keys $mydict] {
    set values [DictGet $mydict $key]
    foreach value $values {
      set idxs [lreverse [lreplace [lsearch -exact -all $values $value] 0 0]]
      foreach idx $idxs {
        set values [lreplace $values $idx $idx]
      }
    }
    dict set new_dict $key $values
  }
  return $new_dict
}

## Reset files in the repository
#
#  @param[in]    reset_file a file containing a list of files separated by new lines or spaces (Hog-CI creates such a file in Projects/hog_reset_files)
#
#  @return       Nothing
#
proc ResetRepoFiles {reset_file} {
  if {[file exists $reset_file]} {
    Msg Info "Found $reset_file, opening it..."
    set fp [open $reset_file r]
    set wild_cards [lsearch -all -inline -not -regexp [split [read $fp] "\n"] "^ *$"]
    close $fp
    Msg Info "Found the following files/wild cards to restore if modified: $wild_cards..."
    foreach w $wild_cards {
      set mod_files [GetModifiedFiles "." $w]
      if {[llength $mod_files] > 0} {
        Msg Info "Found modified $w files: $mod_files, will restore them..."
        RestoreModifiedFiles "." $w
      } else {
        Msg Info "No modified $w files found."
      }
    }
  }
}

## @brief Restore with checkout -- the files specified in pattern
#
# @param[in] repo_path the path of the git repository
# @param[in] pattern the pattern with wildcards that files should match
#
proc RestoreModifiedFiles {{repo_path "."} {pattern "."}} {
  set old_path [pwd]
  cd $repo_path
  set ret [Git checkout $pattern]
  cd $old_path
  return
}

## Search the Hog projects inside a directory
#
#  @param[in]    dir The directory to search
#
#  @return       The list of projects
#
proc SearchHogProjects {dir} {
  set projects_list {}
  if {[file exists $dir]} {
    if {[file isdirectory $dir]} {
      foreach proj_dir [glob -nocomplain -types d $dir/* ] {
        if {![regexp {^.*Top/+(.*)$} $proj_dir dummy proj_name]} {
          Msg Warning "Could not parse Top directory $dir"
          break
        }
        if { [file exists "$proj_dir/hog.conf" ] } {
          lappend projects_list $proj_name
        } else {
          foreach p [SearchHogProjects $proj_dir] {
            lappend projects_list $p
          }
        }
      }

    } else {
      Msg Error "Input $dir is not a directory!"
    }
  } else {
    Msg Error "Directory $dir doesn't exist!"
  }
  return $projects_list
}

## @brief Sets the generics in all the sim.conf simulation file sets
#
# @param[in] repo_path:   the top folder of the projectThe path to the main git repository
# @param[in] proj_dir:    the top folder of the project
# @param[in] target:      software target(vivado, questa)
#
proc SetGenericsSimulation {repo_path proj_dir target} {
  set top_dir "$repo_path/Top/$proj_dir"
  set read_aux [GetConfFiles $top_dir]
  set sim_cfg_index [lsearch -regexp -index 0 $read_aux ".*sim.conf"]
  set sim_cfg_index [lsearch -regexp -index 0 [GetConfFiles $top_dir] ".*sim.conf"]
  set simsets [get_filesets]
  if { $simsets != "" } {
    if {[file exists $top_dir/sim.conf]} {
      set sim_generics_dict [GetGenericsFromConf $proj_dir 1]
      set simsets_generics_dict [GetSimsetGenericsFromConf $proj_dir]

      if {[dict size $sim_generics_dict] > 0 || [dict size $simsets_generics_dict] > 0} {
        foreach simset $simsets {
          # Only for simulation filesets
          if {[get_property FILESET_TYPE $simset] != "SimulationSrcs" } {
            continue
          }
          # Check if any specific generics for this simset
          if {[dict exists $simsets_generics_dict $simset:generics]} {
            set simset_generics_dict [dict get $simsets_generics_dict $simset:generics]
            # Merge with global sim generics (if any), specific simset generics also have priority
            set merged_generics_dict [dict merge $sim_generics_dict $simset_generics_dict]
            set generic_str [GenericToSimulatorString $merged_generics_dict $target]
            set_property generic $generic_str [get_filesets $simset]
            Msg Debug "Setting generics $generic_str for simulator $target and simulation file-set $simset..."
          } elseif {[dict size $sim_generics_dict] > 0} {
            set generic_str [GenericToSimulatorString $sim_generics_dict $target]
            set_property generic $generic_str [get_filesets $simset]
            Msg Debug "Setting generics $generic_str for simulator $target and simulation file-set $simset..."
          }
        }
      }
    } else {
      if {[glob -nocomplain "$top_dir/list/*.sim"] ne ""} {
        Msg CriticalWarning "Simulation sets and .sim files are present in the project but no sim.conf found in $top_dir. Please refer to Hog's manual to create one."
      }
    }
  }
}

## @brief set the top module as top module in the chosen fileset
#
# It automatically recognises the IDE
#
# @param[out] top_module  Name of the top module
# @param[in]  fileset     The name of the fileset
#
proc SetTopProperty {top_module fileset} {
  Msg Info "Setting TOP property to $top_module module"
  if {[IsXilinx]} {
    #VIVADO_ONLY
    set_property "top" $top_module [get_filesets $fileset]
  } elseif {[IsQuartus]} {
    #QUARTUS ONLY
    set_global_assignment -name TOP_LEVEL_ENTITY $top_module
  } elseif {[IsLibero]} {
    set_root -module $top_module
  } elseif {[IsDiamond]} {
    prj_impl option top $top_module
  }
}

## @brief Returns a list of Vivado properties that expect a PATH for value
proc VIVADO_PATH_PROPERTIES {} {
  return {"\.*\.TCL\.PRE$" "^.*\.TCL\.POST$" "^RQS_FILES$" "^INCREMENTAL\_CHECKPOINT$"}
}

## @brief Write a property configuration file from a dictionary
#
#  @param[in]    file_name the configuration file
#  @param[in]    config the configuration dictionary
#  @param[in]    comment comment to add at the beginning of configuration file
#
#
proc WriteConf {file_name config {comment ""}} {
  if { [catch {package require inifile 0.2.3} ERROR] } {
    puts "$ERROR\n If you are running this script on tclsh, you can fix this by installing 'tcllib'"
    return 1
  }

  ::ini::commentchar "#"
  set f [::ini::open $file_name w]

  foreach sec [dict keys $config] {
    set section [dict get $config $sec]
    dict for {p v} $section {
      if {[string trim $v] == ""} {
          Msg Warning "Property $p has empty value. Skipping..."
          continue;
      }
      ::ini::set $f $sec $p $v
    }
  }

  #write comment before the first section (first line of file)
  if {![string equal "$comment"  ""]} {
    ::ini::comment $f [lindex [::ini::sections $f] 0] "" $comment
  }
  ::ini::commit $f

  ::ini::close $f

}

## Set the generics property
#
#  @param[in]    mode if it's "create", the function will assume the project is being created
#  @param[in]    repo_path The path to the main git repository
#  @param[in]    design The name of the design

#  @param[in]    list of variables to be written in the generics in the usual order

proc WriteGenerics {mode repo_path design date timee commit version top_hash top_ver hog_hash hog_ver cons_ver cons_hash libs vers hashes ext_names ext_hashes user_ip_repos user_ip_vers user_ip_hashes flavour {xml_ver ""} {xml_hash ""}} {
  Msg Info "Passing parameters/generics to project's top module..."
  #####  Passing Hog generic to top file
  # set global generic variables
  set generic_string [concat \
                          "GLOBAL_DATE=[FormatGeneric $date]" \
                          "GLOBAL_TIME=[FormatGeneric $timee]" \
                          "GLOBAL_VER=[FormatGeneric $version]" \
                          "GLOBAL_SHA=[FormatGeneric $commit]" \
                          "TOP_SHA=[FormatGeneric $top_hash]" \
                          "TOP_VER=[FormatGeneric $top_ver]" \
                          "HOG_SHA=[FormatGeneric $hog_hash]" \
                          "HOG_VER=[FormatGeneric $hog_ver]" \
                          "CON_VER=[FormatGeneric $cons_ver]" \
                          "CON_SHA=[FormatGeneric $cons_hash]"]
  # xml hash
  if {$xml_hash != "" && $xml_ver != ""} {
    lappend generic_string \
          "XML_VER=[FormatGeneric $xml_ver]" \
          "XML_SHA=[FormatGeneric $xml_hash]"
  }
  #set project specific lists
  foreach l $libs v $vers h $hashes {
    set ver "[string toupper $l]_VER=[FormatGeneric $v]"
    set hash "[string toupper $l]_SHA=[FormatGeneric $h]"
    lappend generic_string "$ver" "$hash"
  }

  foreach e $ext_names h $ext_hashes {
    set hash "[string toupper $e]_SHA=[FormatGeneric $h]"
    lappend generic_string "$hash"
  }

  foreach repo $user_ip_repos v $user_ip_vers h $user_ip_hashes {
    set repo_name [file tail $repo]
    set ver "[string toupper $repo_name]_VER=[FormatGeneric $v]"
    set hash "[string toupper $repo_name]_SHA=[FormatGeneric $h]"
    lappend generic_string "$ver" "$hash"
  }

  if {$flavour != -1} {
    lappend generic_string "FLAVOUR=$flavour"
  }

  # Dealing with project generics in Vivado
  if {[IsVivado]} {
    set prj_generics [GenericToSimulatorString [GetGenericsFromConf $design] "Vivado"]
    set generic_string "$prj_generics $generic_string"
  }

  # Extract the generics from the top level source file
  if {[IsXilinx]} {
    # Top File can be retrieved only at creation time or in ISE
    if {$mode == "create" || [IsISE]} {

      set top_file [GetTopFile]
      set top_name [GetTopModule]
      if {[file exists $top_file]} {
        set generics [GetFileGenerics $top_file $top_name]

        Msg Debug "Found top level generics $generics in $top_file"

        set filtered_generic_string ""

        foreach generic_to_set [split [string trim $generic_string]] {
          set key [lindex [split $generic_to_set "="] 0]
          if {[dict exists $generics $key]} {
            Msg Debug "Hog generic $key found in $top_name"
            lappend filtered_generic_string "$generic_to_set"
          } else {
            Msg Warning "Generic $key is passed by Hog but is NOT present in $top_name."
          }
        }

        # only filter in ISE
        if {[IsISE]} {
          set generic_string $filtered_generic_string
        }
      }
    }

    set_property generic $generic_string [current_fileset]
    Msg Info "Setting parameters/generics..."
    Msg Debug "Detailed parameters/generics: $generic_string"


    if {[IsVivado]} {
      # Dealing with project generics in Simulators
      set simulator [get_property target_simulator [current_project]]
      if {$mode == "create"} {
        SetGenericsSimulation $repo_path $design $simulator
      }

      WriteGenericsToBdIPs $mode $repo_path $design $generic_string
    }
  } elseif {[IsSynplify]} {
    Msg Info "Setting Synplify parameters/generics one by one..."
    foreach generic $generic_string {
      Msg Debug "Setting Synplify generic: $generic"
      set_option -hdl_param -set "$generic"
    }
  } elseif {[IsDiamond]} {
    Msg Info "Setting Diamond parameters/generics one by one..."
    prj_impl option -impl Implementation0 HDL_PARAM "$generic_string"
  }
}

## @brief Applies generic values to IPs within block designs
#
#  @param[in]    mode           create: to write the generics at creation time. synth to write at synthesis time
#  @param[in]    repo_path      The main path of the git repository
#  @param[in]    proj           The project name
#  @param[in]    generic_string the string containing the generics to be applied
proc WriteGenericsToBdIPs {mode repo_path proj generic_string} {
  Msg Debug "Parameters/generics passed to WriteGenericsToIP: $generic_string"

  set bd_ip_generics false
  set properties [ReadConf [lindex [GetConfFiles $repo_path/Top/$proj] 0]]
  if {[dict exists $properties "hog"]} {
    set propDict [dict get $properties "hog"]
    if {[dict exists $propDict "PASS_GENERICS_TO_BD_IPS"]} {
      set bd_ip_generics [dict get $propDict "PASS_GENERICS_TO_BD_IPS"]
    }
  }

  if {[string compare [string tolower $bd_ip_generics] "false"]==0} {
    return
  }

  if {$mode == "synth"} {
    Msg Info "Attempting to apply generics pre-synthesis..."
    set PARENT_PRJ [get_property "PARENT.PROJECT_PATH" [current_project]]
    set workaround [open "$repo_path/Projects/$proj/.hog/presynth_workaround.tcl" "w"]
    puts $workaround "source \[lindex \$argv 0\];"
    puts $workaround "open_project \[lindex \$argv 1\];"
    puts $workaround "WriteGenericsToBdIPs \[lindex \$argv 2\] \[lindex \$argv 3\] \[lindex \$argv 4\] \[lindex \$argv 5\];"
    puts $workaround "close_project"
    close $workaround
    if {[catch {
      exec vivado -mode batch -source $repo_path/Projects/$proj/.hog/presynth_workaround.tcl \
      -tclargs $repo_path/Hog/Tcl/hog.tcl $PARENT_PRJ \
      "childprocess" $repo_path $proj $generic_string
    } errMsg] != 0} {
      Msg Error "Encountered an error while attempting workaround: $errMsg"
    }
    file delete $repo_path/Projects/$proj/.hog/presynth_workaround.tcl
    Msg Info "Done applying generics pre-synthesis."
    return
  }

  Msg Info "Looking for IPs to add generics to..."
  set ips_generic_string ""
  foreach generic_to_set [split [string trim $generic_string]] {
    set key [lindex [split $generic_to_set "="] 0]
    set value [lindex [split $generic_to_set "="] 1]
    append ips_generic_string "CONFIG.$key $value "
  }


  if {[string compare [string tolower $bd_ip_generics] "true"]==0} {
    set ip_regex ".*"
  } else {
    set ip_regex $bd_ip_generics
  }

  set ip_list [get_ips -regex $ip_regex]
  Msg Debug "IPs found with regex \{$ip_regex\}: $ip_list"

  set regen_targets {}

  foreach {ip} $ip_list {
    set WARN_ABOUT_IP false
    set ip_props [list_property [get_ips $ip]]

    #Not sure if this is needed, but it's here to prevent potential errors with get_property
    if {[lsearch -exact $ip_props "IS_BD_CONTEXT"] == -1} {
      continue
    }

    if {[get_property "IS_BD_CONTEXT" [get_ips $ip]] eq "1"} {
      foreach {ip_prop} $ip_props {
        if {[dict exists $ips_generic_string $ip_prop ]} {
          if {$WARN_ABOUT_IP == false} {
            lappend regen_targets [get_property SCOPE [get_ips $ip]]
            Msg Warning "The ip \{$ip\} contains generics that are set by Hog.\
              If this is IP is apart of a block design, the .bd file may contain stale, unused, values.\
              Hog will always apply the most up-to-date values to the IP during synthesis,\
              however these values may or may not be reflected in the .bd file."
            set WARN_ABOUT_IP true
          }

          # vivado is annoying about the format when setting generics for ips
          # this tries to find and set the format to what vivado likes
          set xci_path [get_property IP_FILE [get_ips $ip]]
          set generic_format [GetGenericFormatFromXci $ip_prop $xci_path]
          if {[string equal $generic_format "ERROR"]} {
            Msg Warning "Could not find format for generic $ip_prop in IP $ip. Skipping..."
            continue
          }

          set value_to_set [dict get $ips_generic_string $ip_prop]
          switch -exact $generic_format {
            "long" {
              if {[string first "32'h" $value_to_set] != -1} {
                scan [string map {"32'h" ""} $value_to_set] "%x" value_to_set
              }
            }
            "bool" {
              set value_to_set [expr {$value_to_set ? "true" : "false"}]
            }
            "float" {
              if {[string first "32'h" $value_to_set] != -1} {
                binary scan [binary format H* [string map {"32'h" ""} $value_to_set]] d value_to_set
              }
            }
            "bitString" {
                set value_to_set [format "0x%x" [string map {"32'h" ""} $value_to_set]]
            }
            "string" {
              set value_to_set [format "%s" $value_to_set]
            }
            default {
              Msg Warning "Unknown generic format $generic_format for IP $ip. Will attempt to pass as string..."
            }
          }


          Msg Info "The IP \{$ip\} contains: $ip_prop ($generic_format), setting it to $value_to_set."
          if {[catch {set_property -name $ip_prop -value $value_to_set -objects [ get_ips $ip ]} prop_error]} {
            Msg CriticalWarning "Failed to set property $ip_prop to $value_to_set for IP \{$ip\}: $prop_error"
          }
        }
      }
    }
  }

  foreach {regen_target} [lsort -unique $regen_targets] {
    Msg Info "Regenerating target: $regen_target"
    if {[catch {generate_target -force all [get_files $regen_target]} prop_error]} {
      Msg CriticalWarning "Failed to regen targets: $prop_error"
    }
  }

}

## @brief Returns the format of a generic from an XML file
## @param[in] generic_name: The name of the generic
## @param[in] xml_file: The path to the XML XCI file
proc GetGenericFormatFromXciXML {generic_name xml_file} {

  if {![file exists $xml_file]} {
    Msg Error "Could not find XML file: $xml_file"
    return "ERROR"
  }

  set fp [open $xml_file r]
  set xci_data [read $fp]
  close $fp

  set paramType "string"
  set modelparam_regex [format {^.*\y%s\y.*$} [string map {"CONFIG." "MODELPARAM_VALUE."} $generic_name]]
  set format_regex {format="([^"]+)"}

  set line [lindex [regexp -inline -line $modelparam_regex $xci_data] 0]
  Msg Debug "line: $line"

  if {[regexp $format_regex $line match format_value]} {
    Msg Debug "Extracted: $format_value format from xml"
    set paramType $format_value
  } else {
    Msg Debug "No format found, using string"
  }

  return $paramType
}

## @brief Returns the format of a generic from an XCI file
## @param[in] generic_name: The name of the generic
## @param[in] xci_file: The path to the XCI file
proc GetGenericFormatFromXci {generic_name xci_file} {

  if {! [file exists $xci_file]} {
    Msg Error "Could not find XCI file: $xci_file"
    return "ERROR"
  }

  set fp [open $xci_file r]
  set xci_data [read $fp]
  close $fp

  set paramType "string"
  if {[string first "xilinx.com:schema:json_instance:1.0" $xci_data] == -1} {
    Msg Debug "XCI format is not JSON, trying XML..."
    set xml_file "[file rootname $xci_file].xml"
    return [GetGenericFormatFromXciXML $generic_name $xml_file]

  }

  set generic_name [string map {"CONFIG." ""} $generic_name]
  set ip_inst [ParseJSON $xci_data "ip_inst"]
  set parameters [dict get $ip_inst parameters]
  set component_parameters [dict get $parameters component_parameters]
  if {[dict exists $component_parameters $generic_name]} {
    set generic_info [dict get $component_parameters $generic_name]
    if {[dict exists [lindex $generic_info 0] format]} {
      set paramType [dict get [lindex $generic_info 0] format]
      Msg Debug "Extracted: $paramType format from xci"
      return $paramType
    }
    Msg Debug "No format found, using string"
    return $paramType
  } else {
    return "ERROR"
  }
}


## @brief Returns the gitlab-ci.yml snippet for a CI stage and a defined project
#
# @param[in] proj_name:   The project name
# @param[in] ci_confs:    Dictionary with CI configurations
#
proc WriteGitLabCIYAML {proj_name {ci_conf ""}} {
  if { [catch {package require yaml 0.3.3} YAMLPACKAGE]} {
    Msg CriticalWarning "Cannot find package YAML.\n Error message: $YAMLPACKAGE. If you are running on tclsh, you can fix this by installing package \"tcllib\""
    return -1
  }

  set job_list []
  if {$ci_conf != ""} {
    set ci_confs [ReadConf $ci_conf]
    foreach sec [dict keys $ci_confs] {
      if {[string first : $sec] == -1} {
        lappend job_list $sec
      }
    }
  } else {
    set job_list {"generate_project" "simulate_project"}
    set ci_confs ""
  }

  set out_yaml [huddle create]
  foreach job $job_list {
    # Check main project configurations
    set huddle_tags [huddle list]
    set tag_section ""
    set sec_dict [dict create]

    if {$ci_confs != ""} {
      foreach var [dict keys [dict get $ci_confs $job]] {
        if {$var == "tags"} {
          set tag_section "tags"
          set tags [dict get [dict get $ci_confs $job] $var]
          set tags [split $tags ","]
          foreach tag $tags {
            set tag_list [huddle list $tag]
            set huddle_tags [huddle combine $huddle_tags $tag_list]
          }
        } else {
          dict set sec_dict $var [dict get [dict get $ci_confs $job] $var]
        }
      }
    }

    # Check if there are extra variables in the conf file
    set huddle_variables [huddle create "PROJECT_NAME" $proj_name "extends" ".vars"]
    if {[dict exists $ci_confs "$job:variables"]} {
      set var_dict [dict get $ci_confs $job:variables]
      foreach var [dict keys $var_dict] {
        # puts [dict get $var_dict $var]
        set value [dict get $var_dict "$var"]
        set var_inner [huddle create "$var" "$value"]
        set huddle_variables [huddle combine $huddle_variables $var_inner]
      }
    }


    set middle [huddle create "extends" ".$job" "variables" $huddle_variables]
    foreach sec [dict keys $sec_dict] {
      set value [dict get $sec_dict $sec]
      set var_inner [huddle create "$sec" "$value"]
      set middle [huddle combine $middle $var_inner]
    }
    if {$tag_section != ""} {
      set middle2 [huddle create "$tag_section" $huddle_tags]
      set middle [huddle combine $middle $middle2]
    }

    set outer [huddle create "$job:$proj_name" $middle ]
    set out_yaml [huddle combine $out_yaml $outer]
  }

  return [ string trimleft [ yaml::huddle2yaml $out_yaml ] "-" ]
}

# @brief Write the content of Hog-library-dictionary created from the project into a .src/.ext/.con list file
#
# @param[in] libs      The Hog-Library dictionary with the list of files in the project to write
# @param[in] props     The Hog-library dictionary with the file sets
# @param[in] list_path  The path of the output list file
# @param[in] repo_path  The main repository path
# @param[in] ext_path   The external path
proc WriteListFiles {libs props list_path repo_path {$ext_path ""} } {
  # Writing simulation list files
  foreach lib [dict keys $libs] {
    if {[llength [DictGet $libs $lib]] > 0} {
      set list_file_name $list_path$lib
      set list_file [open $list_file_name w]
      Msg Info "Writing $list_file_name..."
      foreach file [DictGet $libs $lib] {
        # Retrieve file properties from prop list
        set prop [DictGet $props $file]
        # Check if file is local to the repository or external
        if {[RelativeLocal $repo_path $file] != ""} {
          set file_path [RelativeLocal $repo_path $file]
          puts $list_file "$file_path $prop"
        } elseif {[RelativeLocal $ext_path $file] != ""} {
          set file_path [RelativeLocal $ext_path $file]
          set ext_list_file [open "[file rootname $list_file].ext" a]
          puts $ext_list_file "$file_path $prop"
          close $ext_list_file
        } else {
          # File is not relative to repo or ext_path... Write a Warning and continue
          Msg Warning "The path of file $file is not relative to your repository. Please check!"
        }
      }
      close $list_file
    }
  }
}

# @brief Write the content of Hog-library-dictionary created from the project into a .sim list file
#
# @param[in] libs      The Hog-Library dictionary with the list of files in the project to write
# @param[in] props     The Hog-library dictionary with the file sets
# @param[in] simsets       The Hog-library dictionary with the file sets (relevant only for simulation)
# @param[in] list_path  The path of the output list file
# @param[in] repo_path  The main repository path
proc WriteSimListFiles {libs props simsets list_path repo_path } {
  # Writing simulation list files
  foreach simset [dict keys $simsets] {
    set list_file_name $list_path/${simset}.sim
    set list_file [open $list_file_name w]
    Msg Info "Writing $list_file_name..."
    foreach lib [DictGet $simsets $simset] {
      foreach file [DictGet $libs $lib] {
        # Retrieve file properties from prop list
        set prop [DictGet $props $file]
        # Check if file is local to the repository or external
        if {[RelativeLocal $repo_path $file] != ""} {
          set file_path [RelativeLocal $repo_path $file]
          set lib_name [file rootname $lib]
          if {$lib_name != $simset} {
            lappend prop "lib=$lib_name"
          }
          puts $list_file "$file_path $prop"
        } else {
          # File is not relative to repo or ext_path... Write a Warning and continue
          Msg Warning "The path of file $file is not relative to your repository. Please check!"
        }
      }
    }
  }
}


## @brief Write into a file, and if the file exists, it will append the string
#
# @param[out] File The log file to write into the message
# @param[in]  msg  The message text
proc WriteToFile {File msg} {
  set f [open $File a+]
  puts $f $msg
  close $f
}

## Write the resource utilization table into a a file (Vivado only)
#
#  @param[in]    input the input .rpt report file from Vivado
#  @param[in]    output the output file
#  @param[in]    project_name the name of the project
#  @param[in]    run synthesis or implementation
proc WriteUtilizationSummary {input output project_name run} {
  set f [open $input "r"]
  set o [open $output "a"]
  puts $o "## $project_name $run Utilization report\n\n"
  struct::matrix util_m
  util_m add columns 14
  util_m add row
  if { [GetIDEVersion] >= 2021.0 } {
    util_m add row "|          **Site Type**         |  **Used**  | **Fixed** | **Prohibited** | **Available** | **Util%** |"
    util_m add row "|  --- | --- | --- | --- | --- | --- |"
  } else {
    util_m add row "|          **Site Type**         | **Used** | **Fixed** | **Available** | **Util%** |"
    util_m add row "|  --- | --- | --- | --- | --- |"
  }

  set luts 0
  set regs 0
  set uram 0
  set bram 0
  set dsps 0
  set ios 0

  while {[gets $f line] >= 0} {
    if { ( [string first "| CLB LUTs" $line] >= 0 || [string first "| Slice LUTs" $line] >= 0 ) && $luts == 0 } {
      util_m add row $line
      set luts 1
    }
    if { ( [string first "| CLB Registers" $line] >= 0  || [string first "| Slice Registers" $line] >= 0  ) && $regs == 0} {
      util_m add row $line
      set regs 1
    }
    if { [string first "| Block RAM Tile" $line] >= 0 && $bram == 0 } {
      util_m add row $line
      set bram 1
    }
    if { [string first "URAM " $line] >= 0 && $uram == 0} {
      util_m add row $line
      set uram 1
    }
    if { [string first "DSPs" $line] >= 0 && $dsps == 0 } {
      util_m add row $line
      set dsps 1
    }
    if { [string first "Bonded IOB" $line] >= 0 && $ios == 0 } {
      util_m add row $line
      set ios 1
    }
  }
  util_m add row

  close $f
  puts $o [util_m format 2string]
  close $o
}

# Check Git Version when sourcing hog.tcl
if {[GitVersion 2.7.2] == 0 } {
  Msg Error "Found Git version older than 2.7.2. Hog will not work as expected, exiting now."
}

### Source the Create project file TODO: Do we need to source in hog.tcl?
#source [file dirname [info script]]/create_project.tcl
