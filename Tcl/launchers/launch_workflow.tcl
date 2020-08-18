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
if {[catch {package require cmdline} ERROR] || [catch {package require struct::matrix} ERROR]} {
  puts "$ERROR\n Tcllib not found. If you are running this script on tclsh, you can fix this by installing 'tcllib'"
  return
}

set parameters {
  {ip_eos_path.arg "" "If set, the synthesised IPs will be copied to the specified EOS path."}
  {no_bitstream    "If set, the bitstream file will not be produced."}
  {synth_only      "If set, only the synthesis will be performed."}
  {reset           "If set, resets the runs (synthesis and implementation) before launching them."}
  {check_syntax    "If set, the HDL syntax will be checked at the beginning of the worflow."}
  {njobs.arg 4 "Number of jobs. Default: 4"}
}

set usage "- USAGE: $::argv0 \[OPTIONS\] <project> \n. Options:"
set path [file normalize "[file dirname [info script]]/.."]

if {[catch {array set options [cmdline::getoptions ::argv $parameters $usage]}] ||  [llength $argv] < 1 } {
  Msg Info [cmdline::usage $parameters $usage]
  exit 1
} else {
  set project [lindex $argv 0]
  set main_folder [file normalize "$path/../../VivadoProject/$project/$project.runs/"]
  set do_implementation 1
  set do_bitstream 1
  set reset 0
  set check_syntax 0
  set ip_path ""
}

set old_path [pwd]
set bin_dir [file normalize "$path/../../bin"]

#Go to Hog/Tcl
cd $path

source ./hog.tcl

if { $options(no_bitstream) == 1 } {
  set do_bitstream 0
}

if { $options(synth_only) == 1 } {
  set do_implementation 0
}

if { $options(reset) == 1 } {
  set reset 1
}

if { $options(check_syntax) == 1 } {
  set check_syntax 1
}

#Copy IP from EOS
if { $options(ip_eos_path) != "" } {
  set ip_path $options(ip_eos_path)

  Msg Info "Getting IPs for $project..."
  set ips {}
  lassign [GetHogFiles "../../Top/$project/list/" "*.src"] src_files dummy
  dict for {f files} $src_files {
    #library names have a .src extension in values returned by GetHogFiles
    if { [file ext $f] == ".ip" } {
      lappend ips $files
    }
  }

  Msg Info "Copying IPs from $ip_path..."
  set copied_ips 0
  foreach ip $ips {
    set ret [HandleIP pull $ip $ip_path $main_folder]
    if {$ret == 0} {
      incr copied_ips 
    }
  }
  Msg Info "$copied_ips IPs were copied from the EOS repository."
}


if {$do_implementation == 1} {
  if {$do_bitstream == 1} {
    Msg Info "Will launch implementation and write bitstream..."
  } else {
    Msg Info "Will launch implementation only..."
  }
} else {
  Msg Info "Will launch synthesis only..."
}

if { $ip_path != "" } {
  Msg Info "Will copy synthesised IPs from/to $ip_path"
}

Msg Info "Number of jobs set to $options(njobs)."

############# CREATE or OPEN project ############
if { [string first PlanAhead [version]] == 0 } {
  set project_file [file normalize ../../VivadoProject/$project/$project.ppr]
} else {
  set project_file [file normalize ../../VivadoProject/$project/$project.xpr]
}

if {[file exists $project_file]} {
  Msg Info "Found project file $project_file for $project ..."
  open_project $project_file
} else {
  Msg Info "Project file not found for $project, sourcing the project Tcl script ..."
  source ../../Top/$project/$project.tcl
}

########## CHECK SYNTAX ###########
Msg Info "Checkin syntax for project $project..."
set syntax [check_syntax -return_string]

if {[string first "CRITICAL" $syntax ] != -1} {
  check_syntax
  exit 1
}


############# SYNTH ###############
if {$reset == 1 } {
  Msg Info "Resetting run before launching synthesis..."
  reset_run synth_1
  
}
if { [string first PlanAhead [version]] ==0 } {
  source  integrated/pre-synthesis.tcl
}

launch_runs synth_1  -jobs $options(njobs) -dir $main_folder
wait_on_run synth_1

set prog [get_property PROGRESS [get_runs synth_1]]
set status [get_property STATUS [get_runs synth_1]]
Msg Info "Run: synth_1 progress: $prog, status : $status"

if {$prog ne "100%"} {
  Msg Error "Synthesis error, status is: $status"
}

# Copy IP reports in bin/
set ips [get_ips *]

#go to repository path
cd $path/../..

lassign [GetRepoVersion [file normalize ./Top/$project/$project.tcl]] sha
set describe [GetGitDescribe $sha]
Msg Info "Git describe set to $describe"

foreach ip $ips {
  set xci_file [get_property IP_FILE $ip]
  set xci_path [file dir $xci_file]
  set xci_ip_name [file root [file tail $xci_file]]
  foreach rptfile [glob -nocomplain -directory $xci_path *.rpt] {
    file copy $rptfile $bin_dir/$project-$describe/reports
  }
  
  ######### Copy IP to EOS repository
  if {($ip_path != "")} {
    set force 0
    if [info exist runs] {
      if {[lsearch $runs $ip\_synth_1] != -1} {
        Msg Info "$ip was synthesized, will force the copy to EOS..."
        set force 1
      }
    }
    Msg Info "Copying synthesised IP $xci_ip_name ($xci_file) to $ip_path..."
    HandleIP push $xci_file $ip_path $main_folder $force
  }
}

############### IMPL ###################

if {$do_implementation == 1 } {

  Msg Info "Starting implementation flow..."
  if { $reset == 1 } {
    Msg Info "Resetting run before launching implementation..."
    reset_run impl_1
  }

  if { [string first PlanAhead [version]] ==0} {source  integrated/pre-implementation.tcl}
  launch_runs impl_1 -jobs $options(njobs) -dir $main_folder
  wait_on_run impl_1
  if { [string first PlanAhead [version]] ==0} {source  integrated/post-implementation.tcl}
  
  set prog [get_property PROGRESS [get_runs impl_1]]
  set status [get_property STATUS [get_runs impl_1]]
  Msg Info "Run: impl_1 progress: $prog, status : $status"
  
  # Check timing
  if { [string first PlanAhead [version]] !=0 } {
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
  }
  
  if {$prog ne "100%"} {
    Msg Error "Implementation error"
  }
  
  if {$do_bitstream == 1} {
    Msg Info "Starting write bitstream flow..."
    if { [string first PlanAhead [version]] == 0 } {
      # PlanAhead command
      Msg Info "running pre-bitstream"
      source  integrated/pre-bitstream.tcl
      launch_runs impl_1 -to_step Bitgen -jobs 4 -dir $main_folder
      wait_on_run impl_1
      Msg Info "running post-bitstream"
      source  integrated/post-bitstream.tcl
    } elseif { [string first Vivado [version]] ==0} {
      # Vivado command
      launch_runs impl_1 -to_step write_bitstream -jobs 4 -dir $main_folder
      wait_on_run impl_1
    }
    
    set prog [get_property PROGRESS [get_runs impl_1]]
    set status [get_property STATUS [get_runs impl_1]]
    Msg Info "Run: impl_1 progress: $prog, status : $status"
    
    if {$prog ne "100%"} {
      Msg Error "Write bitstream error, status is: $status"
    }
    
    if { [string first PlanAhead [version]] !=0 } {
      Msg Status "*** Timing summary (again) ***"
      Msg Status "WNS: $wns"
      Msg Status "TNS: $tns"
      Msg Status "WHS: $whs"
      Msg Status "THS: $ths"
    }
  }

  #Go to repository path
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

}

Msg Info "All done."
cd $old_path
