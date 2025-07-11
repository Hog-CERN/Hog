#!/usr/bin/env tclsh
#   Copyright 2018-2025 The University of Birmingham
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
# Retrieves binary files links or creates new one to be uploaded as Releases


set OldPath [pwd]
set TclPath [file dirname [info script]]/..
set repo_path [file normalize "$TclPath/../.."]
source $TclPath/hog.tcl

if {[catch {package require cmdline} ERROR]} {
  Msg Error "$ERROR\n If you are running this script on tclsh, you can fix this by installing 'tcllib'"
  return
}

set parameters {
  {force "Forces the creation of new project links"}
}

set usage "- CI script that retrieves binary files links or creates new ones to be uploaded to a GitLab release\n \
USAGE: $::argv0 <tag> <ext_path> \[OPTIONS\] \n. Options:"

if {[catch {array set options [cmdline::getoptions ::argv $parameters $usage]}] || [llength $argv] < 2} {
  Msg Info [cmdline::usage $parameters $usage]
  cd $OldPath
  return
}

set tag [lindex $argv 0]
set ext_path [lindex $argv 1]
cd $repo_path
# Find link for every project:
set projects_list [SearchHogProjects $repo_path/Top]

foreach proj $projects_list {
  #find project version
  set proj_name [file tail $proj]
  set proj_dir [file dirname $proj]
  set dir $repo_path/Top/$proj
  set ver [GetProjectVersion $dir $repo_path $ext_path 1]
  if {"$ver" == "0" || "$ver" == "$tag" || $options(force) == 1} {
    # Project was modified in current version, upload the files
    Msg Info "Retrieving $proj binaries and tag $tag..."
    if {[catch {glob -types d $repo_path/bin/$proj*} prj_dir]} {
      Msg CriticalWarning "Cannot find $proj binaries in artifacts"
      continue
    }
    if {$proj_dir != "."} {
      set proj_zip [string map {/ _} $proj_dir]
      set files [glob -nocomplain -directory "$repo_path/zipped/" ${proj_zip}_${proj_name}-${tag}.z*]
    } else {
      set files [glob -nocomplain -directory "$repo_path/zipped/" ${proj_name}-${tag}.z*]
    }
    foreach f $files {
      set ext [file extension $f]
      Execute glab release upload $tag "$f#${proj}-${tag}$ext"
    }
  } elseif {"$ver" == "-1"} {
    # Something went wrong...
    Msg CriticalWarning "Something went wrong when tried to retrieve version for project $proj"
    cd $OldPath
    return
  } else {
    # Project was not modified in current version. Let's retrieve the last available link.
    Msg Info "Retrieving existing link for $proj binaries and tag $ver"
    lassign [ExecuteRet glab release view $ver] ret msg
    if {$ret != 0} {
      Msg Warning "Some problem when fetching release $ver : $msg"
    } else {
      set link ""
      foreach line [split $msg "\n"] {
        if {[string first "${proj}-${ver}.z" $line] == 0} {
          set name [lindex [split $line] 0]
          set link [lindex [split $line] 1]
          set json "\[{ \"name\": \"$name\",\"url\": \"$link\",\"link_type\": \"other\" } \]"
          Execute glab release upload $tag --assets-links=$json
        }
      }
    }
  }
}
cd $OldPath
