# @file
# Collection of Tcl functions used in vivado scripts

########################################################

## Display Vivado Info message
#
# Arguments:
# * title: The name of the script displaying the message
# * id: A progressive number used as message ID
# * msg: the message text
proc Info {title id msg} {
    if {[info commands send_msg_id] != ""} {
	send_msg_id $title-$id {INFO} $msg
    } else {
	puts "*** $title-$id INFO $msg"
    }
}
########################################################

## Display Vivado Info message and wrtite it into a log file
#
# Arguments:
# * File: The log file onto which write the message
# * title: The name of the script displaying the message
# * id: A progressive number used as message ID
# * msg: the message text
proc fInfo {File title id msg} {
    Info $title $id $msg
    set f [open $File a+]
    puts $f $msg
    close $f
}
########################################################

## Display Vivado Status message
#
# Arguments:
# * title: The name of the script displaying the message
# * id: A progressive number used as message ID
# * msg: the message text
proc Status {title id msg} {
    if {[info commands send_msg_id] != ""} {
	send_msg_id $title-$id {STATUS} $msg
    } else {
	puts "*** $title-$id STATUS $msg"
    }
}
########################################################

## Display Vivado Warning message
#
# Arguments:
# * title: The name of the script displaying the message
# * id: A progressive number used as message ID
# * msg: the message text
proc Warning {title id msg} {
    if {[info commands send_msg_id] != ""} {
	send_msg_id $title-$id {WARNING} $msg
    } else {
	puts "*** $title-$id WARNING $msg"
    }
}
########################################################

## Display Vivado Critical Warning message
#
# Arguments:
# * title: The name of the script displaying the message
# * id: A progressive number used as message ID
# * msg: the message text
proc CriticalWarining {title id msg} {
    if {[info commands send_msg_id] != ""} {
	send_msg_id $title-$id {CRITICAL WARNING} $msg
    } else {
	puts "*** $title-$id CRITICAL WARNING $msg"
    }
}
########################################################

## Display Vivado Error message
#
# Arguments:
# * title: The name of the script displaying the message
# * id: A progressive number used as message ID
# * msg: the message text
proc Error            {title id msg} {
    if {[info commands send_msg_id] != ""} {
	send_msg_id $title-$id {ERROR} $msg
    } else {
	puts "*** $title-$id ERROR $msg"
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
    set current_ver [split [lindex [exec git --version] 2] "."]
    set target [expr [lindex $ver 0]*100000 + [lindex $ver 1]*100 + [lindex $ver 0]]
    set current [expr [lindex $current_ver 0]*100000 + [lindex $current_ver 1]*100 + [lindex $current_ver 0]]
    
    return [expr $target <= $current]
}

########################################################

## Read a list file and adds the files to Vivado project, adding the additional information as file type.
#
# Additional information is provided with text separated from the file name with one or more spaces
#
# Arguments:
# * lsit_file: file containing vhdl list with optional properties
# * path:      the path the vhdl file are referred to in the list file
# * lib :      the name of the library files will be added to
# * src :      the name of VivadoFileSet files will be added to
proc ReadListFile {list_file path lib src} {
    set list_file 
    set fp [open $list_file r]
    set file_data [read $fp]
    close $fp

    #  Process data file
    set data [split $file_data "\n"]
    set n [llength $data]
    Info ReadListFile 0 "$n lines read from $list_file"
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
		    SmartListFile $vhdlfile $path
		} else {
		    add_files -norecurse -fileset $src $vhdlfile
		    incr cnt
		    set file_obj [get_files -of_objects [get_filesets $src] [list "*$vhdlfile"]]
		    if {$lib ne ""} {set_property -name "library" -value $lib -objects $file_obj}

		    ### Set file properties
		    set prop [lrange $file_and_prop 1 end]
		    # VHDL 2008 compatibility
		    if {[lsearch -inline -regex $prop "2008"] >= 0} {
			Info ReadListFile 1 "Setting filetype VHDL 2008 for $vhdlfile"
			set_property -name "file_type" -value "VHDL 2008" -objects $file_obj
		    }

		    # XDC
		    if {[lsearch -inline -regex $prop "XDC"] >= 0 || [file ext $vhdlfile] == ".xdc"} {
			Info ReadListFile 1 "Setting filetype XDC for $vhdlfile"
			    set_property -name "file_type" -value "XDC" -objects $file_obj
		    }

		    # Not used in synthesis
		    if {[lsearch -inline -regex $prop "nosynth"] >= 0} {
			Info ReadListFile 1 "Setting not used in synthesis for $vhdlfile..."
			set_property -name "used_in_synthesis" -value "false" -objects $file_obj
		    }

		    # Not used in implementation
		    if {[lsearch -inline -regex $prop "noimpl"] >= 0} {
			Info ReadListFile 1 "Setting not used in implementation for $vhdlfile..."
			set_property -name "used_in_implementation" -value "false" -objects $file_obj
		    }

		    # Not used in simulation
		    if {[lsearch -inline -regex $prop "nosim"] >= 0} {
			Info ReadListFile 1 "Setting not used in simulation for $vhdlfile..."
			set_property -name "used_in_simulation" -value "false" -objects $file_obj
		    }


		    ## Simulation properties
		    # Top simulation module
		    set top_sim [lindex [split [lsearch -inline -regex $prop topsim=] =] 1]
		    if { $top_sim != "" } {
			Info ReadListFile 1 "Setting $top_sim as top module for simulation file set $src..."
			set_property "top"  $top_sim [get_filesets $src]
			current_fileset -simset [get_filesets $src]
		    }

		    # Wave do file
		    set wave_file [lindex [split [lsearch -inline -regex $prop wavefile=] =] 1]
		    if { $wave_file != "" } {
			set r_path [GetRepoPath]
			set file_name "$r_path/sim/$wave_file"
			Info ReadListFile 1 "Setting $file_name as wave do file for simulation file set $src..."
			# check if file exists...
			if [file exists $file_name] {
			    set_property "modelsim.simulate.custom_wave_do" $file_name [get_filesets $src]
			} else {
			    Warning ReadlistFIle 1 "File $file_name was not found."
			}
		    }

		    #Do file
		    set do_file [lindex [split [lsearch -inline -regex $prop dofile=] =] 1]
		    if { $do_file != "" } {
			set r_path [GetRepoPath]
			set file_name "$r_path/sim/$do_file"
			Info ReadListFile 1 "Setting $file_name as udo file for simulation file set $src..."
			if [file exists $file_name] {
			    set_property "modelsim.simulate.custom_udo" $file_name [get_filesets $src]
			} else {
			    Warning ReadlistFIle 1 "File $file_name was not found."
			}
		    }
		}
	    } else {
		Error ReadListFile 0 "File $vhdlfile not found"
	    }
	}
    }
    Info ReadListFile 1 "$cnt file/s added to $lib..."
}
########################################################

## Read a list file and adds the files to Vivado project, adding the additional information as file type.
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

proc SmartListFile {list_file path} {
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
	default {
	    Error SmartListFile 0 "Unknown extension $ext"
	}
    }
    Info SmartListFile 0 "Reading sources from file $list_file, lib: $lib, file-set: $file_set"
    ReadListFile $list_file $path $lib $file_set
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
		    Warning GetFileList 0 "File $vhdlfile not found"
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
	    Warning GetVer 1 "No tag contains $SHA"
	    set ver "none"
	} else {
	    set vers [split $result "\n"]
	    set ver [lindex $vers 0]	    
	    foreach v $vers {
		if {[regexp {^v.*$} $v]} {
		    set ver $v
		    break
		}
	    }
	}
    } else {
	Warning GetVer 1 "Error while trying to find tag for $SHA in file: $FILE, path: [pwd]"
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
	set n [format %04X 0]
	set official [format %04X 0x8000]
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
	Warning GetVer 1 "Could not parse git describe: $ver"
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


## Return the new tag to be given to the repository
# Arguments:\n
# * merge_request_number: Gitlab merge request number to be used in candidate version
# * version_level:        0 if patch is to be increased (default), 1 if minor level is to be increase, 2 if major lav´e is to be increased

proc TagRepository {merge_request_number {version_level 0}} {
    if [catch {exec git tag --sort=taggerdate} last_tag] {
	Warning TagRepository 1 "No tags found in this repository, starting from v0.0.1..."
	set new_tag b${mr}v0.0.1-0
    } else {
	set vers [split $last_tag "\n"]
	set ver [lindex $vers 0]
	
	if {[regexp {^(?:b(\d+))?v(\d+)\.(\d+).(\d+)(?:-(\d+))?$} $ver -> mr M m p n]} {
	    if {$mr == "" } {
		Info TagRepository 1 "Found official version $M.$m.$p."
		if {$version_level >=2} {
		    incr M
		    set m 0
		    set p 0
		} elseif {$version_level ==1} {
		    incr m
		    set p 0
		} else {
		    incr p
		}
		set mr $merge_request_number
		set n 0
	    } else {
		Info TagRepository 1 "Found candidate for version $M.$m.$p, merge request number $mr, attempt number $n."
		if {$mr != $merge_request_number} {
		    Error TagRepository 1 "Merge request number $merge_request_number differs from the one found in the tag $mr, will use $merge_request_number."
		    set mr $merge_request_number
		}
		incr n
	    }
	    set new_tag b${mr}v$M.$m.$p-$n

	    if [catch {exec git tag $new_tag} msg] {
		Error TagRepository 2 "Could not create new tag $new_tag: $msg"
	    } else {
		Info TagRepository 3 "New tag $new_tag created successully."
	    }
	} else {
	    Error TagRepository 3 "Could not parse git describe: $last_tag"
	}
    }
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
    Info ReadListFile 1 "$n lines read from $list_file"
    set cnt 0
    foreach line $data {
	if {![regexp {^ *$} $line] & ![regexp {^ *\#} $line] } { #Exclude empty lines and comments
	    set file_and_prop [regexp -all -inline {\S+} $line]
	    set xmlfile [lindex $file_and_prop 0]
	    set xmlfile "$path/$xmlfile"
	    if {[file exists $xmlfile]} {
		set xmlfile [file normalize $xmlfile]
		Info ReadListFile 2 "Copying $xmlfile to $dst..."
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
		Info ReadListFile 0 "err: XML file $xmlfile not found"
	    }
	}
    }
    Info ReadListFile 1 "$cnt file/s copied"
}
########################################################
