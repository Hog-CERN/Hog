#!/usr/bin/env tclsh
#   Copyright 2018-2025 The University of Birmingham
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

set tcl_path [file normalize "[file dirname [info script]]/.."]
set repo_path [file normalize "$tcl_path/../.."]

source $tcl_path/hog.tcl

# Import tcllib for libero
if {[IsLibero]} {
  if {[info exists env(HOG_TCLLIB_PATH)]} {
    lappend auto_path $env(HOG_TCLLIB_PATH)
  } else {
    puts "ERROR: To run Hog with Microsemi Libero SoC, you need to define the HOG_TCLLIB_PATH variable."
    return
  }
}

#parsing command options
if {[catch {package require cmdline} ERROR] || [catch {package require struct::matrix} ERROR]} {
  puts "$ERROR\n Tcllib not found. If you are running this script on tclsh, you can fix this by installing 'tcllib'"
  return
}

set parameters {
  {sim    "If set, checks also the version of the simulation files."}
  {ext_path.arg "" "Sets the absolute path for the external libraries."}
}

set usage "- USAGE: $::argv0 \[OPTIONS\] <project> \n. Options:"

if { $::argc eq 0 } {
  Msg Info [cmdline::usage $parameters $usage]
  exit 1
} elseif {[IsQuartus] && [ catch {array set options [cmdline::getoptions quartus(args) $parameters $usage] } ] || $::argc eq 0 } {
  #Quartus
  Msg Info [cmdline::usage $parameters $usage]
  exit 1
} elseif {[catch {array set options [cmdline::getoptions ::argv $parameters $usage]}] } {
  Msg Info [cmdline::usage $parameters $usage]
  exit 1
  ##nagelfar ignore Unknown variable
}

set project [lindex $argv 0]
set sim 0
set ext_path ""
set project_dir $repo_path/Top/$project

if {$options(sim) == 1} {
  set sim 1
  Msg Info "Will check also the version of the simulation files..."
}

if { $options(ext_path) != "" } {
  set ext_path $options(ext_path)
  Msg Info "External path set to $ext_path"
}

set ver [ GetProjectVersion $project_dir $repo_path $ext_path $sim ]
if {$ver == 0} {
  Msg Info "$project was modified, continuing with the CI..."
} elseif {$ver != -1} {
  Msg Info "$project was not modified since version: $ver, disabling the CI..."
  file mkdir $repo_path/Projects/$project
  set fp [open "$repo_path/Projects/$project/skip.me" w+]
  close $fp
}
