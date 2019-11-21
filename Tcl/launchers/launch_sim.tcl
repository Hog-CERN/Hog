set Name LaunchSim
if { $::argc eq 0 } {
    puts "USAGE: $::argv0 <project>"
    exit 1
} else {
    set project [lindex $argv 0]
#    if { $::argc > 1 } {
#	set main_folder [file normalize [lindex $argv 1]]
#    } else {
#	set main_folder [file normalize "../../VivadoProject/$project/$project.sim/"]
#    }
#
#    if { $::argc > 2 } {
#	set NJOBS [lindex $argv 2]
#    } else {
#	set NJOBS 4
#    }
#
#    if { $::argc > 3 } {
#	set no_time [lindex $argv 3]
#    } else {
#	set no_time 0
#    }
}

set old_path [pwd]
set path [file normalize "[file dirname [info script]]/.."]
cd $path
source ./hog.tcl

if [file exists ../../VivadoProject/$project/$project.xpr] {
    Info $Name 1 "Opening project $project..."
    open_project ../../VivadoProject/$project/$project.xpr
} else {
    Info $Name 2 "Running project script: $project.tcl..."
    source -notrace ../../Top/$project/$project.tcl
}

Info $Name 3 "Upgrading IPs if any..."
set ips [get_ips *]
if {$ips != ""} {
    upgrade_ip $ips
}

set sims [get_filesets -regexp .*_sim]
Info $Name 1 "Simulations file sets found: $sims"
Info $Name 2 "Looping over simulation filesets..."
foreach s $sims {
    set top [get_property TOP $s]
    set do  [get_property MODELSIM.SIMULATE.CUSTOM_UDO $s]
    if {$top != "" && $do != ""} {
	Info $Name 3 "Simulating set $s with top file: $top and do file: $do"
	launch_simulation -simset $s 
    }
}

Info $Name 1 "All done."
cd $old_path
