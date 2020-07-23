
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
# Copy project file and documentation from  HOG_UNOFFICIAL_BIN_EOS_PATH to HOG_OFFICIAL_BIN_EOS_PATH

#parsing command options
if {[catch {package require cmdline} ERROR]} {
  puts "$ERROR\n If you are running this script on tclsh, you can fix this by installing 'tcllib'" 
  return
}
set parameters {
}


set usage   "Script to get project link\n- USAGE: $::argv0 \[OPTIONS\] <projec.tclt> \n. Options: "
set path [file normalize "[file dirname [info script]]/.."]

source $path/hog.tcl
if {[catch {array set options [cmdline::getoptions ::argv $parameters $usage]}] ||  [llength $argv] < 1 } {
  Msg Info [cmdline::usage $parameters $usage]
  exit 1
} else {
  set project_tcl [file normalize [lindex $argv 0]]
  set project [file rootname [file tail $project_tcl]]
}

set old_path [pwd]


set fp [open "$path/../../project_versions.txt" a]
puts $fp "$project [GetProjectVersion $project_tcl]"
close $fp
