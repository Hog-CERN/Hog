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

## @file commands.tcl
# Cheby commands, sourced from cheby.tcl inside the Tools::Cheby namespace.
#
# The tool node itself is the command, so the syntax stays the legacy one:
#   ./Hog/Do CHEBY <project> [-generate]
# RegisterTool only gives the node a description and aliases, so the script
# and options are added here with UpdateCommand. UpdateCommand drops every
# alias pointing to the node, hence the CHEBY and CHB aliases are re-added.

Commands::UpdateCommand TOOL.CHEBY {
  aliases     {CHB}
  description "Check or regenerate the Cheby register-map artefacts declared in the project .chb list files."
  requires_proj true
  options {
    {generate          "Overwrite the artefacts on disk instead of only checking them."}
    {dst_dir.arg ""    "Destination folder for the traceability copies (default is in the ./bin folder)."}
    {profile.arg "all" "Only process the .chb lines whose profile= property matches, e.g. hdl, sw, doc."}
    {tool.arg    ""    "Path to the cheby executable. Defaults to \$HOG_CHEBY_TOOL, then to cheby from PATH."}
    {strict            "Report any mismatch or missing artefact as an error rather than a critical warning."}
    {verbose           "If set, launch the script in verbose mode."}
  }
  script { Tools::Cheby::Run }
}
Commands::AddAlias CHEBY TOOL.CHEBY
Commands::AddAlias CHB   TOOL.CHEBY


## @brief Return the tracked files among @a files that have uncommitted changes.
#
# Paths outside the repository are skipped, so that git does not fail on them.
#
# @param[in] files      Absolute or repository-relative paths.
# @param[in] repo_path  Repository root.
#
# @return  The list of changed paths as printed by git, empty when clean or when
#          git could not tell.
proc _ChangedFiles {files repo_path} {
  # Normalise both sides, the repository may be reached through a symlink
  set repo_path [file normalize $repo_path]
  set in_repo [list]
  foreach f $files {
    set abs [file normalize [file join $repo_path $f]]
    if {[string first "$repo_path/" $abs] == 0} {
      lappend in_repo [string range $abs [string length "$repo_path/"] end]
    }
  }
  if {[llength $in_repo] == 0} {
    return {}
  }
  set saved_pwd [pwd]
  cd $repo_path
  lassign [GitRet {status --untracked-files=no --porcelain} $in_repo] ret result
  cd $saved_pwd
  if {$ret != 0} {
    return {}
  }
  set changed [list]
  foreach line [split $result "\n"] {
    if {[string trim $line] ne ""} {
      lappend changed [string range $line 3 end]
    }
  }
  return $changed
}


## @brief Return the Hog describe string used to name the traceability folder.
#
# Same result as GetHogDescribe, but without its critical warning when the
# project files are not committed: that does not affect what Cheby checks or
# generates, only the name of the folder, which then ends in -dirty.
#
# @param[in] hog_project  The current project.
# @param[in] proj_dir     The project folder in Top/.
# @param[in] repo_path    Repository root.
proc _Describe {hog_project proj_dir repo_path} {
  set files [Projects::GetProjectFiles $hog_project -as paths]
  lappend files $proj_dir Hog
  if {[llength [_ChangedFiles $files $repo_path]] == 0} {
    return [GetHogDescribe $proj_dir $repo_path]
  }
  Msg Info "The project has uncommitted changes, the traceability copies go to a -dirty folder."
  return "v0.0.0-[string toupper [GetSHA]]-dirty"
}


## @brief Check or regenerate the Cheby artefacts of the current project.
#
# Exits with 1 when the project declares no register map or when any line
# fails, 0 otherwise.
proc Run {} {
  if {[Launcher::GetOr options verbose 0]} {
    setDebugMode 1
  }

  set repo_path    [Repo::Get repo_path]
  set project_name [CurrentProject::Get project_name]
  set hog_project  [CurrentProject::GetProjectObj]

  set entries [EntriesFromProject $hog_project]
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
    set describe [_Describe $hog_project $proj_dir $repo_path]
    set dst_dir  [file normalize "$repo_path/bin/$project_name-$describe"]
  }
  set cheby_dst [file join [file normalize $dst_dir] cheby]
  file mkdir $cheby_dst

  set n_errors [Process $entries $repo_path $cheby_dst \
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
