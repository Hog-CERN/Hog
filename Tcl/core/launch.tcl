
#if {[catch {
################################################################################
## Set up hog environment
################################################################################
set tcl_path  [file normalize [file join [file dirname [info script]] ..]]
set repo_path [file normalize [file join $tcl_path .. ..]]
set top_path [file join $repo_path Top]

source [file join $tcl_path hog.tcl]
source [file join $tcl_path create_project.tcl]
source [file join $tcl_path core tobj.tcl]
source [file join $tcl_path core context.tcl]
source [file join $tcl_path core commands.tcl]
source [file join $tcl_path core tools.tcl]
source [file join $tcl_path core flow.tcl]


Logo $repo_path
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

  Context::Set launcher Name "Experimental"
  Context::Set launcher Version "0.1.0"
  Context::Set launcher time [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]
  Context::Set launcher script [file normalize [info script]]

  Context::Set launcher settings tcl_path     $tcl_path
  Context::Set launcher settings repo_path    $repo_path
  Context::Set launcher settings project      $project
  Context::Set launcher settings project_name $project_name
  Context::Set launcher settings group_name   $project_group
  Context::Set launcher settings top_path     $top_path

  Context::Set settings repo_path    $repo_path
  Context::Set settings design       $project_name
  Context::Set settings project_name $project_name
  Context::Set settings project      $project
  Context::Set settings group_name   [file dirname $DESIGN]

  Context::Set settings user_ip_repo ""
  Context::Set settings pre_synth_file           "pre-synthesis.tcl"
  Context::Set settings post_synth_file          "post-synthesis.tcl"
  Context::Set settings pre_impl_file            "pre-implementation.tcl"
  Context::Set settings post_impl_file           "post-implementation.tcl"
  Context::Set settings pre_bit_file             "pre-bitstream.tcl"
  Context::Set settings post_bit_file            "post-bitstream.tcl"
  Context::Set settings quartus_post_module_file "quartus-post-module.tcl"
  Context::Set settings pre_synth                [file normalize "${tcl_path}/integrated/[Context::Get settings pre_synth_file]"]
  Context::Set settings post_synth               [file normalize "${tcl_path}/integrated/[Context::Get settings post_synth_file]"]
  Context::Set settings pre_impl                 [file normalize "${tcl_path}/integrated/[Context::Get settings pre_impl_file]"]
  Context::Set settings post_impl                [file normalize "${tcl_path}/integrated/[Context::Get settings post_impl_file]"]
  Context::Set settings pre_bit                  [file normalize "${tcl_path}/integrated/[Context::Get settings pre_bit_file]"]
  Context::Set settings post_bit                 [file normalize "${tcl_path}/integrated/[Context::Get settings post_bit_file]"]
  Context::Set settings quartus_post_module      [file normalize "${tcl_path}/integrated/[Context::Get settings quartus_post_module_file]"]


  Context::Set settings DESIGN [file tail ${DESIGN}]
  Context::Set settings top_path "${repo_path}/Top/${DESIGN}"
  Context::Set settings list_path "${repo_path}/Top/${DESIGN}/list"
  Context::Set settings build_dir "${repo_path}/Projects/${DESIGN}"
  Context::Set settings top_name [file rootname [file tail $DESIGN]]
  Context::Set settings synth_top_module "top_[Context::Get settings top_name]"
  Context::Set settings user_ip_repo ""


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
    Context::SetObj launcher options $_opts_tdict
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





  Context::Set launcher settings ide $tool
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
    Context::SetObj launcher options $_opts_tdict
    Context::Set launcher settings directive $directive

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
    Flow::Run [Context::Get launcher settings directive]
  } _tool_err _tool_opts]} {
    # This catches errors inside the tool, otherwise we would only catch errors about launching the tool
    # this doesn't catch Msg Error errors tho...

    puts "Error: $_tool_err"
    Context::Set ERROR MESSAGE  "Failed to run tool '[ActiveTool::CurrentTool]': $_tool_err"
    Context::Set ERROR TRACE    [dict get $_tool_opts -errorinfo]
    Context::Set ERROR CODE     [dict get $_tool_opts -errorcode]
    Context::SaveJsonToFile [file join [Context::Get launcher settings repo_path] hog_[ActiveTool::CurrentTool]_error.json] 1
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
