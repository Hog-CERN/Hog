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
# Merges a branch into HOG_TARGET_BRANCH (default 'master') and creates a new tag

#parsing command options

set old_path [pwd]
set TclPath [file dirname [info script]]/..
source $TclPath/hog.tcl

if {[catch {package require cmdline} ERROR]} {
  Msg Error "$ERROR\n If you are running this script on tclsh, you can fix this by installing 'tcllib'" 
  return
}

set parameters {
  {Hog "Runs merge and tag of Hog repository. Default = off. To be only used by HOG developers!!!"}
  {merged "If set, instructs this script to tag the new official version (of the form vM.m.p). To be used once the merge request is merged is merged Default = off"}
  {mr_par.arg "" "Merge request parameters in JSON format. Ignored if -merged is set"}
  {mr_id.arg 0 "Merge request ID. Ignored if -merged is set"}
  {push.arg "" "Optional: git branch for push"}
  {main_branch.arg "master" "Main branch (default = master)"}
  {default_version_level.arg "patch" "Default version level to increase if nothing is specified in the merge request description. Can be patch, minor, major. Default = patch"}
  {no_increase "If set, prevents this script to increase the version if MAJOR_VARION, MINOR_VERSION or PATCH_VERSION directives are found in the merge request descritpion. Default = off"}
}

set usage "- CI script that merges your branch with \$HOG_TARGET_BRANCH and creates a new tag\n USAGE: $::argv0 \[OPTIONS\] \n. Options:"

if {[catch {array set options [cmdline::getoptions ::argv $parameters $usage]}] } {
  Msg Info [cmdline::usage $parameters $usage]
  cd $old_path
  return
}




if { $options(Hog) == 0 } {
  set onHOG ""
} else {
  Msg Info "You are merging and tagging Hog (only for Hog developers!)"
  set onHOG "-Hog"
}

set VERSION 0  

set merge_request_number 0
if {$options(merged) == 0} {
  if {$options(mr_par) ==""} {
    Msg Error "Merge request parameters not provided! You must provide them using \"-mr_par \$MR_PARAMETERS\" flag"
    cd $old_path
    exit 1
  }
  if {$options(mr_id) ==""} {
    Msg Error "Merge request id not provided! You must provide them using \"-mr_id \$MR_ID\" flag"
    cd $old_path
    exit 1
  }
  set WIP [ParseJSON  $options(mr_par) "work_in_progress"]
  set MERGE_STATUS [ParseJSON  $options(mr_par) "merge_status"]
  set DESCRIPTION [ParseJSON  $options(mr_par) "description"]
  Msg Info "WIP: ${WIP},  Merge Request Status: ${MERGE_STATUS}   Description: ${DESCRIPTION}"
  if {$options(no_increase) != 0} {
    Msg Info "Will ignore the  directives in the MR description to increase version, if any."
    set VERSION 0
  } else {
    if {[lsearch $DESCRIPTION "*PATCH_VERSION*" ] >= 0} {
      set VERSION 0
    }
    if {[lsearch $DESCRIPTION "*MINOR_VERSION*" ] >= 0} {
      set VERSION 1
    }
    if {[lsearch $DESCRIPTION "*MAJOR_VERSION*" ] >= 0} {
      set VERSION 2
    } 
    set merge_request_number $options(mr_id)
  }
} else {
  set VERSION 3
}

Msg Info "Version Level $VERSION"
if {[catch {exec git merge --no-commit origin/$options(main_branch)} MRG]} {
  Msg Error "Branch is outdated, please merge the latest changes from $options(main_branch) with:\n git fetch && git merge origin/$options(main_branch)\n"
  exit 1	
}

Msg Info [exec $TclPath/CI/tag_repository.tcl -level $VERSION $onHOG $merge_request_number -default_version_level $options(default_version_level)]
if {$options(push)!= ""} {
  if {[catch {exec git push origin $options(push)} TMP]} {
    Msg Warning $TMP
  } else {
    Msg Info $TMP
  }
  if {[catch {exec git push --tags origin $options(push)} TMP]} {
    Msg Warning $TMP
  } else {
    Msg Info $TMP
  }
}
