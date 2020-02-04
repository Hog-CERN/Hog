set Name launch_synthesis
set path [file normalize "[file dirname [info script]]/.."]
if { $::argc eq 0 } {
    puts "USAGE: $::argv0 <project>"
    exit 1
} else {
    set project [lindex $argv 0]
	set main_folder [file normalize "$path/../../VivadoProject/$project/$project.runs/"]
	set NJOBS 4
}

set old_path [pwd]
cd $path
source ./hog.tcl
Msg Info "Number of jobs set to $NJOBS."
set commit [GetHash ALL ../../]

Msg Info "Opening $project..."
open_project ../../VivadoProject/$project/$project.xpr

Msg Info "Starting complete design flow..."
reset_run synth_1

launch_runs synth_1  -jobs $NJOBS -dir $main_folder
wait_on_run synth_1

set prog [get_property PROGRESS [get_runs synth_1]]
set status [get_property STATUS [get_runs synth_1]]
Msg Info "Run: synth_1 progress: $prog, status : $status"

if {$prog ne "100%"} {
    Msg Error "Synthesis error, status is: $status"
}

Msg Info "All done."
cd $old_path
