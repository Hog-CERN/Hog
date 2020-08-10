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
}

set usage "- CI script that retrieves binary files links or creates new ones to be uploaded as Releases\n USAGE: $::argv0 <push token> <Gitlab api url> <project id> <project url> <tag> \[OPTIONS\] \n. Options:"

if {[catch {array set options [cmdline::getoptions ::argv $parameters $usage]}] ||  [llength $argv] < 5 } {
  Msg Info [cmdline::usage $parameters $usage]
  cd $OldPath
  return
}
                                                                                                                        
set push_token [lindex $argv 0]
set api [lindex $argv 1]
set proj_id [lindex $argv 2]
set prj_url [lindex $argv 3]
set tag [lindex $argv 4]

set fp [open "$repo_path/project_links.txt" w]

cd $repo_path
# Find link for every project:
foreach dir [glob -type d $repo_path/Top/* ] {
  set proj [ file tail $dir ]
  #find project version
  set ver [ GetProjectVersion $dir/$proj.tcl ]
  if {"$ver"=="0" || "$ver"=="$tag" } {
    Msg Info "Creating new link for $proj binaries and tag $tag"
    if [catch {glob -type d $repo_path/bin/$proj* } prj_dir] {
      Msg CriticalWarning "Cannot find $proj binaries in artifacts"
      break
    }
    exec zip -r $proj.zip bin/[ file tail $prj_dir]
    set content [exec curl -s --request POST --header "PRIVATE-TOKEN: ${push_token}" --form "file=@$repo_path/$proj.zip" ${api}/projects/${proj_id}/uploads]
    # get the url from the json return
    set url [ParseJSON $content "url"]
    set absolute_url ${prj_url}${url}
     puts $fp "$proj $absolute_url"     
    
  } elseif {"$ver"=="-1"} {
    Msg CriticalWarning "Something went wrong when tried to retrieve version for project $proj"
    cd $OldPath
    return
  } else {
    Msg Info "Retrieving existing link for $proj binaries and tag $ver"
    if [catch {exec curl -s --header "PRIVATE-TOKEN: ${push_token}" "${api}/projects/${proj_id}/releases/$ver"} msg ] {
      Msg Warning "Some problem when fetching release $ver : $msg"
    } else {
      set link ""
      foreach line [split  [ParseJSON $msg description] "\n"] {
        if {[string first "\[$proj.zip\]" $line] != -1} {
          set link [lindex [split $line "()"] 1]  
          puts $fp "$proj $link"
        }
      }
      if {"$link" == ""} {
        Msg CriticalWarning "Could not find link to binaries for project $proj and tag $ver"
        break
      }
    }
  }
}
cd $OldPath
close $fp