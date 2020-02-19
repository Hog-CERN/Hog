#!/usr/bin/env tclsh
if { $::argc eq 0 } {
    puts "USAGE: $::argv0 <IP file.xci> \[IP repository path (on eos)\]"
    exit 1
} else {
    set xci_file [file normalize [lindex $argv 0]]
    if { $::argc > 1 } {
	set ip_path [lindex $argv 1]
    } else {
	if [info exists env(HOG_IP_EOS_PATH)] {
	    set ip_path $env(HOG_IP_EOS_PATH)
	} else {
	    puts "ERROR: environment variable HOG_IP_EOS_PATH is not defined. Please define it or specify a path as an argument to $::argv0."
	    exit -1
	}
    }
}
set old_path [pwd]
set path [file dirname [info script]]
cd $path
source ./hog.tcl

set ip_path_path [file normalize $ip_path/..]
if  {[catch {exec eos ls $ip_path_path} result]} {
    Msg Error "Could not find mother directory for $ip_path: $ip_path_path."
    exit -1
} else {
    if  {[catch {exec eos ls $ip_path} result]} {
	Msg Info "IP repostory path on eos does not exist, creating it now..."
	exec eos mkdir $ip_path
    } else {
	Msg Info "IP repostory path on eos is set to: $ip_path"
    }
}

if !([file exists $xci_file]) {
    Msg Error "Could not find $xci_file"
    exit -1
}

set xci_path [file dir $xci_file]
set xci_name [file tail $xci_file]
set xci_dir_name [file tail $xci_path]

set hash [lindex [exec md5sum $xci_file] 0]
set file_name $xci_name\_$hash


if  {[catch {exec eos ls $ip_path/$file_name} result]} {
    Msg Info "IP not found in the repository, copying it over..."
    exec -ignorestderr eos cp -r $xci_path $ip_path
    exec eos mv $ip_path/$xci_dir_name $ip_path/$file_name

} else {
    Msg Info "IP found in the repository, copying it locally..."
    exec -ignorestderr eos cp -r $ip_path/$file_name/* $xci_path
} 

#exec -ignorestderr eos cp -r $unofficial/$f/* $dst/

cd $old_path
