#!/usr/bin/env tclsh
if { $::argc < 2 } {
    puts "USAGE: $::argv0 <push|pull> <IP file.xci> <runs dir> <IP repository path (on eos)> "
    exit 1
} else {
    set what_to_do [lindex $argv 0]
    if {!($what_to_do eq "push") && !($what_to_do eq "pull")} {
	puts "ERROR: you must specify push or pull as first argument\n\n"
	exit -1
    }

    set xci_file [file normalize [lindex $argv 1]]
    set runs_dir [lindex $argv 2]

    if { $::argc > 3 } {
	set ip_path [lindex $argv 3]
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

HandleIP $what_to_do $xci_file $ip_path $runs_dir

Msg Info "All done."
cd $old_path
