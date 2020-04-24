#!/usr/bin/env tclsh
# @file
# Check the code syntax in a vivado project

#parsing command options
if {[catch {package require cmdline} ERROR]} {
	puts "$ERROR\n If you are running this script on tclsh, you can fix this by installing 'tcllib'" 
	return
}
set parameters {
}

set usage   "USAGE: $::argv0 <project>"



set Name LaunchCheckSyntax
set hog_path [file normalize "[file dirname [info script]]/.."]
set repo_path [pwd]
cd $hog_path
source ./hog.tcl

if {[catch {array set options [cmdline::getoptions ::argv $parameters $usage]}] || $::argc eq 0 } {
    Msg Info [cmdline::usage $parameters $usage]
	cd $repo_path
    exit 1
} else {
    set project [lindex $argv 0]
        set main_folder [file normalize "$repo_path/VivadoProject/$project/$project.runs/"]
}

Msg Info "Opening project $project..."

open_project ../../VivadoProject/$project/$project.xpr


Msg Info "Checkin syntax for project $project..."
set syntax [check_syntax -return_string]

if {[string first "CRITICAL" $syntax ] != -1} {
    check_syntax
    exit 1
}

