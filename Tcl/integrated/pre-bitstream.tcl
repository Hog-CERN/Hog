#!/usr/bin/env tclsh
#   Copyright 2018-2023 The University of Birmingham
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

set old_path [pwd]
set tcl_path [file normalize "[file dirname [info script]]/.."]
source $tcl_path/hog.tcl

if {[IsQuartus]} {
  # Quartus
  Msg Error "Pre-module scripts are not supported in Quartus mode!"
  return TCL_ERROR
}

# Go to repository path
cd "$tcl_path/../.."

if {[IsXilinx]} {
  # Vivado + PlanAhead
  # Vivado + PlanAhead
  if {[IsISE]} {
    # planAhead
    set work_path [get_property DIRECTORY [get_runs impl_1]]
  } else {
    # Vivado
    set work_path $old_path
  }

  set proj_name [file tail [file normalize $work_path/../../]]
  set proj_dir [file normalize "$work_path/../.."]

  set group_name [GetGroupName $proj_dir "$tcl_path/../.."]

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

if {[IsXilinx]} {
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
