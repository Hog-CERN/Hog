set Name LaunchWriteBitstream
set path [file normalize "[file dirname [info script]]/.."]
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

Msg Info "Opening $project..."
open_project ../../VivadoProject/$project/$project.xpr

Msg Info "Starting write bitstream flow..."

launch_runs impl_1 -to_step write_bitstream -jobs 4 -dir $main_folder
wait_on_run impl_1

set prog [get_property PROGRESS [get_runs impl_1]]
set status [get_property STATUS [get_runs impl_1]]
Msg Info "Run: impl_1 progress: $prog, status : $status"

if {$prog ne "100%"} {
    Msg Error "Write bitstream error, status is: $status"
}
Msg Info "All done."
cd $old_path
