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

set usage "- USAGE: $::argv0 <project> \n."

set repo_path [pwd]
set tcl_path [file normalize "[file dirname [info script]]/.."]
source $tcl_path/hog.tcl

if { [ llength $argv] < 1 } { 
  puts [cmdline::usage $usage]
  exit 1
} else {
  set project [lindex $argv 0]
}

set ver [ GetProjectVersion $repo_path/Top/$project/$project.tcl ]
if {$ver == 0} {
  Msg Info "$project was modified, continuing with the CI..."
} else {
  Msg Info "$proj was not modified since version: $ver, disabling the CI..."
  file mkdir $repo_path/SkippedProjects
  set fp [open "$repo_path/SkippedProjects/$project" w+]
  close $fp
}