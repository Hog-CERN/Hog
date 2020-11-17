#!/usr/bin/env tclsh
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

# @file
# The post bistream script copies binary files, reports and other files to the bin directory in your repository.
# This script is automatically integrated into the Vivado/Quartus workflow by the Create Project script.

set old_path [pwd]
set tcl_path [file normalize "[file dirname [info script]]/.."]
source $tcl_path/hog.tcl

if {[info commands get_property] != ""} {
    # Vivado + PlanAhead
    if { [string first PlanAhead [version]] == 0 } {
        # planAhead
        set work_path [get_property DIRECTORY [get_runs impl_1]]
    } else {
        # Vivado
        set work_path $old_path
    }
} elseif {[info commands quartus_command] != ""} {
    # Quartus
    set work_path $old_path
} else {
    #tcl shell
    set work_path $old_path
}

set fw_file   [file normalize [lindex [glob -nocomplain "$work_path/*.bit"] 0]]
set proj_name [file tail [file normalize $work_path/../../]]
set top_name  [file rootname [file tail $fw_file]]

set bit_file [file normalize "$work_path/$top_name.bit"]
set bin_file [file normalize "$work_path/$top_name.bin"]
set ltx_file [file normalize "$work_path/$top_name.ltx"]

if [file exists $bit_file] {

  set xml_dir [file normalize "$work_path/../xml"]
  set run_dir [file normalize "$work_path/.."]
  set bin_dir [file normalize "$work_path/../../../../bin"]

    # Go to repository path
  cd $tcl_path/../../

  Msg Info "Evaluating Git sha for $proj_name..."
  lassign [GetRepoVersion ./Top/$proj_name/$proj_name.tcl] sha

  set describe [GetGitDescribe $sha]
  Msg Info "Git describe set to: $describe"

  set ts [clock format [clock seconds] -format {%Y-%m-%d-%H-%M}]

  set dst_dir [file normalize "$bin_dir/$proj_name\-$describe"]
  set dst_bit [file normalize "$dst_dir/$proj_name\-$describe.bit"]
  set dst_bin [file normalize "$dst_dir/$proj_name\-$describe.bin"]
  set dst_ltx [file normalize "$dst_dir/$proj_name\-$describe.ltx"]
  set dst_xml [file normalize "$dst_dir/xml"]

  Msg Info "Creating $dst_dir..."
  file mkdir $dst_dir
  Msg Info "Evaluating differences with last commit..."
  set diff [Git diff]
  if {$diff != ""} {
    Msg Warning "Found non committed changes:"
    Msg Status "$diff"
    set fp [open "$dst_dir/diff_postbitstream.txt" w+]
    puts $fp "$diff"
    close $fp
  } else {
    Msg Info "No uncommitted changes found."
  }

  Msg Info "Copying bit file $bit_file into $dst_bit..."
  file copy -force $bit_file $dst_bit
  # Reports
  file mkdir $dst_dir/reports
  if { [string first PlanAhead [version]] == 0 } {
      set reps [glob -nocomplain "$run_dir/*/*{.syr,.srp,.mrp,.map,.twr,.drc,.bgn,_routed.par,_routed_pad.txt,_routed.unroutes}"]
  } else {
      set reps [glob -nocomplain "$run_dir/*/*.rpt"]
  }
  if [file exists [lindex $reps 0]] {
    file copy -force {*}$reps $dst_dir/reports
  } else {
    Msg Warning "No reports found in $run_dir subfolders"
  }

  # Log files
  set logs [glob -nocomplain "$run_dir/*/runme.log"]
  foreach log $logs {
    set run_name [file tail [file dir $log]]
    file copy -force $log $dst_dir/reports/$run_name.log
  }

    # IPbus XML
  if [file exists $xml_dir] {
    Msg Info "XML directory found, copying xml files from $xml_dir to $dst_xml..."
    if [file exists $dst_xml] {
      Msg Info "Directory $dst_xml exists, deleting it..."
      file delete -force $dst_xml
    }
    file copy -force $xml_dir $dst_xml
  }
    # bin File
  if [file exists $bin_file] {
    Msg Info "Copying bin file $bin_file into $dst_bin..."
    file copy -force $bin_file $dst_bin
  } else {
    Msg Info "No bin file found: $bin_file, that is not a problem"
  }

  write_debug_probes -quiet $ltx_file

    # ltx File
  if [file exists $ltx_file] {
    Msg Info "Copying ltx file $ltx_file into $dst_ltx..."
    file copy -force $ltx_file $dst_ltx
  } else {
    Msg Info "No ltx file found: $ltx_file, that is not a problem"
  }

} else {
  Msg CriticalWarning "Firmware binary file not found."
}

set user_post_bitstream_file "./Top/$proj_name/post-bitstream.tcl"
if {[file exists $user_post_bitstream_file]} {
    Msg Info "Sourcing user post-bitstream file $user_post_bitstream_file"
    source $user_post_bitstream_file
}

cd $old_path
Msg Info "All done."
