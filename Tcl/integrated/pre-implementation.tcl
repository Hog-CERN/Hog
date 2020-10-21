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

set old_path [pwd]
set tcl_path [file normalize "[file dirname [info script]]/.."]
source $tcl_path/hog.tcl

# Go to repository path
cd "$tcl_path/../.."

if {[info commands get_property] != ""} {
  # Vivado
  if { [string first PlanAhead [version]] == 0 } {
      set proj_file [get_property DIRECTORY [current_project]]
  } else {
      set proj_file [get_property parent.project_path [current_project]]
  }
} elseif {[info commands project_new] != ""} {
    # Quartus
  set proj_file "/q/a/r/Quartus_project.qpf"
} else {
    #Tclssh
  set proj_file $old_path/[file tail $old_path].xpr
  Msg CriticalWarning "You seem to be running locally on tclsh, so this is a debug, the project file will be set to $proj_file and was derived from the path you launched this script from: $old_path. If you want this script to work properly in debug mode, please launch it from the top folder of one project, for example Repo/VivadoProject/fpga1/ or Repo/Top/fpga1/"
}

set proj_dir [file normalize [file dirname $proj_file]]
set proj_name [file rootname [file tail $proj_file]]


#number of threads
set maxThreads [GetMaxThreads $proj_name]
if {$maxThreads != 1} {
  Msg CriticalWarning "Multithreading enabled. Bitfile will not be deterministic. Number of threads: $maxThreads"
} else {
  Msg Info "Disabling multithreading to assure deterministic bitfile"
}

if {[info commands get_property] != ""} {
    # Vivado
  set_param general.maxThreads $maxThreads
} elseif {[info commands project_new] != ""} {
    # Quartus
  #TO BE IMPLEMENTED
} else {
    #Tclssh
}

set user_pre_implementation_file "./Top/$proj_name/pre-implementation.tcl"
if {[file exists $user_pre_implementation_file]} {
    Msg Status "Sourcing user pre-implementation file $user_pre_implementation_file"
    source $user_pre_implementation_file
}

cd $old_path
Msg Info "All done"
