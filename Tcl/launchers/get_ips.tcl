set path [file normalize "[file dirname [info script]]/.."]
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

if [info exists env(HOG_IP_EOS_PATH)] {
    set ip_path $env(HOG_IP_EOS_PATH)
    Msg Info "Will use the EOS ip repository on $ip_path to speed up ip synthesis..."
} else {
    set ip_path 0
}


Msg Info "Opening project $project..."
open_project ../../VivadoProject/$project/$project.xpr


Msg Info "Preparing runs..."
reset_run synth_1
launch_runs -scripts_only synth_1
reset_run synth_1

set ips [get_ips *]
if {($ip_path != 0) && ($ips != "")  } {
    Msg Info "Scanning through all the IPs and possibly copying synthesis result from the EOS path..."
    set copied_ips 0
    foreach ip $ips {
	set ret [HandleIP pull [get_property IP_FILE $ip] $ip_path $main_folder]
	if {$ret == 0} {
	    incr copied_ips 
	}
    }

    Msg Info "$copied_ips were copied from the EOS repository"

    if {$copied_ips > 0} {
	Msg Info "Re-creating project $project..."
	close_project
	source ../../Top/$project/$project.tcl
    }
}

Msg Info "All done."
cd $old_path
