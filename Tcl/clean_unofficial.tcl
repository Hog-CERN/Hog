#!/usr/bin/env tclsh
if {$argc != 1} {
    puts "Script to clean project files in $\HOG_UNOFFICIAL_BIN_EOS_PATH of commits already merged into master.\n"
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

#set master_shas [exec git log --pretty=format:%h]
#Msg Info "Retrieving list of commits for 'master' branch..."
#set list_master_shas [split $master_shas "\n"]
# puts $list_master_shas

set unofficial $path_to_clean
Msg Info "Retrieving list of bitfiles in $unofficial..."
set bitfiles [exec eos ls $unofficial]
set list_bitfiles [split $bitfiles "\n"]
# puts $list_bitfiles

foreach bitfile $list_bitfiles {
   	set status [catch {exec git branch master --contains $bitfile} contained]
   	if { $status==0 && [string first "master" $contained] != -1 } {
       Msg Info "Removing files corresponding to SHA $bitfile"
       set status2 [catch {exec eos rm -r $unofficial/$bitfile} deletion]
   }
}

Msg Info "Cleaning done"

cd $old_path
