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
    Msg Info "Will use the EOS ip repository on $ip_path to copy synthesised IPs..."
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

if {$ips != ""} {
    foreach ip $ips {
	if { [get_runs $ip\_synth_1] != "" } {
	    Msg Info "Adding run for $ip..."
	    set run_name [get_runs $ip\_synth_1]
	    reset_run $run_name
	    lappend runs $run_name
	} else {
	    Msg Info "No run found for $ip."
	}
    }
}

set jobs 4
set failure 0

if [info exists runs] {
    foreach run_name $runs {
	Msg Info "Launching $run_name..."
	launch_runs $run_name -dir $main_folder
	lappend running $run_name
	if {[llength $running] >= $jobs} {
	    wait_on_run [get_runs [lindex $running 0]]
	    set running [lreplace $running 0 0]
	}
    }

    while {[llength $running] > 0} {
	Msg Info "Checking [lindex $running 0]..."
	wait_on_run [get_runs [lindex $running 0]]
	set running [lreplace $running 0 0]
    }
    if { $runs != "" } { 
	foreach run_name $runs {
	    set prog [get_property PROGRESS $run_name]
	    set status [get_property STATUS $run_name]
	    Msg Info "Run: $run_name progress: $prog, status : $status"
	    if {$prog ne "100%"} {
		set failure 1
	    }
	}
    }
}

if {$failure eq 1} {
    Msg Error "At least on IP synthesis failed"
}

if {($ip_path != 0)} {
    Msg Info "Copying synthesised IPs to $ip_path..."
    foreach ip $ips {
	set force 0
	if [info exist runs] {
	    if {[lsearch $runs $ip\_synth_1] != -1} {
		Msg Info "$ip was synthesized, will force the copy to EOS..."
		set force 1
	    }
	}
	HandleIP push [get_property IP_FILE $ip] $ip_path $main_folder $force
    }
}

Msg Info "All done."
cd $old_path
