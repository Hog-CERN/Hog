#!/usr/bin/env tclsh
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
Msg Info "Evaluating repository git SHA..."
set commit "0000000"
if { [exec git status --untracked-files=no  --porcelain] eq "" } {
    Msg Info "Git working directory [pwd] clean."
    lassign [GetVer ALL ./] version commit
} else {
    Msg CriticalWarning "Git working directory [pwd] not clean, git commit hash be set to 0."
    set commit   "0000000"
}

set commit_usr [exec git rev-parse --short=8 HEAD]

Msg Info "The git SHA value $commit will be set as bitstream USERID."

# Set bitstream embedded variables
set_property BITSTREAM.CONFIG.USERID $commit [current_design]
set_property BITSTREAM.CONFIG.USR_ACCESS $commit_usr [current_design]

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

cd $old_path

Msg Info "All done."
