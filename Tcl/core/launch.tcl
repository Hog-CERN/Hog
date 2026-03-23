
<<<<<<< HEAD
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
Launcher::Set HogTag [Git describe]
Launcher::Set directive $directive
Launcher::Set cmd          $cmd
Launcher::Set full_cmd     $full_cmd
Launcher::Set project      $project
Launcher::Set project_name $project_name
Launcher::Set options      $options

set _old_dir [pwd]
cd $repo_path
Repo::Set Tag [Git describe]
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
  Tools::Launch $ide
  return

} else {

################################################################################
## Tool Pass
################################################################################

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
||||||| parent of 58a89ed3 (added initial modular tool flow)
=======
################################################################################
## Set up hog environment
################################################################################
set tcl_path  [file normalize [file join [file dirname [info script]] ..]]
set repo_path [file normalize [file join $tcl_path .. ..]]

source [file join $tcl_path core context.tcl]
source [file join $tcl_path core tools.tcl]
source [file join $tcl_path hog.tcl]


################################################################################
## Tool Discovery
################################################################################
set _builtin_tools_dir [file normalize [file join $tcl_path tools]]
set _user_tools_dir    [file normalize [file join $repo_path hog-tools]]


################################################################################
## Command Registration
################################################################################
set default_commands {

  \^L(IST)?$ {
    Msg Status "\n** The projects in this repository are:"
    ListProjects $repo_path $list_all
    Msg Status "\n"
    exit 0
  # NAME*: LIST or L
  # DESCRIPTION: List the projects in the repository. To show hidden projects use the -all option
  # OPTIONS: all, verbose
  }

  \^H(ELP)?$ {
    puts "$usage"
    exit 0
  # NAME: HELP or H
  # DESCRIPTION: Display this help message or specific help for each directive
  # OPTIONS:
  }

  \^(CHECKCI|CIE)?$ {
    set do_check_ci_env 1
    # NAME: CHECKCIENV or CIE
    # DESCRIPTION: Check that the common environment variables needed for Hog-CI are set
    # OPTIONS: verbose
  }

  \^(CHECKPROJENV|CPE)?$ {#
    set do_checkproj_env 1
  # NAME: CHECKPROJENV or CPE
  # DESCRIPTION: Check that the environment variables needed for Hog-CI to run the chosen project are set and point to valid paths
  # OPTIONS: verbose
  }

  \^(CHECKPROJVER|CPV)?$ {#
    set do_checkproj_ver 1
  # NAME: CHECKPROJVER or CPV
  # DESCRIPTION: Check the project version just before creating the HDL project in Create_Project stage. \
  The CI job will SKIP the project pipeline, if it the project has not been modified with respect to the target branch.
  # OPTIONS: ext_path.arg, simcheck, verbose
  }

  \^C(REATE)?$ {#
    set do_create 1
    set recreate 1
  # NAME*: CREATE or C
  # DESCRIPTION: Create the project, replace it if already existing.
  # OPTIONS: ext_path.arg, lib.arg, vivado_only, verbose
  }

  \^I(MPL(EMENT(ATION)?)?)?$ {#
    set do_implementation 1
    set do_bitstream 1
    set do_compile 1
  # NAME: IMPLEMENTATION or I
  # DESCRIPTION: Runs only the implementation, the project must already exist and be synthesised.
  # OPTIONS: check_syntax, ext_path.arg, njobs.arg, no_bitstream, no_reset, recreate, verbose
  }

  \^SYNT(H(ESIS(E)?)?)? {#
    set do_synthesis 1
    set do_compile 1
  # NAME: SYNTH
  # DESCRIPTION: Run synthesis only, create the project if not existing.
  # OPTIONS: check_syntax, ext_path.arg, njobs.arg, recreate, verbose
  }

  \^S(IM(ULAT(ION|E)?)?)?$ {#
    set do_simulation 1
    set do_create 1
  # NAME*: SIMULATION or S
  # DESCRIPTION: Simulate the project, creating it if not existing, unless it is a GHDL simulation.
  # OPTIONS: check_syntax, compile_only, ext_path.arg, lib.arg, recreate, scripts_only, simset.arg, verbose
  }

  \^W(ORK(FLOW)?)?$ {#
    set do_implementation 1
    set do_synthesis 1
    set do_bitstream 1
    set do_compile 1
    set do_vitis_build 0
  # NAME*: WORKFLOW or W
  # DESCRIPTION: Runs the full workflow, creates the project if not existing.
  # OPTIONS: bitstream_only, check_syntax, ext_path.arg, impl_only, njobs.arg, no_bitstream, recreate, synth_only, verbose, vitis_only, xsa.arg
  }

  \^(CREATEWORKFLOW|CW)?$ {#
    set do_implementation 1
    set do_synthesis 1
    set do_bitstream 1
    set do_compile 1
    set recreate 1
    set do_vitis_build 0
  # NAME: CREATEWORKFLOW or CW
  # DESCRIPTION: Creates the project -even if existing- and launches the complete workflow.
  # OPTIONS: check_syntax, ext_path.arg, njobs.arg, no_bitstream, synth_only, verbose, vivado_only, vitis_only, xsa.arg
  }

  \^(CHECKSYNTAX|CS)?$ {#proj
    set do_check_syntax 1
  # NAME: CHECKSYNTAX or CS
  # DESCRIPTION: Check the syntax of the project. Only for Vivado, Quartus and Libero projects.
  # OPTIONS: ext_path.arg, recreate, verbose
  }

  ^(IPB(US)?)|(X(ML)?)$ {#proj
    set do_ipbus_xml 1
  # NAME: IPBUS or IPB
  # DESCRIPTION: Copy, check or create the IPbus XMLs for the project.
  # OPTIONS: dst_dir.arg, generate, verbose
  }

  \^V(IEW)?$ {#proj
    set do_list_file_parse 1
  # NAME*: VIEW or V
  # DESCRIPTION: Print Hog list file contents in a tree-like fashon.
  # OPTIONS: verbose
  }

  \^(CHECKYAML|YML)?$ {
    set min_n_of_args -1
    set max_n_of_args 1
    set do_check_yaml_ref 1
  # NAME: CHECKYML or YML
  # DESCRIPTION: Check that the ref to Hog repository in the .gitlab-ci.yml file, matches the one in Hog submodule.
  # OPTIONS: verbose
  }

  \^B(UTTONS)?$ {
    set min_n_of_args -1
    set max_n_of_args 1
    set do_buttons 1
  # NAME: BUTTONS or B
  # DESCRIPTION: Add Hog buttons to the Vivado GUI, to check and recreate Hog list and configuration files.
  # OPTIONS: verbose
  }

  \^(CHECKLIST|CL)?$ {#proj
    set do_check_list_files 1
  # NAME: CHECKLIST or CL
  # DESCRIPTION: Check that list and configuration files on disk match what is on the project.
  # OPTIONS: ext_path.arg, verbose
  }

  \^COMPSIM(LIB)?$ {
    set do_compile_lib 1
    set argument_is_no_project 1
  # NAME: COMPSIMLIB or COMPSIM
  # DESCRIPTION: Compiles the simulation library for the chosen simulator with Vivado.
  # OPTIONS: dst_dir.arg, verbose
  }

  \^RTL(ANALYSIS)?$ {#
    set do_rtl 1
  # NAME: RTL or RTLANALYSIS
  # DESCRIPTION: Elaborate the RTL analysis report for the chosen project.
  # OPTIONS: check_syntax, recreate, verbose
  }

  \^SIG(ASI)?$ {#
    set do_sigasi 1
  # NAME: SIGASI or SIG
  # DESCRIPTION: Create a .csv file to be used in Sigasi.
  # OPTIONS: verbose
  }

  \^T(REE)?$ {#
    set do_hierarchy 1
  # NAME: TREE or T
  # DESCRIPTION: Print the design hierarchy for the chosen project.
  # OPTIONS: compile_order, ext_path.arg, ignore.arg, include_gen_prods, include_ieee, light, output.arg, top.arg, verbose
  }

  default {
    if {$directive != ""} {
      set NO_DIRECTIVE_FOUND 1
    } else {
      puts "$usage"
      exit 0
    }
  }
}

# Add this bit above!
#  \^NEW_DIRECTIVE?$ {
#    set do_new_directive 1
#  }


#parsing command options
set parameters {
  {no_bitstream    "If set, the bitstream file will not be produced."}
  {recreate        "If set, the project will be re-created if it already exists."}
  {no_reset        "If set, runs (synthesis and implementation) won't be reset before launching them."}
  {check_syntax    "If set, the HDL syntax will be checked at the beginning of the workflow."}
  {njobs.arg 4     "Number of jobs. Default: 4"}
  {ext_path.arg "" "Sets the absolute path for the external libraries."}
  {lib.arg      "" "Simulation library path, compiled or to be compiled"}
  {synth_only      "If set, only the synthesis will be performed."}
  {impl_only       "If set, only the implementation will be performed. This assumes synthesis was already done."}
  {scripts_only    "If set, the simulation scripts will be generated, but the simulation will not be run."}
  {compile_only    "If set, the simulation libraries will be compiled, but not run."}
  {bitstream_only  "If set, only the bitstream will be produced. This assumes implementation was already done. For a Vivado-Vitis\
                    project this command can be used to generate the boot artifacts including the ELF file(s) without running the\
                    full Vivado workflow."}
  {vivado_only     "If set, and project is vivado-vitis, vitis project will not be created."}
  {vitis_only      "If set, and project is vivado-vitis create only vitis project. If an xsa is not given, a pre-synth xsa will be created."}
  {xsa.arg      "" "If set, and project is vivado-vitis, use this xsa for creating platforms without a defined hw."}
  {simset.arg   "" "Simulation sets, separated by commas, to be run."}
  {all             "List all projects, including test projects. Test projects have #test on the second line of hog.conf."}
  {generate        "For IPbus XMLs, it will re create the VHDL address decode files."}
  {dst_dir.arg  "" "For reports, IPbus XMLs, set the destination folder (default is in the ./bin folder)."}
  {output.arg   "" "For tree hierarchy mode, set the output file (default is console)."}
  {top.arg      "" "For tree hierarchy mode, set the top module (default is the top module defined in hog.conf)."}
  {ignore.arg   "" "For tree hierarchy mode, filter's the printed hierarchy to exclude modules that match the given string."}
  {include_ieee "" "For tree hierarchy mode, include IEEE/STD libraries in the printed hierarchy. (Default 0)"}
  {include_gen_prods "" "For tree hierarchy mode, include IP generated products in the printed hierarchy. (Default 0)"}
  {compile_order "" "For tree hierarchy mode, prints compile order instead of hierarchy."}
  {verbose          "If set, launch the script in verbose mode"}
  {light            "For tree hierarchy mode, print a light version of the hierarchy (without file paths)."}
  {simcheck         "If set, checks also the version of the simulation files."}
}

Tools::Init "$_builtin_tools_dir $_user_tools_dir"

################################################################################
## TCLSH Pass
################################################################################
if {[ActiveTool::CurrentTool] == "tlcsh"} {

  Context::Set launcher Name "Experimental" 
  Context::Set launcher Version "0.1.0"
  Context::Set launch_script [file normalize [info script]]
  Context::Set tcl_path $tcl_path
  Context::Set repo_path $repo_path

  puts "========================================="
  puts "Launcher: [Context::Get launcher Name]"
  puts " Version: [Context::Get launcher Version]"
  puts "========================================="
  puts "tcl_path: [Context::Get tcl_path]"
  puts "repo_path: [Context::Get repo_path]"


  ### CUSTOM COMMANDS ###
  set commands_path [file normalize "$tcl_path/../../hog-commands/"]
  set custom_commands [GetCustomCommands $parameters $commands_path ]

  lassign [InitLauncher $::argv0 $tcl_path $parameters $default_commands $argv $custom_commands] \
  directive project project_name group_name repo_path old_path bin_dir top_path usage short_usage cmd ide list_of_options

  Context::Set LaunchSettings directive $directive
  Context::Set LaunchSettings project $project
  Context::Set LaunchSettings project_name $project_name
  Context::Set LaunchSettings group_name $group_name
  Context::Set LaunchSettings repo_path $repo_path
  Context::Set LaunchSettings old_path $old_path
  Context::Set LaunchSettings bin_dir $bin_dir
  Context::Set LaunchSettings top_path $top_path
  #Context::Set LaunchSettings usage $usage
  #Context::Set LaunchSettings short_usage $short_usage
  Context::Set LaunchSettings cmd $cmd
  Context::Set LaunchSettings ide $ide
  Context::Set LaunchSettings list_of_options $list_of_options


  Msg Debug "========================================="
  Msg Debug "Launch Settings:"
  dict for {key value} [Context::Get LaunchSettings] {
    Msg Debug "  $key: $value"
  }
  Msg Debug "========================================="


  



  Tools::PrintTools


  Tools::Launch [Context::Get LaunchSettings ide]
  return
}

################################################################################
## Tool Pass
################################################################################

ActiveTool::Initialize {*}$::argv

# maybe we can build a list of steps based off options, then loop through them...
#
# tools could also advertise different flows they support, for example 
# vivado has a synthesis flow and a simulation flow
#
# DEFAULT_WORKFLOW {CreateProject Synthesize Implement GenerateBitstream}
# SIMULATE {CreateProject Simulate}
#
# -no_bitstream would just remove GenerateBitstream from the WORKFLOW flow, and 
# -synth_only would remove Implement and GenerateBitstream, etc.
#
#
# users could then add/remove steps from flows and create custom flows,
# 
# maybe we look for a set of default flows that map to current supported hog flows:
#   CREATE, SYNTH, IMPL, WORKFLOW, CREATEWORKFLOW, SIMULATE, etc
# and execute these flows based off current Hog/Do <flow> command, 
#
# custom flows would then be execute with 
# ./Hog/Do FLOW <custom_flow_name>
#
# Defined in a tools Manifest: 
# Flows {
#   @CREATE         {CreateProject}
#   @SYNTH          {@CREATE  Synthesize}
#   @IMPL           {@SYNTH   Implement}
#   @WORKFLOW       {@IMPL    GenerateBitstream}
#
#   -- CUSTOMFLOW EXANPLE:
#   @GEN_IP_FILES   {@CREATE  DoSomething GenIpFiles}
# }
#
# each flow is defined by @<FLOW>
# each step in the flow points to a proc defined in <tool>.tcl
# a flow can depend on other flows by including them with @<FLOW> syntax
#
# can probably dynamically define -no_<step> options for each step in flow
# i.e. user could provide ./Hog/Do FLOW GEN_IP_FILES -no_DoSomething to skip that step 
#

set flow [list  ActiveTool::CreateProject ActiveTool::Synthesize ActiveTool::Implement]

foreach step $flow {
  if {[catch {set result [eval $step]} err]} {
    Msg Error "Error during $step: $err"
    exit 1
  } else {
    Msg Info "$step completed successfully: $result"
  }
}




>>>>>>> 58a89ed3 (added initial modular tool flow)
