set path [file normalize "[file dirname [info script]]/.."]
if { $::argc eq 0 } {
    puts "USAGE: $::argv0 <project> [no_bitstream]"
    puts ""
    puts "if no_bitstream is set to any value different than 0 (default), the bitstream file will not be produced."
    exit 1
} else {
    set project [lindex $argv 0]
    set main_folder [file normalize "$path/../../VivadoProject/$project/$project.runs/"]
    set do_bitstream 1
    if { $::argc > 1 } {
	if {[lindex $argv 1] != 0} {
	    set do_bitstream 0
	}
    }
}

set old_path [pwd]
cd $path
source ./hog.tcl

set commit [GetHash ALL ../../]

Msg Info "Opening $project..."
open_project ../../VivadoProject/$project/$project.xpr


Msg Info "Starting implementation flow..."
reset_run impl_1

launch_runs impl_1 -jobs 4 -dir $main_folder
wait_on_run impl_1

set prog [get_property PROGRESS [get_runs impl_1]]
set status [get_property STATUS [get_runs impl_1]]
Msg Info "Run: impl_1 progress: $prog, status : $status"

# Check timing
set wns [get_property STATS.WNS [get_runs [current_run]]]
set tns [get_property STATS.TNS [get_runs [current_run]]]
set whs [get_property STATS.WHS [get_runs [current_run]]]
set ths [get_property STATS.THS [get_runs [current_run]]]    

if {$wns >= 0 && $whs >= 0} {
    Msg Info "Time requirements are met"
    set status_file [open "$main_folder/timing_ok.txt" "w"]
} else {
    Msg CriticalWarning "Time requirements are NOT met"
    set status_file [open "$main_folder/timing_error.txt" "w"]
}

Msg Status "*** Timing summary ***"
Msg Status "WNS: $wns"
Msg Status "TNS: $tns"
Msg Status "WHS: $whs"
Msg Status "THS: $ths"

puts $status_file "WNS: $wns"
puts $status_file "TNS: $tns"
puts $status_file "WHS: $whs"
puts $status_file "THS: $ths"        
close $status_file

if {$prog ne "100%"} {
    Msg Error "Implementation error"
}


if {$do_bitstream == 1} {
    Msg Info "Starting write bitstream flow..."
    launch_runs impl_1 -to_step write_bitstream -jobs 4 -dir $main_folder
    wait_on_run impl_1
    
    set prog [get_property PROGRESS [get_runs impl_1]]
    set status [get_property STATUS [get_runs impl_1]]
    Msg Info "Run: impl_1 progress: $prog, status : $status"
    
    if {$prog ne "100%"} {
	Msg Error "Write bitstream error, status is: $status"
    }

    Msg Status "*** Timing summary (again) ***"
    Msg Status "WNS: $wns"
    Msg Status "TNS: $tns"
    Msg Status "WHS: $whs"
    Msg Status "THS: $ths"
}

Msg Info "All done."
cd $old_path
