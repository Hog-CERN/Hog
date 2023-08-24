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
# The post implementation script embeds the git SHA of the current commit into the binary file of the project.
# In Vivado this is done using the USERID and USR_ACCESS variables. In Quartus this is done with the STRATIX_JTAG_USER_CODE variable.
# 
# The USERID is always set to the commit, while the USR_ACCESS and STRATIX_JTAG_USER_CODE are set only if Hog can guarantee the reproducibility of the firmware workflow:
#
# - The firmware repostory must be clean (no uncommitted modification)
# - The Multithread option must be disabled
# This script is automatically integrated into the Vivado/Quartus workflow by the Create Project script.

##nagelfar variable quartus

set old_path [pwd]
set tcl_path [file normalize "[file dirname [info script]]/.."]
source $tcl_path/hog.tcl

# Go to repository pathcd $old_pathcd $old_path
cd $tcl_path/../../
set repo_path "$tcl_path/../.."

if {[IsXilinx]} {
  # Vivado + planAhead
  if {[IsISE]} {
    set proj_file [get_property DIRECTORY [current_project]]
    set work_path [get_property DIRECTORY [get_runs impl_1]]
  } else {
    set proj_file [get_property parent.project_path [current_project]]
    set work_path $old_path
  }
  set proj_dir [file normalize [file dirname $proj_file]]
  set proj_name [file rootname [file tail $proj_file]]
  set run_dir [file normalize "$work_path/.."]
  set top_name [get_property top [current_fileset]]

} elseif {[IsQuartus]} {
  # Quartus
  set proj_name [lindex $quartus(args) 1]
  set proj_dir $old_path
} else {
  #Tclssh
  set proj_file $old_path/[file tail $old_path].xpr
  Msg CriticalWarning "You seem to be running locally on tclsh, so this is a debug, the project file will be set to $proj_file and was derived from the path you launched this script from: $old_path. If you want this script to work properly in debug mode, please launch it from the top folder of one project, for example Repo/Projects/fpga1/ or Repo/Top/fpga1/"
}

set group_name [GetGroupName $proj_dir "$tcl_path/../.."]
Msg Info "Evaluating Git sha for $proj_name..."
lassign [GetRepoVersions [file normalize ./Top/$group_name/$proj_name] $repo_path] sha

set describe [GetHogDescribe $sha $repo_path]
Msg Info "Git describe set to: $describe"

set ts [clock format [clock seconds] -format {%Y-%m-%d-%H-%M}]

set bin_dir [file normalize "$repo_path/bin"]
set dst_dir [file normalize "$bin_dir/$group_name/$proj_name\-$describe"]



Msg Info "Evaluating last git SHA in which $proj_name was modified..."
set commit "0000000"


#check if diff_presynthesis.txt is not empty (problem with list files or conf files)
if {[file exists $dst_dir/diff_presynthesis.txt]} {
  set fp [open "$dst_dir/diff_presynthesis.txt" r]
  set file_data [read $fp]
  close $fp
  if {$file_data != ""} {
    Msg CriticalWarning "Git working directory [pwd] not clean, git commit hash be set to 0."
    set commit_usr  "0000000"
    set commit   "0000000"
  } else {
    lassign [GetRepoVersions [file normalize ./Top/$group_name/$proj_name] $repo_path ] commit version
  }
} else {
  lassign [GetRepoVersions [file normalize ./Top/$group_name/$proj_name] $repo_path ] commit version
}

#number of threads
set maxThreads [GetMaxThreads [file normalize ./Top/$group_name/$proj_name]]
if {$maxThreads != 1} {
  Msg CriticalWarning "Multithreading enabled. Number of threads: $maxThreads"
  set commit_usr   "0000000"
} else {
  set commit_usr $commit
}

#check if diff_list_and_conf.txt is not empty (problem with list files or conf files)
if {[file exists $dst_dir/diff_list_and_conf.txt]} {
  set fp [open "$dst_dir/diff_list_and_conf.txt" r]
  set file_data [read $fp]
  close $fp
  if {$file_data != ""} {
    Msg CriticalWarning "List files and project properties not clean, git commit hash be set to 0."
    set commit_usr  "0000000"
    set commit   "0000000"
  }
}

Msg Info "The git SHA value $commit will be embedded in the binary file."

# Set bitstream embedded variables
if {[IsXilinx]} {
  if {[IsISE]} {
    # get the existing "more options" so that we can append to them when adding the userid
    set props [get_property "STEPS.BITGEN.ARGS.MORE OPTIONS" [get_runs impl_1]]
    # need to trim off the curly braces that were used in creating a dictionary
    regsub -all {\{|\}} $props "" props
    set PART [get_property part [current_project]]
    # only some part families have both usr_access and userid
    if {[string first "xc5v" $PART] != -1 || [string first "xc6v" $PART] != -1 || [string first "xc7" $PART] != -1} {
      set props  "$props -g usr_access:0x[format %08X 0x$commit] -g userid:0x[format %08X 0x$commit_usr]"
    } else {
      set props  "$props -g userid:0x[format %08X 0x$commit_usr]"
    }
    set_property -name {steps.bitgen.args.More Options} -value $props -objects [get_runs impl_1]
  } else {
    if {[IsVersal [get_property PART [current_design]]]} {
      Msg Info "This design uses a Versal chip, USERID does not exist."
    } else {
      set_property BITSTREAM.CONFIG.USERID $commit [current_design]
    }
    set_property BITSTREAM.CONFIG.USR_ACCESS $commit_usr [current_design]
  }
} elseif {[IsQuartus]} {
  cd $proj_dir
  project_open $proj_name -current_revision
  cd $old_path
  set_global_assignment -name USE_CHECKSUM_AS_USERCODE OFF  
  set_global_assignment -name STRATIX_JTAG_USER_CODE $commit
  project_close
} else {
  # Tclsh
}

set user_post_implementation_file "./Top/$group_name/$proj_name/post-implementation.tcl"
if {[file exists $user_post_implementation_file]} {
  Msg Info "Sourcing user post_implementation file $user_post_implementation_file"
  source $user_post_implementation_file
}

# Vivado
if {[IsXilinx]} {
  # Go to repository path
  cd $tcl_path/../../

  Msg Info "Evaluating Git sha for $proj_name..."
  lassign [GetRepoVersions [file normalize ./Top/$group_name/$proj_name] $repo_path] sha

  set describe [GetHogDescribe $sha $repo_path]
  Msg Info "Git describe set to: $describe"

  set ts [clock format [clock seconds] -format {%Y-%m-%d-%H-%M}]

  set dst_dir [file normalize "$bin_dir/$group_name/$proj_name\-$describe"]
  Msg Info "Creating $dst_dir..."
  file mkdir $dst_dir

  #check list files and project properties
  set confDict [dict create]
  set full_diff_log 0
  if {[file exists "$tcl_path/../../Top/$group_name/$proj_name/hog.conf"]} {
    set confDict [ReadConf "$tcl_path/../../Top/$group_name/$proj_name/hog.conf"]
    set full_diff_log [DictGet [DictGet $confDict "hog"] "FULL_DIFF_LOG"  0]
  }

  Msg Info "Evaluating differences with last commit..."
  set found_uncommitted 0
  set diff [Git diff]
  set diff_stat [Git "diff --stat"]
  if {$diff != ""} {
    set found_uncommitted 1
    Msg Warning "Found non committed changes:"
    if {$full_diff_log} {
      Msg Status "$diff"
    } else {
      Msg Status "$diff_stat"
    }
    set fp [open "$dst_dir/diff_postimplementation.txt" w+]
    puts $fp "$diff"
    close $fp
  }

  if {$found_uncommitted == 0} {
    Msg Info "No uncommitted changes found."
  }

  # Reports
  file mkdir $dst_dir/reports
  if {[IsVivado]} {
    report_utilization -hierarchical -hierarchical_percentages -file $dst_dir/reports/hierarchical_utilization.txt
  }


  if {[IsISE]} {
    set reps [glob -nocomplain "$run_dir/*/*{.syr,.srp,.mrp,.map,.twr,.drc,.bgn,_routed.par,_routed_pad.txt,_routed.unroutes}"]
  } else {
    set reps [glob -nocomplain "$run_dir/*/*.rpt"]
  }
  if {[file exists [lindex $reps 0]]} {
    file copy -force {*}$reps $dst_dir/reports
    if {[file exists [glob -nocomplain "$dst_dir/reports/${top_name}_utilization_placed.rpt"] ]} {
      set utilization_file [file normalize $dst_dir/utilization.txt]
      set report_file [glob -nocomplain "$dst_dir/reports/${top_name}_utilization_placed.rpt"]
      if {$group_name != ""} {
        WriteUtilizationSummary $report_file $utilization_file $group_name/$proj_name "Implementation"
      } else {
        WriteUtilizationSummary $report_file $utilization_file $proj_name "Implementation"
      }
    }
  } else {
    Msg Warning "No reports found in $run_dir subfolders"
  }

  # Log files
  set logs [glob -nocomplain "$run_dir/*/runme.log"]
  foreach log $logs {
    set run_name [file tail [file dirname $log]]
    file copy -force $log $dst_dir/reports/$run_name.log
  }

}

# Run user post-implementation file
set user_post_implementation_file "./Top/$group_name/$proj_name/post-implementation.tcl"
if {[file exists $user_post_implementation_file]} {
  Msg Info "Sourcing user post-implementation file $user_post_implementation_file"
  source $user_post_implementation_file
}

cd $old_path
Msg Info "All done."
