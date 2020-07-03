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
# The post implementation script embeds the git SHA of the current commit into the binary file of the project.
# In Vivado this is done using the USERID and USR_ACCESS variables.
# The USERID is always set to the commit, while the USR_ACCESS only if Hog can guarantee the reploducibility of the firmware workflow:
#
# - The firmware repostory must be clean (no uncommitted modification)
# - The Multithread option must be disabled
# This script is automatically integrated into the Vivado/Quartus workflow by the Create Project script.

set old_path [pwd]
set tcl_path [file normalize "[file dirname [info script]]/.."]
source $tcl_path/hog.tcl
# Go to repository pathcd $old_pathcd $old_path
cd $tcl_path/../../

if {[info commands get_property] != ""} {
    # Vivado
  set proj_file [get_property parent.project_path [current_project]]
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


Msg Info "Evaluating last git SHA in which $project_name was modified..."
set commit "0000000"
if { [exec git status --untracked-files=no  --porcelain] eq "" } {
  Msg Info "Git working directory [pwd] clean."
  lassign [GetRepoVersion ./Top/$proj_name/$proj_name.tcl] commit version
  Msg Info "Found last SHA for $proj_name: $commit"

} else {
  Msg CriticalWarning "Git working directory [pwd] not clean, git commit hash be set to 0."
  set commit   "0000000"
}

#number of threads
set maxThreads [GetMaxThreads $proj_name]
if {$maxThreads != 1} {
  Msg CriticalWarning "Multithreading enabled. Number of threads: $maxThreads"
  set commit_usr   "0000000"
} else {
 set commit_usr $commit
}

Msg Info "The git SHA value $commit will be set as bitstream USERID."

# Set bitstream embedded variables
if {[info commands send_msg_id] != ""} {
  #Vivado 
  set_property BITSTREAM.CONFIG.USERID $commit [current_design]
  set_property BITSTREAM.CONFIG.USR_ACCESS $commit_usr [current_design]
} elseif {[info commands post_message] != ""} {
  # Quartus
} else {
  # Tclsh
}

cd $old_path
Msg Info "All done."
