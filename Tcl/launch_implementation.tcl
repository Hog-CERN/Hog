set Name LaunchImplementation
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

set commit [GetHash ALL ../../]

Info $Name 2 "Opening project: $project.tcl..."
open_project ../../VivadoProject/$project/$project.tcl

Info $Name 5 "Starting implementation flow..."

launch_runs impl_1 -to_step write_bitstream -jobs 4 -dir $main_folder
wait_on_run impl_1

set prog [get_property PROGRESS impl_1]
set status [get_property STATUS impl_1]

Info $Name 6 "Run: impl_1 progress: $prog, status : $status"
Info $Name 7 "All done."
cd $old_path
