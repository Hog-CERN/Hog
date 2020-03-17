#!/usr/bin/env tclsh

#parsing command options
if {[catch {package require cmdline} ERROR]} {
	puts "$ERROR\n If you are running this script on tclsh, you can fix this by installing 'tcllib'" 
	return
}

set parameters {
	{outdir.arg ""   "Output directory. Default: VivadoProject/<project>/<project>.runs/"}
	{NJOBS.arg  4    "Number of jobs. Default: 4"}
	{no_time         "no_time"}
}

set usage "- USAGE: $::argv0 <project> \[OPTIONS\]\n. Options:"

set Name LaunchRuns
set path [file normalize "[file dirname [info script]]/.."]
if { [catch {array set options [cmdline::getoptions ::argv $parameters $usage]}] ||  [llength $argv] < 1 } {
    puts [cmdline::usage $parameters $usage]
    exit 1
} else {
    set project [lindex $argv 0]
    if { $options(outdir)!= "" } {
	set main_folder [file normalize $options(outdir)]
    } else {
	set main_folder [file normalize "$path/../../VivadoProject/$project/$project.runs/"]
    }

}

set old_path [pwd]
cd $path
source ./hog.tcl
Msg Info "Number of jobs set to $options(NJOBS)."

set commit [GetHash ALL ../../]

Msg Info "Running project script: $project.tcl..."
source -notrace ../../Top/$project/$project.tcl
Msg Info "Upgrading IPs if any..."
set ips [get_ips *]
if {$ips != ""} {
    upgrade_ip $ips
}
Msg Info "Creating directory and buypass file..."
file mkdir $main_folder
set cfile [open $main_folder/buypass_commit w]
puts $cfile $commit
close $cfile
if {$options(no_time) == 1 } {
    set cfile [open $main_folder/no_time w]
    puts $cfile $commit
    close $cfile
}
Msg Info "Starting complete design flow..."
launch_runs impl_1 -to_step write_bitstream -jobs $options(NJOBS) -dir $main_folder
cd $old_path
