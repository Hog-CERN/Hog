#!/usr/bin/env tclsh
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
# The pre synthesis script checks the status of your git repository and stores into a set of variables that are fed as genereics to the HDL project.
# This script is automatically integrated into the Vivado/Quartus workflow by the Create Project script.

if {[catch {package require struct::matrix} ERROR]} {
  puts "$ERROR\n If you are running this script on tclsh, you can fix this by installing 'tcllib'"
  return
}

if {[info commands get_property] != "" && [string first PlanAhead [version]] == 0 } {
  # Vivado + PlanAhead
  set old_path [file normalize "../../Projects/$project/$project.runs/synth_1"]
  file mkdir $old_path
} else {
  set old_path [pwd]
}

set tcl_path [file normalize "[file dirname [info script]]/.."]
source $tcl_path/hog.tcl

if {[info exists env(HOG_EXTERNAL_PATH)]} {
  set ext_path $env(HOG_EXTERNAL_PATH)
  Msg Info "Found environment variable HOG_EXTERNAL_PATH, setting path for external files to $ext_path..."
} else {
  set ext_path ""
}

# Go to repository path
set repo_path [file normalize "$tcl_path/../.."]
cd $repo_path

if {[info commands get_property] != ""} {
  # Vivado + PlanAhead
  if { [string first PlanAhead [version]] == 0 } {
    set proj_file [get_property DIRECTORY [current_project]]
  } else {
    set proj_file [get_property parent.project_path [current_project]]
  }
  set proj_dir [file normalize [file dirname $proj_file]]
  set proj_name [file rootname [file tail $proj_file]]
} elseif {[info commands project_new] != ""} {
  # Quartus
  set proj_name [lindex $quartus(args) 1]
  set proj_dir [file normalize "$repo_path/Projects/$proj_name"]
  set proj_file [file normalize "$proj_dir/$proj_name.qpf"]
} else {
  #Tclssh
  set proj_file $old_path/[file tail $old_path].xpr
  Msg CriticalWarning "You seem to be running locally on tclsh, so this is a debug, the project file will be set to $proj_file and was derived from the path you launched this script from: $old_path. If you want this script to work properly in debug mode, please launch it from the top folder of one project, for example Repo/Projects/fpga1/ or Repo/Top/fpga1/"
}
set index_a [string last "Projects/" $proj_dir]
set index_a [expr $index_a + 8]
set index_b [string last "/$proj_name" $proj_dir]
set group_name [string range $proj_dir $index_a $index_b]
# Calculating flavour if any
set flavour [string map {. ""} [file ext $proj_name]]
if {$flavour != ""} {
  if [string is integer $flavour] {
    Msg Info "Project $proj_name has flavour = $flavour, the generic variable FLAVUOR will be set to $flavour"
  } else {
    Msg Warning "Project name has a unexpected non numeric extension, flavour will be set to -1"
    set flavour -1
  }

} else {
  set flavour -1
}

######## Reset files before synthesis ###########
ResetRepoFiles "./Projects/hog_reset_files"

# Getting all the versions and SHAs of the repository
lassign [GetRepoVersions [file normalize ./Top/$group_name/$proj_name] $repo_path $ext_path] commit version  hog_hash hog_ver  top_hash top_ver  libs hashes vers  cons_ver cons_hash  ext_names ext_hashes  xml_hash xml_ver

set this_commit  [Git {log --format=%h -1}]

set describe [GetGitDescribe $commit]
Msg Info "Git describe for $commit is: $describe"

if {$commit == 0 } {
  Msg CriticalWarning "Repository is not clean, will use current SHA ($this_commit) and create a dirty bitfile..."
  set commit $this_commit
} else {
  Msg Info "Found last SHA for $proj_name: $commit"
  if {$commit != $this_commit} {
    set count [Git "rev-list --count $commit..$this_commit"]
    Msg Info "The commit in which project $proj_name was last modified is $commit, that is $count commits older than current commit $this_commit."
  }
}

if {$xml_hash != 0} {
  set xml_dst [file normalize $old_path/../xml]
  Msg Info "Creating XML directory $xml_dst..."
  file mkdir $xml_dst
  Msg Info "Copying xml files to $xml_dst and replacing placeholders with xml version $xml_ver..."
  CopyXMLsFromListFile ./Top/$group_name/$proj_name/list/xml.lst ./ $xml_dst [HexVersionToString $xml_ver] $xml_hash
  set use_ipbus 1
} else {
  set use_ipbus 0
}

#number of threads
set maxThreads [GetMaxThreads [file normalize ./Top/$group_name/$proj_name/]]
if {$maxThreads != 1} {
  Msg CriticalWarning "Multithreading enabled. Bitfile will not be deterministic. Number of threads: $maxThreads"
} else {
  Msg Info "Disabling multithreading to assure deterministic bitfile"
}

if {[info commands set_param] != ""} {
    ### Vivado
  set_param general.maxThreads $maxThreads
} elseif {[info commands project_new] != ""} {
  # QUARTUS
  if { [catch {package require ::quartus::project} ERROR] } {
    Msg Error "$ERROR\n Can not find package ::quartus::project"
    cd $old_path
    return 1
  }
  set this_dir [pwd]
  cd $proj_dir
  project_open $proj_name -current_revision
  cd $this_dir
  set_global_assignment -name NUM_PARALLEL_PROCESSORS $maxThreads
  project_close
} else {
    ### Tcl Shell
  puts "Hog:DEBUG MaxThread is set to: $maxThreads"
}

set clock_seconds [clock seconds]
set tt [clock format $clock_seconds -format {%d/%m/%Y at %H:%M:%S}]

if [GitVersion 2.9.3] {
  set date [Git "log -1 --format=%cd --date=format:'%d%m%Y' $commit"]
  set timee [Git "log -1 --format=%cd --date=format:'00%H%M%S' $commit"]
} else {
  Msg Warning "Found Git version older than 2.9.3. Using current date and time instead of commit time."
  set date [clock format $clock_seconds  -format {%d%m%Y}]
  set timee [clock format $clock_seconds -format {00%H%M%S}]
}

#####  Passing Hog generic to top file
if {[info commands set_property] != ""} {
  ### VIVADO
  # set global generic varibles
  set generic_string "GLOBAL_DATE=32'h$date GLOBAL_TIME=32'h$timee GLOBAL_VER=32'h$version GLOBAL_SHA=32'h0$commit TOP_SHA=32'h0$top_hash TOP_VER=32'h$top_ver HOG_SHA=32'h0$hog_hash HOG_VER=32'h$hog_ver CON_VER=32'h$cons_ver CON_SHA=32'h0$cons_hash"
  if {$use_ipbus == 1} {
    set generic_string "$generic_string XML_VER=32'h$xml_ver XML_SHA=32'h0$xml_hash"
  }

  #set project specific lists
  foreach l $libs v $vers h $hashes {
    set ver "[string toupper $l]_VER=32'h$v "
    set hash "[string toupper $l]_SHA=32'h0$h"
    set generic_string "$generic_string $ver $hash"
  }

  foreach e $ext_names h $ext_hashes {
    set hash "[string toupper $e]_SHA=32'h0$h"
    set generic_string "$generic_string $hash"
  }

  if {$flavour != -1} {
    set generic_string "$generic_string FLAVOUR=$flavour"
  }

  set_property generic $generic_string [current_fileset]
  set status_file [file normalize "$old_path/../versions.txt"]

} elseif {[info commands project_new] != ""} {
  #Quartus
  if { [catch {package require ::quartus::project} ERROR] } {
    Msg Error "$ERROR\n Can not find package ::quartus::project"
    cd $old_path
    return 1
  }
  set this_dir [pwd]
  cd $proj_dir
  project_open $proj_name -current_revision
  cd $this_dir

  set zero_ttb 00000000

  binary scan [binary format H* [string map {{'} {}} $date]] B32 bits
  set_parameter -name GLOBAL_DATE $bits
  binary scan [binary format H* [string map {{'} {}} $timee]] B32 bits
  set_parameter -name GLOBAL_TIME $bits
  binary scan [binary format H* [string map {{'} {}} $version]] B32 bits
  set_parameter -name GLOBAL_VER $bits
  binary scan [binary format H* [string map {{'} {}} $commit]] B32 bits
  set_parameter -name GLOBAL_SHA $bits
  binary scan [binary format H* [string map {{'} {}} $top_hash]] B32 bits
  set_parameter -name TOP_SHA $bits
  binary scan [binary format H* [string map {{'} {}} $top_ver]] B32 bits
  set_parameter -name TOP_VER $bits
  binary scan [binary format H* [string map {{'} {}} $hog_hash]] B32 bits
  set_parameter -name HOG_SHA $bits
  binary scan [binary format H* [string map {{'} {}} $hog_ver]] B32 bits
  set_parameter -name HOG_VER $bits
  binary scan [binary format H* [string map {{'} {}} $cons_ver]] B32 bits
  set_parameter -name CON_VER $bits
  binary scan [binary format H* [string map {{'} {}} $cons_hash]] B32 bits
  set_parameter -name CON_SHA $bits

  if {$use_ipbus == 1} {
    binary scan [binary format H* [string map {{'} {}} $xml_ver]] B32 bits
    set_parameter -name XML_VER $bits
    binary scan [binary format H* [string map {{'} {}} $xml_hash]] B32 bits
    set_parameter -name XML_SHA $bits
  }

  #set project specific lists
  foreach l $libs v $vers h $hashes {
    binary scan [binary format H* [string map {{'} {}} $v]] B32 bits
    set_parameter -name "[string toupper $l]_VER" $bits
    binary scan [binary format H* [string map {{'} {}} $h]] B32 bits
    set_parameter -name "[string toupper $l]_SHA" $bits
  }

  foreach e $ext_names h $ext_hashes {
    binary scan [binary format H* [string map {{'} {}} $h]] B32 bits
    set_parameter -name "[string toupper $e]_SHA" $bits
  }

  if {$flavour != -1} {
     set_parameter -name FLAVOUR $flavour
  }

  if {![file exists "$old_path/output_files"]} {
    file mkdir "$old_path/output_files"
  }

  set  status_file "$old_path/output_files/versions.txt"
  project_close

} else {
  ### Tcl Shell
  puts "Hog:DEBUG GLOBAL_DATE=$date GLOBAL_TIME=$timee"
  puts "Hog:DEBUG GLOBAL_SHA=$commit TOP_SHA=$top_hash"
  puts "Hog:DEBUG CON_VER=$cons_ver CON_SHA=$cons_hash"
  puts "Hog:DEBUG XML_SHA=$xml_hash GLOBAL_VER=$version TOP_VER=$top_ver"
  puts "Hog:DEBUG XML_VER=$xml_ver HOG_SHA=$hog_hash HOG_VER=$hog_ver"
  puts "Hog:DEBUG LIBS: $libs $vers $hashes"
  puts "Hog:DEBUG EXT: $ext_names $ext_hashes"
  puts "Hog:DEBUG FLAVOUR: $flavour"
  set  status_file "$old_path/versions.txt"

}
Msg Info "Opening version file $status_file..."
set status_file [open $status_file "w"]

set dst_dir [file normalize "bin/$group_name/$proj_name\-$describe"]
Msg Info "Creating $dst_dir..."
file mkdir $dst_dir/reports

Msg Info "Evaluating non committed changes..."
set diff [Git diff]
if {$diff != ""} {
  Msg Warning "Found non committed changes:..."
  Msg Status "$diff"
  set fp [open "$dst_dir/diff_presynthesis.txt" w+]
  puts $fp "$diff"
  close $fp
} else {
  Msg Info "No uncommitted changes found."
}

Msg Status " ------------------------- PRE SYNTHESIS -------------------------"
Msg Status " $tt"
Msg Status " Firmware date and time: $date, $timee"
if {$flavour != -1} {
  Msg Status " Project flavour: $flavour"
}

set version [HexVersionToString $version]
puts $status_file "## $proj_name version table"
struct::matrix m
m add columns 7

m add row  "| \"**File set**\" | \"**Commit SHA**\" | **Version**  |"
m add row  "| --- | --- | --- |"
Msg Status " Global SHA: $commit, VER: $version"
m add row  "| Global | [string tolower $commit] | $version |"

set cons_ver [HexVersionToString $cons_ver]
Msg Status " Constraints SHA: $cons_hash, VER: $cons_ver"
m add row  "| Constraints | [string tolower $cons_hash] | $cons_ver |"

if {$use_ipbus == 1} {
  set xml_ver [HexVersionToString $xml_ver]
  Msg Status " IPbus XML SHA: $xml_hash, VER: $xml_ver"
  m add row "| \"IPbus XML\" | [string tolower $xml_hash] | $xml_ver |"
}
set top_ver [HexVersionToString $top_ver]
Msg Status " Top SHA: $top_hash, VER: $top_ver"
m add row "| \"Project Tcl\" | [string tolower $top_hash] | $top_ver |"

set hog_ver [HexVersionToString $hog_ver]
Msg Status " Hog SHA: $hog_hash, VER: $hog_ver"
m add row "| Hog | [string tolower $hog_hash] | $hog_ver |"

Msg Status " --- Libraries ---"
foreach l $libs v $vers h $hashes {
  set v [HexVersionToString $v]
  Msg Status " $l SHA: $h, VER: $v"
  m add row "| \"**Lib:** $l\" |  [string tolower $h] | $v |"
}

Msg Status " --- External Libraries ---"
foreach e $ext_names eh $ext_hashes {
  Msg Status " $e SHA: $eh"
  m add row "| \"**Ext:** $e\" | [string tolower $eh] | \" \" |"
}
Msg Status " -----------------------------------------------------------------"

puts $status_file [m format 2string]
puts $status_file "\n\n"
close $status_file

CheckYmlRef [file normalize $tcl_path/../..] true

set user_pre_synthesis_file "./Top/$group_name/$proj_name/pre-synthesis.tcl"
if {[file exists $user_pre_synthesis_file]} {
    Msg Info "Sourcing user pre-synthesis file $user_pre_synthesis_file"
    source $user_pre_synthesis_file
}

cd $old_path

#check list files
if {[info commands get_property] != "" && [string first PlanAhead [version]] != 0} {
    if {![string equal ext_path ""]} {
        set argv [list "-ext_path" "$ext_path" "-project" "$group_name/$proj_name"]
    } else {
        set argv [list "-project" "$group_name/$proj_name"]
    }
    source  $tcl_path/utils/check_list_files.tcl
} elseif {[info commands project_new] != ""} {
    # Quartus
  #TO BE IMPLEMENTED
} else {
    #Tclssh
}

Msg Info "All done."
