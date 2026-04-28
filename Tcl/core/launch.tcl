
#if {[catch {
################################################################################
## Set up hog environment
################################################################################
set tcl_path  [file normalize [file join [file dirname [info script]] ..]]
set repo_path [file normalize [file join $tcl_path .. ..]]
set top_path [file join $repo_path Top]

source [file join $tcl_path hog.tcl]
source [file join $tcl_path core context.tcl]
source [file join $tcl_path create_project.tcl]
source [file join $tcl_path core hog.tcl]
source [file join $tcl_path core tobj.tcl]
source [file join $tcl_path core commands.tcl]
source [file join $tcl_path core tools.tcl]
source [file join $tcl_path core flow.tcl]


################################################################################
## Tool Discovery
################################################################################
Tools::RegisterFromDir [file join $tcl_path tools]
Tools::RegisterFromDir [file join $repo_path hog-tools]
Tools::Init


################################################################################
## Flows
################################################################################
Flow::RegisterCustomFlows $repo_path/hog-flows
ActiveTool::Refresh


################################################################################
## Command Registration
################################################################################
Commands::RegisterCommandsDir [file join $tcl_path  commands]
Commands::RegisterCommandsDir [file join $repo_path hog-commands]



################################################################################
## TCLSH Pass
################################################################################
Msg Debug  "[ActiveTool::CurrentTool] launched with arguments: $::argv"

if {[ActiveTool::CurrentTool] eq "tclsh"} {
  Logo $repo_path

  if {[catch {package require cmdline} ERROR]} {
    Msg Debug "The cmdline Tcl package was not found, sourcing it from Hog..."
    source $tcl_path/utils/cmdline.tcl
  }


  # argv layout: directive [project] [options...]
  # if argv[1] starts with '-' it is an option
  set directive [string toupper [lindex $::argv 0]]
  set _arg1     [lindex $::argv 1]
  if {$_arg1 ne "" && ![string match "-*" $_arg1]} {
    set project  $_arg1
    set _options [lrange $::argv 2 end]
  } else {
    set project  ""
    set _options [lrange $::argv 1 end]
  }

  if {$directive eq ""} {
    Msg Error "No directive given. Run './Hog/Do HELP' for usage."
    exit 1
  }

  if {$directive ne "HELP" && $project ne ""} {
    regsub "^(\./)?Top/" $project "" project
    # Remove trailing / and spaces if in project_name
    regsub "/? *\$" $project "" project
    #set proj_conf [ProjectExists $project $repo_path]
  }

  set project_group [file dirname $project]
  set project_name $project
  set project [file tail $project]
  set DESIGN $project_name
  Msg Debug "InitLauncher: project_group=$project_group, project_name=$project_name, project=$project"

  DataStore::create Repo
  DataStore::create Launcher
  DataStore::create HogProject


  Launcher::Set Name "Experimental"
  Launcher::Set Version "0.1.0"
  Launcher::Set time [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]
  Launcher::Set script [file normalize [info script]]
  Launcher::Set Git  [lindex [Git --version] 2]
  Launcher::Set HogTag [Git describe]

  
  set old_dir [pwd]
  cd $repo_path
  Repo::Set Tag [Git describe]
  cd $old_dir

  Repo::Set repo_path    $repo_path
  Repo::Set tcl_path     $tcl_path
  Repo::Set top_path     $top_path
  Repo::Set  pre_synth                [file normalize "${tcl_path}/integrated/pre-synthesis.tcl"]
  Repo::Set  post_synth               [file normalize "${tcl_path}/integrated/post-synthesis.tcl"]
  Repo::Set  pre_impl                 [file normalize "${tcl_path}/integrated/pre-implementation.tcl"]
  Repo::Set  post_impl                [file normalize "${tcl_path}/integrated/post-implementation.tcl"]
  Repo::Set  pre_bit                  [file normalize "${tcl_path}/integrated/pre-bitstream.tcl"]
  Repo::Set  post_bit                 [file normalize "${tcl_path}/integrated/post-bitstream.tcl"]
  Repo::Set  quartus_post_module      [file normalize "${tcl_path}/integrated/quartus-post-module.tcl"]

  Repo::Set projects_dir [file join $repo_path Projects]
  Repo::SetObj projects  [tdict create]
  dict for {proj conf} [GetProjectsConf $repo_path] {
    if {[file exists $conf]} {
      set PROPERTIES [ReadConf $conf]
      Repo::Set projects $proj conf_file $conf
      Repo::Set projects $proj tool [Tools::GetToolForProject $proj $top_path]
      dict for {section content} $PROPERTIES {
        dict for {p v} $content {
          Msg Debug "Setting property $p to $v for section $section"
          Repo::Set projects $proj $section $p $v
        }
      }
    }
  }

  HogProject::Set design       $project_name
  HogProject::Set project_name $project_name
  HogProject::Set project      $project
  HogProject::Set group_name   [file dirname $DESIGN]


  HogProject::Set list_path    [file join $repo_path Top $DESIGN list]
  HogProject::Set build_dir    [file join $repo_path Projects $DESIGN]


  HogProject::Set DESIGN [file tail ${DESIGN}]
  HogProject::Set top_name [file rootname [file tail $DESIGN]]
  HogProject::Set synth_top_module "top_[HogProject::Get top_name]"


  # Check if HogEnv.conf exists and parse it
  if {[file exists [Hog::LoggerLib::GetUserFilePath "HogEnv.conf"]] } {
    Msg Debug "HogEnv.conf found"
    set loggerdict [Hog::LoggerLib::ParseTOML [Hog::LoggerLib::GetUserFilePath "HogEnv.conf" ]]
    set HogEnvDict [Hog::LoggerLib::GetTOMLDict]
    Hog::LoggerLib::PrintTOMLDict $HogEnvDict
  }

  if {[Commands::AliasExists $directive] || [Flow::AliasExists $directive]} {
    if {"--help" in $_options || "-help" in $_options || "-h" in $_options || "-?" in $_options} {
      set ::argv [list HELP $directive]
      Commands::Run HELP
    }
  }


  if {[Commands::AliasExists $directive]} {
    set cmd [Commands::GetCommand $directive]
    if {[tdict getval $cmd requires_proj] && $project eq ""} {
      Msg Error "Directive '$directive' requires a project. Run './Hog/Do HELP' for usage."
      exit 1
    }

    set cmd_opts [Commands::GetCommandOptions $directive]
    if {[catch {array set _parsed [cmdline::getoptions _options $cmd_opts ""]} err]} {
      Msg Error "Option error for '$directive': $err"
      exit 1
    }
    set _opts_tdict [tdict create]
    foreach k [array names _parsed] {
      tdict set _opts_tdict $k [tinf $_parsed($k)]
    }
    Launcher::SetObj options $_opts_tdict
    Commands::Run $directive
    return
  }


  if {$project eq ""} {
    Msg Error "No project given. Run './Hog/Do HELP' for usage."
    exit 1
  }

  set tool [Tools::GetToolForProject $project $top_path]
  if {$tool eq ""} {
    exit 1
  }

  ################################################################################
  # Project Flows and Commands
  ################################################################################
  Launcher::Set ide $tool
  HogProject::Set ide $tool
  if {[Flow::AliasExistsForTool $directive $tool]} {
    set flow_opts [Flow::GetFlowOptions $tool $directive]
    if {[catch {array set _parsed [cmdline::getoptions _options $flow_opts ""]} err]} {
      Msg Error "Option error for '$directive': $err"
      exit 1
    }
    set _opts_tdict [tdict create]
    foreach k [array names _parsed] {
      tdict set _opts_tdict $k [tinf $_parsed($k)]
    }
    Launcher::SetObj options $_opts_tdict
    Launcher::Set directive $directive

    Tools::Launch $tool
    return
  }

  Msg Error "Unknown directive '$directive' for tool '[namespace tail $tool]'."
  exit 1
} else {

################################################################################
## Tool Pass
################################################################################

  if {[catch {
    ActiveTool::Initialize {*}$::argv
    Flow::Run [Launcher::Get directive]
  } _tool_err _tool_opts]} {
    # This catches errors inside the tool, otherwise we would only catch errors about launching the tool
    # this doesn't catch Msg Error errors tho...

    puts "Error: $_tool_err"
    #Launcher::Set ERROR MESSAGE  "Failed to run tool '[ActiveTool::CurrentTool]': $_tool_err"
    #Launcher::Set ERROR TRACE    [dict get $_tool_opts -errorinfo]
    #Launcher::Set ERROR CODE     [dict get $_tool_opts -errorcode]
    #Launcher::SaveJsonToFile [file join [Launcher::Get repo_path] hog_[ActiveTool::CurrentTool]_error.json] 1
    Msg Error "Failed to run tool '[ActiveTool::CurrentTool]': $_tool_err"
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
