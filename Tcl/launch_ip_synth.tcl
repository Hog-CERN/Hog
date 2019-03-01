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

Info $Name 1 "Running project script: $project.tcl..."
source -notrace ../../Top/$project/$project.tcl
Info $Name 2 "Upgrading IPs if any..."
set ips [get_ips *]
if {$ips != ""} {
    upgrade_ip $ips
}

#foreach ip $ips {
#    Info $Name 3 "Launching run for $ip..."
#    if {[get_runs $ip*] != ""} {
#	set run_name [get_runs $ip*]
#	launch_runs $run_name -dir $main_folder
#	wait_on_run $run_name
#	puts [get_property PROGRESS $run_name]
#	puts [get_property STATUS $run_name]
#    }
#}

launch_runs synth_1 -dir $main_folder -jobs 4  
wait_on_run synth_1

cd $old_path
