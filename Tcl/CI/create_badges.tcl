#!/usr/bin/env tclsh
#   Copyright 2018-2026 The University of Birmingham
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


proc generate_prj_badge {prj_name ver color file {is_hls 0}} {
  # Left-panel font auto-shrink (existing behaviour).
  set font_size 11.0
  set max_characters 20.0
  if { [expr {[string length $prj_name] > $max_characters}] } {
    set scaling_factor [expr {$max_characters / [string length $prj_name]}]
    set font_size [expr {ceil($scaling_factor * $font_size)}]
  }

  # Right-panel text: for HLS badges prepend "HLS " as a subtle marker.
  if {$is_hls} {
    set ver_text "HLS $ver"
  } else {
    set ver_text $ver
  }

  # Right-panel font auto-shrink, proportional to the narrower 90-px panel.
  set ver_font_size 11.0
  set ver_max_characters 12.0
  if { [expr {[string length $ver_text] > $ver_max_characters}] } {
    set ver_scaling [expr {$ver_max_characters / [string length $ver_text]}]
    set ver_font_size [expr {ceil($ver_scaling * $ver_font_size)}]
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
    <g fill=\"#fff\" text-anchor=\"middle\" font-family=\"DejaVu Sans,Verdana,Geneva,sans-serif\" font-size=\"$ver_font_size\">
        <text x=\"205\" y=\"14\">$ver_text</text>
    </g>
</svg>"

  if {
    [catch {
      set fh [open $file w]
      puts $fh $svg_content
      close $fh
    } error_msg]
  } {
    error "Failed to write to file: $error_msg"
  }
}

proc generate_res_badge {res res_value color file {is_hls 0}} {
  # Right-panel text: for HLS badges prepend "HLS " as a subtle marker.
  if {$is_hls} {
    set value_text "HLS $res_value"
  } else {
    set value_text $res_value
  }

  # Right-panel font auto-shrink (60-px panel).
  set value_font_size 11.0
  set value_max_characters 9.0
  if { [expr {[string length $value_text] > $value_max_characters}] } {
    set value_scaling [expr {$value_max_characters / [string length $value_text]}]
    set value_font_size [expr {ceil($value_scaling * $value_font_size)}]
  }

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
    <g fill=\"#fff\" text-anchor=\"middle\" font-family=\"DejaVu Sans,Verdana,Geneva,sans-serif\" font-size=\"$value_font_size\">
        <text x=\"90\" y=\"15\" fill=\"#010101\" fill-opacity=\".3\">$value_text</text>
        <text x=\"90\" y=\"14\">$value_text</text>
    </g>
</svg>"

  if {
    [catch {
      set fh [open $file w]
      puts $fh $svg_content
      close $fh
    } error_msg]
  } {
    error "Failed to write to file: $error_msg"
  }
}

set OldPath [pwd]
set TclPath [file dirname [info script]]/..
set repo_path [file normalize "$TclPath/../.."]
source $TclPath/hog.tcl
set curl_cmd [GetCurl]

set usage "- CI script that creates GitLab badges with utilisation and timing results for a chosen Hog project.\n\
USAGE: $::argv0 <push token> <Gitlab api url> <Gitlab project id> <Gitlab project url> <GitLab Server URL> <Hog project> <ext_path>"

if {[llength $argv] < 7} {
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
set ver [GetProjectVersion $repo_path/Top/$project $repo_path $ext_path 0]

set accumulated ""
set current_badges [dict create]
set page 0

Msg Info "Retrieving current badges..."
while {1} {
  lassign [ExecuteRet {*}$curl_cmd --header "PRIVATE-TOKEN: $push_token" "$api_url/projects/${project_id}/badges?page=$page" --request GET] ret content
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


if {[catch {glob -types d $repo_path/bin/$project-${ver}} prj_dir]} {
  Msg CriticalWarning "Cannot find $project binaries in artifacts"
  return
}

# Parse a Vivado utilization.txt into a dict { "LUTs" -> percentage, ... }.
# The existing Vivado format uses substring matching on the `resources` dict
# (keys: "LUTs", "Registers", "Block", "URAM", "DSPs").
proc parse_vivado_util {lines resources} {
  set usage_dict [dict create]
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
  return $usage_dict
}

# Parse an HLS utilization.txt (markdown) into a dict { "LUTs" -> percentage, ... }.
# Rows look like "| LUT | 1234 | 230400 | 0.54 |". Implementation tables appear
# after Synthesis ones, so the dict naturally ends up with post-P&R numbers.
proc parse_hls_util {lines} {
  set usage_dict [dict create]
  set hls_res_map [dict create LUT "LUTs" FF "FFs" BRAM "BRAM" BRAM_18K "BRAM" URAM "URAM" DSP "DSPs"]
  foreach line $lines {
    if {![regexp {^\s*\|\s*([A-Za-z_0-9]+)\s*\|\s*\S+\s*\|\s*\S+\s*\|\s*(\S+)\s*\|} $line -> site pct]} {
      continue
    }
    if {[dict exists $hls_res_map $site]} {
      set res_name [dict get $hls_res_map $site]
      if {[string is double -strict $pct]} {
        dict set usage_dict $res_name $pct
      }
    }
  }
  return $usage_dict
}

# Emit one timing badge + one set of resource badges for a given "source"
# (either Vivado at the project root, or one HLS component in a subfolder).
#
#   util_dir      — directory holding utilization.txt + timing_ok/error.txt
#   badge_suffix  — suffix used for filenames and GitLab badge names
#   label_left    — text shown on the left of each badge
#   is_hls        — 1 for HLS badges (adds "HLS" marker on the right side)
#   util_dict     — parsed { resource -> usage% } dict
#   ver           — version string
#   new_badges_var — name of caller dict to update with generated badge names
proc emit_badges {util_dir badge_suffix label_left is_hls util_dict ver new_badges_var} {
  upvar 1 $new_badges_var new_badges

  # Timing badge
  if {[file exists $util_dir/timing_error.txt]} {
    generate_prj_badge $label_left $ver "#E05D44" "timing-$badge_suffix.svg" $is_hls
  } elseif {[file exists $util_dir/timing_ok.txt]} {
    generate_prj_badge $label_left $ver "#006400" "timing-$badge_suffix.svg" $is_hls
  } else {
    generate_prj_badge $label_left $ver "#696969" "timing-$badge_suffix.svg" $is_hls
  }
  dict set new_badges "timing-$badge_suffix" "timing-$badge_suffix"

  # Resource badges
  foreach res [dict keys $util_dict] {
    set usage [DictGet $util_dict $res]
    set res_value "$usage\% "
    if {[expr {$usage < 50.0}]} {
      generate_res_badge $res $res_value "#90CAF9" "$res-$badge_suffix.svg" $is_hls
    } elseif {[expr {$usage < 80.0}]} {
      generate_res_badge $res $res_value "#1565C0" "$res-$badge_suffix.svg" $is_hls
    } else {
      generate_res_badge $res $res_value "#0D2B6B" "$res-$badge_suffix.svg" $is_hls
    }
    dict set new_badges "$res-$badge_suffix" "$res-$badge_suffix"
  }
}

cd $prj_dir

set new_badges [dict create]
set prj_name [string map {/ _} $project]

# -------- Vivado (top-level utilization.txt) --------
if {[file exists utilization.txt]} {
  set fp [open utilization.txt]
  set vivado_lines [split [read $fp] "\n"]
  close $fp
  set vivado_util [parse_vivado_util $vivado_lines $resources]
  emit_badges "." $prj_name $prj_name 0 $vivado_util $ver new_badges
}

# -------- HLS components --------
# Mixed (vivado_vitis_unified) projects group HLS under vitis_hls/<component>/;
# pure vitis_unified projects place them directly under <component>/.
# The glob order also determines upload order — Vivado (already handled above)
# comes first, then mixed-project HLS components, then pure-HLS components.
set hls_util_files [concat \
  [glob -nocomplain vitis_hls/*/utilization.txt] \
  [glob -nocomplain */utilization.txt]]
foreach hls_util $hls_util_files {
  set comp_dir [file dirname $hls_util]
  # Skip Vivado utilization.txt at the project root (already processed above).
  if {$comp_dir eq "." || $comp_dir eq ""} { continue }
  set comp_name [file tail $comp_dir]
  # Skip the 'vitis_hls' wrapper itself (we iterate its children separately).
  if {$comp_name eq "vitis_hls"} { continue }
  set fp [open $hls_util]
  set hls_lines [split [read $fp] "\n"]
  close $fp
  set hls_util_dict [parse_hls_util $hls_lines]
  set badge_suffix "$prj_name-$comp_name"
  # Avoid emitting duplicate badges if a component name collides between the
  # two globs (shouldn't happen in practice, but defensive).
  if {[dict exists $new_badges "timing-$badge_suffix"]} { continue }
  emit_badges $comp_dir $badge_suffix $comp_name 1 $hls_util_dict $ver new_badges
}

# -------- Upload all generated badges --------
foreach badge_name [dict keys $new_badges] {
  Msg Info "Uploading badge image $badge_name.svg ...."
  # tclint-disable-next-line line-length
  lassign [ExecuteRet {*}$curl_cmd --request POST --header "PRIVATE-TOKEN: ${push_token}" --form "file=@$badge_name.svg" $api_url/projects/$project_id/uploads] ret content
  set image_url [ParseJSON $content full_path]
  set image_url $gitlab_url/$image_url
  if {[dict exists $current_badges $badge_name]} {
    Msg Info "Badge $badge_name exists, updating it..."
    set badge_id [DictGet $current_badges $badge_name]
    Execute curl --header "PRIVATE-TOKEN: $push_token" "$api_url/projects/${project_id}/badges/$badge_id" --request PUT --data "image_url=$image_url"
  } else {
    Msg Info "Badge $badge_name does not exist yet. Creating it..."
    # tclint-disable-next-line line-length
    Execute curl --header "PRIVATE-TOKEN: $push_token" --request POST --data "link_url=$project_url/-/releases&image_url=$image_url&name=$badge_name" "$api_url/projects/$project_id/badges"
  }
}

cd $OldPath
