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
# Copy project file and documentation from  HOG_UNOFFICIAL_BIN_EOS_PATH to HOG_OFFICIAL_BIN_EOS_PATH

#parsing command options
if {[catch {package require cmdline} ERROR]} {
  puts "$ERROR\n If you are running this script on tclsh, you can fix this by installing 'tcllib'" 
  return
}
set parameters {
}

set usage   "Script to copy project files and documentation from \$HOG_UNOFFICIAL_BIN_EOS_PATH to \$HOG_OFFICIAL_BIN_EOS_PATH \nUsage: $argv0 <hog official eos path> <hog unofficial eos path> <tag> <commit short SHA>\n"


set repo_path [pwd]
set tclpath [file dirname [info script]]
cd $tclpath
source ../hog.tcl
if {[catch {array set options [cmdline::getoptions ::argv $parameters $usage]}] || $argc != 4} {
  Msg Info [cmdline::usage $parameters $usage]
  cd $repo_path
  exit 1
}
lassign $argv official unofficial tag current_sha

cd ../../../
Msg Info "Evaluating git describe..."
set describe [exec git describe --always --tags --long]
Msg Info "Git describe: $describe"


lassign [ExtractVersionFromTag $tag] M m p mr

if {$mr == -1} {
  set wild_card $unofficial/$current_sha
  lassign [eos "ls $wild_card"] status folders

  if {$status == 0} {
    Msg Info "Found these files using $wild_card: $folders"
    set new_dir $official/$tag
    Msg Info "Copying $wild_card into $new_dir"
    eos "cp -r $wild_card $official" 5
    eos "mv -r $official/$current_sha $new_dir" 5
         # f Loop over projects in repository
    foreach f $folders {
      set new_folder ""
      regexp {(.*?)(?:-v\d+\.\d+\.\d+)?-\d+-g.+} $f a new_folder 
      if { $new_folder != ""} {
        Msg Info "Renaming folder $f into $new_folder-$tag" 
        eos "mv -r $new_dir/$f $new_dir/$new_folder-$tag" 5
        lassign [eos "ls $new_dir/$new_folder-$tag"] sub_status sub_folders
        foreach fp $sub_folders {
          set new_file ""
          regexp {(.*?)(?:-v\d+\.\d+\.\d+)?-\d+-g.+} $fp a new_file 
          set extension [string range $fp [expr {[string last "." $fp]} + 1] end]
          if {$new_file != ""} {
            Msg Info "Renaming file $fp into $new_file-$tag.$extension"
            eos "mv $new_dir/$new_folder-$tag/$fp $new_dir/$new_folder-$tag/$new_file-$tag.$extension" 5
          }
        }
      }
      if { $new_folder == "Doc" } {
        Msg Info "Updating official doxygen documentation in $official/Doc"    
        eos "mkdir -p $official/Doc" 5
        eos "cp -r $new_dir/$new_folder-$tag/* $official/Doc/" 5           
      }    
    }
  } else {
    Msg Error "Could not find anything useful using $wild_card."
  }
}

cd $repo_path
