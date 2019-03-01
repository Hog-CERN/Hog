set Name LaunchIPSynthesis
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

Info $Name 1 "Opening project $project..."
open_project ../../VivadoProject/$project/$project.xpr


Info $Name 2 "Preparing runs..."
reset_run synth_1
launch_runs -scripts_only synth_1
reset_run synth_1

set ips [get_ips *]
foreach ip $ips {
    Info $Name 3 "Launching run for $ip..."
    if { [get_runs $ip\_synth_1] != "" } {
        set run_name [get_runs $ip\_synth_1]
        set run_name [get_runs $ip\_synth_1]

        reset_run $run_name
        launch_runs $run_name -dir $main_folder
        wait_on_run $run_name
        puts [get_property PROGRESS $run_name]
        puts [get_property STATUS $run_name]
    } else {
        Warning $Name 3 "No run found for $ip."
    }
}

launch_runs synth_1 -dir $main_folder -jobs 4
wait_on_run synth_1

cd $old_path
