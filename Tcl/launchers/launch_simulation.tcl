
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
Msg Info "Simulation library path is set to $lib_path."
if !([file exists $lib_path]) {
    Msg Error "Could not find simulation library path: $lib_path."
    exit -1
}

Msg Info "Opening project $project..."
open_project ../../VivadoProject/$project/$project.xpr
set_property "compxlib.modelsim_compiled_library_dir" $lib_path [current_project]
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

set errors 0
if [info exists simdirs] {
    foreach  s $simdirs {
	cd $s
	set cmd "./compile.sh"
	Msg Info "Compiling: $cmd..."
	set status [catch {exec $cmd} result]
	Msg Status "Compilation result\n******************\n$result"
	if {$status == 0} {
	    Msg Info "Compilation successful for $s."
	} else {
	    Msg CriticalWarning "Compilation failed foir $s"
	    incr errors
	}

	set cmd "./simulate.sh"
	Msg Info "Simulating: $cmd..."
	set status [catch {exec $cmd} result]
	Msg Status "Simulation result\n******************\n$result"
	if {$status == 0} {
	    Msg Info "Simulation successful for $s."
	} else {
	    Msg CriticalWarning "Simulation failed for $s."
	    incr errors
	}
    }
    
    if {$errors > 0) {
	Msg Error "Simualtion failed, there were $errors failures. Look above for details."
	exit -1
    }

} else {
    Msg Info "No simulation set was found in this project."
}

Msg Info "All done."
