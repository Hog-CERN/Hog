#!/usr/bin/env tclsh
set tcl_path [file dirname [info script]]
set repo_path $tcl_path/../..

if {$argc != 2} {
    puts "\nCopy IPBus XML files listed in a Hog list file and replace the version and SHA placeholders if they are present in any of the XML files."
    puts "Usage: $argv0 <XML list file> <destination directory>\n\n"
    exit
}

source $tcl_path/hog.tcl

set list_file [lindex $argv 0]
set dst       [lindex $argv 1]

if {[file exists $list_file]} {
    if ![file exists $dst] {
	Warning CopyXML 0 "$dst directory not found, creating it..."
	file mkdir $dst
    }
} else {
    Error CopyXML 0 "$list_file not found"
    exit
}
lassign [GetXMLVer $list_file $tcl_path] ver sha
CopyXMLsFromListFile $list_file $tcl_path $dst $ver $sha
