#!/usr/bin/env tclsh
set Name clean_unofficial

set old_path [pwd]
set path [file dirname [info script]]
cd $path
source ./hog.tcl
cd ../../

set master_shas [exec git rev-parse --short=8 master --remotes]
Msg Info "Retrieving list of commits for 'master' branch..."
set list_master_shas [split $master_shas "\n"]
puts $list_master_shas

set unofficial $env(HOG_UNOFFICIAL_BIN_EOS_PATH)
Msg Info "Retrieving list of bitfiles in $unofficial..."
set bitfiles [exec eos ls $unofficial]
set list_bitfiles [split $bitfiles "\n"]
puts $list_bitfiles

foreach sha $list_master_shas {
    foreach bitfile $list_bitfiles {
        if {$sha == $bitfile} {
            Msg Info "Removing files corresponding to SHA $sha"
            set status [catch {exec eos rm -r $unofficial/$sha} deletion]
            puts $status
        }
    }
}

Msg Info "Cleaning done"

cd $old_path
