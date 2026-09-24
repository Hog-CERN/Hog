namespace eval Hog {
  variable _loading_custom 0
  variable _loading_source ""
  variable _initialized 0

  variable _tcl_path [file normalize [file join [file dirname [info script]] ..]]

  # set context, source in the global namespace, reset context.
  # label, if given, is folded into the warning on failure for extra
  # info a generic message can't have (e.g. which tool directory a file belongs to).
  proc SourceFile {file is_custom {label ""}} {
    variable _loading_custom
    variable _loading_source
    set _loading_custom $is_custom
    set _loading_source $file
    if {[catch {namespace eval :: [list source $file]} err]} {
      set _for [expr {$label ne "" ? " for $label" : ""}]
      Msg Warning "failed to source [file tail $file]$_for: $err"
    }
    set _loading_custom 0
    set _loading_source ""
  }

  # Entry point to run a command/flow internally
  # mirrors how one would run it from the cmdline:
  # 'Hog::Do vivado create -option example' == './Hog/Do vivado create -option example'
  # Lets one tool run another tool's command/flow (booting into the tool's IDE when required). 
  # Inherits the caller's project context;
  # snapshots/restores Launcher state so a nested call can't corrupt the outer.
  proc Do {args} {
    set _saved_argv $::argv
    set _keys {directive cmd full_cmd args project project_name options ide}
    set _snap [dict create]
    foreach _k $_keys { dict set _snap $_k [Launcher::GetOr $_k ""] }

    set ::argv $args
    set _code [catch {Commands::RunRequest [Commands::Resolve $args]} _res _opts]

    set ::argv $_saved_argv
    foreach _k $_keys { Launcher::Set $_k [dict get $_snap $_k] }
    return -options $_opts $_res
  }
}

# Loads every core module, discovers tools/commands/flows
# Populates the Repo/Launcher/CurrentProject DataStores.
# Allows resourcing without wiping live state
proc InitHog {} {
  if {$::Hog::_initialized} { return }
  set ::Hog::_initialized 1

  set tcl_path  $::Hog::_tcl_path
  set repo_path [file normalize [file join $tcl_path .. ..]]
  set top_path  [file join $repo_path Top]

  source [file join $tcl_path hog.tcl]
  source [file join $tcl_path core datastore.tcl]
  source [file join $tcl_path create_project.tcl]
  source [file join $tcl_path core listfile.tcl]
  source [file join $tcl_path core project.tcl]
  source [file join $tcl_path core tobj.tcl]
  source [file join $tcl_path core commands.tcl]
  source [file join $tcl_path core tools.tcl]
  source [file join $tcl_path core flow.tcl]

  if {[catch {package require cmdline} ERROR]} {
    Msg Debug "The cmdline Tcl package was not found, sourcing it from Hog..."
    source $tcl_path/utils/cmdline.tcl
  }

  ################################################################################
  ## Tool Discovery
  ################################################################################
  Tools::RegisterFromDir [file join $tcl_path tools]
  Tools::RegisterFromDir [file join $repo_path hog-tools] -custom
  Tools::Init

  ################################################################################
  ## Flows
  ################################################################################
  # Custom flows load after tools, so their parent tool groups already exist.
  Flow::RegisterCustomFlows $repo_path/hog-flows

  ################################################################################
  ## Command Registration
  ################################################################################
  Commands::RegisterCommandsDir [file join $tcl_path  commands]
  Commands::RegisterCommandsDir [file join $repo_path hog-commands] -custom

  ################################################################################
  ## DataStores
  ################################################################################
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
  Launcher::Set Git    [lindex [Git --version] 2]
  Launcher::Set HogTag [Git {describe --tags --always}]

  set _old_dir [pwd]
  cd $repo_path
  Repo::Set Tag [Git {describe --tags --always}]
  cd $_old_dir

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
  Repo::Set config_path           [file normalize [file join $top_path repo.conf]]
  Repo::Set config                [tdict create]
  if {[file exists [Repo::Get config_path]]} {
    set PROPERTIES [ReadConf [Repo::Get config_path]]
    dict for {section content} $PROPERTIES {
      Repo::Set config $section [tdict create]
      dict for {key val} $content {
        Msg Debug "Setting property $key to $val for section $section"
        Repo::Set config $section $key $val
      }
    }
  }

  Repo::Set projects_dir [file join $repo_path Projects]
  Repo::Set projects [Projects::GetAll $repo_path]

  ################################################################################
  ## Lint
  ################################################################################
  Commands::Lint
}
