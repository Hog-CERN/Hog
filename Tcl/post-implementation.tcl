set NAME "Post_Implementation"
set old_path [pwd]
set tcl_path [file dirname [info script]]
source $tcl_path/hog.tcl

set run_path [file normalize "$old_path/.."]

    
# Check timing
set wns [get_property STATS.WNS [get_runs impl_1]]
set tns [get_property STATS.TNS [get_runs impl_1]]
set whs [get_property STATS.WHS [get_runs impl_1]]
set ths [get_property STATS.THS [get_runs impl_1]]    

if {$wns == 0 && $whs == 0} {
    Info $NAME 7 "Time requirements are met"
    set status_file [open "$run_path/timing_ok.txt" "w"]
} else {
 	CriticalWarning $NAME 7 "Time requirements are NOT met"
    set status_file [open "$run_path/timing_error.txt" "w"]
}

Status $NAME 8 "WNS: $wns"
Status $NAME 8 "TNS: $tns"
Status $NAME 8 "WHS: $whs"
Status $NAME 8 "THS: $ths"

puts $status_file "WNS: $wns"
puts $status_file "TNS: $tns"
puts $status_file "WHS: $whs"
puts $status_file "THS: $ths"        
close $status_file

cd $old_path
Info $NAME 8 "All done."
