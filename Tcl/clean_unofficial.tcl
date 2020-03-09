#!/usr/bin/env tclsh

set old_path [pwd]
set path [file dirname [info script]]
cd $path
source ./hog.tcl
cd ../../

#set master_shas [exec git log --pretty=format:%h]
#Msg Info "Retrieving list of commits for 'master' branch..."
#set list_master_shas [split $master_shas "\n"]
# puts $list_master_shas

set unofficial $env(HOG_UNOFFICIAL_BIN_EOS_PATH)
Msg Info "Retrieving list of bitfiles in $unofficial..."
set bitfiles [exec eos ls $unofficial]
set list_bitfiles [split $bitfiles "\n"]
# puts $list_bitfiles

foreach bitfile $list_bitfiles {
   if {[exec git branch master --contains $bitfile] != ""} {
       Msg Info "Removing files corresponding to SHA $bitfile"
       set status [catch {exec eos rm -r $unofficial/$bitfile} deletion]
   }
}

Msg Info "Cleaning done"

cd $old_path
