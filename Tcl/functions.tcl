## @file
# Collection of Tcl functions used in vivado scripts

########################################################

## Display Vivado Info message
#
# Arguments:
# * title: The name of the script displaying the message
# * id: A progressive number used as message ID
# * msg: the message text
proc Info {title id msg} { send_msg_id $title-$id {INFO} $msg}

########################################################

## Display Vivado Info message and wrtite it into a log file
#
# Arguments:
# * File: The log file onto which write the message
# * title: The name of the script displaying the message
# * id: A progressive number used as message ID
# * msg: the message text
proc fInfo            {File title id msg} {
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
proc Status           {title id msg} { send_msg_id $title-$id {STATUS} $msg}

########################################################

## Display Vivado Warning message
#
# Arguments:
# * title: The name of the script displaying the message
# * id: A progressive number used as message ID
# * msg: the message text
proc Warning          {title id msg} { send_msg_id $title-$id {WARNING} $msg}

########################################################

## Display Vivado Critical Warning message
#
# Arguments:
# * title: The name of the script displaying the message
# * id: A progressive number used as message ID
# * msg: the message text
proc CriticalWarining {title id msg} { send_msg_id $title-$id {CRITICAL WARNING} $msg}

########################################################

## Display Vivado Error message
#
# Arguments:
# * title: The name of the script displaying the message
# * id: A progressive number used as message ID
# * msg: the message text
proc Error            {title id msg} { send_msg_id $title-$id {ERROR} $msg}

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
		add_files -norecurse -fileset $src $vhdlfile
		incr cnt
		set file_obj [get_files -of_objects [get_filesets $src] [list "*$vhdlfile"]]
		if {$lib ne ""} {set_property -name "library" -value $lib -objects $file_obj}
		if {[llength $file_and_prop] > 1} {
		    set prop [lrange $file_and_prop 1 end]
		    set type [lindex $prop 0]
		    if {$type eq "2008" } {set type "VHDL 2008"}
		    set_property -name "file_type" -value $type -objects $file_obj
		}
	    } else {
		Error ReadListFile 0 "File $vhdlfile not found"
	    }
	}
    }
    Info ReadListFile 1 "$cnt file/s added to $lib..."
    if {$n ne $cnt} {
	Warning ReadListFile 1 "The number of files in the list differs form the number of files added to project..."
    }
    
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
	    set file_set "sim_1"	    
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

## Get git SHA of a subset of list file
#
# Arguments:\n
# * FILE: list file or path containing the subset of files whose latest commit hash will be returned
# * path:      the path the vhdl file are referred to in the list file (not used if FILE is a path or "ALL")
#
# if the special string "ALL" is used, returns the global hash
proc GetHash {FILE path} {
    if {$FILE eq "ALL"} {
	set ret [exec git log --format=%h -1]
    } elseif {[file isfile $FILE]} {

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
		    lappend lista $vhdlfile
		} else { 
		    Warning GetHash 0 "File $vhdlfile not found"
		}
	    }
	}

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
	    puts "Tags found: $vers"
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
