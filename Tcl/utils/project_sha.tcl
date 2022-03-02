#!/usr/bin/env tclsh
#   Copyright 2018-2022 The University of Birmingham
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
# Get the SHA of the last commit of a specific project

if {[catch {package require cmdline} ERROR]} {
  puts "$ERROR\n If you are running this script on tclsh, you can fix this by installing 'tcllib'"
  return
}

set parameters {
  {version  "If set, the version is returned rather than the git sha."}
  {ext_path.arg "" "Path to external libraries"}
}

set usage   "Returns the git SHA of the last commit in which the specified project was modified.\nUsage: $argv0 \[-version\] <project name>"
set tcl_path [file dirname [info script]]
set repo_path [file normalize $tcl_path/../../..]
source $tcl_path/../hog.tcl


if {[catch {array set options [cmdline::getoptions ::argv $parameters $usage]}] || [llength $argv] < 1} {
  Msg Info [cmdline::usage $parameters $usage]
  exit 1
} else {
  set project [lindex $argv 0]
  if { $options(version) == 1 } {
    set do_ver 1
  } else {
    set do_ver 0
  }
  if { $options(ext_path) == "" } {
    set ext_path ""
  } else {
    set ext_path $options(ext_path)
  }
}
set proj_dir $repo_path/Top/$project

if {[file exists $proj_dir]} {
  lassign [GetRepoVersions $proj_dir $repo_path $ext_path] sha ver
  if {$do_ver == 1} {
    set ret [HexVersionToString $ver]
  } else {
    set ret $sha
  }

} else {
  Msg Error "Project $project does not exist: $proj_dir not found."
  exit
}

puts $ret
