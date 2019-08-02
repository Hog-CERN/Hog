set Name launch_synthesis
set path [file normalize [file dirname [info script]]]
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
Info $Name 1 "Number of jobs set to $NJOBS."
set commit [GetHash ALL ../../]

Info $Name 2 "Opening $project..."
open_project ../../VivadoProject/$project/$project.xpr

Info $Name 3 "Starting complete design flow..."
launch_runs synth_1  -jobs $NJOBS -dir $main_folder
wait_on_run synth_1

set prog [get_property PROGRESS [get_runs synth_1]]
set status [get_property STATUS [get_runs synth_1]]
Info $Name 4 "Run: synth_1 progress: $prog, status : $status"

if {$status ne "Complete!"} {
    Error $Name 5 "Synthesis error"
}

Info $Name 6 "All done."
cd $old_path
