# @file
# Launch vivado synthesis in text mode

#parsing command options
if {[catch {package require cmdline} ERROR]} {
  puts "$ERROR\n If you are running this script on tclsh, you can fix this by installing 'tcllib'"
  return
}
set parameters {
  {NJOBS.arg 4 "Number of jobs. Default: 4"}
}

set usage   "USAGE: $::argv0 <project>"
set Name launch_synthesis
set path [file normalize "[file dirname [info script]]/.."]


set old_path [pwd]
cd $path
source ./hog.tcl

if {[catch {array set options [cmdline::getoptions ::argv $parameters $usage]}] || $::argc eq 0 } {
  Msg Info [cmdline::usage $parameters $usage]
  cd $old_path
  exit 1
} else {
  set project [lindex $argv 0]
  set main_folder [file normalize "$path/../../VivadoProject/$project/$project.runs/"]
}
Msg Info "Number of jobs set to $options(NJOBS)."
set commit [GetHash ALL ../../]

Msg Info "Opening $project..."
open_project ../../VivadoProject/$project/$project.xpr

reset_run synth_1

launch_runs synth_1  -jobs $options(NJOBS) -dir $main_folder
wait_on_run synth_1

set prog [get_property PROGRESS [get_runs synth_1]]
set status [get_property STATUS [get_runs synth_1]]
Msg Info "Run: synth_1 progress: $prog, status : $status"

if {$prog ne "100%"} {
  Msg Error "Synthesis error, status is: $status"
}

# Copy IP reports in bin/
set ips [get_ips *]
cd $old_path
set describe [exec git describe --always --dirty --tags --long]

foreach ip $ips {
  set xci_file [get_property IP_FILE $ip]
  set xci_path [file dir $xci_file]
  set xci_ip_name [file root [file tail $xci_file]]
  foreach rptfile [glob -nocomplain -directory $xci_path *.rpt] {
    file copy $rptfile $old_path/bin/$project-$describe/reports
  }
}


Msg Info "All done."
cd $old_path
