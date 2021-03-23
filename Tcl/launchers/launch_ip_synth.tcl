#   Copyright 2018-2021 The University of Birmingham
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


# @file
# Launch the IP synthesis in a vivado project in text mode

#parsing command options
if {[catch {package require cmdline} ERROR]} {
  puts "$ERROR\n If you are running this script on tclsh, you can fix this by installing 'tcllib'"
  return
}
set parameters {
  {eos_ip_path.arg "" "Path of the EOS IP repository"}
  {NJOBS.arg 4 "Number of jobs. Default: 4"}
}

set usage "- USAGE: $::argv0 \[OPTIONS\] <project> \n. Options:"

set path [file normalize "[file dirname [info script]]/.."]
set repo_path [file normalize "$path/../.."]

set old_path [pwd]
cd $path
source ./hog.tcl

if {[catch {array set options [cmdline::getoptions ::argv $parameters $usage]}] || [llength $argv] < 1 } {
  Msg Info [cmdline::usage $parameters $usage]
  exit 1
} elseif { $::argc eq 1 } {
  set project [lindex $argv 0]
  set project [lindex $argv 0]
  set group_name [file dirname $project]
  set project [file tail $project]
  if { $group_name != "." } {
    set project_name "$group_name/$project"
  } else {
    set project_name "$project"
  }
  set main_folder [file normalize "$repo_path/Projects/$project_name/$project.runs/"]
  set ip_path ""
} else {
  set project [lindex $argv 0]
  set main_folder [file normalize "$repo_path/Projects/$project_name/$project.runs/"]
  set ip_path $options(eos_ip_path)
  Msg Info "Will use the EOS ip repository on $ip_path to speed up ip synthesis..."
}

Msg Info "Opening project $project_name..."
open_project $repo_path/Projects/$project_name/$project.xpr


Msg Info "Preparing IP runs..."
reset_run synth_1
launch_runs -scripts_only synth_1
reset_run synth_1

set ips [get_ips *]
set list_ip_ver {}
set list_ip_lock {}
set vivado_version [version -short]

if {$ips != ""} {
  foreach ip $ips {
    set lock [get_property IS_LOCKED $ip]
    set ip_version [get_property SW_VERSION $ip]
    set ip_name [get_property NAME $ip]
    lappend list_ip_lock $lock
    lappend list_ip_ver $ip_version

    if { [get_runs $ip\_synth_1] != "" } {
      Msg Info "Adding run for $ip..."
      set run_name [get_runs $ip\_synth_1]
      reset_run $run_name
      lappend runs $run_name
    } elseif { [get_runs $ip\_impl_1] != ""} {
      Msg Info "Adding run for $ip..."
      set run_name [get_runs $ip\_impl_1]
      reset_run $run_name
      lappend runs $run_name
    } else {
      Msg Info "No run found for $ip."
    }
  }
}



Msg Info "Number of jobs set to $options(NJOBS)."
set jobs $options(NJOBS)
set failure 0

if [info exists runs] {
  foreach run_name $runs {
    Msg Info "Launching $run_name..."
    launch_runs $run_name -dir $main_folder
    lappend running $run_name
    if {[llength $running] >= $jobs} {
      wait_on_run [get_runs [lindex $running 0]]
      set running [lreplace $running 0 0]
    }
  }

  while {[llength $running] > 0} {
    Msg Info "Checking [lindex $running 0]..."
    wait_on_run [get_runs [lindex $running 0]]
    set running [lreplace $running 0 0]
  }
  if { $runs != "" } {
    foreach run_name $runs {
      set prog [get_property PROGRESS $run_name]
      set status [get_property STATUS $run_name]
      Msg Info "Run: $run_name progress: $prog, status : $status"
      if {$prog ne "100%"} {
        set failure 1
      }
    }
  }
}

if {$ips != ""} {
  foreach ip $ips {
    set index 0
    set ip_name [get_property NAME $ip]
    set lock [lindex $list_ip_lock $index]
    set ip_version [lindex $list_ip_ver $index]
    if { $lock || $vivado_version != $ip_version } {
      Msg CriticalWarning "A different version of Vivado ($vivado_version) is used with respect to the one that has been used to create the IP $ip_name ($ip_version)\nPlease upgrade your IP or use the $ip_version version of Vivado"
    }
    incr index
  }
}

if {$failure eq 1} {
  Msg Error "At least on IP synthesis failed"
}

if {($ip_path != "")} {
  Msg Info "Copying synthesised IPs to $ip_path..."
  foreach ip $ips {
    set force 0
    if [info exist runs] {
      if {[lsearch $runs $ip\_synth_1] != -1} {
        Msg Info "$ip was synthesized, will force the copy to EOS..."
        set force 1
      }
    }
    HandleIP push [get_property IP_FILE $ip] $ip_path $main_folder $force
  }
}

Msg Info "All done."
cd $old_path
