#!/usr/bin/env tclsh
# @file
# Retrieves the IP synthesis file from an EOS repository

#parsing command options
if {[catch {package require cmdline} ERROR]} {
  puts "$ERROR\n If you are running this script on tclsh, you can fix this by installing 'tcllib'" 
  return
}
set parameters {
  {eos_ip_path.arg "" "Path of the EOS IP repository"}
}

set usage "- USAGE: $::argv0 \[OPTIONS\] <project> \n. Options:"
set tcl_path [file normalize "[file dirname [info script]]/.."]

set repo_path [pwd]
cd $tcl_path
source ./hog.tcl

if {[catch {array set options [cmdline::getoptions ::argv $parameters $usage]}] || [llength $argv] < 1 } {
  Msg Info [cmdline::usage $parameters $usage]
  exit 1
} elseif { $::argc eq 1 } {
  set project [lindex $argv 0]
  Msg Info "Creating directory $repo_path/VivadoProject/$project/$project.runs"
  file mkdir $repo_path/VivadoProject/$project/$project.runs
  set main_folder [file normalize "$repo_path/VivadoProject/$project/$project.runs/"]
  set ip_path 0
} else {
  set project [lindex $argv 0]
  Msg Info "Creating directory $repo_path/VivadoProject/$project/$project.runs"
  file mkdir $repo_path/VivadoProject/$project/$project.runs
  set main_folder [file normalize "$repo_path/VivadoProject/$project/$project.runs/"]
  set ip_path $options(eos_ip_path)
  Msg Info "Will use the EOS ip repository on $ip_path to speed up ip synthesis..."
}

Msg Info "Opening project $project..."
open_project $repo_path/VivadoProject/$project/$project.xpr


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
}

Msg Info "All done."
cd $repo_path
