#!/usr/bin/env tclsh
if {[catch {package require cmdline} ERROR]} {
	puts "$ERROR\n If you are running this script on tclsh, you can fix this by installing 'tcllib'" 
	return
}
set parameters {
}

set usage   "Copy IPBus XML files listed in a Hog list file and replace the version and SHA placeholders if they are present in any of the XML files.\nUsage: $argv0 <XML list file> <destination directory>"
set tcl_path [file dirname [info script]]
set repo_path [file normalize $tcl_path/../..]
source $tcl_path/hog.tcl

if {[catch {array set options [cmdline::getoptions ::argv $parameters $usage]}] || $argc != 2} {
    Msg Info [cmdline::usage $parameters $usage]
    exit
}
set list_file [lindex $argv 0]
set dst       [lindex $argv 1]

if {[file exists $list_file]} {
    if ![file exists $dst] {
	Msg Info "$dst directory not found, creating it..."
	file mkdir $dst
    }
} else {
    Msg Error "$list_file not found"
    exit
}
lassign [GetVer $list_file $repo_path] hex_ver sha

set ver [HexVersionToString $hex_ver]
CopyXMLsFromListFile $list_file $repo_path $dst $ver $sha
