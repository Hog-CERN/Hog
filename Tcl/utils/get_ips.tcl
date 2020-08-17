#!/usr/bin/env tclsh
#   Copyright 2018-2020 The University of Birmingham
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

# @file
# Retrieves the IP synthesis file from an EOS repository

#parsing command options
if {[catch {package require cmdline} ERROR]} {
  puts "$ERROR\n If you are running this script on tclsh, you can fix this by installing 'tcllib'" 
  return
}
set parameters {
  {ip_eos_path.arg "" "Path of the EOS IP repository"}
}

set usage "- USAGE: $::argv0 \[OPTIONS\] <project> \n. Options:"
set tcl_path [file normalize "[file dirname [info script]]/.."]

set repo_path [pwd]
cd $tcl_path
source ./hog.tcl

if {[catch {array set options [cmdline::getoptions ::argv $parameters $usage]}] || [llength $argv] < 1 } {
  Msg Info [cmdline::usage $parameters $usage]
  exit 1
} else {
  set project [lindex $argv 0]
  Msg Info "Creating directory $repo_path/VivadoProject/$project/$project.runs"
  file mkdir $repo_path/VivadoProject/$project/$project.runs
  set main_folder [file normalize "$repo_path/VivadoProject/$project/$project.runs/"]
  set ip_path $options(ip_eos_path)

  if {$ip_path eq ""} { 
    Msg Warning "No EOS ip repository defined"
  } else {
    Msg Info "Will use the EOS ip repository on $ip_path to speed up ip synthesis"
  }
}

Msg Info "Getting IPs for $project..."

set ips {}
lassign [GetHogFiles "$repo_path/Top/$project/list/" "*.src"] src_files dummy
dict for {f files} $src_files {
  #library names have a .src extension in values returned by GetHogFiles
  if { [file ext $f] == ".ip" } {
    lappend ips $files
  }
}


if {$ip_path == "" } {
  Msg Warning "Cannot copy from EOS."
} else {
  Msg Info "Copying IPs from $ip_path..."
  set copied_ips 0
  foreach ip $ips {
    set ret [HandleIP pull $ip $ip_path $main_folder]
    if {$ret == 0} {
      incr copied_ips 
    }
  }
  Msg Info "$copied_ips IPs were copied from the EOS repository."
}


Msg Info "All done."
cd $repo_path
