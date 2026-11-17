#   Copyright 2018-2026 The University of Birmingham
#   Copyright 2018-2026 Max-Planck-Institute for Physics
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

Commands::RegisterCommand CHEBY {
  aliases     {CHB}
  description "Check or regenerate the Cheby register-map artefacts declared in the project .chb list files."
  requires_proj true
  options {
    {generate      "Overwrite the artefacts on disk instead of only checking them."}
    {dst_dir.arg "" "Destination folder for the traceability copies (default is in the ./bin folder)."}
    {profile.arg "all" "Only process the .chb lines whose profile= property matches, e.g. hdl, sw, doc."}
    {tool.arg    "" "Path to the cheby executable. Defaults to \$HOG_CHEBY_TOOL, then to cheby from PATH."}
    {strict        "Report any mismatch or missing artefact as an error rather than a critical warning."}
    {verbose       "If set, launch the script in verbose mode."}
  }
  script {
    if {[Launcher::GetOr options verbose 0]} {
      setDebugMode 1
    }

    set repo_path    [Repo::Get repo_path]
    set project_name [CurrentProject::Get project_name]
    set hog_project  [CurrentProject::GetProjectObj]

    set entries [Cheby::EntriesFromProject $hog_project]
    if {[llength $entries] == 0} {
      Msg Error "Project $project_name declares no Cheby register map.\
                 Add a .chb list file to [CurrentProject::Get list_path] first."
      exit 1
    }
    Msg Info "Handling Cheby register-map outputs for $project_name..."

    # The version and SHA of the register maps are those of the descriptions
    # plus the .chb list files that pull them in.
    set sha_files [Projects::GetProjectFiles $hog_project -library {^cheby\.chb$} -as paths]
    tlist foreachval list_file [tdict get $hog_project list_files] {
      if {[file extension $list_file] eq ".chb"} {
        lappend sha_files $list_file
      }
    }
    lassign [GetVer $sha_files] cheby_ver cheby_sha

    set dst_dir [Launcher::GetOr options dst_dir ""]
    if {$dst_dir eq ""} {
      set proj_dir [file normalize [file join [Repo::Get top_path] $project_name]]
      set describe [GetHogDescribe $proj_dir $repo_path]
      set dst_dir  [file normalize "$repo_path/bin/$project_name-$describe"]
    }
    set cheby_dst [file join [file normalize $dst_dir] cheby]
    file mkdir $cheby_dst

    set n_errors [Cheby::Process $entries $repo_path $cheby_dst \
      -generate [Launcher::GetOr options generate 0] \
      -profile  [Launcher::GetOr options profile "all"] \
      -tool     [Launcher::GetOr options tool ""] \
      -strict   [Launcher::GetOr options strict 0] \
      -verbose  [Launcher::GetOr options verbose 0] \
      -version  [HexVersionToString $cheby_ver] \
      -sha      $cheby_sha \
    ]

    if {$n_errors > 0} {
      Msg CriticalWarning "Cheby step finished with $n_errors error(s)."
      exit 1
    }
    exit 0
  }
}
