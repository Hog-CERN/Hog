set Name LaunchWriteBitstream
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

Info $Name 2 "Opening $project..."
open_project ../../VivadoProject/$project/$project.xpr

Info $Name 5 "Starting write bitstream flow..."

# write_bitstream $project.bit
launch_runs impl_1 -to_step write_bitstream -jobs 4 -dir $main_folder
wait_on_run impl_1

set prog [get_property PROGRESS [get_runs impl_1]]
set status [get_property STATUS [get_runs impl_1]]
Info $Name 6 "Run: impl_1 progress: $prog, status : $status"

if {$prog ne "100%"} {
    Error $Name 5 "Write bitstream error, status is: $status"
}
Info $Name 7 "All done."
cd $old_path
