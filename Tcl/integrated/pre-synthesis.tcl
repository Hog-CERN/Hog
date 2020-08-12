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
# The pre synthesis script checks the status of your git repository and stores into a set of variables that are fed as genereics to the HDL project.
# This script is automatically integrated into the Vivado/Quartus workflow by the Create Project script.

if {[catch {package require struct::matrix} ERROR]} {
  puts "$ERROR\n If you are running this script on tclsh, you can fix this by installing 'tcllib'"
  return
}

set old_path [pwd]
set tcl_path [file normalize "[file dirname [info script]]/.."]
source $tcl_path/hog.tcl

# Go to repository path
cd "$tcl_path/../.."

if {[info commands get_property] != ""} {
  # Vivado + PlanAhead
  if { [string first PlanAhead [version]] == 0 } {
    set proj_file [get_property DIRECTORY [current_project]]
  } else {
    set proj_file [get_property parent.project_path [current_project]]
  }
} elseif {[info commands project_new] != ""} {
    # Quartus
  set proj_file "/q/a/r/Quartus_project.qpf"
} else {
    #Tclssh
  set proj_file $old_path/[file tail $old_path].xpr
  Msg CriticalWarning "You seem to be running locally on tclsh, so this is a debug, the project file will be set to $proj_file and was derived from the path you launched this script from: $old_path. If you want this script to work properly in debug mode, please launch it from the top folder of one project, for example Repo/VivadoProject/fpga1/ or Repo/Top/fpga1/"
}

set proj_dir [file normalize [file dirname $proj_file]]
set proj_name [file rootname [file tail $proj_file]]

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

# Getting all the versions and SHAs of the repository
lassign [GetRepoVersions ./Top/$proj_name/$proj_name.tcl] commit version  hog_hash hog_ver  top_hash top_ver  libs hashes vers  subs subs_hashes  cons_ver cons_hash  ext_names ext_hashes  xml_hash xml_ver 

set this_commit  [exec git log --format=%h -1]

set describe [GetGitDescribe $commit]
Msg Info "Git describe for $commit is: $describe"

if {$commit == 0 } {
  Msg CriticalWarning "Repository is not clean, will use current SHA ($this_commit) and create a dirty bitfile..."
  set commit $this_commit
} else {
  Msg Info "Found last SHA for $proj_name: $commit"
  if {$commit != $this_commit} {
    set count [exec git rev-list --count $commit..$this_commit]
    Msg Info "The commit in which project $proj_name was last modified is $commit, that is $count commits older than current commit $this_commit."
  }
}

if {$xml_hash != 0} {
  set xml_dst [file normalize $old_path/../xml]
  Msg Info "Creating XML directory $xml_dst..."
  file mkdir $xml_dst
  Msg Info "Copying xml files to $xml_dst and replacing placeholders with xml version $xml_ver..."
  CopyXMLsFromListFile ./Top/$proj_name/list/xml.lst ./ $xml_dst [HexVersionToString $xml_ver] $xml_hash
  set use_ipbus 1
} else {
  set use_ipbus 0
}

#number of threads
set maxThreads [GetMaxThreads $proj_name]
if {$maxThreads != 1} {
  Msg CriticalWarning "Multithreading enabled. Bitfile will not be deterministic. Number of threads: $maxThreads"
} else {
  Msg Info "Disabling multithreading to assure deterministic bitfile"
}

if {[info commands set_param] != ""} {
    ### Vivado
  set_param general.maxThreads $maxThreads
} elseif {[info commands quartus_command] != ""} {
    ### QUARTUS
  quartus_command $maxThreads
} else {
    ### Tcl Shell
  puts "Hog:DEBUG MAxThread is set to: $maxThreads"
}

set clock_seconds [clock seconds]
set tt [clock format $clock_seconds -format {%d/%m/%Y at %H:%M:%S}]

if [GitVersion 2.9.3] {
  set date [exec git log -1 --format=%cd --date=format:'%d%m%Y' $commit --]
  set timee [exec git log -1 --format=%cd --date=format:'00%H%M%S' $commit --]
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
    set generic_string "$generic_string XML_VER=32'h$xml_ver XML_SHA=32'h$xml_hash"
  }

  #set project specific lists
  foreach l $libs v $vers h $hashes {
    set ver "[string toupper $l]_VER=32'h$v "
    set hash "[string toupper $l]_SHA=32'h0$h"
    set generic_string "$generic_string $ver $hash"
  }

  #set project specific sub modules
  foreach s $subs h $subs_hashes {
    set hash "[string toupper $s]_SHA=32'h0$h"
    set generic_string "$generic_string $hash"
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

} elseif {[info commands quartus_command] != ""} {
    ### QUARTUS
  set  status_file "$old_path/../versions.txt"

} else {
  ### Tcl Shell
  puts "Hog:DEBUG GLOBAL_DATE=$date GLOBAL_TIME=$timee"
  puts "Hog:DEBUG GLOBAL_SHA=$commit TOP_SHA=$top_hash"
  puts "Hog:DEBUG CON_VER=$cons_ver CON_SHA=$cons_hash"
  puts "Hog:DEBUG XML_SHA=$xml_hash GLOBAL_VER=$version TOP_VER=$top_ver"
  puts "Hog:DEBUG XML_VER=$xml_ver HOG_SHA=$hog_hash HOG_VER=$hog_ver"
  puts "Hog:DEBUG LIBS: $libs $vers $hashes"
  puts "Hog:DEBUG SUBS: $subs $subs_hashes"
  puts "Hog:DEBUG EXT: $ext_names $ext_hashes"
  puts "Hog:DEBUG FLAVOUR: $flavour"
  set  status_file "$old_path/versions.txt"

}
Msg Info "Opening version file $status_file..."
set status_file [open $status_file "w"]

set dst_dir [file normalize "bin/$proj_name\-$describe"]
Msg Info "Creating $dst_dir..."
file mkdir $dst_dir/reports

Msg Info "Evaluating non committed changes..."
set diff [exec git diff]
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
Msg Status " --- Submodules ---"
foreach s $subs sh $subs_hashes {
  Msg Status " $s SHA: $sh"
  m add row "| \"**Sub:** $s\" |  [string tolower $sh] | \" \"  |"
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
cd $old_path

Msg Info "All done."
