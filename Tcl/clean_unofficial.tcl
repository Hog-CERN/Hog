#!/usr/bin/env tclsh
## @file clean_unofficial.tcl

#parsing command options
if {[catch {package require cmdline} ERROR]} {
	puts "$ERROR\n If you are running this script on tclsh, you can fix this by installing 'tcllib'" 
	return
}
set parameters {
}

set usage   "Script to clean EOS unofficial path of commits already merged into master.\nUsage: $argv0 <path_to_clean> \n"


set old_path [pwd]
set path [file dirname [info script]]
cd $path
source ./hog.tcl
cd ../../

if {[catch {array set options [cmdline::getoptions ::argv $parameters $usage]}] ||  [llength $argv] < 1} {
	Msg Info [cmdline::usage $parameters $usage]
	cd $old_path
    exit 1
} else {
    set path_to_clean [lindex $argv 0]
}

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
