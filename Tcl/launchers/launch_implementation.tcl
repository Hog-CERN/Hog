# @file
#   Copyright 2018-2020 The University of Birmingham
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.


# Launch vivado implementation and possibly write bitstream in text mode

#parsing command options
if {[catch {package require cmdline} ERROR]} {
  puts "$ERROR\n If you are running this script on tclsh, you can fix this by installing 'tcllib'"
  return
}

if {[catch {package require struct::matrix} ERROR]} {
  puts "$ERROR\n If you are running this script on tclsh, you can fix this by installing 'tcllib'"
  return
}

set parameters {
  {no_bitstream    "If set, the bitstream file will not be produced."}
  {NJOBS.arg 4 "Number of jobs. Default: 4"}
}

set usage "- USAGE: $::argv0 \[OPTIONS\] <project> \n. Options:"
set path [file normalize "[file dirname [info script]]/.."]

if {[catch {array set options [cmdline::getoptions ::argv $parameters $usage]}] ||  [llength $argv] < 1 } {
  Msg Info [cmdline::usage $parameters $usage]
  exit 1
} else {
  set project [lindex $argv 0]
  set main_folder [file normalize "$path/../../VivadoProject/$project/$project.runs/"]
  set do_bitstream 1
  if { $options(no_bitstream) == 1 } {
    set do_bitstream 0
  }
}

set old_path [pwd]
set bin_dir [file normalize "$old_path/bin"]
puts "old_path: $old_path \n bin_dir: $bin_dir \n path: $path "
cd $path
source ./hog.tcl

if {$do_bitstream == 1} {
  Msg Info "Will launch implementation and write bitstream..."
} else {
  Msg Info "Will launch implementation only..."
}

Msg Info "Opening project: $project..."
open_project ../../VivadoProject/$project/$project.xpr

Msg Info "Number of jobs set to $options(NJOBS)."

Msg Info "Starting implementation flow..."
reset_run impl_1

launch_runs impl_1 -jobs $options(NJOBS) -dir $main_folder
wait_on_run impl_1

set prog [get_property PROGRESS [get_runs impl_1]]
set status [get_property STATUS [get_runs impl_1]]
Msg Info "Run: impl_1 progress: $prog, status : $status"

# Check timing
set wns [get_property STATS.WNS [get_runs [current_run]]]
set tns [get_property STATS.TNS [get_runs [current_run]]]
set whs [get_property STATS.WHS [get_runs [current_run]]]
set ths [get_property STATS.THS [get_runs [current_run]]]

if {$wns >= 0 && $whs >= 0} {
  Msg Info "Time requirements are met"
  set status_file [open "$main_folder/timing_ok.txt" "w"]
  set timing_ok 1
} else {
  Msg CriticalWarning "Time requirements are NOT met"
  set status_file [open "$main_folder/timing_error.txt" "w"]
  set timing_ok 0
}

Msg Status "*** Timing summary ***"
Msg Status "WNS: $wns"
Msg Status "TNS: $tns"
Msg Status "WHS: $whs"
Msg Status "THS: $ths"

struct::matrix m
m add columns 5
m add row

puts $status_file "## $project Timing summary"
m add row  "| **Parameter** | \"**value (ns)**\" |"
m add row  "| --- | --- |"
m add row  "|  WNS:  |  $wns  |"
m add row  "|  TNS:  |  $tns  |"
m add row  "|  WHS:  |  $whs  |"
m add row  "|  THS:  |  $ths  |"

puts $status_file [m format 2string]
puts $status_file "\n"
if {$timing_ok == 1} {
  puts $status_file " Time requirements are met."
} else {
  puts $status_file "Time requirements are **NOT** met."
}
puts $status_file "\n\n"
close $status_file

if {$prog ne "100%"} {
  Msg Error "Implementation error"
}

if {$do_bitstream == 1} {
  Msg Info "Starting write bitstream flow..."
  launch_runs impl_1 -to_step write_bitstream -jobs 4 -dir $main_folder
  wait_on_run impl_1

  set prog [get_property PROGRESS [get_runs impl_1]]
  set status [get_property STATUS [get_runs impl_1]]
  Msg Info "Run: impl_1 progress: $prog, status : $status"

  if {$prog ne "100%"} {
    Msg Error "Write bitstream error, status is: $status"
  }

  Msg Status "*** Timing summary (again) ***"
  Msg Status "WNS: $wns"
  Msg Status "TNS: $tns"
  Msg Status "WHS: $whs"
  Msg Status "THS: $ths"
}

cd $path/../../

lassign [GetRepoVersion [file normalize ./Top/$project/$project.tcl]] sha
set describe [GetGitDescribe $sha]
Msg Info "Git describe set to $describe"

set dst_dir [file normalize "$bin_dir/$project\-$describe"]

file mkdir $dst_dir

#Version table
if [file exists $main_folder/versions.txt] {
  file copy -force $main_folder/versions.txt $dst_dir
} else {
  Msg Warning "No versions file found"
}
#Timing file
set timing_files [ glob -nocomplain "$main_folder/timing_*.txt" ]
set timing_file [file normalize [lindex $timing_files 0]]

if [file exists $timing_file ] {
  file copy -force $timing_file $dst_dir/
} else {
  Msg Warning "No timing file found, not a problem if running locally"
}

Msg Info "All done."
cd $old_path
