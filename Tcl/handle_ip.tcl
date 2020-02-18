#!/usr/bin/env tclsh
if { $::argc eq 0 } {
    puts "USAGE: $::argv0 <IP file.xci> \[IP repository path (on eos)\]"
    exit 1
} else {
    set xci_file [file normalize [lindex $argv 0]]
    if { $::argc > 1 } {
	set ip_path [lindex $argv 1]
    } else {
	set ip_path $env(HOG_IP_EOS_PATH)
    }
}
set old_path [pwd]
set path [file dirname [info script]]
cd $path
source ./hog.tcl

if !([file exists $xci_file]) {
    Msg Error "Could not find $xci_file"
}
set xci_path [file dir $xci_file]
set xci_name [file tail $xci_file]

set hash [lindex [exec md5sum $xci_file] 0]
set file_name $xci_name\_$hash


if  {[catch {exec eos ls $ip_path/$file_name} result]} {
    Msg Info "IP not found in the repository, copying it over..."
    exec -ignorestderr eos cp -r $xci_path/* $ip_path/$file_name/

} else {
    Msg Info "IP found in the repository, copying it locally...  from: $ip_path/$file_name/* to: $xci_path"
    exec -ignorestderr eos cp -r $ip_path/$file_name/* $xci_path 
} 

#exec -ignorestderr eos cp -r $unofficial/$f/* $dst/

cd $old_path
