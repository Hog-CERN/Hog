set Name LaunchIPSynthesis
set path [file normalize "../[file dirname [info script]]"]
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

Info $Name 1 "Opening project $project..."
open_project ../../VivadoProject/$project/$project.xpr


Info $Name 2 "Preparing runs..."
reset_run synth_1
launch_runs -scripts_only synth_1
reset_run synth_1

set ips [get_ips *]
foreach ip $ips {
    Info $Name 3 "Adding run for $ip..."
    if { [get_runs $ip\_synth_1] != "" } {
        set run_name [get_runs $ip\_synth_1]
        reset_run $run_name
	lappend runs $run_name
    } else {
        Warning $Name 3 "No run found for $ip."
    }
}

set jobs 4
foreach run_name $runs {
    Info $Name 4 "Launching $run_name..."
    launch_runs $run_name -dir $main_folder
    lappend running $run_name
    if {[llength $running] >= $jobs} {
	wait_on_run [get_runs [lindex $running 0]]
	set running [lreplace $running 0 0]
    }
}

while {[llength $running] > 0} {
    Info $Name 5 "Checking [lindex $running 0]..."
    wait_on_run [get_runs [lindex $running 0]]
    set running [lreplace $running 0 0]
}

foreach run_name $runs {
    set prog [get_property PROGRESS $run_name]
    set status [get_property STATUS $run_name]
    Info $Name 6 "Run: $run_name progress: $prog, status : $status"
    if {$prog ne "100%"} {
	set failure 1
    } else {
	set failure 0
    }
}

if {$failure eq 1} {
    Error $Name 7 "At least on IP synthesis failed"
}

Info $Name 8 "All done."
cd $old_path
