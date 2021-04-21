#!/usr/bin/env tclsh
#   Copyright 2018-2021 The University of Birmingham
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

if {[info commands project_new] != ""} {
  # Quartus
  Msg Error "Pre-module scripts are not supported in Quartus mode!"
  return TCL_ERROR
}

set old_path [pwd]
set tcl_path [file normalize "[file dirname [info script]]/.."]
source $tcl_path/hog.tcl

# Go to repository path
cd "$tcl_path/../.."

if {[info commands get_property] != ""} {
  # Vivado + PlanAhead
  if { [string first PlanAhead [version]] == 0 } {
    # planAhead
    set proj_file [get_property DIRECTORY [current_project]]
    set proj_name  [file tail [get_property DIRECTORY [current_project]]]
  } else {
    # vivado
    set proj_name [file tail [file normalize $old_path/../..]]
    set proj_file [get_property parent.project_path [current_project]]
  }
  set index_a [string last "Projects/" $proj_dir]
  set index_a [expr $index_a + 9]
  set index_b [string last "/$proj_name" $proj_dir]
  set index_b [expr $index_b - 1]
  set group_name [string range $proj_dir $index_a $index_b]

} else {
  #Tclssh
  set proj_name [file tail [file normalize $old_path/../..]]
  Msg CriticalWarning "You seem to be running locally on tclsh, so this is a debug, the project file will be set to $proj_file and was derived from the path you launched this script from: $old_path. If you want this script to work properly in debug mode, please launch it from the top folder of one project, for example Repo/Projects/fpga1/ or Repo/Top/fpga1/"
}


#number of threads
set maxThreads [GetMaxThreads [file normalize $tcl_path/../../Top/$group_name/$proj_name]]
if {$maxThreads != 1} {
  Msg CriticalWarning "Multithreading enabled. Bitfile will not be deterministic. Number of threads: $maxThreads"
} else {
  Msg Info "Disabling multithreading to assure deterministic bitfile"
}

if {[info commands get_property] != ""} {
  # Vivado
  set_param general.maxThreads $maxThreads
} else {
  #Tclssh
}

######## Reset files before bitstream creation ###########
ResetRepoFiles "./Projects/hog_reset_files"

set user_pre_bitstream_file "./Top/$group_name/$proj_name/pre-bitstream.tcl"
if {[file exists $user_pre_bitstream_file]} {
  Msg Info "Sourcing user pre-bitstream file $user_pre_bitstream_file"
  source $user_pre_bitstream_file
}

cd $old_path
Msg Info "All done."
