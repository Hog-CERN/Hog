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
# Create and uploads GitLab badges for chosen projects

set OldPath [pwd]
set TclPath [file dirname [info script]]/..
set repo_path [file normalize "$TclPath/../.."]
source $TclPath/hog.tcl

set usage "- CI script that creates GitLab badges with utilisation and timing results for a chosen Hog project \n USAGE: $::argv0 <push token> <Gitlab api url> <Gitlab project id> <Gitlab project url> <Hog project> <ext_path>"

if { [llength $argv] < 1 } {
    Msg Info [cmdline::usage $usage]
    cd $OldPath
    return
}

set result [catch {package require json} JsonFound]
if {"$result" != "0"} {
    Msg CriticalWarning "Cannot find JSON package equal or higher than 1.0.\n $JsonFound\n Exiting"
    return -1
}

set push_token [lindex $argv 0]
set api_url [lindex $argv 1]
set project_id [lindex $argv 2]
set project_url [lindex $argv 3]
set project [lindex $argv 4]
set ext_path [lindex $argv 5]

set resources [dict create "LUTs" "LUTs" "Registers" "FFs" "Block" "BRAM" "URAM" "URAM" "DSPs" "DSPs"]
set ver [ GetProjectVersion $repo_path/Top/$project $repo_path $ext_path 0 ]

set accumulated ""
set current_badges []
set page 1

while {1} {
    lassign [ExecuteRet curl --header "PRIVATE-TOKEN: $push_token" "$api_url/projects/${project_id}/badges?page=$page" --request GET] ret content
    if {[llength $content] > 0 && $page < 100} {
        set accumulated "$accumulated$content"
        incr page
    } else {
        set current_badges [json::json2dict $accumulated]
        break
    }
}


if [catch {glob -type d $repo_path/bin/$project-${ver} } prj_dir] {
    Msg CriticalWarning "Cannot find $project binaries in artifacts"
    return
}

cd $prj_dir
if {[file exists utilization.txt]} {
    set fp [open utilization.txt]
    set lines [split [read $fp] "\n"]
    close $fp
    set new_badges [dict create]
    set prj_name [string map {/ _} $project]

    set res_value ""
    set usage_dict [dict create]
    # Resource Badges
    foreach line $lines {
        set str [string map {| ""} $line]
        set str [string map {"<" ""} $str]
        set str [string trim $str]

        set usage [lindex [split $str] end]
        foreach res [dict keys $resources] {
            if {[string first $res $str] > -1} {
                set res_name [dict get $resources $res]
                dict set usage_dict $res_name $usage
            }
        }
    }
    foreach res [dict keys $usage_dict] {
        set usage [DictGet $usage_dict $res]
        append res_value $res ": $usage\% "
    }

    Execute anybadge -l "$project-$ver" -v "$res_value" -f $prj_name.svg --color=blue -o;
    dict set new_badges "$prj_name" "$prj_name"

    # Timing Badge
    if {[file exists timing_error.txt]} {
        Execute anybadge -l timing -v "FAILED" -f timing-$prj_name.svg --color=red -o;
    } else {
        Execute anybadge -l timing -v "OK" -f timing-$prj_name.svg --color=green -o;
    }
    dict set new_badges "timing-$prj_name" "timing-$prj_name"



    foreach badge_name [dict keys $new_badges] {
        set badge_found 0
        lassign [ExecuteRet curl -s --request POST --header "PRIVATE-TOKEN: ${push_token}" --form "file=@$badge_name.svg" $api_url/projects/$project_id/uploads] ret content
        set image_url [ParseJSON $content url]
        foreach badge $current_badges {
            set current_badge_name [dict get $badge "name"]
            set badge_id [dict get $badge "id"]
            if {$current_badge_name == $badge_name} {
                set badge_found 1
                Msg Info "Badge $badge_name exists, updating it..."
                Execute curl --header "PRIVATE-TOKEN: $push_token" "$api_url/projects/${project_id}/badges/$badge_id" --request PUT --data "image_url=$project_url/$image_url"
                break
            }
        }
        if {$badge_found == 0} {
            Msg Info "Badge $badge_name does not exist yet. Creating it..."
            Execute curl --header "PRIVATE-TOKEN: $push_token" --request POST --data "link_url=$project_url/-/releases&image_url=$project_url/$image_url&name=$badge_name" "$api_url/projects/$project_id/badges"
        }
    }
}

cd $OldPath
