#!/usr/bin/env tclsh

#parsing command options
if {[catch {package require cmdline} ERROR]} {
	puts "$ERROR\n If you are running this script on tclsh, you can fix this by installing 'tcllib'" 
	return
}

set parameters {
	{no_bitstream    "If set, the bitstream file will not be produced. If not set, it will check the enviromental variable \$HOG_NO_BITSTREAM. If \$HOG_NO_BITSTREAM is set to a value different from 0, the bitstream file will not be produced"}
}

set usage "- USAGE: $::argv0 <project> \[OPTIONS\]\n. Options:"
set path [file normalize "[file dirname [info script]]/.."]

if {[catch {array set options [cmdline::getoptions ::argv $parameters $usage]}] ||  [llength $argv] < 1 } {
	puts [cmdline::usage $parameters $usage]
	exit 1
} else {
    set project [lindex $argv 0]
    set main_folder [file normalize "$path/../../VivadoProject/$project/$project.runs/"]
    set do_bitstream 1
    if { $options(no_bitstream) == 1 } {
		set do_bitstream 0
    } else {
		if [info exists env(HOG_NO_BITSTREAM)] {
			if {$env(HOG_NO_BITSTREAM) != 0} {
				puts "\$HOG_NO_BITSTREAM is set to a value different from 0, bitstream will not be generated"
				set do_bitstream 0
			} 
		}
	}
}

set old_path [pwd]
cd $path
source ./hog.tcl

if {$do_bitstream == 1} {
    Msg Info "Will launch implementation and write bitstream..."
} else {
    Msg Info "Will launch implementation only..."
}

Msg Info "Opening project: $project..."
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
