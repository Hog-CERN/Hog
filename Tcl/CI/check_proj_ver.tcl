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

set tcl_path [file normalize "[file dirname [info script]]/.."]
set repo_path [file normalize "$tcl_path/../.."]

source $tcl_path/hog.tcl

# Import tcllib for libero
if {[IsLibero]} {
  if {[info exists env(HOG_TCLLIB_PATH)]} {
    lappend auto_path $env(HOG_TCLLIB_PATH)
  } else {
    puts "ERROR: To run Hog with Microsemi Libero SoC, you need to define the HOG_TCLLIB_PATH variable."
    return
  }
}

#parsing command options
if {[catch {package require cmdline} ERROR] || [catch {package require struct::matrix} ERROR]} {
  puts "$ERROR\n Tcllib not found. If you are running this script on tclsh, you can fix this by installing 'tcllib'"
  return
}



set parameters {
  {sim    "If set, checks also the version of the simulation files."}
  {ext_path.arg "" "Sets the absolute path for the external libraries."}
}

set usage "- USAGE: $::argv0 \[OPTIONS\] <project> \n. Options:"

if {$::argc eq 0} {
  Msg Info [cmdline::usage $parameters $usage]
  exit 1
} elseif {[IsQuartus] && [catch {array set options [cmdline::getoptions quartus(args) $parameters $usage]}] || $::argc eq 0} {
  #Quartus
  Msg Info [cmdline::usage $parameters $usage]
  exit 1
} elseif {[catch {array set options [cmdline::getoptions ::argv $parameters $usage]}]} {
  Msg Info [cmdline::usage $parameters $usage]
  exit 1
  ##nagelfar ignore Unknown variable
}

set project [lindex $argv 0]
set sim 0
set ext_path ""
set project_dir $repo_path/Top/$project

if {$options(sim) == 1} {
  set sim 1
  Msg Info "Will check also the version of the simulation files..."
}

if {$options(ext_path) != ""} {
  set ext_path $options(ext_path)
  Msg Info "External path set to $ext_path"
}

set ci_run 0
if {[info exists env(HOG_PUSH_TOKEN)] && [info exist env(CI_PROJECT_ID)] && [info exist env(CI_API_V4_URL)] } {
  set token $env(HOG_PUSH_TOKEN)
  set api_url $env(CI_API_V4_URL)
  set project_id $env(CI_PROJECT_ID)
  set ci_run 1
}

set ver [GetProjectVersion $project_dir $repo_path $ext_path $sim]
if {$ver == 0} {
  Msg Info "$project was modified, continuing with the CI..."
  if {$ci_run == 1 && ![IsQuartus] && ![IsISE]} {
    Msg Info "Checking if the project has been already built in a previous CI run..."
    lassign [GetRepoVersions $project_dir $repo_path] sha
    Msg Info "Checking if project $project has been build in a previous CI run with sha $sha..."
    set result [catch {package require json} JsonFound]
    if {"$result" != "0"} {
      Msg CriticalWarning "Cannot find JSON package equal or higher than 1.0.\n $JsonFound\n Exiting"
      return
    }
    lassign [ExecuteRet curl --header "PRIVATE-TOKEN: $token" "$api_url/projects/$project_id/pipelines"] ret content
    set pipeline_dict [json::json2dict $content]
    if {[llength $pipeline_dict] > 0} {
      foreach pip $pipeline_dict {
        # puts $pip
        set pip_sha [DictGet $pip sha]
        set source [DictGet $pip source]
        if {$source == "merge_request_event" && [string first $sha $pip_sha] != -1} {
          Msg Info "Found pipeline with sha $pip_sha for project $project"
          puts $pip
          set pipeline_id [DictGet $pip id]
          # tclint-disable-next-line line-length
          lassign [ExecuteRet curl --header "PRIVATE-TOKEN: $token" "$api_url/projects/${project_id}/pipelines/${pipeline_id}/jobs?pagination=keyset&per_page=100"] ret2 content2
          set jobs_dict [json::json2dict $content2]
          if {[llength $jobs_dict] > 0} {
            foreach job $jobs_dict {
              set job_name [DictGet $job name]
              set job_id [DictGet $job id]
              set artifacts [DictGet $job artifacts_file]
              set status [DictGet $job status]
              set current_job_name $env(CI_JOB_NAME)
              if {$current_job_name == $job_name && $status == "success"} {
                # tclint-disable-next-line line-length
                lassign [ExecuteRet curl --location --output artifacts.zip --header "PRIVATE-TOKEN: $token" --url "$api_url/projects/$project_id/jobs/$job_id/artifacts"] ret3 content3
                if {$ret3 != 0} {
                  Msg CriticalWarning "Cannot download artifacts for job $job_name with id $job_id"
                  return
                } else {
                  Execute unzip -o $repo_path/artifacts.zip
                  Msg Info "Artifacts for job $job_name with id $job_id downloaded and unzipped."
                  exit 0
                }
              }
            }
          }
        }
      }
    }
  }
} elseif {$ver != -1} {
  Msg Info "$project was not modified since version: $ver, disabling the CI..."
  file mkdir $repo_path/Projects/$project
  set fp [open "$repo_path/Projects/$project/skip.me" w+]
  close $fp
}
