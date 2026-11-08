namespace eval Hog {
  variable _loading_custom 0
  variable _loading_source ""
  variable _initialized
  if {![info exists _initialized]} { set _initialized 0 }

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
  # Lets one tool run another tool's command/flow
  proc Do {args} {
    set _wrapper [file join [Repo::Get repo_path] Hog Do]

    set ::env(HOG_LOGO_PRINTED) 1
    Msg Info "Running sub process: $args"
    set _code [catch {exec -ignorestderr $_wrapper {*}$args >@ stdout 2>@ stderr} _res _opts]
    if {$_code} {
      set _exit 1
      if {[dict exists $_opts -errorcode]} {
        set _ec [dict get $_opts -errorcode]
        if {[lindex $_ec 0] eq "CHILDSTATUS" && [llength $_ec] >= 3} {
          set _exit [lindex $_ec 2]
        }
      }
      return -code error -errorcode [list HOG_SPAWN_FAILED $_exit] \
        "Hog::Spawn $args failed (exit $_exit): $_res"
    }
    return $_res
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
  source [file join $tcl_path core tobj tobj.tcl]
  source [file join $tcl_path core hogstruct.tcl]
  source [file join $tcl_path core datastore.tcl]
  source [file join $tcl_path create_project.tcl]
  source [file join $tcl_path core hogfile.tcl]
  source [file join $tcl_path core listfile.tcl]
  source [file join $tcl_path core project.tcl]
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

  # Maybe move these to their own files?
  HogStruct::Define HogLauncher {
    field String name
    field String version
    field String launch_time
    field String script
    field String git_ver
    field String hog_tag
    field String directive
    field String cmd
    field List   full_cmd
    field List   args
    field String project
    field String project_name
    field Dict   options
    field String ide
  }


  HogStruct::Define HogRepo {
    field String git_tag
    field String repo_path
    field String tcl_path
    field String top_path
    field String config_path
    field Dict   config
    field String projects_dir
    field Dict   projects
  }

  proc ::HogRepo::LoadProjects {selfVar} {
    upvar 1 $selfVar self
    set projects [tdict create]
    set top [Get $self top_path]
    foreach conf [lsort [findFiles $top hog.conf]] {
      set name [Relative $top [file dirname $conf]]
      set project [HogProject::Create -project_name $name -repo_path [Get $self repo_path]]
      HogProject::LoadConfig project
      tdict set projects $name $project
    }
    Set self projects $projects
  }

  DataStore::Create HogLauncher Launcher
  DataStore::Create HogRepo     Repo
  DataStore::Create HogProject  CurrentProject

  Launcher::Set name "Experimental"
  Launcher::Set version "0.1.0"
  Launcher::Set launch_time [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]
  Launcher::Set script [file normalize [info script]]
  Launcher::Set git_ver    [lindex [Git --version] 2]
  Launcher::Set hog_tag [Git {describe --tags --always}]

  set _old_dir [pwd]
  cd $repo_path
  Repo::Set git_tag [Git {describe --tags --always}]
  cd $_old_dir

  Repo::Set repo_path             $repo_path
  Repo::Set tcl_path              $tcl_path
  Repo::Set top_path              $top_path
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
  set repository [Repo]
  HogRepo::LoadProjects repository
  Repo::Load $repository

  ################################################################################
  ## Lint
  ################################################################################
  Commands::Lint
}
