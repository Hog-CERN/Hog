# @file
# Collection of Tcl functions used in vivado scripts


#################### Hog Wrappers ######################

########################################################
## Namespace of all the project settings
#
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
    variable path_repo
    
    variable pre_synth_file
    variable post_synth_file
    variable post_impl_file
    variable post_bit_file
    variable tcl_path
    variable repo_path
    variable top_path
    variable list_path
    variable BUILD_DIR
    variable modelsim_path
    variable top_name
    variable synth_top_module
    variable synth_top_file
    variable user_ip_repo
    
    variable bin_file


    variable pre_synth
    variable post_synth
    variable post_impl
    variable post_bit
}

########################################################
## Display a Vivado/Quartus/Tcl-shell info message
#
# Arguments:
# * level: the severity level of the message given as string or integer: status/extra_info 0, info 1, warning 2, critical warning 3, error 4.
# * msg: the message text.
# * title: the name of the script displaying the message, if not given, the calling script name will be used by default.
#
proc Msg {level msg {title ""}} { 
    set level [string tolower $level]
    if {$level == 0 || $level == "status" || $level == "extra_info"} {
    set vlevel {STATUS}
    set qlevel extra_info
    } elseif {$level == 1 || $level == "info"} {
    set vlevel {INFO}
    set qlevel info 
    } elseif {$level == 2 || $level == "warning"} {
    set vlevel {WARNING}
    set qlevel warning  
    } elseif {$level == 3 || [string first "critical" $level] !=-1} {
    set vlevel {CRITICAL WARNING}
    set qlevel critial_warning
    } elseif {$level == 4 || $level == "error"} {
    set vlevel {ERROR}
    set qlevel "error"
    } else {
    puts "Hog Error: level $level not defined"
    exit -1
    }

    if {$title == ""} {set title [lindex [info level [expr [info level]-1]] 0]}
    if {[info commands send_msg_id] != ""} {
    # Vivado
    send_msg_id Hog:$title-0 $vlevel $msg
    } elseif {[info commands post_message] != ""} {
    # Quartus
    post_message -type $qlevel "Hog:$title $msg"
    } else {
    # Tcl Shell
    puts "*** Hog:$title $vlevel $msg"
    }
}
########################################################

## Write a into file, if the file exists, it will append the string
#
# Arguments:
# * File: The log file onto which write the message
# * msg:  The message text
proc WrtieToFile {File msg} {
    set f [open $File a+]
    puts $f $msg
    close $f
}

########################################################
proc  SetProperty {property value object} {
    if {[info commands set_property] != ""} {
        # Vivado
    set_property $property $value $object 
        
    } elseif {[info commands quartus_command] != ""} {
        # Quartus
    
    } else {
        # Tcl Shell
    puts "***DEBUG Hog:SetProperty $property to $value of $object"
    }


}
########################################################

########################################################
proc  GetProperty {property object} {
    if {[info commands get_property] != ""} {
        # Vivado
    return [get_property -quiet $property $object]
        
    } elseif {[info commands quartus_command] != ""} {
        # Quartus
    return ""
    } else {
        # Tcl Shell
    puts "***DEBUG Hog:GetProperty $property of $object"
    return "DEBUG_propery_value"
    }
}
########################################################

########################################################
proc  SetParameter {parameter value } {
    set_param $parameter $value
}
########################################################
proc add_top_file {top_module top_file sources} {
    if {[info commands launch_chipscope_analyzer] != ""} {
        #VIVADO_ONLY
        add_files -norecurse -fileset $sources $top_file
    } elseif {info commands project_new] != ""} {
        #QUARTUS ONLY
        set file_type [FindFileType $top_file]
        set hdl_version [FindVhdlVersion $top_file]
        set_global_assignment -name $file_type $top_file 
    } else {
        puts "Adding project top module $top_module" 
    }
}
########################################################
proc SetTopProperty {top_module sources} {
    Msg Info "Setting TOP property to $top_module module" 
    if {[info commands launch_chipscope_analyzer] != ""} {
        #VIVADO_ONLY
        set_property "top" $top_module $sources
    } elseif {info commands project_new] != ""} {
        #QUARTUS ONLY
        set_global_assignment -name TOP_LEVEL_ENTITY $top_module
    }

}

########################################################
proc CreateProject {} {
    if {[info commands create_project] != ""} {
            #VIVADO_ONLY
            if {$globalSettings::top_name != $globalSettings::DESIGN} {
            Msg Info "This project has got a flavour, the top module name will differ from the project name."
        }
        create_project -force $globalSettings::DESIGN $globalSettings::BUILD_DIR -part $globalSettings::FPGA

        ## Set project properties
        set obj [get_projects $globalSettings::DESIGN]
        set_property "simulator_language" "Mixed" $obj
        set_property "target_language" "VHDL" $obj
        set_property "compxlib.modelsim_compiled_library_dir" $globalSettings::modelsim_path $obj
        set_property "default_lib" "xil_defaultlib" $obj
        set_property "target_simulator" $globalSettings::SIMULATOR $obj
        
        ## Enable VHDL 2008
        set_param project.enableVHDL2008 1
        set_property "enable_vhdl_2008" 1 $obj

        ## Setting user IP repository to default Hog directory
        if [file exists $globalSettings::user_ip_repo] {
            Msg Info "Found directory $globalSettings::user_ip_repo, setting it as user IP repository..."
            set_property  ip_repo_paths $globalSettings::user_ip_repo [current_project]
        } else {
            Msg Info "$globalSettings::user_ip_repo not found, no user IP repository will be set." 
        }
    } elseif {[info commands project_new] != ""} {
        package require ::quartus::project
        #QUARTUS_ONLY
        if {[string equal $globalSettings::FAMILY "quartus_only"]} {
        Msg Error "You must specify a device Familty for Quartus"
        } else {
        file mkdir $globalSettings::BUILD_DIR
        cd $globalSettings::BUILD_DIR
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

    ## Set synthesis TOP
    if [file exists $globalSettings::synth_top_file.v] {
        Msg Info "Adding top file found in Top folder $globalSettings::synth_top_file.v" 
        add_top_file $globalSettings::synth_top_module $globalSettings::synth_top_file.v  $sources
    } elseif [file exists $globalSettings::synth_top_file.vhd] {
        Msg Info "Adding top file found in Top folder $globalSettings::synth_top_file.vhd" 
        add_top_file $globalSettings::synth_top_module $globalSettings::synth_top_file.vhd  $sources
    } else {
        Msg Info "No top file found in Top folder, please make sure that the top file - i.e. containing a module called $globalSettings::synth_top_module - is included in one of the libraries"     
    }

    SetTopProperty $globalSettings::synth_top_module $sources

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

    foreach f $list_files {
        SmartListFile $f $globalSettings::top_path
    }
}
########################################################


### SYNTH ###

proc configureSynth {} {
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
            set_property STEPS.SYNTH_DESIGN.TCL.PRE $globalSettings::pre_synth $obj
        } elseif {[info commands project_new] != ""} {
            #QUARTUS only
            set_global_assignment -name PRE_FLOW_SCRIPT_FILE quartus_sh:$globalSettings::pre_synth

        } else {
            Msg info "Configuring $globalSettings::pre_synth script before syntesis"
        }
    }

    ## set post synthesis script
    if {$globalSettings::post_synth_file ne ""} { 
        if {[info commands send_msg_id] != ""} {
            #Vivado Only
            set_property STEPS.SYNTH_DESIGN.TCL.POST $globalSettings::post_synth $obj
        } elseif {[info commands project_new] != ""} {
            #QUARTUS only
            set_global_assignment -name POST_MODULE_SCRIPT_FILE quartus_sh:$globalSettings::post_synth

        } else {
            Msg info "Configuring $globalSettings::post_synth script after syntesis"
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
    } elseif {[info commands project_new] != ""} {
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
        if {$globalSettings::bin_file == 1} {
            set_property "steps.write_bitstream.args.bin_file" "1" $obj
        } else {
           set_property "steps.write_bitstream.args.bin_file" "0" $obj
        }
    } elseif {[info commands project_new] != ""} {
            #QUARTUS only
            set obj ""
    }

    ## set post routing script
    if {$globalSettings::post_impl_file ne ""} { 
        if {[info commands send_msg_id] != ""} {
            #Vivado Only
            set_property STEPS.ROUTE_DESIGN.TCL.POST $globalSettings::post_impl $obj
        } elseif {[info commands project_new] != ""} {
            #QUARTUS only
            set_global_assignment -name POST_MODULE_SCRIPT_FILE quartus_sh:$globalSettings::post_impl

        } else {
            Msg info "Configuring $globalSettings::post_impl script after implementation"
        }
    } 

    ## set post write bitstream script
    if {$globalSettings::post_bit_file ne ""} { 
        if {[info commands send_msg_id] != ""} {
            #Vivado Only
            set_property STEPS.WRITE_BITSTREAM.TCL.POST $globalSettings::post_bit $obj
        } elseif {[info commands project_new] != ""} {
            #QUARTUS only
            set_global_assignment -name POST_FLOW_SCRIPT_FILE quartus_sh:$globalSettings::post_bit

        } else {
            Msg info "Configuring $globalSettings::post_bit script after bitfile generation"
        }
    }

    CreateReportStrategy $globalSettings::DESIGN $obj
}




proc configureSimulation {} {
    if {[info commands send_msg_id] != ""} {

        ##############
        # SIMULATION #
        ##############
        Msg Info "Setting load_glbl parameter to false for every fileset..."
        foreach f [get_filesets -quiet *_sim] {
            set_property -name {xsim.elaborate.load_glbl} -value {false} -objects $f
        }
    }  elseif {[info commands project_new] != ""} {
            #QUARTUS only
            #TO BE DONE

    } else {
        Msg info "Configuring simulation"
    }
}

proc configureProperties {} {
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


proc upgradeIP {} {
    if {[info commands send_msg_id] != ""} {
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
    } elseif {[info commands project_new] != ""} {
            #QUARTUS only
            #TO BE DONE

    } else {
        Msg info "Upgrading IPs"
    }
}




proc GetProject {proj} {
    if {[info commands get_projects] != ""} {
        # Vivado
    return [get_projects $proj]
        
    } elseif {[info commands quartus_command] != ""} {
        # Quartus
    return ""
    } else {
        # Tcl Shell
    puts "***DEBUG Hog:GetProject $project"
    return "DEBUG_project"
    }

}

proc GetRun {run} {
    if {[info commands get_projects] != ""} {
        # Vivado
    return [get_runs -quiet $run]
        
    } elseif {[info commands quartus_command] != ""} {
        # Quartus
    return ""
    } else {
        # Tcl Shell
    puts "***DEBUG Hog:GetRun $run"
    return "DEBUG_run"
    }
}

proc GetFile {file} {
        if {[info commands get_files] != ""} {
        # Vivado
    return [get_files $file]
        
    } elseif {[info commands quartus_command] != ""} {
        # Quartus
    return ""
    } else {
        # Tcl Shell
    puts "***DEBUG Hog:GetFile $file"
    return "DEBUG_file"
    }
}

proc CreateFileSet {fileset} {
    set a  [create_fileset -srcset $fileset]
    return  $a
}

proc GetFileSet {fileset} {
    set a  [get_filesets $fileset]
    return  $a
}

proc AddFile {file fileset} {
    add_files -norecurse -fileset $fileset $file 
}


proc CreateReportStrategy {DESIGN obj} {
    if {[info commands create_report_config] != ""} {
    ## Viavado Report Strategy
    if {[string equal [get_property -quiet report_strategy $obj] ""]} {
        # No report strategy needed
        Msg Info "No report strategy needed for implementation"
        
    } else {
        # Report strategy needed since version 2017.3
        set_property -name "report_strategy" -value "Vivado Implementation Default Reports" -objects $obj
        
        set reports [get_report_configs -of_objects $obj]
        if { [llength $reports ] > 0 } {
        delete_report_config [get_report_configs -of_objects $obj]
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
    }
    } else {
    puts "Won't create any report strategy, not in Vivado"
    } 
}
########################################################


proc GetRepoPath {} {
    return "[file normalize [file dirname [info script]]]/../../"
}
########################################################

## Return 1 if the system Git version is greater or equal to the target
proc GitVersion {target_version} {
    set ver [split $target_version "."]
    set v [exec git --version]
    Msg Info "Found Git version: $v"
    set current_ver [split [lindex $v 2] "."]
    set target [expr [lindex $ver 0]*100000 + [lindex $ver 1]*100 + [lindex $ver 2]]
    set current [expr [lindex $current_ver 0]*100000 + [lindex $current_ver 1]*100 + [lindex $current_ver 2]]

    return [expr $target <= $current]
}
########################################################

## Return 1 if the system Doxygen version is greater or equal to the target
proc DoxygenVersion {target_version} {
    set ver [split $target_version "."]
    set v [exec doxygen --version]
    Msg Info "Found doxygen version: $v"
    set current_ver [split $v "."]
    set target [expr [lindex $ver 0]*100000 + [lindex $ver 1]*100 + [lindex $ver 2]]
    set current [expr [lindex $current_ver 0]*100000 + [lindex $current_ver 1]*100 + [lindex $current_ver 2]]

    return [expr $target <= $current]
}
########################################################

## Quartus only: determine file type from extension
#
## Return FILE_TYPE
proc FindFileType {file_name} {
    set extension [file ext $file_name]
    switch $extension {
        .vhd {
            set file_extension "VHDL_FILE"
        }
        .v {
            set file_extension "VERILOG_FILE"
        }
        .sv {
            set file_extension "SYSTEMVERILOG_FILE"
        }
        .ip {
            set file_extension "IP_FILE"
        }
        .ip {
            set file_extension "COMMAND_MACRO_FILE"
        }
        default {
            set file_extension "ERROR"  
            Error FindFileType 0 "Unknown file extension $extension"
        }
    }

    return $file_extension
}

proc FindVhdlVersion {file_name} {
    set extension [file ext $file_name]
    switch $extension {
        .vhd {
            set vhdl_version "-hdl_version VHDL_2008"
        }
        default {
            set vhdl_version ""
        }
    }

    return $vhdl_version
}



########################################################

## Read a list file and adds the files to Vivado/Quartus, adding the additional information as file type.
#
# Additional information is provided with text separated from the file name with one or more spaces
#
# Arguments:
# * lsit_file: file containing vhdl list with optional properties
# * path     : path the vhdl file are referred to in the list file
# * lib      : name of the library files will be added to
# * src      : name of VivadoFileSet files will be added to
# * no_add   : if a value is specified, the files will added to memory only, not to the project
proc ReadListFile {list_file path lib src {no_add 0}} {
    set list_file 
    set fp [open $list_file r]
    set file_data [read $fp]
    close $fp
    set list_file_ext [file ext $list_file]

    set libraries [dict create]
    set properties [dict create]

    #  Process data file
    set data [split $file_data "\n"]
    set n [llength $data]
    Msg Info "$n lines read from $list_file"
    set cnt 0
    foreach line $data {
        if {![regexp {^ *$} $line] & ![regexp {^ *\#} $line] } { #Exclude empty lines and comments
            set file_and_prop [regexp -all -inline {\S+} $line]
            set vhdlfile [lindex $file_and_prop 0]
            set vhdlfile "$path/$vhdlfile"
            if {[file exists $vhdlfile]} {
                set vhdlfile [file normalize $vhdlfile]
                set extension [file ext $vhdlfile]
                if { [lsearch {.src .sim .con .sub} $extension] >= 0 } {
                    Msg Info "List file $vhdlfile found in list file, recoursively opening it..."
                        lassign [SmartListFile $vhdlfile $path $no_add] l p
                    set libraries [dict merge $l $libraries]
                    set properties [dict merge $p $properties]          
                } else {


                    ### Set file properties
                    set prop [lrange $file_and_prop 1 end]
                    dict lappend properties $vhdlfile $prop

                    #Adding IP library
                    if {[string equal $extension ".xci"] || [string equal $extension ".ip"] } {
                        dict lappend libraries "IP" $vhdlfile
                    } else {
                        dict lappend libraries $lib $vhdlfile
                    }

                    if {$no_add == 0} {
                        if {[info commands add_files] != ""} {
                            #VIVADO_ONLY

                            add_files -norecurse -fileset $src $vhdlfile 
                            
                            set file_obj [get_files -of_objects [get_filesets $src] [list "*$vhdlfile"]]

                            #ADDING LIBRARY
                            if {$lib ne ""} {
                                set_property -name "library" -value $lib -objects $file_obj
                            }

                            #ADDING FILE PROPERTIES
                            if {[lsearch -inline -regex $prop "2008"] >= 0} {
                                Msg Info "Setting filetype VHDL 2008 for $vhdlfile"
                                set_property -name "file_type" -value "VHDL 2008" -objects $file_obj
                            }
                            
                            # XDC
                            if {[lsearch -inline -regex $prop "XDC"] >= 0 || [file ext $vhdlfile] == ".xdc"} {
                                Msg Info "Setting filetype XDC for $vhdlfile"
                                set_property -name "file_type" -value "XDC" -objects $file_obj
                            }

                            # Not used in synthesis
                            if {[lsearch -inline -regex $prop "nosynth"] >= 0} {
                                Msg Info "Setting not used in synthesis for $vhdlfile..."
                                set_property -name "used_in_synthesis" -value "false" -objects $file_obj
                            }

                            # Not used in implementation
                            if {[lsearch -inline -regex $prop "noimpl"] >= 0} {
                                Msg Info "Setting not used in implementation for $vhdlfile..."
                                set_property -name "used_in_implementation" -value "false" -objects $file_obj
                            }

                            # Not used in simulation
                            if {[lsearch -inline -regex $prop "nosim"] >= 0} {
                                Msg Info "Setting not used in simulation for $vhdlfile..."
                                set_property -name "used_in_simulation" -value "false" -objects $file_obj
                            }


                            ## Simulation properties
                            # Top simulation module
                            set top_sim [lindex [split [lsearch -inline -regex $prop topsim=] =] 1]
                            if { $top_sim != "" } {
                                Msg Info "Setting $top_sim as top module for simulation file set $src..."
                                set_property "top"  $top_sim [get_filesets $src]
                                current_fileset -simset [get_filesets $src]
                            }

                            # Wave do file
                            set wave_file [lindex [split [lsearch -inline -regex $prop wavefile=] =] 1]
                            if { $wave_file != "" } {
                                set r_path [GetRepoPath]
                                set file_name "$r_path/sim/$wave_file"
                                Msg Info "Setting $file_name as wave do file for simulation file set $src..."
                                # check if file exists...
                                if [file exists $file_name] {
                                set_property "modelsim.simulate.custom_wave_do" $file_name [get_filesets $src]
                                } else {
                                Msg Warning "File $file_name was not found."
                                }
                            }
                            
                            #Do file
                            set do_file [lindex [split [lsearch -inline -regex $prop dofile=] =] 1]
                            if { $do_file != "" } {
                                set r_path [GetRepoPath]
                                set file_name "$r_path/sim/$do_file"
                                Msg Info "Setting $file_name as udo file for simulation file set $src..."
                                if [file exists $file_name] {
                                    set_property "modelsim.simulate.custom_udo" $file_name [get_filesets $src]
                                } else {
                                    Msg Warning "File $file_name was not found."
                                }
                            }
                        } elseif {[info commands project_new] != ""} {
                            #QUARTUS ONLY
                            set file_type [FindFileType $vhdlfile]
                            set hdl_version [FindVhdlVersion $vhdlfile]
                            if {$lib ne ""} {
                                Msg Warning "set_global_assignment -name $file_type $vhdlfile -library $lib "
                                set_global_assignment -name $file_type $vhdlfile  -library $lib 
                            } else {
                                set_global_assignment  -name $file_type $vhdlfile  $hdl_version
                            }
                            #missing : ADDING QUARTUS FILE PROPERTIES

                        } else {
                            #default
                            puts "Adding file $vhdlfile to project into library $lib"
                        }
                    }
                    incr cnt
                }
            } else {
                Msg Error  "File $vhdlfile not found"
            }
        }
    }
    Msg Info "$cnt file/s added to $lib..."
    return [list $libraries $properties]
}
########################################################

## Read a list file and adds the files to Vivado/Quartus, adding the additional information as file type.
# This procedure extracts the Vivado fileset and the library name from the list-file name.
#
# Additional information is provided with text separated from the file name with one or more spaces
#
# Arguments:
# * lsit_file: file containing vhdl list with optional properties
# * path:      the path the vhdl file are referred to in the list file
# 
# list_file should be formatted as follows:
# LIB_NAME.FILE_SET
#
# LIB_NAME : the Vivado library you want to include the file to
# FILE_SET : the Vivado file set you want to include the file to:
# * .src : for source files (corresponding to sources_1)
# * .sub : for source files in a git submodule (corresponding to sources_1)
# * .sim : for simulation files (corresponding to sim_1)
# * .con : for constraint files (corresponding to constrs_1)
# any other file extension will cause an error

proc SmartListFile {list_file path {no_add 0}} {
    set ext [file extension $list_file]
    set lib [file rootname [file tail $list_file]]
    switch $ext {
    .src {
        set file_set "sources_1"
    }
    .sub {
        set file_set "sources_1"
    }
    .sim {
        set file_set "$lib\_sim"
        # if this simulation fileset was not created we do it now
        if {[string equal [get_filesets -quiet $file_set] ""]} {
        create_fileset -simset $file_set
        set simulation  [get_filesets $file_set]
        set_property -name {modelsim.compile.vhdl_syntax} -value {2008} -objects $simulation
        set_property SOURCE_SET sources_1 $simulation
        }
    }
    .con {
        set file_set "constrs_1"
    }
    .ext {
        set file_set "sources_1"
        # Msg Info "Reading sources from file $list_file, lib: $lib, file-set: $file_set"
        # return [ReadExternalListFile $list_file $path $lib $file_set $no_add]
    }   
    default {
        Msg Error "Unknown extension $ext"
    }
    }
    Msg Info "Reading sources from file $list_file, lib: $lib, file-set: $file_set"
    return [ReadListFile $list_file $path $lib $file_set $no_add]
}
########################################################

## Get git SHA of a vivado library
#
# Arguments:\n
# * lib: the name of the library whose latest commit hash will be returned
#
# if the special string "ALL" is used, returns the global hash
proc GetHashLib {lib} {
    if {$lib eq "ALL"} {
    set ret [exec git log --format=%h -1]
    } else {
    set ret [exec git log --format=%h -1 {*}[get_files -filter LIBRARY==$lib]]
    }

    return $ret
}
########################################################

## Recursively gets file names from list file
#
# Arguments:\n
# * FILE: list file to open
# * path: the path the files are referred to in the list file
#
# if the list file contains files with extension .src .sim .con .sub, it will recursively open them
proc GetFileList {FILE path} {
    set fp [open $FILE r]
    set file_data [read $fp]
    close $fp
    #  Process data file
    set data [split $file_data "\n"]
    foreach line $data {
    if {![regexp {^ *$} $line] & ![regexp {^ *\#} $line] } { #Exclude empty lines and comments
        set file_and_prop [regexp -all -inline {\S+} $line]
        set vhdlfile [lindex $file_and_prop 0]
        set vhdlfile "$path/$vhdlfile"
        if {[file exists $vhdlfile]} {
        set extension [file ext $vhdlfile]
        if { [lsearch {.src .sim .con .sub} $extension] >= 0 } {
            lappend lista {*}[GetFileList $vhdlfile $path]]
        } else {
        lappend lista $vhdlfile
        }
    } else { 
        Msg Warning "File $vhdlfile not found"
    }
    }
}

return $lista
}
########################################################

## Get git SHA of a subset of list file
#
# Arguments:\n
# * FILE: list file or path containing the subset of files whose latest commit hash will be returned
# * path:      the path the vhdl files are referred to in the list file (not used if FILE is a path or "ALL")
#
# if the special string "ALL" is used, returns the global hash
proc GetHash {FILE path} {
    if {$FILE eq "ALL"} {
    set ret [exec git log --format=%h -1]
    } elseif {[file isfile $FILE]} {
    set lista [GetFileList $FILE $path]
    set ret [exec git log --format=%h -1 -- {*}$lista ]
    
    } elseif {[file isdirectory $FILE]} {

    set ret [exec git log --format=%h -1 $FILE ]
    
    } else {
    puts "ERROR: $FILE not found"
    set ret 0
    }
    return $ret
    
}
########################################################


## Get git version and commit hash of a subset of files
# Arguments:\n
## * FILE: list file or path containing the subset of files whose latest commit hash will be returned
# * path:      the path the vhdl file are referred to in the list file (not used if FILE is a path or "ALL")
#
# if the special string "ALL" is used, returns the global hash of the path specified in path
proc GetVer {FILE path} {
    set SHA [GetHash $FILE $path]
    set path [file normalize $path]
    set status [catch {exec git tag --sort=taggerdate --contain $SHA} result]
    if {$status == 0} {
    if {[regexp {^ *$} $result]} {
        if [catch {exec git tag --sort=-creatordate} last_tag] {
        Msg CriticalWarning "No Hog version tags found in this repository ($path)."
        set ver v0.0.0
        } else {
	    set tags [split $last_tag "\n"]
	    set tag [lindex $tags 0]
	    lassign [ExtractVersionFromTag $tag] M m p n mr
        if {$mr == -1} {
            incr p
            Msg Info "No tag contains $SHA for $FILE ($path), will use most recent tag $tag. As this is an official tag, patch will be incremented to $p."
        } else {
            Msg Info "No tag contains $SHA for $FILE ($path), will use most recent tag $tag. As this is a candidate tag, the patch level will be kept at $p."
        }
        set ver v$M.$m.$p
        
        }

    } else {
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
    Msg Warning "Error while trying to find tag for $SHA in file: $FILE, path: [pwd]"
    set ver "error: $result"
    }

    lassign [ExtractVersionFromTag $ver] M m c n mr
    
    if {$mr > -1} { # Candidate tab
	set M [format %02X $M]
	set m [format %02X $m]
	set c [format %04X $c]
	set n [format %04X $n]
	set comm $SHA
    } elseif { $M > -1 } { # official tag
	set M [format %02X $M]
	set m [format %02X $m]
	set c [format %04X $c]
	set n [format %04X 0]
	set comm $SHA
    } else {
	Msg Warning "Tag does not contain a properly formatted version: $ver in repository containing $FILE"
	set M [format %02X 0]
	set m [format %02X 0]
	set c [format %04X 0]
	set n [format %04X 0]
	set comm $SHA
    }
    set comm [format %07X 0x$comm]
    return [list $M$m$c $comm]
    cd $old_path
}
########################################################


## Convert hex version to M.m.p string
# Arguments:\n
# version: the version (in 32-bt hexadecimal format 0xMMmmpppp) to be converted

proc HexVersionToString {version} {
    scan [string range $version 0 1] %x M
    scan [string range $version 2 3] %x m
    scan [string range $version 4 7] %x c
    return "$M.$m.$c"
}
########################################################


## Tags the repository with a new version calculated on the basis of the previous tags
# Arguments:\n
# * tag: a tag in the Hog format: v$M.$m.$p or b$(mr)v$M.$m.$p-$n

proc ExtractVersionFromTag {tag} {
    if {[regexp {^(?:b(\d+))?v(\d+)\.(\d+).(\d+)(?:-(\d+))?$} $tag -> mr M m p n]} {
	if {$mr eq ""} {
	    set mr -1
	    set n -1
	}
    } else {
	Msg Warning "Repository tag $tag is not in a Hog-compatible format."
	set mr -1
	set M -1
	set m -1
	set p -1
	set n -1    
    }
    return [list $M $m $p $n $mr]
}


## Tags the repository with a new version calculated on the basis of the previous tags
# Arguments:\n
# * merge_request_number: Gitlab merge request number to be used in candidate version
# * version_level:        0 if patch is to be increased (default), 1 if minor level is to be increase, 2 if major level is to be increased, 3 or bigger is used to trasform a candidate for a version (starting with b) into an official version

proc TagRepository {{merge_request_number 0} {version_level 0}} {
    if [catch {exec git tag --sort=-creatordate} last_tag] {
	Msg Error "No Hog version tags found in this repository."
    } else {
	set tags [split $last_tag "\n"]
	set tag [lindex $tags 0]
	lassign [ExtractVersionFromTag $tag] M m p n mr
    
	if { $M > -1 } { # M=-1 means that the tag could not be parsed following a Hog format
	    if {$mr == -1 } { # Tag is official, no b at the beginning (and no merge request number at the end)
		Msg Info "Found official version $M.$m.$p."
		if {$version_level == 2} {
		    incr M
		    set m 0
		    set p 0
		    set new_tag b${merge_request_number}v$M.$m.$p
		    set tag_opt ""
		    if {$merge_request_number <= 0} {
			Msg Error "You should specify a valid merge request number not to risk to fail beacuse of duplicated tags"
			return -1
		    }
		    
		} elseif {$version_level == 1} {
		    incr m
		    set p 0
		    set new_tag b${merge_request_number}v$M.$m.$p
		    set tag_opt ""
		    if {$merge_request_number <= 0} {
			Msg Error "You should specify a valid merge request number not to risk to fail beacuse of duplicated tags"
			return -1
		    }
		    
		} elseif {$version_level >= 3} {
            # Version level >= 3 is used to create official tags from beta tags
		    incr p
		    #create official tag
		    Msg Info "No major/minor version increase, new tag will be v$M.$m.$p..."
		    set new_tag v$M.$m.$p
		    set tag_opt "-m 'Official_version_$M.$m.$p'"
		    
		}
		
	    } else { # Tag is not official
		#Not official, do nothing unless version level is >=3, in which case convert the unofficial to official
		Msg Info "Found candidate version for $M.$m.$p."
		if {$version_level >= 3} {
		    Msg Info "New tag will be an official version v$M.$m.$p..."
		    set new_tag v$M.$m.$p
		    set tag_opt "-m 'Official_version_$M.$m.$p'"
		}
	    }
	    
        # Tagging repositroy
	    if [info exists new_tag] {
		Msg Info "Tagging repository with $new_tag..."
		if [catch {exec git tag {*}"$new_tag $tag_opt"} msg] {
		    Msg Error "Could not create new tag $new_tag: $msg"
		} else {
		    Msg Info "New tag $new_tag created successully."
		}
	    } else {
		set new_tag $tag
		Msg Info "Tagging is not needed"
	    }
	} else {
	    Msg Error "Could not parse tag: $tag"
	}
    }
    
    return [list $tag $new_tag]
}
########################################################

## Read a XML list file and copy files to destination
#
# Additional information is provided with text separated from the file name with one or more spaces
#
# Arguments:
# * lsit_file:   file containing list of XML files with optional properties
# * path:        the path the XML files are referred to in the list file
# * dst:         the path the XML files must be copyed to
# * xml_version: the M.m.p version to be used to replace the __VERSION__ placeholder in any of the xml files
# * xml_sha:     the Git-SHA to be used to replace the __GIT_SHA__ placeholder in any of the xml files

proc CopyXMLsFromListFile {list_file path dst {xml_version "0.0.0"} {xml_sha "00000000"} } {
    set list_file
    set fp [open $list_file r]
    set file_data [read $fp]
    close $fp
    #  Process data file
    set data [split $file_data "\n"]
    set n [llength $data]
    Msg Info "$n lines read from $list_file"
    set cnt 0
    foreach line $data {
    if {![regexp {^ *$} $line] & ![regexp {^ *\#} $line] } { #Exclude empty lines and comments
        set file_and_prop [regexp -all -inline {\S+} $line]
        set xmlfile [lindex $file_and_prop 0]
        set xmlfile "$path/$xmlfile"
        if {[llength $file_and_prop] > 1} {
        set vhdlfile [lindex $file_and_prop 1]
        set vhdlfile "$path/$vhdlfile"      
        } else {
        set vhdlfile 0
        }
        if {[file exists $xmlfile]} {
        set xmlfile [file normalize $xmlfile]
        Msg Info "Copying $xmlfile to $dst..."
        set in  [open $xmlfile r]
        set out [open $dst/[file tail $xmlfile] w]
        
        while {[gets $in line] != -1} {
            set new_line [regsub {(.*)__VERSION__(.*)} $line "\\1$xml_version\\2"]
            set new_line2 [regsub {(.*)__GIT_SHA__(.*)} $new_line "\\1$xml_sha\\2"]         
            puts $out $new_line2
        }
        close $in
        close $out
        incr cnt
        if {[llength $file_and_prop] > 1} {
            set prop [lrange $file_and_prop 1 end]
            set type [lindex $prop 0]
        }
        } else {
        Msg Warning "XML file $xmlfile not found"
        }
        
    }
    }
    Msg Info "$cnt file/s copied"
}
########################################################

## Returns the dst path relative to base
## Arguments:
# * base   the path with respect to witch the dst path is calculated                             
# * dst:   the path to be calculated with respect to base

proc relative {base dst} {
    if {![string equal [file pathtype $base] [file pathtype $dst]]} {
        return -code error "Unable to compute relation for paths of different pathtypes: [file pathtype $base] vs. [file pathtype $dst], ($base vs. $dst)"
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
########################################################                                                                                                                                                  
## Returns a list of 2 dictionaries: libraries and properties
# - libraries has library name as keys and a list of filenames as values
# - properties has as file names as keys and a list of properties as values
#
# Files, libraries and properties are extracted from the current Vivado project

proc GetProjectFiles {} {
    
    set all_files [get_files]
    set libraries [dict create]
    set properties [dict create]

    foreach f $all_files {
    if { [get_property  IS_GENERATED [get_files $f]] == 0} {
        set f [file normalize $f]
        lappend files $f 
        set type  [get_property FILE_TYPE [get_files $f]]
        set lib [get_property LIBRARY [get_files $f]]

        # Type can be complex like VHDL 2008, in that case we want the second part to be a property
        if {[llength $type] > 1} {
        set prop [lrange $type 1 [llength $type]]
        set type [lindex $type 0]
        } else {
        set prop ""
        } 

        #check where the file is used and add it to prop
        if {[string equal $type "VHDL"]} {
        dict lappend libraries $lib $f
        dict lappend properties $f $prop
        } elseif {[string equal $type "IP"]} {
        dict lappend libraries "IP" $f
        } elseif {[string equal $type "XDC"]} {
        dict lappend libraries "XDC" $f
        dict lappend properties $f "XDC"        
        } else {
        dict lappend libraries "OTHER" $f
        }
        
    }
    
    }

    #    dict for {lib f} $libraries {
    #   Msg Status "   Library: $lib: \n *******"
    #   foreach n $f {
    #       Msg Status "$n"
    #   }
    #   
    #   Msg Status "*******"
    #    }
    
    return [list $libraries $properties]
}
########################################################


## Returns a list of 2 dictionaries: libraries and properties
# - libraries has library name as keys and a list of filenames as values
# - properties has as file names as keys and a list of properties as values
#
# Files, libraries and properties are extracted from the project's Hog list files
#
# Arguments:
# - proj_path: the path of the Vivado project xpr file inside the Hog repository.
#     If not given it will be automatically evaluated if the function is called from within Vivado.

proc GetHogFiles {{proj_path 0}} {
    if {$proj_path == 0} {
    set proj_path [get_property DIRECTORY [get_projects]]
    Msg Info "Project path is: $proj_path"
    }
    set proj_name [file tail $proj_path]
    Msg Info "Project name is: $proj_name"
    set top_path [file normalize $proj_path/../../Top/$proj_name]
    set list_path $globalSettings::top_path/list
    set libraries [dict create]
    set properties [dict create]
    
    puts $globalSettings::list_path
    set list_files [glob -directory $globalSettings::list_path "*"]
    
    foreach f $list_files {
        lassign [SmartListFile $f $globalSettings::top_path 1] l p
    set libraries [dict merge $l $libraries]
    set properties [dict merge $p $properties]
    }

    #   dict for {lib f} $libraries {
    #   Msg Status "   Library: $lib: \n *******"
    #   foreach n $f {
    #       Msg Status "$n"
    #   }
    #   
    #   Msg Status "*******"
    #   }    

    return [list $libraries $properties]
}
########################################################

## Forces all the Vivado runs to look up to date, useful before write bitstream
#

proc ForceUpToDate {} {
    Msg Info "Forcing all the runs to look up to date..."
    set runs [get_runs]
    foreach r $runs {
    Msg Info "Forcing $r..."
    set_property needs_refresh false [get_runs $r]
    }
}
########################################################

## Copy IP generated files from/to an EOS repository
# Arguments:\n
# - what_to_do: can be "push", if you want to copy the local IP synth result to eos or "pull" if you want to copy the files from eos to your local repository
# - xci_file: the local IP xci file
# - ip_path: the path of directory you want the IP to be saved on eos

proc HandleIP {what_to_do xci_file ip_path runs_dir} {
    if {!($what_to_do eq "push") && !($what_to_do eq "pull")} {
	Msg Error "You must specify push or pull as first argument."
    }
    
    set ip_path_path [file normalize $ip_path/..]
    if  {[catch {exec eos ls $ip_path_path} result]} {
	Msg CriticalWarning "Could not find mother directory for $ip_path: $ip_path_path."
	return -1
    } else {
	if  {[catch {exec eos ls $ip_path} result]} {
	    Msg Info "IP repostory path on eos does not exist, creating it now..."
	    exec eos mkdir $ip_path
	} else {
	    Msg Info "IP repostory path on eos is set to: $ip_path"
	}
    }
    
    if !([file exists $xci_file]) {
	Msg CriticalWarning "Could not find $xci_file."
	return -1
    }
    

    set xci_path [file dir $xci_file]
    set xci_name [file tail $xci_file]
    set xci_ip_name [file root [file tail $xci_file]]
    set xci_dir_name [file tail $xci_path]
    
    set hash [lindex [exec md5sum $xci_file] 0]
    set file_name $xci_name\_$hash
    
    Msg Info "Preparing to handle IP: $xci_name..."

    if {$what_to_do eq "push"} {
	if  {[catch {exec eos ls $ip_path/$file_name} result]} {
	    set ip_synth_files [glob -nocomplain $runs_dir/$xci_ip_name*]
	    if {[llength $ip_synth_files] > 0} {
		Msg Info "Found some IP synthesised files matching $ip_path/$file_name*"
		Msg Info "Creating IP directories on EOS..."
		exec  eos mkdir -p "$ip_path/$file_name/synthesized"
		Msg Info "Copying generated files for $xci_name..."
		exec -ignorestderr eos cp -r $xci_path $ip_path/$file_name/
		exec eos mv $ip_path/$file_name/$xci_dir_name $ip_path/$file_name/generated
		Msg Info "Copying synthesised files for $xci_name..."
		exec -ignorestderr eos cp -r $ip_synth_files $ip_path/$file_name/synthesized 
	    } else {
		Msg Warning "Could not find synthesized files matching $ip_path/$file_name*"
	    }
	} else {
	    Msg Info "IP already in the repository, will not copy..."
	}
    } elseif {$what_to_do eq "pull"} {
	if  {[catch {exec eos ls $ip_path/$file_name} result]} {
	    Msg Info "Nothing for $xci_name was found in the repository, cannot pull."
	    return -1
	    
	} else {
	    Msg Info "IP $xci_name found in the repository, copying it locally..."
	    set ret_g [catch {exec eos ls $ip_path/$file_name/generated/*} ip_gen_files]
	    set ret_s [catch {exec eos ls $ip_path/$file_name/synthesized/*} ip_syn_files]
	    #puts "ret g: $ret_g"
	    Msg Status "Generated files found for $xci_ip_name ($ret_g):\n $ip_gen_files"
	    #puts "ret s: $ret_s"
	    Msg Status "Synthesised files found for $xci_ip_name ($ret_s):\n $ip_syn_files"

	    if  {($ret_g == 0) && ([llength $ip_gen_files] > 0)} {
		exec -ignorestderr eos cp -r $ip_path/$file_name/generated/* $xci_path
	    } else {
		Msg Warning "Cound not find generated IP files on EOS path" 
	    }

	    if  {($ret_s == 0) && ([llength $ip_syn_files] > 0)} {
		exec -ignorestderr eos cp -r $ip_path/$file_name/synthesized/* $runs_dir	
	    } else {
		Msg Warning "Cound not find synthesized IP files on EOS path" 
	    }

	

	} 
    }
    
    return 0   
}
########################################################

## Checks that "ref" in .gitlab-ci.yml actually matches the gitlab-ci file in the 
##  Hog submodule
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
	if [file exists .gitlab-ci.yml] {
		#get .gitlab-ci ref

		set YML_REF ""
		set yamlDict [::yaml::yaml2dict -file .gitlab-ci.yml]
		dict for {dictKey dictValue} $yamlDict {
			#looking for Hog include in .gitlab-ci.yml
			if {"$dictKey" == "include" && [lsearch [split $dictValue " {}"] "hog/Hog" ] != "-1"} {
				set YML_REF [lindex [split $dictValue " {}"]  [expr [lsearch -dictionary [split $dictValue " {}"] "ref"]+1 ] ]
			}
		}

		if {$YML_REF == ""} {
			Msg Warning "Hog version not specified in the .gitlab-ci.yml. Assuming that master branch is used"
			cd Hog
			set YML_REF_F [exec git name-rev --tags --name-only origin/master]
			cd ..
		} else {
			set YML_REF_F [regsub -all "'" $YML_REF ""]
		}

		#getting Hog repository tag and commit
		cd "Hog"
		set HOGYML_SHA [exec git log --format=%H -1 --  gitlab-ci.yml ]
		if { [catch {exec git log --format=%H -1 $YML_REF_F gitlab-ci.yml} EXPECTEDYML_SHA]} {
			if { [catch {exec git log --format=%H -1 origin/$YML_REF_F gitlab-ci.yml} EXPECTEDYML_SHA]} {
				Msg $MSG_TYPE "Error in project .gitlab-ci.yml. ref: $YML_REF not found"		
				set EXPECTEDYML_SHA ""
			}
 
		} 
		if  {!($EXPECTEDYML_SHA eq "")} {
			
			if {$HOGYML_SHA == $EXPECTEDYML_SHA} {
				Msg Info "Hog gitlab-ci.yml SHA matches with the \"ref\" in the .gitlab-ci.yml."

			} else {
				Msg $MSG_TYPE "HOG gitlab-ci.yml SHA mismatch. 
From Hog submodule: $HOGYML_SHA
From .gitlab-ci.yml: $EXPECTEDYML_SHA 
You can fix this in 2 ways: (A) by changing the ref in your repository or (B) by changing the Hog submodule commit.
\tA) edit project .gitlab-ci.yml ---> ref: '$HOGYML_SHA'
\tB) modify Hog submodule: git checkout $EXPECTEDYML_SHA"
			}
		}
	} else {
		Msg Info ".gitlab-ci.yml not found in $repo_path. Skipping this step"
	}

	cd "$thisPath"
}

