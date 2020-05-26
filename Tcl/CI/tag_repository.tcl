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

## @file tag_repository.tcl

set old_path [pwd]
set tcl_path [file dirname [info script]]
cd $tcl_path
source ../hog.tcl

#parsing command options
if {[catch {package require cmdline} ERROR]} {
  Msg Error "$ERROR\n If you are running this script on tclsh, you can fix this by installing 'tcllib'" 
  cd $old_path
  return
}

set parameters {
  {Hog    "Runs merge and tag of Hog repository. Default = off. To be only used by HOG developers!!!"}
  {level.arg 0   "Tag version level: \n\t0 -> patch (p) \n\t1 -> minor (m)\n\t2 -> major(M)\n Tag format: M.m.p. Default = 0"}
  {default_version_level.arg "patch" "Default version level to increase if nothing is psecified in the merge request description. Can be patch, minor, major (default = patch)"}
}

set usage "- USAGE: $::argv0 <merge request> \[options\].\n Options:"

if {[catch {array set options [cmdline::getoptions ::argv $parameters $usage]}] || [llength $argv] < 1 } {
  Msg Info [cmdline::usage $parameters $usage]
  cd $old_path
  return
}

set merge_request [lindex $argv 0]

if { $options(Hog) == 1 } {
  set TaggingPath ../..
} else {
  set TaggingPath ../../..
}
cd $TaggingPath

switch $options(default_version_level) {
  patch {
    Info "Patch will be used as default level"
    set def_l 0 
  }
  minor {
    Info "Minor will be used as default level"
    set def_l 1	
  }
  major {
    Info "Major will be used as default level"
    set def_l 2 	
  }
  default {
    Msg Warning "Invalid default level $options(default_version_level), assuming patch."
    set def_l 0
  }
}

set tags [TagRepository $merge_request $options(level) $def_l]
set old_tag [lindex $tags 0]
set new_tag [lindex $tags 1]
Msg Info "Old tag was: $old_tag and new tag is: $new_tag"

cd $old_path
