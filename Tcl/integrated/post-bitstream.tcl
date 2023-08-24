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
# The post bitstream script copies binary files, reports and other files to the bin directory in your repository.
# This script is automatically integrated into the Vivado/Quartus workflow by the Create Project script.

set old_path [pwd]
set tcl_path [file normalize "[file dirname [info script]]/.."]
source $tcl_path/hog.tcl
set repo_path [file normalize "$tcl_path/../../"]

# Import tcllib
if {[IsLibero]} {
  if {[info exists env(HOG_TCLLIB_PATH)]} {
    lappend auto_path $env(HOG_TCLLIB_PATH) 
  } else {
    puts "ERROR: To run Hog with Microsemi Libero SoC, you need to define the HOG_TCLLIB_PATH variable."
    return
  }
}

if {[info exists env(HOG_EXTERNAL_PATH)]} {
  set ext_path $env(HOG_EXTERNAL_PATH)
  Msg Info "Found environment variable HOG_EXTERNAL_PATH, setting path for external files to $ext_path..."
} else {
  set ext_path ""
}

set bin_dir [file normalize "$repo_path/bin"]

if {[IsXilinx]} {
  # Binary files are called .bit for ISE and for Vivado unless the chip is a Versal
  set fw_file_ext "bit"
  
  # Vivado + PlanAhead
  if {[IsISE]} {
    # planAhead
    set work_path [get_property DIRECTORY [get_runs impl_1]]
  } else {
    # Vivado
    set work_path $old_path
    if {[IsVersal [get_property PART [current_design]]]} {
      #In Vivado if a Versal chip is used, the main binary file is called .bif
      set fw_file_ext "bif"
    }
  }
  
  set main_file   [file normalize [lindex [glob -nocomplain "$work_path/*.$fw_file_ext"] 0]]
  set proj_name [file tail [file normalize $work_path/../../]]
  set proj_dir [file normalize "$work_path/../.."]

  set top_name  [file rootname [file tail $main_file]]

  set additional_ext "bin ltx pdi"

  set xml_dir [file normalize "$work_path/../xml"]
  set run_dir [file normalize "$work_path/.."]

} elseif {[IsQuartus]} {
  # Quartus
  ##nagelfar ignore Unknown variable
  set proj_name [lindex $quartus(args) 1]
  set proj_dir [pwd]
  set xml_dir [file normalize "$repo_path/xml"]
  set run_dir [file normalize "$proj_dir"]
  set name [file rootname [file tail [file normalize [pwd]]]]
  # programming object file
  set pof_file [file normalize "$proj_dir/output_files/$proj_name.pof"]
  # SRAM Object File
  set sof_file [file normalize "$proj_dir/output_files/$proj_name.sof"]
  # raw binary file
  set rbf_file [file normalize "$proj_dir/output_files/$proj_name.rbf"]
  #raw programming file
  set rpd_file [file normalize "$proj_dir/output_files/$proj_name.rpd"]
  # signal tap file
  set stp_file [file normalize "$proj_dir/output_files/$proj_name.stp"]
  #source and probes file
  set spf_file [file normalize "$proj_dir/output_files/$proj_name.spf"]

} elseif {[IsLibero]} {
  # Libero
  ##nagelfar ignore Unknown variable
  set proj_name $project
  ##nagelfar ignore Unknown variable
  set proj_dir $main_folder
  set map_file [file normalize [lindex [glob -nocomplain "$proj_dir/synthesis/*.map"] 0]]
  set sap_file [file normalize [lindex [glob -nocomplain "$proj_dir/synthesis/*.sap"] 0]]
  set srd_file [file normalize [lindex [glob -nocomplain "$proj_dir/synthesis/*.srd"] 0]]
  set srm_file [file normalize [lindex [glob -nocomplain "$proj_dir/synthesis/*.srm"] 0]]
  set srs_file [file normalize [lindex [glob -nocomplain "$proj_dir/synthesis/*.srs"] 0]]
  set xml_dir [file normalize "$repo_path/xml"]

} else {
  #tcl shell
  set work_path $old_path
  set fw_file   [file normalize [lindex [glob -nocomplain "$work_path/*.bit"] 0]]
  set proj_name [file tail [file normalize $work_path/../../]]
  set proj_dir [file normalize "$work_path/../.."]

  set top_name  [file rootname [file tail $fw_file]]

  set main_file [file normalize "$work_path/$top_name.bit"]
  set bin_file [file normalize "$work_path/$top_name.bin"]
  set ltx_file [file normalize "$work_path/$top_name.ltx"]

  set xml_dir [file normalize "$work_path/../xml"]
  set run_dir [file normalize "$work_path/.."]
}

set group_name [GetGroupName $proj_dir "$tcl_path/../.."]

# Vivado
if {[IsXilinx] && [file exists $main_file]} {

  # Go to repository path
  cd $tcl_path/../../

  Msg Info "Evaluating Git sha for $proj_name..."
  lassign [GetRepoVersions [file normalize ./Top/$group_name/$proj_name] $repo_path] sha

  set describe [GetHogDescribe $sha $repo_path]
  Msg Info "Hog describe set to: $describe"

  set ts [clock format [clock seconds] -format {%Y-%m-%d-%H-%M}]

  set dst_dir [file normalize "$bin_dir/$group_name/$proj_name\-$describe"]
  set dst_main [file normalize "$dst_dir/$proj_name\-$describe.$fw_file_ext"]
  set dst_xml [file normalize "$dst_dir/xml"]
  
  Msg Info "Creating $dst_dir..."
  file mkdir $dst_dir

  Msg Info "Copying main binary file $main_file into $dst_main..."
  file copy -force $main_file $dst_main

  # LTX file for ILA, needs a special treatment...
  set ltx_file "$work_path/$top_name.ltx"
  write_debug_probes -quiet $ltx_file
  
  # Additional files
  foreach e $additional_ext {
    set orig [file normalize "$work_path/$top_name.$e"]
    set dst  [file normalize "$dst_dir/$proj_name\-$describe.$e"]
    if {[file exists $orig]} {
      Msg Info "Copying $orig file into $dst..."
      file copy -force $orig $dst
    } else {
      Msg Debug "File: $orig not found."
    }
      
  }



} elseif {[IsQuartus]} {
  #Quartus
  # Go to repository path
  cd $repo_path

  Msg Info "Evaluating Git sha for $name... repo_path: $repo_path"
  puts "$repo_path repo_path"
  lassign [GetRepoVersions "$repo_path/Top/$group_name/$name" "$repo_path"] sha

  set describe [GetHogDescribe $sha $repo_path]
  Msg Info "Git describe set to: $describe"

  set ts [clock format [clock seconds] -format {%Y-%m-%d-%H-%M}]

  set dst_dir [file normalize "$bin_dir/$group_name/$proj_name\-$describe"]
  set dst_pof [file normalize "$dst_dir/$name\-$describe.pof"]
  set dst_sof [file normalize "$dst_dir/$name\-$describe.sof"]
  set dst_rbf [file normalize "$dst_dir/$name\-$describe.rbf"]
  set dst_rpd [file normalize "$dst_dir/$name\-$describe.rpd"]
  set dst_stp [file normalize "$dst_dir/$name\-$describe.stp"]
  set dst_spf [file normalize "$dst_dir/$name\-$describe.spf"]
  set dst_xml [file normalize "$dst_dir/xml"]

  Msg Info "Creating $dst_dir..."
  file mkdir $dst_dir
  Msg Info "Evaluating differences with last commit..."
  set found_uncommitted 0
  set diff [Git diff]
  if {$diff != ""} {
    set found_uncommitted 1
    Msg Warning "Found non committed changes:"
    Msg Status "$diff"
    set fp [open "$dst_dir/diff_postbistream.txt" w+]
    puts $fp "$diff"
    close $fp
  }

  if {$found_uncommitted == 0} {
    Msg Info "No uncommitted changes found."
  }

  #pof file
  if {[file exists $pof_file]} {
    Msg Info "Copying pof file $pof_file into $dst_pof..."
    file copy -force $pof_file $dst_pof
  } else {
    Msg Info "No pof file found: $pof_file, that is not a problem"
  }

  #Reports
  file mkdir $dst_dir/reports
  set reps [glob -nocomplain "$proj_dir/output_files/*.rpt"]

  if {[file exists [lindex $reps 0]]} {
    file copy -force {*}$reps $dst_dir/reports
  } else {
    Msg Warning "No reports found in $proj_dir/output_files subfolders"
  }

  # sof File
  if {[file exists $sof_file]} {
    Msg Info "Copying sof file $sof_file into $dst_sof..."
    file copy -force $sof_file $dst_sof
  } else {
    Msg Info "No sof file found: $sof_file, that is not a problem"
  }


  #rbf rpd
  if { [file exists $rbf_file] ||  [file exists $rpd_file] } {
    if {[file exists $rbf_file]} {
      file copy -force $rbf_file $dst_rbf
    }
    if {[file exists $rpd_file]} {
      file copy -force $rpd_file $dst_rpd
    }
  } else {
    Msg Info "No rbf or rpd file found: this is not a problem"
  }

  # stp and spf File
  if {[file exists $stp_file] || [file exists $spf_file]} {
    if {[file exists $stp_file]} {
      file copy -force $stp_file $dst_stp
    }
    if {[file exists $spf_file]} {
      file copy -force $spf_file $dst_spf
    }
  } else {
    Msg Info "No stp or spf file found: that is not a problem"
  }

} elseif {[IsLibero] } {
  # Go to repository path
  cd $tcl_path/../../
  ##nagelfar variable project
  Msg Info "Evaluating git SHA for $project..."
  lassign [GetRepoVersions [file normalize ./Top/$group_name/$project] $repo_path] sha
  set describe [GetHogDescribe $sha $repo_path]
  Msg Info "Git describe set to: $describe"

  set ts [clock format [clock seconds] -format {%Y-%m-%d-%H-%M}]

  set dst_dir [file normalize "$bin_dir/$group_name/$project\-$describe"]
  set dst_map [file normalize "$dst_dir/$project\-$describe.map"]
  set dst_sap [file normalize "$dst_dir/$project\-$describe.sap"]
  set dst_srd [file normalize "$dst_dir/$project\-$describe.srd"]
  set dst_srm [file normalize "$dst_dir/$project\-$describe.srm"]
  set dst_srs [file normalize "$dst_dir/$project\-$describe.srs"]
  set dst_xml [file normalize "$dst_dir/xml"]

  Msg Info "Creating $dst_dir..."
  file mkdir $dst_dir

  if {[file exists $map_file]} {
    Msg Info "Copying map file $map_file into $dst_map..."
    file copy -force $map_file $dst_map
  }

  if {[file exists $sap_file]} {
    Msg Info "Copying sap file $sap_file into $dst_sap..."
    file copy -force $sap_file $dst_sap
  }

  if {[file exists $srd_file]} {
    Msg Info "Copying srd file $srd_file into $dst_srd..."
    file copy -force $srd_file $dst_srd
  }

  if {[file exists $srm_file]} {
    Msg Info "Copying srm file $srm_file into $dst_srm..."
    file copy -force $srm_file $dst_map
  }
  
  if {[file exists $srs_file]} {
    Msg Info "Copying srs file $srs_file into $dst_srs..."
    file copy -force $srs_file $dst_map
  }

} else {
  Msg CriticalWarning "Firmware binary file not found."
}


# IPbus XML
if {[file exists $xml_dir]} {
  Msg Info "XML directory found, copying xml files from $xml_dir to $dst_xml..."
  if {[file exists $dst_xml]} {
    Msg Info "Directory $dst_xml exists, deleting it..."
    file delete -force $dst_xml
  }
  file copy -force $xml_dir $dst_xml
}

# Zynq XSA Export
if {[IsXilinx]} { 
  # Vivado
  # automatically export for zynqs (checking via regex)
  set export_xsa false
  set part [get_property part [current_project]]
  set is_zynq [expr {[regexp {xc7z.*} $part] || [regexp {xczu.*} $part]}]
  if {${is_zynq} == 1} {
    set export_xsa true
  }

  # check for explicit EXPORT_XSA flag in hog.conf
  set properties [ReadConf [lindex [GetConfFiles $repo_path/Top/$group_name/$proj_name] 0]]
  if {[dict exists $properties "hog"]} {
    set propDict [dict get $properties "hog"]
    if {[dict exists $propDict "EXPORT_XSA"]} {
      set export_xsa [dict get $propDict "EXPORT_XSA"]
    }
  }

  if {[string compare [string tolower $export_xsa] "true"]==0} {
    # there is a bug in Vivado 2020.1, check for that version and warn
    # that we can't export XSAs
    regexp -- {Vivado v([0-9]{4}\.[0-9,A-z,_,\.]*) } [version] -> VIVADO_VERSION
    if {[string compare "2020.1" $VIVADO_VERSION]==0} {
      Msg Warning "Vivado 2020.1, a patch must be applied to Vivado to export XSA Files, c.f. https://www.xilinx.com/support/answers/75210.html"
    } else {
      set dst_xsa [file normalize "$dst_dir/${proj_name}\-$describe.xsa"]
      Msg Info "Generating XSA File at $dst_xsa"
      write_hw_platform -fixed -force -include_bit -file "$dst_xsa"
    }
  }
}

# Run user post-bitstream file

set user_post_bitstream_file "./Top/$group_name/$proj_name/post-bitstream.tcl"
if {[file exists $user_post_bitstream_file]} {
  Msg Info "Sourcing user post-bitstream file $user_post_bitstream_file"
  source $user_post_bitstream_file
}

cd $old_path
Msg Info "All done."
