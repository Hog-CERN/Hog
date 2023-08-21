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
# The pre synthesis script checks the status of your git repository and stores into a set of variables that are fed as generics to the HDL project.
# This script is automatically integrated into the Vivado/Quartus workflow by the Create Project script.

##nagelfar variable quartus
##nagelfar variable project

set tcl_path [file normalize "[file dirname [info script]]/.."]
source $tcl_path/hog.tcl

# Import tcllib
if {[IsSynplify]} {
  if {[info exists env(HOG_TCLLIB_PATH)]} {
    lappend auto_path $env(HOG_TCLLIB_PATH) 
  } else {
    puts "ERROR: To run Hog with Microsemi Libero SoC, you need to define the HOG_TCLLIB_PATH variable."
    return
  }
}

if {[IsLibero]} {
  puts "I am running Libero"
}

if {[catch {package require struct::matrix} ERROR]} {
  puts "$ERROR\n If you are running this script on tclsh, you can fix this by installing 'tcllib'"
  return
}



if {[IsISE]} {
  # Vivado + PlanAhead
  set old_path [file normalize "../../Projects/$project/$project.runs/synth_1"]
  file mkdir $old_path
} else {
  set old_path [pwd]
}

if {[info exists env(HOG_EXTERNAL_PATH)]} {
  set ext_path $env(HOG_EXTERNAL_PATH)
  Msg Info "Found environment variable HOG_EXTERNAL_PATH, setting path for external files to $ext_path..."
} else {
  set ext_path ""
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
} elseif {[IsSynplify]} {
  set proj_dir [file normalize [file dirname "[project_data -dir]/../.."]  ]
  set proj_name [file tail $proj_dir]
  set project $proj_name
} else {
  #Tclssh
  set proj_file $old_path/[file tail $old_path].xpr
  set proj_dir [file normalize [file dirname $proj_file]]
  set proj_name [file rootname [file tail $proj_file]]
  Msg CriticalWarning "You seem to be running locally on tclsh, so this is a debug, the project file will be set to $proj_file and was derived from the path you launched this script from: $old_path. If you want this script to work properly in debug mode, please launch it from the top folder of one project, for example Repo/Projects/fpga1/ or Repo/Top/fpga1/"
}

# Go to repository path
set repo_path [file normalize "$tcl_path/../.."]
cd $repo_path

set group [GetGroupName $proj_dir "$tcl_path/../.."]

# Calculating flavour if any
set flavour [string map {. ""} [file extension $proj_name]]
if {$flavour != ""} {
  if {[string is integer $flavour]} {
    Msg Info "Project $proj_name has flavour = $flavour, the generic variable FLAVOUR will be set to $flavour"
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
lassign [GetRepoVersions [file normalize $repo_path/Top/$group/$proj_name] $repo_path $ext_path] commit version  hog_hash hog_ver  top_hash top_ver  libs hashes vers  cons_ver cons_hash  ext_names ext_hashes  xml_hash xml_ver user_ip_repos user_ip_hashes user_ip_vers


set describe [GetHogDescribe $commit $repo_path]
set dst_dir [file normalize "bin/$group/$proj_name\-$describe"]
Msg Info "Creating $dst_dir..."
file mkdir $dst_dir/reports


#check list files and project properties
set confDict [dict create]
set allow_fail_on_conf 0
set allow_fail_on_list 0
set allow_fail_on_git 0
set full_diff_log     0
if {[file exists "$tcl_path/../../Top/$group/$proj_name/hog.conf"]} {
  set confDict [ReadConf "$tcl_path/../../Top/$group/$proj_name/hog.conf"]
  set allow_fail_on_check [DictGet [DictGet $confDict "hog"] "ALLOW_FAIL_ON_CHECK" 0]
  set allow_fail_on_git  [DictGet [DictGet $confDict "hog"] "ALLOW_FAIL_ON_GIT"  0]
  set full_diff_log      [DictGet [DictGet $confDict "hog"] "FULL_DIFF_LOG"      0]
}


set this_commit [GetSHA]

if {[IsVivado]} {
  ##nagelfar ignore
  if {![string equal ext_path ""]} {
    set argv [list "-ext_path" "$ext_path" "-project" "$group/$proj_name" "-outDir" "$dst_dir" "-log" "[expr {!$allow_fail_on_check}]"]
  } else {
    set argv [list "-project" "$group/$proj_name" "-outDir" "$dst_dir" "-log" "[expr {!$allow_fail_on_check}]"]
  }
  source $tcl_path/utils/check_list_files.tcl
  if {[file exists "$dst_dir/diff_list_and_conf.txt"]} {
    Msg CriticalWarning "Project list or hog.conf mismatch, will use current SHA ($this_commit) and version will be set to 0."
    set commit 0000000
    set version 00000000
  }
} elseif {[IsQuartus]} {
  # Quartus
  #TO BE IMPLEMENTED
} else {
  #Tclssh
}

Msg Info "Evaluating non committed changes..."
set found_uncommitted 0
set diff [Git diff]
set diff_stat [Git "diff --stat"]
if {$diff != ""} {
  set found_uncommitted 1
  Msg Warning "Found non committed changes:..."
  if {$full_diff_log} {
    Msg Status "$diff"
  } else {
    Msg Status "$diff_stat"
  }
  set fp [open "$dst_dir/diff_presynthesis.txt" w+]
  puts $fp "$diff"
  close $fp
  Msg CriticalWarning "Repository is not clean, will use current SHA ($this_commit) and create a dirty bitfile..."
}

lassign [GetHogFiles  -ext_path "$ext_path" "$tcl_path/../../Top/$group/$proj_name/list/" "$tcl_path/../../"] listLibraries listProperties

if {!$allow_fail_on_git} {
  foreach library [dict keys $listLibraries] {
    set fileNames [dict get $listLibraries $library]
    foreach fileName $fileNames {
      if {[FileCommitted $fileName] == 0} {
        set fp [open "$dst_dir/diff_presynthesis.txt" a+]
        set found_uncommitted 1
        puts $fp "\n[Relative $tcl_path/../../ $fileName] is not in the git repository"
        Msg CriticalWarning "[Relative $tcl_path/../../ $fileName] is not in the git repository. Will use current SHA ($this_commit) and version will be set to 0."
        close $fp
      }
    }
  }
}
if {$found_uncommitted == 0} {
  Msg Info "No uncommitted changes found."
} else {
  set commit 0000000
  set version 00000000
}


# Check if repository has v0.0.1 tag
lassign [GitRet "tag -l v0.0.1" ] status result
if {$status == 1} {
  Msg CriticalWarning "Repository does not have an initial v0.0.1 tag yet. Please create it with \"git tag v0.0.1\" "
}


Msg Info "Git describe for $commit is: $describe"

if {$commit == 0 } {
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
  CopyXMLsFromListFile ./Top/$group/$proj_name/list/xml.lst ./ $xml_dst [HexVersionToString $xml_ver] $xml_hash
  set use_ipbus 1
} else {
  set use_ipbus 0
}

#number of threads
set maxThreads [GetMaxThreads [file normalize ./Top/$group/$proj_name/]]
if {$maxThreads != 1} {
  Msg CriticalWarning "Multithreading enabled. Bitfile will not be deterministic. Number of threads: $maxThreads"
} else {
  Msg Info "Disabling multithreading to assure deterministic bitfile"
}

if {[IsXilinx]} {
  ### Vivado
  set_param general.maxThreads $maxThreads
} elseif {[IsQuartus]} {
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
} elseif {[IsSynplify]} {
  set_option -max_parallel_jobs $maxThreads
} else {
  ### Tcl Shell
  puts "Hog:DEBUG MaxThread is set to: $maxThreads"
}

set clock_seconds [clock seconds]
set tt [clock format $clock_seconds -format {%d/%m/%Y at %H:%M:%S}]

if {[GitVersion 2.9.3]} {
  set date [Git "log -1 --format=%cd --date=format:%d%m%Y $commit"]
  set timee [Git "log -1 --format=%cd --date=format:00%H%M%S $commit"]
} else {
  Msg Warning "Found Git version older than 2.9.3. Using current date and time instead of commit time."
  set date [clock format $clock_seconds  -format {%d%m%Y}]
  set timee [clock format $clock_seconds -format {00%H%M%S}]
}

#####  Passing Hog generic to top file
if {[IsXilinx] || [IsSynplify]} {
  ### VIVADO
  set proj_path "$group/$proj_name"
  # set global generic variables
  WriteGenerics "synth" $proj_path $date $timee $commit $version $top_hash $top_ver $hog_hash $hog_ver $cons_ver $cons_hash  $libs $vers $hashes $ext_names $ext_hashes $user_ip_repos $user_ip_vers $user_ip_hashes $flavour $xml_ver $xml_hash
  set status_file [file normalize "$old_path/../versions.txt"]

} elseif {[IsQuartus]} {
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

  set status_file "$old_path/output_files/versions.txt"
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
set status_file [open $status_file "w+"]

Msg Status " ------------------------- PRE SYNTHESIS -------------------------"
Msg Status " $tt"
Msg Status " Firmware date and time: $date, $timee"
if {$flavour != -1} {
  Msg Status " Project flavour: $flavour"
}

set version [HexVersionToString $version]
if {$group != ""} {
  puts $status_file "## $group/$proj_name Version Table\n"
} else {
  puts $status_file "## $proj_name Version Table\n"
}

struct::matrix m
m add columns 7

m add row  "| \"**File set**\" | \"**Commit SHA**\" | **Version**  |"
m add row  "| --- | --- | --- |"
Msg Status " Global SHA: $commit, VER: $version"
m add row  "| Global | $commit | $version |"

set cons_ver [HexVersionToString $cons_ver]
Msg Status " Constraints SHA: $cons_hash, VER: $cons_ver"
m add row  "| Constraints | $cons_hash | $cons_ver |"

if {$use_ipbus == 1} {
  set xml_ver [HexVersionToString $xml_ver]
  Msg Status " IPbus XML SHA: $xml_hash, VER: $xml_ver"
  m add row "| \"IPbus XML\" | $xml_hash | $xml_ver |"
}
set top_ver [HexVersionToString $top_ver]
Msg Status " Top SHA: $top_hash, VER: $top_ver"
m add row "| \"Top Directory\" | $top_hash | $top_ver |"

set hog_ver [HexVersionToString $hog_ver]
Msg Status " Hog SHA: $hog_hash, VER: $hog_ver"
m add row "| Hog | $hog_hash | $hog_ver |"

Msg Status " --- Libraries ---"
foreach l $libs v $vers h $hashes {
  set v [HexVersionToString $v]
  Msg Status " $l SHA: $h, VER: $v"
  m add row "| \"**Lib:** $l\" | $h | $v |"
}

if {[llength $user_ip_repos] > 0} {

  Msg Status " --- User IP Repositories ---"
  foreach r $user_ip_repos v $user_ip_vers h $user_ip_hashes {
    set v [HexVersionToString $v]
    set repo_name [file tail $r]
    Msg Status " $repo_name SHA: $h, VER: $v"
    m add row "| \"**Repo:** $repo_name\" | $h | $v |"
  }
}

if {[llength $ext_names] > 0} {
  Msg Status " --- External Libraries ---"
  foreach e $ext_names eh $ext_hashes {
    Msg Status " $e SHA: $eh"
    m add row "| \"**Ext:** $e\" | $eh | \" \" |"
  }
}

Msg Status " -----------------------------------------------------------------"

puts $status_file [m format 2string]
puts $status_file "\n\n"
close $status_file

if {[IsXilinx]} {
  CheckYmlRef [file normalize $tcl_path/../..] true
}

set user_pre_synthesis_file "./Top/$group/$proj_name/pre-synthesis.tcl"
if {[file exists $user_pre_synthesis_file]} {
  Msg Info "Sourcing user pre-synthesis file $user_pre_synthesis_file"
  source $user_pre_synthesis_file
}

cd $old_path

Msg Info "All done."
