#!/usr/bin/env tclsh
#parsing command options
if {[catch {package require cmdline} ERROR]} {
	puts "$ERROR\n If you are running this script on tclsh, you can fix this by installing 'tcllib'" 
	return
}
set parameters {
}

set usage   "USAGE: $::argv0 <project>"

set path [file normalize "[file dirname [info script]]/.."]


set old_path [pwd]
cd $path
source ./hog.tcl

if {[catch {array set options [cmdline::getoptions ::argv $parameters $usage]}] || $::argc eq 0 } {
    Msg Info [cmdline::usage $parameters $usage]
	cd $old_path
    exit 1
} else {
    set project [lindex $argv 0]
    set main_folder [file normalize "$path/../../VivadoProject/$project/$project.runs/"]
}

if [info exists env(HOG_IP_EOS_PATH)] {
    set ip_path $env(HOG_IP_EOS_PATH)
    Msg Info "Will use the EOS ip repository on $ip_path to speed up ip synthesis..."
} else {
    set ip_path 0
}


Msg Info "Opening project $project..."
open_project ../../VivadoProject/$project/$project.xpr


Msg Info "Preparing IP runs..."
reset_run synth_1
launch_runs -scripts_only synth_1
reset_run synth_1

set ips [get_ips *]
if {($ip_path != 0) && ($ips != "")  } {
    Msg Info "Scanning through all the IPs and possibly copying synthesis result from the EOS path..."
    set copied_ips 0
    foreach ip $ips {
	set ret [HandleIP pull [get_property IP_FILE $ip] $ip_path $main_folder]
	if {$ret == 0} {
	    incr copied_ips 
	}
    }

    Msg Info "$copied_ips IPs were copied from the EOS repository"

    if {$copied_ips > 0} {
	Msg Info "Re-creating project $project..."
	close_project
	source ../../Top/$project/$project.tcl
    }
}

Msg Info "All done."
cd $old_path
