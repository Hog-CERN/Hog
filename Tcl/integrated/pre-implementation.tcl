#!/usr/bin/env tclsh


set old_path [pwd]
set tcl_path [file normalize "[file dirname [info script]]/.."]
source $tcl_path/hog.tcl

# Go to repository path
cd "$tcl_path/../.."

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


#number of threads
set maxThreads [GetMaxThreads $proj_name]
if {$maxThreads != 1} {
  Msg CriticalWarning "Multithreading enabled. Bitfile will not be deterministic. Number of threads: $maxThreads"
} else {
  Msg Info "Disabling multithreading to assure deterministic bitfile"
}

set_param general.maxThreads $maxThreads

cd $old_path
Msg Info "All done"
