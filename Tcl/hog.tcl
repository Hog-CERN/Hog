# @file
# Collection of Tcl functions used in vivado scripts


#################### Hog Wrappers ######################

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
	send_msg_id Hog:$title-0 {$vlevel} $msg
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
proc  CreateProject {proj dir fpga} {
    create_project -force $proj $dir -part $fpga
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


proc CreateReportStrategy {} {
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
	    if { [ string equal [get_report_configs -of_objects [get_runs impl_1] $DESIGN\_impl_1_route_report_timing_summary] "" ] } {
		create_report_config -report_name $DESIGN\_impl_1_route_report_timing_summary -report_type report_timing_summary:1.0 -steps route_design -runs impl_1
	    }
	    set obj [get_report_configs -of_objects [get_runs impl_1] $DESIGN\_impl_1_route_report_timing_summary]
	    if { $obj != "" } {
		Msg Info "Report timing created successfully"	
	    }
	    
	    # Create 'impl_1_route_report_utilization' report (if not found)
	    if { [ string equal [get_report_configs -of_objects [get_runs impl_1] $DESIGN\_impl_1_route_report_utilization] "" ] } {
		create_report_config -report_name $DESIGN\_impl_1_route_report_utilization -report_type report_utilization:1.0 -steps route_design -runs impl_1
	    }
	    set obj [get_report_configs -of_objects [get_runs impl_1] $DESIGN\_impl_1_route_report_utilization]
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
			set file_extension "VHDL_FILE -hdl_version VHDL_2008"
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
					Info ReadListFile 1 "List file $vhdlfile found in list file, recoursively opening it..."
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
						} elseif {info commands project_new] != ""} {
							#QUARTUS ONLY
							set file_type [FindFileType $vhdlfile]
							if {$lib ne ""} {
								set_global_assignment -name $file_type $vhdlfile  -library $lib
							} else {
								set_global_assignment  -name $file_type $vhdlfile 
							}
							#missing : ADDING QUARTUS FILE PROPERTIES

						}
						else {
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
# if the special string "ALL" is used, returns the global hash
proc GetVer {FILE path} {
    set SHA [GetHash $FILE $path]
    set status [catch {exec git tag --sort=taggerdate --contain $SHA} result]
    if {$status == 0} {
	if {[regexp {^ *$} $result]} {
	    Msg Warning "No tag contains $SHA"
	    set ver "none"
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
    if {[regexp {^b(?:\d+)v(\d+)\.(\d+).(\d+)-(\d+)$} $ver -> M m c n]} {
	# official not yet merged (beta)
	set M [format %02X $M]
	set m [format %02X $m]
	set c [format %04X $c]
	set n [format %04X $n]
	set official [format %04X 0xc000]
	set comm $SHA
    } elseif {[regexp {^v(\d+)\.(\d+).(\d+)$} $ver -> M m c]} {
	# official merged
	set M [format %02X $M]
	set m [format %02X $m]
	set c [format %04X $c]
	if {[regexp {^b(?:\d+)v(\d+)\.(\d+).(\d+)-(\d+)$} $un_ver -> M_u m_u c_u n]} {
	    Msg Info "Beta version $un_ver was found for official version $ver, using attempt number $n"
	    if {$M != $M_u || $m != $m_u || $c != $c_u} {
		Msg Warning "Beta version $un_ver and official version $ver do not match"		
	    }
	    set n [format %04X $n]

	} else {
	    Msg Warning "No beta version was found for official version $ver"
	    set n [format %04X 0]
	}
	
	set official [format %04X 0xc000]
	set comm $SHA
    } elseif {$ver == "none"} {
	# Unofficial done locally but properly committed
	set M [format %02X 0]
	set m [format %02X 0]
	set c [format %04X 0]
	set n [format %04X 0]
	set official [format %04X 0x2000]
	set comm $SHA
    } else {
	Msg Warning "Could not parse git describe: $ver"
	set M [format %02X 0]
	set m [format %02X 0]
	set c [format %04X 0]
	set n [format %04X 0]
	set official [format %04X 0x0008]
	set comm $SHA
    }
    set comm [format %07X 0x$comm]
    return [list $M$m$c $comm $official$n]
    cd $old_path
}
########################################################


## Tags the repository with a new version calculated on the basis of the previous tags
# Arguments:\n
# * merge_request_number: Gitlab merge request number to be used in candidate version
# * version_level:        0 if patch is to be increased (default), 1 if minor level is to be increase, 2 if major lav´e is to be increased, 3 or bigger is used to tag an official version from a candidate

proc TagRepository {merge_request_number {version_level 0}} {
    if [catch {exec git tag --sort=-creatordate} last_tag] {
	Msg Error "No Hog version tags found in this repository."
    } else {
	set vers [split $last_tag "\n"]
	set ver [lindex $vers 0]
	
	if {[regexp {^(?:b(\d+))?v(\d+)\.(\d+).(\d+)(?:-(\d+))?$} $ver -> mr M m p n]} {
	    if {$mr == "" } { # Tag is official, no b at the beginning
		Msg Info "Found official version $M.$m.$p."
		if {$version_level == 2} {
		    incr M
		    set m 0
		    set p 0
		} elseif {$version_level == 1} {
		    incr m
		    set p 0
		} elseif {$version_level >= 3} {
		    Msg Error "Last tag is already official, cannot make it more official than this"		    
		} else {
		    incr p
		}
		set mr $merge_request_number
		set n 0

	    } else { # Tag is not official, just increment the attempt
		Msg Info "Found candidate for version $M.$m.$p, merge request number $mr, attempt number $n."
		if {$mr != $merge_request_number} {
		    Msg Warning "Merge request number $merge_request_number differs from the one found in the tag $mr, will use $merge_request_number."
		    set mr $merge_request_number
		}
		incr n
	    }
	    if {$version_level >= 3} {
		Msg Info "Creating official version v$M.$m.$p..."
		set new_tag v$M.$m.$p 
		set tag_opt "-m 'Official_version_$M.$m.$p'"
	    } else {
		set new_tag b${mr}v$M.$m.$p-$n
		set tag_opt ""
	    }

	    # Tagging repositroy
	    if [catch {exec git tag {*}"$new_tag $tag_opt"} msg] {
		Msg Error "Could not create new tag $new_tag: $msg"
	    } else {
		Msg Info "New tag $new_tag created successully."
	    }
	    
	} else {
	    Msg Error "Could not parse tag: $last_tag"
	}
    }
    
    return [list $ver $new_tag]
}
########################################################

## Read a XML list file and evaluate the Git SHA and version of the listed XML files contained
#
# Arguments:
# * xml_lsit_file: file containing list of XML files with optional properties
# * path:          the path the XML files are referred to in the list file
proc GetXMLVer {xml_list_file path} {
    lassign [GetVer $xml_list_file $path] xml_ver xml_hash dummy
    scan [string range $xml_ver 0 1] %x M
    scan [string range $xml_ver 2 3] %x m
    scan [string range $xml_ver 4 7] %x c
    set xml_ver_formatted "$M.$m.$c"
    return [list $xml_hash $xml_ver_formatted]
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
    #	Msg Status "   Library: $lib: \n *******"
    #	foreach n $f {
    #	    Msg Status "$n"
    #	}
    #	
    #	Msg Status "*******"
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
    set list_path $top_path/list
    set libraries [dict create]
    set properties [dict create]
    
    puts $list_path
    set list_files [glob -directory $list_path "*"]
    
    foreach f $list_files {
    	lassign [SmartListFile $f $top_path 1] l p
	set libraries [dict merge $l $libraries]
	set properties [dict merge $p $properties]
    }

    #   dict for {lib f} $libraries {
    #	Msg Status "   Library: $lib: \n *******"
    #	foreach n $f {
    #	    Msg Status "$n"
    #	}
    #	
    #	Msg Status "*******"
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
