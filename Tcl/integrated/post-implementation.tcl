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
    # Vivado + planAhead
    if { [string first PlanAhead [version]] == 0 } {
        set proj_file [get_property DIRECTORY [current_project]]
    } else {
        set proj_file [get_property parent.project_path [current_project]]
    }
    set proj_dir [file normalize [file dirname $proj_file]]
    set proj_name [file rootname [file tail $proj_file]]
    set index_a [string last "Projects/" $proj_dir]
    set index_a [expr $index_a + 8]
    set index_b [string last "/$proj_name" $proj_dir]
    set group_name [string range $proj_dir $index_a $index_b]
} elseif {[info commands project_new] != ""} {
    # Quartus
  set proj_name [lindex $quartus(args) 1]
} else {
    #Tclssh
  set proj_file $old_path/[file tail $old_path].xpr
  Msg CriticalWarning "You seem to be running locally on tclsh, so this is a debug, the project file will be set to $proj_file and was derived from the path you launched this script from: $old_path. If you want this script to work properly in debug mode, please launch it from the top folder of one project, for example Repo/Projects/fpga1/ or Repo/Top/fpga1/"
}


Msg Info "Evaluating last git SHA in which $proj_name was modified..."
set commit "0000000"

lassign [GitRet {status --untracked-files=no  --porcelain}] ret msg
if {$ret !=0} {
  Msg Error "Git status failed: $msg"
}

if {$msg eq "" } {
  Msg Info "Git working directory [pwd] clean."
  lassign [GetRepoVersions [file normalize ./Top/$group_name/$proj_name]] commit version
  Msg Info "Found last SHA for $proj_name: $commit"

} else {
  Msg CriticalWarning "Git working directory [pwd] not clean, git commit hash be set to 0."
  set commit   "0000000"
}

#number of threads
set maxThreads [GetMaxThreads [file normalize ./Top/$group_name/$proj_name]]
if {$maxThreads != 1} {
  Msg CriticalWarning "Multithreading enabled. Number of threads: $maxThreads"
  set commit_usr   "0000000"
} else {
 set commit_usr $commit
}

Msg Info "The git SHA value $commit will be set as bitstream USERID."

# Set bitstream embedded variables
if {[info commands send_msg_id] != ""} {
    if { [string first PlanAhead [version]] == 0 } {
        # get the existing "more options" so that we can append to them when adding the userid
        set props [get_property "STEPS.BITGEN.ARGS.MORE OPTIONS" [get_runs impl_1]]
        # need to trim off the curly braces that were used in creating a dictionary
        regsub -all {\{|\}} $props "" props
		set PART [get_property part [current_project]]
		if {[string first "xc5v" $PART] != -1 || [string first "xc6v" $PART] != -1 || [string first "xc7" $PART] != -1} {
        	set props  "$props -g usr_access:0x0$commit -g userid:0x0$commit_usr"
		} else {
			set props  "$props -g userid:0x0$commit_usr"
		}
        set_property -name {steps.bitgen.args.More Options} -value $props -objects [get_runs impl_1]
    } else {
        set_property BITSTREAM.CONFIG.USERID $commit [current_design]
        set_property BITSTREAM.CONFIG.USR_ACCESS $commit_usr [current_design]
    }
} elseif {[info commands post_message] != ""} {
  # Quartus TODO
} else {
  # Tclsh
}

set user_post_implementation_file "./Top/$group_name/$proj_name/post-implementation.tcl"
if {[file exists $user_post_implementation_file]} {
    Msg Info "Sourcing user post_implementation file $user_post_implementation_file"
    source $user_post_implementation_file
}
cd $old_path
Msg Info "All done."
