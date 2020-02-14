
set path [file normalize "[file dirname [info script]]/.."]
if { $::argc eq 0 } {
    puts "USAGE: $::argv0 <project> [questa library path]"
    exit 1
} else {
    set project [lindex $argv 0]
    set main_folder [file normalize "$path/../../VivadoProject/$project/$project.sim/"]

    if {[llength $argv] > 1} {
	set lib_path [lindex $argv 1]
    } else {
	set lib_path [file normalize "$main_folder/../../../ModelsimLib"]
    }
}

set old_path [pwd]
cd $path
source ./hog.tcl
Msg Info "Opening project $project..."
open_project ../../VivadoProject/$project/$project.xpr

Msg Info "Retrieving list of simulation sets..."


foreach s [get_filesets] {
    set type [get_property FILESET_TYPE $s]
    if {$type eq "SimulationSrcs"} {
	if {!($s eq "sim_1")} { 
	    Msg Info "Creating simulation scripts for $s..."
	    launch_simulation -scripts_only -simset $s
	    set sim_dir  [file normalize $main_folder/$s/behav/modelsim] 
	    Msg Info "Setting script location for $s: $sim_dir..."
	    lappend simdirs $sim_dir
	}
    }
}

if [info exists simdirs] {
    puts $simdirs
} else {
    Msg Info "No simulation set was found in this project."
}
