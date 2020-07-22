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
  puts "$ERROR\n If you are running this script on tclsh, you can fix this by installing 'tcllib'"
  return
}

if {[catch {package require cmdline} ERROR]} {
  puts "$ERROR\n If you are running this script on tclsh, you can fix this by installing 'tcllib'"
  return
}

set parameters {
  {runall  "If set, it will generate a gitlab-ci yml file for all projects in the Top folder, even if it has not been modified with respect to the target branch."}
  {external_path.arg "" "Path for the external libraries not stored in the git repository."}
}

set usage "Generate a gitlab-ci.yml config file for the child pipeline - USAGE: \[-runall\]"

set tcl_path [file normalize "[file dirname [info script]]/.."]

set repo_path [pwd]
source $tcl_path/hog.tcl

array set options [cmdline::getoptions ::argv $parameters $usage]
if { $options(runall) == 1 } {
  set runall 1
} else {
  set runall 0
}
if { $options(external_path) != "" } {
  set ext_path $options(external_path)
  Msg Info "External path set to $ext_path"
} else {
  set ext_path ""
}

set stage_list { "create_project" "simulate_project" "synthesise_project" "implement_project" }

file copy -force $repo_path/Hog/YAML/hog-child.yml $repo_path/generated-config.yml
set fp [open "$repo_path/generated-config.yml" a]
puts $fp "\n"

foreach dir [glob -type d $repo_path/Top/* ] {
  set proj [ file tail $dir ]
  set ver [ GetProjectVersion $dir/$proj.tcl $ext_path ]
  if {$ver == 0 || $ver == -1 || $runall == 1} {
    if {$runall == 0} {
      Msg Info "$proj was modified, adding it to CI..."
    }
    if { [ file exists "$dir/ci.conf" ] == 1} {
      set cifile [open $dir/ci.conf ]
      set input [read $cifile]
      set lines [split $input "\n"]
      # Loop through each line
      foreach line $lines {
        if {![regexp {^ *$} $line] & ![regexp {^ *\#} $line] } { 
          set stage_and_prop [regexp -all -inline {\S+} $line]
          set stage [lindex $stage_and_prop 0]
          if { [lsearch $stage_list $stage] > -1 } {
            puts $fp [ WriteYAMLStage $stage $proj ]
          } else {
            Msg Error "Stage $stage in $dir/ci.conf is not defined.\n Allowed stages are $stage_list"
            exit 1
          }
        }
      }
    } else {
      foreach stage $stage_list {
        puts $fp [ WriteYAMLStage $stage $proj $stage_list ]
      }
    }
  } else {
    Msg Info "$proj was not modified since version: $ver, skipping."
    #Here we should provide the link to the tag in $ver
  }
}
close $fp
