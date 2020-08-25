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
  {static "Normally the content of the hog-child.yml file is added at the beginning of the generated yml file. If thi flag is set, this will not be done."}
  {external_path.arg "" "Path for the external libraries not stored in the git repository."}
}

set usage "Generate a gitlab-ci.yml config file for the child pipeline - USAGE: generate_yaml.tcl \[options\]"

set old_path [pwd]
set tcl_path [file normalize "[file dirname [info script]]/.."]

set repo_path [file normalize $tcl_path/../..]
source $tcl_path/hog.tcl

array set options [cmdline::getoptions ::argv $parameters $usage]
if { $options(runall) == 1 } {
  set runall 1
} else {
  set runall 0
}
if { $options(static) == 1 } {
  set static 1
  set runall 1
} else {
  set static 0
}

if { $options(external_path) != "" } {
  set ext_path $options(external_path)
  Msg Info "External path set to $ext_path"
} else {
  set ext_path ""
}


set stage_list $CI_STAGES

if {$static == 1 } {
  if { [file exist "$repo_path/.gitlab-ci.yml"] } {
    set created_yml  "$repo_path/new_gitlab-ci.yml"
    Msg Warning "$repo_path/.gitlab-ci.yml, will create (and possibly repleace) $created_yml, please rename it if you want Hog-CI to work."
  } else {
    set created_yml  "$repo_path/.gitlab-ci.yml"
  }
  Msg Info "Creating new file $created_yml..."
  set fp [open $created_yml w]

  Msg Info "Evaluating the current version of Hog to use in the ref in the yml file..."
  cd $tcl_path
  set ref [exec git describe]
  cd $old_path
  # adding include hog.yml and ref
  #set outer [huddle create "inculde" [huddle list [huddle string "project: 'hog/Hog'" "file" "'/hog.yml'" "ref" "'$ref'" ]]]
  #puts $fp [ string trimleft [ yaml::huddle2yaml $outer ] "-" ]
  puts $fp "include:\n  - project: 'hog/Hog'\n    file: 'hog.yml'\n    ref: '$ref'\n"

} else {
  set created_yml  "$repo_path/generated-config.yml"
  Msg Info "Copying $repo_path/Hog/YAML/hog-common.yml to $created_yml..."
  file copy -force $repo_path/Hog/YAML/hog-common.yml $created_yml
  set fp [open $created_yml a]
  Msg Info "Copying $repo_path/Hog/YAML/hog-child.yml to $created_yml..."
  set fp2 [open "$repo_path/Hog/YAML/hog-child.yml" r]
  set file_data [read $fp2]
  puts $fp $file_data
  puts $fp "\n"
}


foreach dir [glob -type d $repo_path/Top/* ] {
  set proj [ file tail $dir ]
  set ver [ GetProjectVersion $dir/$proj.tcl $ext_path ]
  if {$ver == 0 || $ver == -1 || $runall == 1} {
    if {$runall == 0} {
      Msg Info "$proj was modified, adding it to CI..."
    }
    if { [ file exists "$dir/ci.conf" ] == 1} {
      Msg Info "Foung CI configuration file $dir/ci.conf, reading configuration for $proj..."
      set cifile [open $dir/ci.conf ]
      set input [read $cifile]
      set lines [split $input "\n"]
      close $cifile
      # Loop through each line
      foreach line $lines {
        if {![regexp {^ *$} $line] & ![regexp {^ *\#} $line] } {
          set stage_and_prop [regexp -all -inline {\S+} $line]
          set stage [lindex $stage_and_prop 0]
          if { [lsearch $stage_list $stage] > -1 } {
	    Msg Info "Adding job $stage for project: $proj..."
            puts $fp [ WriteYAMLStage $stage $proj ]
          } else {
            Msg Error "Stage $stage in $dir/ci.conf is not defined.\n Allowed stages are $stage_list"
            exit 1
          }
        }
      }
    } else {
      Msg Info "No CI configuration file found ($dir/ci.conf) for $proj, creating all jobs..."
      foreach stage $stage_list {
	Msg Info "Adding job $stage for project: $proj..."
	puts $fp [ WriteYAMLStage $stage $proj ]
      }
    }
  } else {
    Msg Info "$proj was not modified since version: $ver, skipping."
    #Here we should provide the link to the tag in $ver
  }
}
close $fp
Msg Info "$created_yml generated correctly."
