#!/usr/bin/env tclsh
# @file
# Tags the repository

set repo_path [pwd]
set tcl_path [file dirname [info script]]
cd $tcl_path
source ../hog.tcl

#parsing command options
if {[catch {package require cmdline} ERROR]} {
  Msg Error "$ERROR\n If you are running this script on tclsh, you can fix this by installing 'tcllib'" 
  cd $repo_path
  return
}

set parameters {
  {Hog    "Runs merge and tag of Hog repository. Default = off. To be only used by HOG developers!!!"}
  {level.arg 0   "Tag version level: \n\t0 -> patch (p) \n\t1 -> minor (m)\n\t2 -> major(M)\n Tag format: M.m.p. Default = 0"}
}

set usage "- USAGE: $::argv0 <merge request> \[options\].\n Options:"

if {[catch {array set options [cmdline::getoptions ::argv $parameters $usage]}] || [llength $argv] < 1 } {
  Msg Info [cmdline::usage $parameters $usage]
  cd $repo_path
  return
}

set merge_request [lindex $argv 0]

if { $options(Hog) == 1 } {
  set TaggingPath ../..
} else {
  set TaggingPath $repo_path
}
cd $TaggingPath



Msg Info "Evaluating git describe..."
set describe [exec git describe --always --tags --long]
Msg Info "Git describe: $describe"

set tags [TagRepository $merge_request $options(level)]
set old_tag [lindex $tags 0]
set new_tag [lindex $tags 1]
Msg Info "Old tag was: $old_tag and new tag is: $new_tag"


cd $repo_path
