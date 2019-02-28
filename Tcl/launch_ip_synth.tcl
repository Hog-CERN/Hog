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

Info $Name 2 "Running project script: $project.tcl..."
source -notrace ../../Top/$project/$project.tcl
Info $Name 3 "Upgrading IPs if any..."
set ips [get_ips *]
if {$ips != ""} {
    upgrade_ip $ips
}

foreach ip in $ips {
    puts "Launching run for $ip..."
    launch_runs [get_runs $ip*]  -dir $main_folder
    wait_on_run [get_runs $ip*]
    puts [get_property PROGRESS [get_runs $ip*]]
    puts [get_property STATUS [get_runs $ip*]]
}


cd $old_path
