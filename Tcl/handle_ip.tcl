#!/usr/bin/env tclsh
if { $::argc < 2 } {
    puts "USAGE: $::argv0 <push|pull> <IP file.xci> \[IP repository path (on eos)\]"
    exit 1
} else {
    set what_to_do [lindex $argv 0]
    if {!($what_to_do eq "push") && !($what_to_do eq "pull")} {
	puts "ERROR: you must specify push or pull as first argument\n\n"
	exit -1
    }

    set xci_file [file normalize [lindex $argv 1]]
    if { $::argc > 2 } {
	set ip_path [lindex $argv 2]
    } else {
	if [info exists env(HOG_IP_EOS_PATH)] {
	    set ip_path $env(HOG_IP_EOS_PATH)
	} else {
	    puts "ERROR: environment variable HOG_IP_EOS_PATH is not defined. Please define it or specify a path as an argument to $::argv0.\n\n"
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
    Msg Error "Could not find mother directory for $ip_path: $ip_path_path.\n\n"
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
    Msg Error "Could not find $xci_file.\n\n"
    exit -1
}

set xci_path [file dir $xci_file]
set xci_name [file tail $xci_file]
set xci_dir_name [file tail $xci_path]

set hash [lindex [exec md5sum $xci_file] 0]
set file_name $xci_name\_$hash


if {$what_to_do eq "push"} {
    if  {[catch {exec eos ls $ip_path/$file_name} result]} {
	Msg Info "IP not found in the repository, copying it over..."
    } else {
	Msg Warning "IP already in the repository, replacing..."
	exec -ignorestderr eos rm -r $ip_path/$file_name
    }
    exec -ignorestderr eos cp -r $xci_path $ip_path
    exec eos mv $ip_path/$xci_dir_name $ip_path/$file_name
} elseif {$what_to_do eq "pull"} {
    if  {[catch {exec eos ls $ip_path/$file_name} result]} {
	Msg Error "IP not found in the repository, cannot pull.\n\n"
	exit -1
	
    } else {
	Msg Info "IP found in the repository, copying it locally..."
	exec -ignorestderr eos cp -r $ip_path/$file_name/* $xci_path
    } 
}

Msg Info "All done."
cd $old_path
