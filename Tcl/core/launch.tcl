
#if {[catch {
################################################################################
## Set up hog environment
################################################################################
source [file join [file dirname [info script]] hog.tcl]
InitHog


################################################################################
## Resolve argv -> node/project/options (mirrors onto Launcher).
################################################################################
set _tool [ActiveTool::CurrentTool]
Msg Debug "$_tool launched with arguments: $::argv"

set request      [Commands::Resolve $::argv]
set node         [dict get $request node]
set typed_path   [dict get $request typed_path]
set project      [dict get $request project]
set project_name [dict get $request project_name]

################################################################################
## tclsh-only (banner, env, api-mode)
################################################################################
if {$_tool eq "tclsh"} {
  if {$node ne "" && [Commands::Node::IsRunnable $node] && [tdict getor $node api 0]} {
    set ::HOG_API_MODE 1
  }

  Logo [Repo::Get repo_path]

  if {[Launcher::Get directive] eq ""} {
    Msg Error "No directive given. Run './Hog/Do HELP' for usage."
    exit 1
  }

  if {[file exists [Hog::LoggerLib::GetUserFilePath "HogEnv.conf"]]} {
    Msg Debug "HogEnv.conf found"
    set loggerdict [Hog::LoggerLib::ParseTOML [Hog::LoggerLib::GetUserFilePath "HogEnv.conf"]]
    set HogEnvDict [Hog::LoggerLib::GetTOMLDict]
    Hog::LoggerLib::PrintTOMLDict $HogEnvDict
  }
}

################################################################################
## Load the project
################################################################################
if {$project_name ne ""} {
  set hog_project [Projects::GetInfo $project_name [Repo::Get repo_path]]
  if {[file exists [tdict getval $hog_project conf_path]]} {
    Projects::LoadListFiles hog_project
  }
  CurrentProject::Load $hog_project
}

################################################################################
## Dispatch - RunRequest runs inline or boots the right IDE, then returns a
## verdict. Only the top-level entry maps that verdict to a process exit code.
################################################################################
if {[catch {Commands::RunRequest $request} result _ropts]} {
  Msg Error $result
  # Tools::Launch tags a failed IDE child with {HOG_TOOL_FAILED <exit>} so we
  # can mirror the child's status instead of flattening it to 1.
  set _exit 1
  if {[dict exists $_ropts -errorcode]} {
    set _ec [dict get $_ropts -errorcode]
    if {[lindex $_ec 0] eq "HOG_TOOL_FAILED" && [llength $_ec] >= 2} {
      set _exit [lindex $_ec 1]
    }
  }
  exit $_exit
}
switch -- [lindex $result 0] {
  ran     { exit 0 }
  help    { exit 0 }
  usage   { exit 1 }
  boot    { exit 0 }
  default { Msg Error "Unexpected dispatch verdict: $result"; exit 1 }
}

#} _hog_err _hog_opts]} {
#  puts stderr "\nError: $_hog_err"
#  set _hog_code [dict get $_hog_opts -errorcode]
#  if {$_hog_code ne "NONE" && $_hog_code ne ""} { puts stderr "  code: $_hog_code" }
#  if {[info exists ::env(HOG_DEBUG)]} {
#    puts stderr "\nStack trace:"
#    puts stderr [dict get $_hog_opts -errorinfo]
#  }
#  exit 1
#}
