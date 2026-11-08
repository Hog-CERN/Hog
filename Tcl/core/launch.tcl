
# Experimental Msg errors propagate to the launcher's catch, including during initialization. 
set ::HOG_THROW_ERRORS 1

# Keep the original error code and Tcl traceback.
set _hog_phase "initializing Hog"
set _hog_working_dir [pwd]
set _hog_status [catch {

################################################################################
## Set up hog environment
################################################################################

source [file join [file dirname [info script]] hog.tcl]
InitHog


################################################################################
## Resolve argv -> node/project/options
################################################################################
set _hog_phase "resolving command arguments"
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
set _hog_phase "setting up the launcher"
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
set _hog_phase "loading project '$project_name'"
if {$project_name ne ""} {
  set hog_project [HogProject::Create -project_name $project_name -repo_path [Repo::Get repo_path]]
  HogProject::LoadConfig hog_project
  if {[file exists [HogProject::Get $hog_project conf_path]]} {
    set _hog_list_tool [expr {$node eq "" ? "" : [tdict getor $node ide ""]}]
    if {$_hog_list_tool eq "tclsh"} { set _hog_list_tool "" }
    HogProject::LoadFiles hog_project "" $_hog_list_tool
  }
  CurrentProject::Load $hog_project
}

################################################################################
## Dispatch - RunRequest runs inline or boots the right IDE, then returns a
## verdict. Only the top-level entry maps that verdict to a process exit code.
################################################################################
set _hog_phase "dispatching '[join $typed_path { }]'"
set result [Commands::RunRequest $request]
switch -- [lindex $result 0] {
  ran     { exit 0 }
  help    { exit 0 }
  usage   { exit 1 }
  boot    { exit 0 }
  default { error "Unexpected dispatch verdict: $result" }
}

} _hog_err _hog_opts]


################################################################################
## Error Handling
################################################################################
if {$_hog_status} {
  if {![dict exists $_hog_opts -hogreported]} {
    puts stderr "ERROR: \[Hog:launch\] $_hog_err"
  }
  puts stderr "  Phase: $_hog_phase"
  puts stderr "  Command: [list ./Hog/Do {*}$::argv]"
  puts stderr "  Invoked from: $_hog_working_dir"
  puts stderr "  Working directory at failure: [pwd]"
  set _hog_exit 1
  if {[dict exists $_hog_opts -errorcode]} {
    set _hog_code [dict get $_hog_opts -errorcode]
    puts stderr "  Error code: $_hog_code"
    # Preserve both IDE-child and Hog subprocess exit statuses.
    if {[lindex $_hog_code 0] in {HOG_TOOL_FAILED HOG_SPAWN_FAILED} && [llength $_hog_code] >= 2} {
      set _hog_exit [lindex $_hog_code 1]
    }
  }
  if {[dict exists $_hog_opts -hoglocations]} {
    puts stderr "\nSource locations (innermost first):"
    foreach _hog_location [dict get $_hog_opts -hoglocations] {
      puts stderr "  [dict get $_hog_location file]:[dict get $_hog_location line]"

      set _hog_command [regsub -all {\s+} [string trim [dict get $_hog_location command]] { }]
      if {[string length $_hog_command] > 160} {
        set _hog_command "[string range $_hog_command 0 156]..."
      }
      puts stderr "    $_hog_command"
    }
  }
  if {[dict exists $_hog_opts -errorinfo]} {
    puts stderr "\nTcl stack trace:"
    puts stderr [dict get $_hog_opts -errorinfo]
  }
  # API commands keep their JSON error on stdout; diagnostics stay on stderr.
  if {[info exists ::HOG_API_MODE] && $::HOG_API_MODE} {
    puts [tobj tojson [tobj create Dict [dict create error [tobj create String $_hog_err]]]]
  }
  exit $_hog_exit
}
