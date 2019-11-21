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

Info $Name 2 "Opening $project..."
open_project ../../VivadoProject/$project/$project.xpr

Info $Name 5 "Starting implementation flow..."

launch_runs impl_1 -jobs 4 -dir $main_folder
wait_on_run impl_1

set prog [get_property PROGRESS [get_runs impl_1]]
set status [get_property STATUS [get_runs impl_1]]
Info $Name 6 "Run: impl_1 progress: $prog, status : $status"

# Check timing
set wns [get_property STATS.WNS [get_runs [current_run]]]
set tns [get_property STATS.TNS [get_runs [current_run]]]
set whs [get_property STATS.WHS [get_runs [current_run]]]
set ths [get_property STATS.THS [get_runs [current_run]]]    

if {$wns >= 0 && $whs >= 0} {
    Info $Name 7 "Time requirements are met"
    set status_file [open "$main_folder/timing_ok" "w"]
} else {
    CriticalWarning $Name 7 "Time requirements are NOT met"
    set status_file [open "$main_folder/timing_error" "w"]
}

Status $Name 8 "WNS: $wns"
Status $Name 8 "TNS: $tns"
Status $Name 8 "WHS: $whs"
Status $Name 8 "THS: $ths"

puts $status_file "WNS: $wns"
puts $status_file "TNS: $tns"
puts $status_file "WHS: $whs"
puts $status_file "THS: $ths"        
close $status_file

if {$prog ne "100%"} {
    Error $Name 5 "Implementation error"
}

Info $Name 7 "All done."
cd $old_path
