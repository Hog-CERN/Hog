
#if {[catch {
################################################################################
## Set up hog environment
################################################################################
set tcl_path  [file normalize [file join [file dirname [info script]] ..]]
set repo_path [file normalize [file join $tcl_path .. ..]]
set top_path [file join $repo_path Top]

source [file join $tcl_path hog.tcl]
source [file join $tcl_path core datastore.tcl]
source [file join $tcl_path create_project.tcl]
source [file join $tcl_path core listfile.tcl]
source [file join $tcl_path core project.tcl]
source [file join $tcl_path core hog.tcl]
source [file join $tcl_path core tobj.tcl]
source [file join $tcl_path core commands.tcl]
source [file join $tcl_path core tools.tcl]
source [file join $tcl_path core flow.tcl]


################################################################################
## Tool Discovery
################################################################################
Tools::RegisterFromDir [file join $tcl_path tools]
Tools::RegisterFromDir [file join $repo_path hog-tools] -custom
Tools::Init


################################################################################
## Flows
################################################################################
# Custom flows must register BEFORE BuildCommandTree so they're projected into
# the TOOL command tree identically to built-in (Manifest) flows.
Flow::RegisterCustomFlows $repo_path/hog-flows
Tools::BuildCommandTree
ActiveTool::Refresh


################################################################################
## Command Registration
################################################################################
Commands::RegisterCommandsDir [file join $tcl_path  commands]
Commands::RegisterCommandsDir [file join $repo_path hog-commands] -custom
Commands::WarnFlowShadows


################################################################################
## Shared setup: parse argv + populate DataStores
## Runs in both tclsh and tool passes.
################################################################################
Msg Debug "[ActiveTool::CurrentTool] launched with arguments: $::argv"
#puts stderr "\[launch\] [ActiveTool::CurrentTool] argv: $::argv"

if {[catch {package require cmdline} ERROR]} {
  Msg Debug "The cmdline Tcl package was not found, sourcing it from Hog..."
  source $tcl_path/utils/cmdline.tcl
}

# argv layout: <command-path> [project] [options...]
set directive    [string toupper [lindex $::argv 0]]
set request      [Commands::ParseArgv $::argv $top_path]
set cmd          [dict get $request cmd]
set full_cmd     [dict get $request full_cmd]
set project      [dict get $request project]
set project_name [dict get $request project_name]
set options      [dict get $request options]
unset request

DataStore::create Repo
DataStore::create Launcher
DataStore::create CurrentProject
namespace eval CurrentProject {
  proc GetProjectObj {} { variable _ctx; return $_ctx }
}

Launcher::Set Name "Experimental"
Launcher::Set Version "0.1.0"
Launcher::Set time [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]
Launcher::Set script [file normalize [info script]]
Launcher::Set Git  [lindex [Git --version] 2]
Launcher::Set HogTag [Git {describe --tags --always}]
Launcher::Set directive $directive
Launcher::Set cmd          $cmd
Launcher::Set full_cmd     $full_cmd
Launcher::Set project      $project
Launcher::Set project_name $project_name
Launcher::Set options      $options

set _old_dir [pwd]
cd $repo_path
Repo::Set Tag [Git {describe --tags --always}]
cd $_old_dir
unset _old_dir

Repo::Set repo_path             $repo_path
Repo::Set tcl_path              $tcl_path
Repo::Set top_path              $top_path
Repo::Set pre_synth             [file normalize "${tcl_path}/integrated/pre-synthesis.tcl"]
Repo::Set post_synth            [file normalize "${tcl_path}/integrated/post-synthesis.tcl"]
Repo::Set pre_impl              [file normalize "${tcl_path}/integrated/pre-implementation.tcl"]
Repo::Set post_impl             [file normalize "${tcl_path}/integrated/post-implementation.tcl"]
Repo::Set pre_bit               [file normalize "${tcl_path}/integrated/pre-bitstream.tcl"]
Repo::Set post_bit              [file normalize "${tcl_path}/integrated/post-bitstream.tcl"]
Repo::Set quartus_post_module   [file normalize "${tcl_path}/integrated/quartus-post-module.tcl"]

Repo::Set projects_dir [file join $repo_path Projects]
Repo::Set projects [Projects::GetAll $repo_path]

if {$project_name ne ""} {
  set hog_project [Projects::GetInfo $project_name $repo_path]
  if {[file exists [tdict getval $hog_project conf_path]]} {
    Projects::LoadListFiles hog_project
  }
  CurrentProject::Load $hog_project
}

################################################################################
## TCLSH Pass
################################################################################
if {[ActiveTool::CurrentTool] eq "tclsh"} {

  if {$cmd ne "" && [Commands::IsRunnable $cmd] && [tdict getval $cmd api]} {
    # We probably need a way to suppress output earlier, since dynamic loading of
    # commands/tools/flows can produce output before we get here.
    set ::HOG_API_MODE 1
  }

  Logo $repo_path
  #TODO: Check for updates; configurable via repo.conf?

  if {$directive eq ""} {
    Msg Error "No directive given. Run './Hog/Do HELP' for usage."
    exit 1
  }

  Msg Debug "InitLauncher: project_name=$project_name, project=$project"

  if {[file exists [Hog::LoggerLib::GetUserFilePath "HogEnv.conf"]]} {
    Msg Debug "HogEnv.conf found"
    set loggerdict [Hog::LoggerLib::ParseTOML [Hog::LoggerLib::GetUserFilePath "HogEnv.conf"]]
    set HogEnvDict [Hog::LoggerLib::GetTOMLDict]
    Hog::LoggerLib::PrintTOMLDict $HogEnvDict
  }

  # help: render help for whatever was resolved, then exit.
  if {"--help" in $options || "-help" in $options || "-h" in $options || "-?" in $options} {
    Help::RenderPath $full_cmd
    exit 0
  }
  set result [Commands::RunCommand $cmd $full_cmd $project $options]
  if {$result eq "ran"} { return }

  lassign $result _ ide
  Launcher::Set ide       $ide
  if {[Tools::Launch $ide] ne "no_ide"} {
    return
  }

} 

################################################################################
## Tool Pass
################################################################################

if {[ActiveTool::CurrentTool] ne "tclsh"} {

  set DataStore::inIDE 1

  if {$cmd eq "" || ![Commands::IsExecutable $cmd]} {
    Msg Error "Nothing to run in tool pass for '[join $full_cmd { }]'."
    exit 1
  }

  set ide  [tdict getval $cmd ide]
  set tool [Tools::ResolveAlias $ide]
  Launcher::Set ide   $tool
  CurrentProject::Set ide $tool

  set opt_specs [list]
  tlist foreach o [tdict get $cmd options] { lappend opt_specs [tobj value $o] }
  if {[catch {array set parsed_opts [cmdline::getoptions options $opt_specs ""]} err]} {
    Msg Error "Option error for '[join $full_cmd { }]': $err"
    exit 1
  }
  set opts_tdict [tdict create]
  foreach k [array names parsed_opts] { tdict set opts_tdict $k [tinf $parsed_opts($k)] }
  Launcher::Set options   $opts_tdict
  Launcher::Set directive $directive

  if {[catch {
    ActiveTool::Initialize
    if {[Commands::IsFlow $cmd]} {
      Flow::Run [tobj value [tdict get $cmd flow_ref]]
    } else {
      Commands::RunNode $cmd
    }
  } run_err run_opts]} {
    Msg Error "Failed to run '[join $full_cmd { }]': $run_err"
  }
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
