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

#parsing command options
if {[catch {package require yaml} ERROR]} {
  puts "$ERROR\n If you are running this script on tclsh, you can fix this by installing 'yaml'" 
  return
}
set usage "- USAGE: $::argv0"
set tcl_path [file normalize "[file dirname [info script]]/.."]

set repo_path [pwd]
cd $tcl_path
source ./hog.tcl

file copy $repo_path/Hog/hog-dynamic.yml $repo_path/generated-config.yml
set fp [open "$repo_path/generated-config.yml" a]
puts $fp "\n"
foreach dir [glob -type d $repo_path/Top/* ] {
    set proj [ file tail $dir ]
    set ver [ GetProjectVersion $dir/$proj.tcl ]

    if {$ver != 0} {
        puts $fp [ WriteYAMLStage "create_project" $proj ]
        puts $fp [ WriteYAMLStage "simulate_project" $proj ]
        puts $fp [ WriteYAMLStage "synthesise_ips" $proj ]
        puts $fp [ WriteYAMLStage "syntesise_project" $proj ]
        puts $fp [ WriteYAMLStage "implement_project" $proj ]
    }   
}

# puts $fp "test:"
# puts $fp "  stage: test"
# puts $fp "  script:"
# puts $fp "    - echo \"hello\""

close $fp
