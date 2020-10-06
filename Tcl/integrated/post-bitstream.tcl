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

if {[info commands project_new] != ""} {
  if { [catch {package require ::quartus::project} ERROR] } {
    Msg Error "$ERROR\n Can not find package ::quartus::project"
    cd $old_path
    return 1
  }
  set proj_name [$quartus(args)](2)
  if {![is_project_open]}{
    set need_project_close 1
    project_open( $proj_name )
  }
}

if {[info commands get_property] != ""} {

  #Vivado + planAhead
  if { [string first PlanAhead [version]] == 0 } {
    set old_path [get_property DIRECTORY [get_runs impl_1]]
  }

  set fw_file [file normalize [lindex [glob -nocomplain "$old_path/*.bit"] 0]]
  set proj_name [string map {"top_" ""} [file rootname [file tail $fw_file]]]
  if { [string first PlanAhead [version]] == 0 } {
    set name [file rootname [file tail [file normalize $old_path/../..]]]
  } else {
    set name [file rootname [file tail [file normalize [pwd]/..]]]
  }
  set bit_file [file normalize "$old_path/top_$proj_name.bit"]
  set bin_file [file normalize "$old_path/top_$proj_name.bin"]
  set ltx_file [file normalize "$old_path/top_$proj_name.ltx"]

} elseif {[info commands quartus_command] != ""} {
    # Quartus
  set proj_name [lindex $quartus(args) 1]
  set proj_dir [file normalize [ "$tcl_path/../../QuartusProject/$proj_name"]
  set fw_file [file normalize ["$proj_dir/output_files/$proj_name.pof"]]
  
  set name [file rootname [file tail [file normalize [pwd]/..]]]
  # programming object file
  set bit_file [file normalize "$old_path/output_files/$proj_name.pof"]
  # SRAM Object File
  set sof_file [file normalize "$old_path/output_files/$proj_name.sof"]
  # raw binary file
  set rbf_file [file normalize "$old_path/output_files/$proj_name.rbf"]
  #raw programming file
  set rpd_file [file normalize "$old_path/output_files/$proj_name.rpd"]
  # signal tap file
  set stp_file [file normalize "$old_path/output_files/$proj_name.stp"]
  #source and probes file
  set spf_file [file normalize "$old_path/output_files/$proj_name.spf"]
}


} else {
    #tcl shell
  set fw_file [file normalize [lindex [glob -nocomplain "$old_path/*.bit"] 0]]

  set proj_name [string map {"top_" ""} [file rootname [file tail $fw_file]]]
  set name [file rootname [file tail [file normalize [pwd]/..]]]
  set bit_file [file normalize "$old_path/top_$proj_name.bit"]
  set bin_file [file normalize "$old_path/top_$proj_name.bin"]
  set ltx_file [file normalize "$old_path/top_$proj_name.ltx"]
}
if [file exists $fw_file] {


  set xml_dir [file normalize "$old_path/../xml"]
  set run_dir [file normalize "$old_path/.."]
  set bin_dir [file normalize "$old_path/../../../../bin"]

    # Go to repository path
  cd $tcl_path/../../



  Msg Info "Evaluating Git sha for $name..."
  lassign [GetRepoVersion ./Top/$name/$name.tcl] sha

  set describe [GetGitDescribe $sha]
  Msg Info "Git describe set to: $describe"

  set ts [clock format [clock seconds] -format {%Y-%m-%d-%H-%M}]

  set dst_dir [file normalize "$bin_dir/$name\-$describe"]
  set dst_bit [file normalize "$dst_dir/$name\-$describe.bit"]
  set dst_bin [file normalize "$dst_dir/$name\-$describe.bin"]
  set dst_ltx [file normalize "$dst_dir/$name\-$describe.ltx"]
  set dst_xml [file normalize "$dst_dir/xml"]

  Msg Info "Creating $dst_dir..."
  file mkdir $dst_dir
  Msg Info "Evaluating differences with last commit..."
  set diff [exec git diff]
  if {$diff != ""} {
    Msg Warning "Found non committed changes:"
    Msg Status "$diff"
    set fp [open "$dst_dir/diff_postbistream.txt" w+]
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
  } elseif [file exists $rbf_file] ||  [file exists $rpd_file] {
    if [file exists $rbf_file] {
      file copy -force $rbf_file $dst_bin
    }
    if [file exists $rpd_file] {
      file copy -force $rpd_file $dst_bin
    }
  } else {
    Msg Info "No bin file found: $bin_file, that is not a problem"
  }

  write_debug_probes -quiet $ltx_file

    # ltx File
  if [file exists $ltx_file] {
    Msg Info "Copying ltx file $ltx_file into $dst_ltx..."
    file copy -force $ltx_file $dst_ltx
  } elseif [file exists $stp_file] || [file exists $spf_file] {
    if [file exists $stp_file] {
      file copy -force $stp_file $dst_ltx
    }
    if [file exists $spf_file] {
      file copy -force $psf_file $dst_ltx
    }
  }else {
    Msg Info "No ltx file found: $ltx_file, that is not a problem"
  }

} else {
  Msg CriticalWarning "Firmware binary file not found."
}

if {[info commands project_new] != "" && $need_project_close == 1} {
  project_close
}

cd $old_path
Msg Info "All done."
