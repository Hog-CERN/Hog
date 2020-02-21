set simulator xsim
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
	set lib_path [file normalize "$main_folder/../../../SimulationLib"]
    }
}


set old_path [pwd]
cd $path
source ./hog.tcl
Msg Info "Simulation library path is set to $lib_path."
if !([file exists $lib_path]) {
    Msg Error "Could not find simulation library path: $lib_path."
    exit -1
}

Msg Info "Opening project $project..."
open_project ../../VivadoProject/$project/$project.xpr
# set_property "compxlib.modelsim_compiled_library_dir" $lib_path [current_project]
Msg Info "Retrieving list of simulation sets..."

foreach s [get_filesets] {
    set type [get_property FILESET_TYPE $s]
    if {$type eq "SimulationSrcs"} {
	if {!($s eq "sim_1")} { 
	    Msg Info "Creating simulation scripts for $s..."
	    current_fileset -simset $s
	    set sim_dir $main_folder/$s/behav
	    launch_simulation -simset [get_filesets $s]
	}
    }
}

Msg Info "Generating IP simulation targets, if any..."

foreach ip [get_ips] {
    generate_target simulation $ip
}

Msg Info "All done."
