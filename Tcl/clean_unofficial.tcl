#!/usr/bin/env tclsh
if {$argc != 1} {
    puts "Script to clean EOS unofficial path of commits already merged into master.\n"
    puts "Usage: $argv0 <path_to_clean> \n"
    exit 1
} else {
    set path_to_clean [lindex $argv 0]
}


set old_path [pwd]
set path [file dirname [info script]]
cd $path
source ./hog.tcl
cd ../../

set unofficial $path_to_clean
Msg Info "Retrieving list of bitfiles in $unofficial..."

lassign [eos "ls $unofficial"] ret bitfiles
set list_bitfiles [split $bitfiles "\n"]

foreach bitfile $list_bitfiles {
   	set status [catch {exec git branch master --contains $bitfile} contained]
   	if { $status==0 && [string first "master" $contained] != -1 } {
	    Msg Info "Removing files corresponding to SHA $bitfile"
	    lassign [eos "rm -r $unofficial/$bitfile"] status2 deletion
	}
}

Msg Info "Cleaning done"

cd $old_path
