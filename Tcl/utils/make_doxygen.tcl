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
# Create the doxygen documentation

#parsing command options
if {[catch {package require cmdline} ERROR]} {
  puts "$ERROR\n If you are running this script on tclsh, you can fix this by installing 'tcllib'" 
  return
}
set parameters {
}

set usage   "USAGE: $::argv0"

set repo_path [pwd]
set tcl_path [file dirname [info script]]
cd $tcl_path
source ../hog.tcl
cd $repo_path

if {[catch {array set options [cmdline::getoptions ::argv $parameters $usage]}] || $::argc != 0 } {
  Msg Info [cmdline::usage $parameters $usage]
  cd $repo_path
  exit 1
}

lassign [GetVer .] version commit
set version [HexVersionToString $version]
Msg Info "Creating doxygen documentation for tag $version"


# Run doxygen
set doxygen_conf "./doxygen/doxygen.conf"
if {[file exists $doxygen_conf] == 0 } {
    # Using Default hog template
  set doxygen_conf "./Hog/Templates/doxygen.conf"
  Msg Info "Running doxygen with ./Hog/Templates/doxygen.conf..."
} else {
  Msg Info "Running doxygen with $doxygen_conf..."
}

if {[DoxygenVersion 1.8.13]} {
  set outfile [open $doxygen_conf a]
  puts $outfile \nPROJECT_NUMBER=$version
  close $outfile
  Execute doxygen $doxygen_conf
}

cd $repo_path
