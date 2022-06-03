#!/usr/bin/env tclsh
#   Copyright 2018-2022 The University of Birmingham
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
# Merges a branch into HOG_TARGET_BRANCH (default 'master') and creates a new tag

#parsing command options

set OldPath [pwd]
set TclPath [file dirname [info script]]/..
source $TclPath/hog.tcl

if {[catch {package require cmdline} ERROR]} {
  Msg Error "$ERROR\n If you are running this script on tclsh, you can fix this by installing 'tcllib'"
  exit 1
}

set parameters {
  {Hog "Runs merge and tag of Hog repository. Default = off. To be only used by HOG developers!!!"}
  {merged "If set, instructs this script to tag the new official version (of the form vM.m.p). To be used once the merge request is merged is merged Default = off"}
  {mr_par.arg "" "Merge request parameters in JSON format. Ignored if -merged is set"}
  {mr_id.arg 0 "Merge request ID. Ignored if -merged is set"}
  {branch_name.arg "" "Name of the branch to be written in the notes"}
  {push.arg "" "Optional: git branch for push"}
  {main_branch.arg "master" "Main branch (default = master)"}
  {default_level.arg "0" "Default version level to increase if nothing is specified in the merge request description. Can be 0 (patch), 1 (minor), (2) major. Default ="}
  {no_increase "If set, prevents this script to increase the version if MAJOR_VERSION, MINOR_VERSION or PATCH_VERSION directives are found in the merge request descritpion. Default = off"}
}

set usage "- CI script that merges your branch with \$HOG_TARGET_BRANCH and creates a new tag\n USAGE: $::argv0 \[OPTIONS\] \n. Options:"

if {[catch {array set options [cmdline::getoptions ::argv $parameters $usage]}] } {
  Msg Info [cmdline::usage $parameters $usage]
  cd $OldPath
  exit 1
}

if { $options(Hog) == 0 } {
  set onHOG ""
} else {
  Msg Info "You are merging and tagging Hog (only for Hog developers!)"
  set onHOG "-Hog"
}

if {$options(branch_name)==""} {
  set branch_name ""
} else {
  set branch_name $options(branch_name)
}

set version_level 0

set merge_request_number 0
if {$options(merged) == 0} {
  if {$options(mr_par) ==""} {
    Msg Error "Merge request parameters not provided! You must provide them using \"-mr_par \$MR_PARAMETERS\" flag"
    cd $OldPath
    exit 1
  }
  if {$options(mr_id) ==""} {
    Msg Error "Merge request id not provided! You must provide them using \"-mr_id \$MR_ID\" flag"
    cd $OldPath
    exit 1
  } else {
    set merge_request_number $options(mr_id)
  }



  set WIP [ParseJSON  $options(mr_par) "work_in_progress"]
  set MERGE_STATUS [ParseJSON  $options(mr_par) "merge_status"]
  set DESCRIPTION [list [ParseJSON  $options(mr_par) "description"]]
  Msg Info "WIP: ${WIP},  Merge Request Status: ${MERGE_STATUS}   Description: ${DESCRIPTION}"
  if {$options(no_increase) != 0} {
    Msg Info "Will ignore the directives in the MR description to increase version, if any."
    set version_level 0
  } else {
    if {[lsearch $DESCRIPTION "*PATCH_VERSION*" ] >= 0} {
      set version_level 0
    }
    if {[lsearch $DESCRIPTION "*MINOR_VERSION*" ] >= 0} {
      set version_level 1
    }
    if {[lsearch $DESCRIPTION "*MAJOR_VERSION*" ] >= 0} {
      set version_level 2
    }
  }
} else {
  set version_level 3
}

Msg Info "Version Level $version_level"
lassign [GitRet "merge --no-commit origin/$options(main_branch)"] ret msg
if {$ret != 0 || $msg != "Already up to date."} {
  Msg Error "Branch is outdated, please merge the latest changes from $options(main_branch) with:\n git fetch && git merge origin/$options(main_branch)\n"
  exit 1
}

Msg Info "MR = $merge_request_number, version level: $version_level, default version level: $options(default_level)"

if { $options(Hog) == 1 } {
  #Go to Hog directory
  Msg Info "Tagging path is set to Hog repository."
  set TaggingPath [file normalize $TclPath/..]
} else {
  #Go to HDL repository directory
  Msg Info "Tagging path is set to HDL repository."
  set TaggingPath [file normalize $TclPath/../..]
}

Msg Info "Changing directory to tagging path: $TaggingPath..."
cd $TaggingPath

set tags [TagRepository $merge_request_number $version_level  $options(default_level)]
set old_tag [lindex $tags 0]
set new_tag [lindex $tags 1]

Msg Info "Old tag was: $old_tag and new tag is: $new_tag"

if {$branch_name != ""} {
  # if it is a beta tag, we write in the note the possible official version
  lassign [ExtractVersionFromTag $new_tag] M m p mr
  if {$mr == -1} {
    incr p
  }
  set new_tag v$M.$m.$p
  Git "fetch origin refs/notes/*:refs/notes/*"
  Git "notes add -fm \"$merge_request_number $branch_name $new_tag\""
  Git "push origin refs/notes/*"
}

if {$options(push)!= ""} {
  lassign [GitRet "push origin $options(push)"] ret msg

  if {$ret != 0} {
    Msg Warning $msg
  } else {
    Msg Info $msg
  }
  lassign [GitRet "push --tags origin $options(push)"] ret msg
  if {$ret != 0} {
    Msg Warning $msg
  } else {
    Msg Info $msg
  }
}

cd $OldPath
Msg Info "All done."
