#!/usr/bin/env tclsh
#   Copyright 2018-2024 The University of Birmingham
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


proc generate_prj_badge {prj_name ver color file} {
    set font_size 11.0
    set max_characters 31.0
    if { [expr {[string length $prj_name] > $max_characters}] } {
      set scaling_factor [expr { $max_characters / [string length $prj_name] } ]
      set font_size [expr {ceil($scaling_factor*$font_size)}]
    }

    set svg_content "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"250\" height=\"20\">
    <linearGradient id=\"b\" x2=\"0\" y2=\"100%\">
        <stop offset=\"0\" stop-color=\"#bbb\" stop-opacity=\".1\"/>
        <stop offset=\"1\" stop-opacity=\".1\"/>
    </linearGradient>
    <mask id=\"hog_prj_badge\">
        <rect width=\"250\" height=\"20\" rx=\"10\" fill=\"#fff\"/>
    </mask>
    <g mask=\"url(#hog_prj_badge)\">
        <path fill=\"$color\" d=\"M0 0h250v20H0z\"/>
        <path fill=\"#262626\" d=\"M160 0h90v20H160z\"/>
        <path fill=\"#262626\" d=\"M250,20 a1,1 0 0,0 0,-16\"/>
        <path fill=\"url(#b)\" d=\"M0 0h250v20H0z\"/>
    </g>
    <g fill=\"#fff\" text-anchor=\"middle\" font-family=\"DejaVu Sans,Verdana,Geneva,sans-serif\" font-size=\"$font_size\">
        <text x=\"80\" y=\"14\">$prj_name</text>
    </g>
    <g fill=\"#fff\" text-anchor=\"middle\" font-family=\"DejaVu Sans,Verdana,Geneva,sans-serif\" font-size=\"11\">
        <text x=\"205\" y=\"14\">$ver</text>
    </g>
</svg>"

    if {[catch {
        set fh [open $file w]
        puts $fh $svg_content
        close $fh
    } error_msg]} {
        error "Failed to write to file: $error_msg"
    }
}

proc generate_res_badge {res res_value color file} {
    set svg_content "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"120\" height=\"20\">
    <linearGradient id=\"b\" x2=\"0\" y2=\"100%\">
        <stop offset=\"0\" stop-color=\"#bbb\" stop-opacity=\".1\"/>
        <stop offset=\"1\" stop-opacity=\".1\"/>
    </linearGradient>
    <mask id=\"hog_res_badge\">
        <rect width=\"120\" height=\"20\" rx=\"3\" fill=\"#fff\"/>
    </mask>
    <g mask=\"url(#hog_res_badge)\">
        <path fill=\"#555\" d=\"M0 0h60v20H0z\"/>
        <path fill=\"$color\" d=\"M60 0h60v20H60z\"/>
        <path fill=\"url(#b)\" d=\"M0 0h120v20H0z\"/>
    </g>
    <g fill=\"#fff\" text-anchor=\"middle\" font-family=\"DejaVu Sans,Verdana,Geneva,sans-serif\" font-size=\"11\">
        <text x=\"30\" y=\"15\" fill=\"#010101\" fill-opacity=\".3\">$res</text>
        <text x=\"30\" y=\"14\">$res</text>
    </g>
    <g fill=\"#fff\" text-anchor=\"middle\" font-family=\"DejaVu Sans,Verdana,Geneva,sans-serif\" font-size=\"11\">
        <text x=\"90\" y=\"15\" fill=\"#010101\" fill-opacity=\".3\">$res_value</text>
        <text x=\"90\" y=\"14\">$res_value</text>
    </g>
</svg>"

    if {[catch {
        set fh [open $file w]
        puts $fh $svg_content
        close $fh
    } error_msg]} {
        error "Failed to write to file: $error_msg"
    }

}

set OldPath [pwd]
set TclPath [file dirname [info script]]/..
set repo_path [file normalize "$TclPath/../.."]
source $TclPath/hog.tcl

set usage "- CI script that creates GitLab badges with utilisation and timing results for a chosen Hog project \n USAGE: $::argv0 <push token> <Gitlab api url> <Gitlab project id> <Gitlab project url> <GitLab Server URL> <Hog project> <ext_path>"

if { [llength $argv] < 7 } {
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
set gitlab_url [lindex $argv 4]
set project [lindex $argv 5]
set ext_path [lindex $argv 6]

set resources [dict create "LUTs" "LUTs" "Registers" "FFs" "Block" "BRAM" "URAM" "URAM" "DSPs" "DSPs"]
set ver [ GetProjectVersion $repo_path/Top/$project $repo_path $ext_path 0 ]

set accumulated ""
set current_badges [dict create]
set page 0

Msg Info "Retrieving current badges..."
while {1} {
  lassign [ExecuteRet curl --header "PRIVATE-TOKEN: $push_token" "$api_url/projects/${project_id}/badges?page=$page" --request GET] ret content
  set content_dict [json::json2dict $content]
  if {[llength $content_dict] > 0} {
    foreach it $content_dict {
      dict set current_badges [DictGet $it name] [DictGet $it id]
    }
    incr page
  } else {
    break
  }
}


if {[catch {glob -types d $repo_path/bin/$project-${ver} } prj_dir]} {
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

  # Timing Badge
  if {[file exists timing_error.txt]} {
    generate_prj_badge $prj_name $ver "#E05D44" "timing-$prj_name.svg"
  } elseif {[file exists timing_ok.txt]} {
    generate_prj_badge $prj_name $ver "#006400" "timing-$prj_name.svg"
  } else {
    generate_prj_badge $prj_name $ver "#696969" "timing-$prj_name.svg"
  }
  dict set new_badges "timing-$prj_name" "timing-$prj_name"

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
    set res_value "$usage\% "
    if {[ expr {$usage < 50.0} ]} {
      generate_res_badge $res $res_value "#90CAF9" "$res-$prj_name.svg"
    } elseif {[ expr {$usage < 80.0} ]} {
      generate_res_badge $res $res_value "#1565C0" "$res-$prj_name.svg"
    } else {
      generate_res_badge $res $res_value "#0D2B6B" "$res-$prj_name.svg"
    }
    dict set new_badges "$res-$prj_name" "$res-$prj_name"
  }

  foreach badge_name [dict keys $new_badges] {
    set badge_found 0
    Msg Info "Uploading badge image $badge_name.svg ...."
    lassign [ExecuteRet curl --request POST --header "PRIVATE-TOKEN: ${push_token}" --form "file=@$badge_name.svg" $api_url/projects/$project_id/uploads] ret content
    set image_url [ParseJSON $content full_path]
    set image_url $gitlab_url/$image_url

    if {[dict exists $current_badges $badge_name]} {
      Msg Info "Badge $badge_name exists, updating it..."
      set badge_id [DictGet $current_badges $badge_name]
      Execute curl --header "PRIVATE-TOKEN: $push_token" "$api_url/projects/${project_id}/badges/$badge_id" --request PUT --data "image_url=$image_url"
    } else {
      Msg Info "Badge $badge_name does not exist yet. Creating it..."
      Execute curl --header "PRIVATE-TOKEN: $push_token" --request POST --data "link_url=$project_url/-/releases&image_url=$image_url&name=$badge_name" "$api_url/projects/$project_id/badges"
    }
  }
}

cd $OldPath
