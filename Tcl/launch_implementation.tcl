set Name LaunchRuns
set path [file normalize [file dirname [info script]]]
if { $::argc eq 0 } {
    puts "USAGE: $::argv0 <project>"
    exit 1
} else {
    set project [lindex $argv 0]
	set main_folder [file normalize "$path/../../VivadoProject/$project/$project.runs/"]
}

set old_path [pwd]
cd $path
source ./hog.tcl
Info $Name 1 "Number of jobs set to $NJOBS."

set commit [GetHash ALL ../../]

Info $Name 2 "Opening project: $project.tcl..."
open_project ../../VivadoProject/$project/$project.tcl

Info $Name 5 "Starting implementation flow..."

launch_runs impl_1 -to_step write_bitstream -jobs $NJOBS -dir $main_folder
wait_on_run impl_1
puts [get_property PROGRESS [get_runs impl_1]]
puts [get_property STATUS [get_runs impl_1]]

cd $old_path
