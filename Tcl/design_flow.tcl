set i 0

if { $::argc eq 0 } {
    puts "USAGE: $::argv0 <project> [output directory]"
   exit 1
} else {
    set project [lindex $argv 0]
    if { $::argc eq 2 } {
	set main_folder [file normalize [lindex $argv 1]]

    } else {
	set main_folder [file normalize "../VivadoProject"]
    }
}


set Name "*** DesignFlow ***"
set old_path [pwd]
set path [file normalize [file dirname [info script]]]
cd $path
source ./functions.tcl

Info $Name [incr i] "Project: $project, Output directory: $main_folder"
Info $Name [incr i] "Evaluating firmware date and possibly git commit hash..."

if { [exec git status --untracked-files=no  --porcelain] eq "" } {
    Info $Name [incr i] "Git working directory [pwd] clean."
    set commit [GetHash ALL]
    set clean "yes"
} else {
    Error $Name [incr i] "Git working directory [pwd] not clean."
    exit
}

# IPBUS submodule
cd "../eFEX-ipbus"
if { [exec git status --untracked-files=no  --porcelain] eq "" } {
    Info $Name [incr i] "IPBus Git working directory [pwd] clean."
    set ipb_clean "yes"
} else {
    Error $Name [incr i] "IPBus Git working directory [pwd] not clean"
    exit
}

cd $path
if { $clean eq "yes" &&  $ipb_clean eq "yes" } { 
    set new_dir "$commit"
} else {
    set clock_seconds [clock seconds]
    set date [clock format $clock_seconds  -format {%d-%m-%Y}]
    set timee [clock format $clock_seconds -format {%H-%M-%S}]
    set new_dir "$date\_$timee"
}

file mkdir $main_folder/$project/$new_dir

set synth_dir [ file normalize $main_folder/$project/$new_dir/synth]
set impl_dir [ file normalize $main_folder/$project/$new_dir/impl]
set status_file [file normalize $main_folder/$project/$new_dir/status]

fInfo $status_file $Name [incr i] "Running project script: $project.tcl..."
source -notrace ../Top/$project/$project.tcl

fInfo $status_file $Name [incr i] "Running pre synthesis script"
source -notrace $path/pre-synthesis.tcl

fInfo $status_file $Name [incr i] "Creating design flow directory: $synth_dir"
file mkdir $synth_dir
cd $synth_dir

fInfo $status_file $Name [incr i] "Upgrading IPs..."
upgrade_ip [get_ips *]

fInfo $status_file $Name [incr i] "Generating IPs..."
generate_target all [get_ips *]

fInfo $status_file $Name [incr i] "Synthesizing IPs..."
synth_ip  [get_ips *]

fInfo $status_file $Name [incr i] "Updating compiling order..."
update_compile_order

fInfo $status_file $Name [incr i] "Synthesizing design..."
synth_design

fInfo $status_file $Name [incr i] "Writing synthesised checkpoint..."
write_checkpoint -force top_$project-synth.dcp

fInfo $status_file $Name [incr i] "Writing post-synthesis reports..."
set report1 [file normalize top_$project-post_synth-utilization.txt]
report_utilization -file $report1


fInfo $status_file $Name [incr i] "Creating design flow directory: $impl_dir"
file mkdir $impl_dir
cd $impl_dir

fInfo $status_file $Name [incr i] "Optimising design..."
opt_design

fInfo $status_file $Name [incr i] "Placing design..."
place_design

fInfo $status_file $Name [incr i] "Writing placed checkpoint..."
write_checkpoint -force top_$project-place.dcp

fInfo $status_file $Name [incr i] "Physically optimising design..."
phys_opt_design

fInfo $status_file $Name [incr i] "Routing design..."
route_design

fInfo $status_file $Name [incr i] "Writing routed checkpoint..."
write_checkpoint -force top_$project-routed.dcp

fInfo $status_file $Name [incr i] "Writing post-routing reports..."
set report2 [file normalize top_$project-timing.txt]
report_timing_summary -file $report2
set report3 [file normalize top_$project-utilization.txt]
report_utilization -file $report3
set report4 [file normalize top_$project-power.txt]
report_power -file $report4

fInfo $status_file $Name [incr i] "Wrtiting bitstream..."
write_bitstream -force $project\_$new_dir.bit

fInfo $status_file $Name [incr i] "Sending mail..."

set mail_text "Design flow done."

exec cat $report2 | grep "Design Timing Summary" -B1 -A12  | mail -s "Completed design flow for $project ($commit)" -a $report1 -a $report2 -a $report3 -a $report4 l1calo-efex@cern.ch

cd $old_path
fInfo $status_file $Name [incr i] "All done, have fun."
