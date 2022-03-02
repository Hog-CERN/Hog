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
# Create the doxygen documentation

#parsing command options
if {[catch {package require cmdline} ERROR]} {
  puts "$ERROR\n If you are running this script on tclsh, you can fix this by installing 'tcllib'"
  return
}
set parameters {
}

set usage   "USAGE: $::argv0"

set tcl_path [file dirname [info script]]
set repo_path [file normalize $tcl_path/../../..]
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
  if {![DoxygenVersion 1.9.1]} {
    Msg Warning "It seems that you are using Doxygen version [Execute doxygen --version]. We recommend Doxygen version 1.9.1 or higher"
  }
  set conffile [open $doxygen_conf r+]
  #replacing PROJECT_NUMBER with current version if existing, otherwise adding it
  set buf_tmp ""
  set VERSION_SET False
  set conf_read [read $conffile]
  foreach line [split $conf_read \n] {
    if {[string match "#*" [string trim $line]]} {
      append buf_tmp "\n$line"
    } elseif  {[string first "PROJECT_NUMBER" $line] != -1} {
      set VERSION_SET True
      append  buf_tmp "\nPROJECT_NUMBER         = $version"
    } else {
      append buf_tmp "\n$line"
    }
  }
  if {!$VERSION_SET} {
    append buf_tmp "\nPROJECT_NUMBER         = $version"
  }
  close $conffile
  #removing first endline
  set buf_tmp [string range $buf_tmp 1 end]

  set doxygen_conf_out ".doxygen.conf"
  set outfile [open $doxygen_conf_out w+]
  puts -nonewline $outfile $buf_tmp
  close $outfile

  Execute doxygen $doxygen_conf_out
  file delete $doxygen_conf_out
} else {
  cd $repo_path
  Msg Error "Cannot find Doxygen version 1.8.13 or higher"
}

cd $repo_path
