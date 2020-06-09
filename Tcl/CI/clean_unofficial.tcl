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
# Clean the EOS unofficial paths of commits already merged into HOG_TARGET_BRANCH

#parsing command options
if {[catch {package require cmdline} ERROR]} {
  puts "$ERROR\n If you are running this script on tclsh, you can fix this by installing 'tcllib'"
  return
}
set parameters {
}

set usage   "Script to clean EOS unofficial path of commits already merged into \$HOG_TARGET_BRANCH.\nUsage: $argv0 <path_to_clean> <git_tag>\n"


set old_path [pwd]
set path [file dirname [info script]]
cd $path
source ../hog.tcl
cd ../../../

if {[catch {array set options [cmdline::getoptions ::argv $parameters $usage]}] ||  [llength $argv] < 2} {
  Msg Info [cmdline::usage $parameters $usage]
  cd $old_path
  exit 1
} else {
  set path_to_clean [lindex $argv 0]
  set git_tag [lindex $argv 1]
}

set unofficial $path_to_clean
Msg Info "Retrieving list of bitfiles in $unofficial..."

lassign [eos "ls $unofficial"] ret bitfiles
set list_bitfiles [split $bitfiles "\n"]

foreach bitfile $list_bitfiles {
  set status [catch {exec git tag --contains $bitfile -l="v*.*.*"} contained]
  if { $status==0 && [string first "$git_tag" $contained] != -1 } {
    Msg Info "Removing files corresponding to SHA $bitfile"
    lassign [eos "rm -r $unofficial/$bitfile"] status2 deletion
  } elseif { $status!=0 } {
    Msg CriticalWarning "Something got wrong with git tag command: $contained"
  }
}

Msg Info "Cleaning done"

cd $old_path
