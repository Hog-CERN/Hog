#!/usr/bin/env tclsh
#   Copyright 2018-2023 The University of Birmingham
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
# The post synthesis script copies the synthesis reports and other files to the bin.
# This script is automatically integrated into the Vivado/Quartus workflow by the Create Project script.

##nagelfar variable quartus
##nagelfar variable project

if {[catch {package require struct::matrix} ERROR]} {
  puts "$ERROR\n If you are running this script on tclsh, you can fix this by installing 'tcllib'"
  return
}

set tcl_path [file normalize "[file dirname [info script]]/.."]
source $tcl_path/hog.tcl

if {[IsISE]} {
  # Vivado + PlanAhead
  set old_path [file normalize "../../Projects/$project/$project.runs/synth_1"]
  file mkdir $old_path
} else {
  set old_path [pwd]
}

if {[IsXilinx]} {
  # Vivado + PlanAhead
  if {[IsISE]} {
    set proj_file [get_property DIRECTORY [current_project]]
  } else {
    set proj_file [get_property parent.project_path [current_project]]
  }
  set proj_dir [file normalize [file dirname $proj_file]]
  set proj_name [file rootname [file tail $proj_file]]
  set top_name [get_property top [current_fileset]]
} elseif {[IsQuartus]} {
  # Quartus
  set proj_name [lindex $quartus(args) 1]
  #set proj_dir [file normalize "$repo_path/Projects/$proj_name"]
  set proj_dir [pwd]
  set proj_file [file normalize "$proj_dir/$proj_name.qpf"]
  # Test generated files
  set hogQsysFileName [file normalize "$proj_dir/.hog/.hogQsys.md5"]
  if { [file exists $hogQsysFileName] != 0} {
    set hogQsysFile [open $hogQsysFileName r]
    set hogQsysFileLines [split [read $hogQsysFile] "\n"]
    foreach line $hogQsysFileLines {
      set fileEntry [split $line "\t"]
      set fileEntryName [lindex $fileEntry 0]
      if {$fileEntryName != ""} {
        if {[file exists $fileEntryName]} {
          set newMd5Sum [Md5Sum $fileEntryName]
          set oldMd5Sum [lindex $fileEntry 1]
          if { $newMd5Sum != $oldMd5Sum } {
            Msg Warning "The checksum for file $fileEntryName not equal to the one saved in $hogQsysFileName: new checksum $newMd5Sum, old checksum $oldMd5Sum. Please check the any changes in the file are correctly propagated to git!"
          }
        } else {
          Msg Warning "File $fileEntryName not found... Will not check Md5Sum!"
        }
      }
    }

  }
} else {
  #Tclssh
  set proj_file $old_path/[file tail $old_path].xpr
  set proj_dir [file normalize [file dirname $proj_file]]
  set proj_name [file rootname [file tail $proj_file]]
  Msg CriticalWarning "You seem to be running locally on tclsh, so this is a debug, the project file will be set to $proj_file and was derived from the path you launched this script from: $old_path. If you want this script to work properly in debug mode, please launch it from the top folder of one project, for example Repo/Projects/fpga1/ or Repo/Top/fpga1/"
}

# Go to repository path
set repo_path [file normalize "$tcl_path/../.."]
set bin_dir [file normalize "$repo_path/bin"]

cd $repo_path

set group_name [GetGroupName $proj_dir "$tcl_path/../.."]

Msg Info "Evaluating Git sha for $proj_name..."
lassign [GetRepoVersions [file normalize ./Top/$group_name/$proj_name] $repo_path] sha

set describe [GetHogDescribe $sha $repo_path]
Msg Info "Git describe set to: $describe"
set dst_dir [file normalize "$bin_dir/$group_name/$proj_name\-$describe"]

Msg Info "Creating $dst_dir..."
file mkdir $dst_dir
# Reports
file mkdir $dst_dir/reports

# Vivado
if {[IsXilinx]} {

  # Vivado + PlanAhead
  if {[IsISE]} {
    # planAhead
    set work_path [get_property DIRECTORY [get_runs synth_1]]
  } else {
    # Vivado
    set work_path $old_path
  }
  set run_dir [file normalize "$work_path/.."]

  if {[IsISE]} {
    set reps [glob -nocomplain "$run_dir/*/*{.syr,.srp,.mrp,.map,.twr,.drc,.bgn,_routed.par,_routed_pad.txt,_routed.unroutes}"]
  } else {
    set reps [glob -nocomplain "$run_dir/*/*.rpt"]
  }
  if {[file exists [lindex $reps 0]]} {
    file copy -force {*}$reps $dst_dir/reports
    if {[file exists [glob -nocomplain "$dst_dir/reports/${top_name}_utilization_synth.rpt"] ]} {
      set utilization_file [file normalize $dst_dir/utilization.txt]
      set report_file [glob -nocomplain "$dst_dir/reports/${top_name}_utilization_synth.rpt"]
      if {$group_name != ""} {
        WriteUtilizationSummary $report_file $utilization_file $group_name/$proj_name "Synthesis"
      } else {
        WriteUtilizationSummary $report_file $utilization_file $proj_name "Synthesis"
      }
    }
  } else {
    Msg Warning "No reports found in $run_dir subfolders"
  }


  # Handle IPs 
  if {[IsVivado]} {
    if {[info exists env(HOG_IP_PATH)]} {
      set ip_repo $env(HOG_IP_PATH)
      
      if {[IsISE]} {
	# Do nothing...
      } else {
	
	set ips [get_ips *]
	set run_paths [glob -nocomplain "$run_dir/*"]
	set runs {}
	foreach r $run_paths {
	  if {[regexp -all {^(.+)_synth_1}  $r whole_match run]} {
	    lappend runs [file tail $run]
	  }
	}
	
	foreach ip $ips {
	  if {$ip in $runs} {
	    set force 1
	  } else {
	    set force 0
	  }
	  Msg Info "Copying synthesised IP $ip to $ip_repo..."
	  HandleIP push [get_property IP_FILE $ip] $ip_repo $repo_path [get_property IP_OUTPUT_DIR $ip] $force
	}
      }
    }
  }


 # Log files
  set logs [glob -nocomplain "$run_dir/*/runme.log"]
  foreach log $logs {
    set run_name [file tail [file dirname $log]]
    file copy -force $log $dst_dir/reports/$run_name.log
  }
} elseif {[IsQuartus]} {
  #Reports
  set reps [glob -nocomplain "$proj_dir/output_files/*.rpt"]

  if {[file exists [lindex $reps 0]]} {
    file copy -force {*}$reps $dst_dir/reports
  } else {
    Msg Warning "No reports found in $proj_dir/output_files subfolders"
  }
}

# Run user post-synthesis file
set user_post_synthesis_file "./Top/$group_name/$proj_name/post-synthesis.tcl"
if {[file exists $user_post_synthesis_file]} {
  Msg Info "Sourcing user post-synthesis file $user_post_synthesis_file"
  source $user_post_synthesis_file
}

cd $old_path
Msg Info "All done."
