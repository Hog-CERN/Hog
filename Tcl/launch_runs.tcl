set Name LaunchRuns
if { $::argc eq 0 } {
    puts "USAGE: $::argv0 <project> \[output directory\] \[number of jobs\]"
    exit 1
} else {
    set project [lindex $argv 0]
    if { $::argc > 1 } {
	set main_folder [file normalize [lindex $argv 1]]
    } else {
	set main_folder [file normalize "../../VivadoProject/$project/$project.runs/"]
    }

    if { $::argc > 2 } {
	set NJOBS [lindex $argv 2]
    } else {
	set NJOBS 4
    }

    if { $::argc > 3 } {
	set no_time [lindex $argv 3]
    } else {
	set no_time 0
    }
}

set old_path [pwd]
set path [file normalize [file dirname [info script]]]
cd $path
source ./hog.tcl
Info $Name 1 "Number of jobs set to $NJOBS."

set commit [GetHash ALL ../../]

Info $Name 2 "Running project script: $project.tcl..."
source -notrace ../../Top/$project/$project.tcl
Info $Name 3 "Upgrading IPs if any..."
set ips [get_ips *]
if {$ips != ""} {
    upgrade_ip $ips
}
Info $Name 4 "Creating directory and buypass file..."
file mkdir $main_folder
set cfile [open $main_folder/buypass_commit w]
puts $cfile $commit
close $cfile
if {$no_time == 1 } {
    set cfile [open $main_folder/no_time w]
    puts $cfile $commit
    close $cfile
}
Info $Name 5 "Starting complete design flow..."
launch_runs impl_1 -to_step write_bitstream -jobs $NJOBS -dir $main_folder
wait_on_run synth_1
puts get_property PROGRESS [get_runs synth_1]
puts get_property STATUS [get_runs synth_1]
wait_on_run impl_1
puts get_property PROGRESS [get_runs impl_1]
puts get_property STATUS [get_runs impl_1]
cd $old_path
