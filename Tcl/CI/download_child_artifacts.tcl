# @file
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


# Downloads artifacts from child pipelines
#parsing command options
set OldPath [pwd]
set TclPath [file dirname [info script]]/..
set repo_path [file normalize "$TclPath/../.."]
source $TclPath/hog.tcl

set usage "- CI script that downloads artifacts from child pipelines.\n USAGE: $::argv0 <project id> <commit SHA> <create_job id>."

if {[llength $argv] < 3} {
  Msg Info $usage
  cd $OldPath
  return
}

set proj_id [lindex $argv 0]
set commit_sha [lindex $argv 1]
set create_job_id [lindex $argv 2]
set page 1

lassign [ExecuteRet glab api "/projects/$proj_id/jobs/?page=1"] ret msg
if {$ret != 0} {
  Msg Error "Some problem when getting parent pipeline: $msg"
  return -1
} else {
  set result [catch {package require json} JsonFound]
  if {"$result" != "0"} {
    Msg Error "Cannot find JSON package equal or higher than 1.0.\n $JsonFound\n Exiting"
    return -1
  }

  set ChildList [json::json2dict $msg]
  foreach Child $ChildList {
    set result [catch {dict get $Child "id"} child_job_id]
    if {"$result" != "0" || $child_job_id < $create_job_id} {
      continue
    }
    set result [catch {dict get [dict get $Child "commit"] "id"} child_sha]
    if {"$result" != "0"} {
      Msg Error "Error when retrieving SHA of child process $child_job_id. Error message:\n $child_sha\n Exiting"
      return -1
    }
    if {"$child_sha" != "$commit_sha"} {
      #Msg CriticalWarning "Child process $child_job_id SHA $child_sha does not correspond to current SHA $commit_sha. Ignoring child process"
      continue
    }

    set result [catch {dict get $Child "name"} job_name]
    if {"$result" != "0" || "$job_name" != "collect_artifacts"} {
      continue
    }

    #ignoring jobs without artifacts
    set result [catch {dict get $Child "artifacts"} artifact_list]
    if {"$result" != "0"} {
      continue
    }
    set withArchive 0
    foreach artifact $artifact_list {
      set result [catch {dict get $artifact "file_type"} file_type]
      if {"$result" != "0"} {
        Msg CriticalWarning "Problem when reading artifact for child process $job_name"
        continue
      }
      if {"$file_type" == "archive"} {
        set withArchive 1
      }
    }
    if {$withArchive == "0"} {
      Msg Info "No archive artifacts found for child job $job_name, ignoring it\n"
      continue
    }

    Msg Info "Downloading artifacts for child job at: projects/${proj_id}/jobs/${child_job_id}/artifacts/"
    lassign [ExecuteRet glab api "/projects/${proj_id}/jobs/${child_job_id}/artifacts/" > output_${child_job_id}.zip] ret msg
    if {$ret != 0} {
      Msg Error "Some problem when downloading artifacts for child job id:$child_job_id. Error message: $msg"
      return -1
    }
    Execute unzip -o output_${child_job_id}.zip
    file delete output_${child_job_id}.zip
  }
}
