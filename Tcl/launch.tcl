#!/usr/bin/env tclsh
# @file
#   Copyright 2018-2025 The University of Birmingham
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


# Launch Xilinx Vivado or ISE implementation and possibly write bitstream in text mode

#parsing command options
set parameters {
  {no_bitstream    "If set, the bitstream file will not be produced."}
  {recreate        "If set, the project will be re-created if it already exists."}
  {no_reset        "If set, runs (synthesis and implementation) won't be reset before launching them."}
  {check_syntax    "If set, the HDL syntax will be checked at the beginning of the workflow."}
  {njobs.arg 4     "Number of jobs. Default: 4"}
  {ext_path.arg "" "Sets the absolute path for the external libraries."}
  {lib.arg  "" "Compiled simulation library path"}
  {synth_only      "If set, only the synthesis will be performed."}
  {impl_only       "If set, only the implementation will be performed. This assumes synthesis should was already done."}
  {simset.arg  ""   "Simulation sets, separated by commas, to be run."}
  {all             "List all projects, including test projects. Test projects have #test on the second line of hog.conf."}
  {generate        "For IPbus XMLs, it willk re create the VHDL address decode files."}
  {xml_dir.arg "" "For IPbus XMLs, set the destination folder (default is ../<project_name>_xml)."}
  {verbose         "If set, launch the script in verbose mode"}
}

set usage " \[OPTIONS\] <directive> <project>\n The most common <directive> values are CREATE (or C), WORKFLOW (or W), SIMULATE (or S).

** Directives (case insensitive):
- CREATE or C: Create the project, replacing it if already existing.
- WORKFLOW or W: Launches the complete workflow, creates the project if not existing.
- CREATEWORKFLOW or CW: Creates the project -even if existing- and launches the complete workflow.
- SIMULATE or S: Simulate the project, creating it if not existing.
- IMPLEMENT: Runs the implementation only, the project must already exist and be synthesised.
- SYNTHESIS: Runs the synthesis only, creates the project if not existing.
- LIST or L: Only list all the projects.
- VIEW or V: Show name of list files, the source files in each and their Hog properties, if any.
- XML or X: Copy, check or create IPbus XMLs.
"

set tcl_path [file normalize "[file dirname [info script]]"]
source $tcl_path/hog.tcl
source $tcl_path/create_project.tcl
# Quartus needs extra packages and treats the argv in a different way
if {[IsQuartus]} {
  load_package report
  set argv $quartus(args)
}

Msg Debug "s: $::argv0 a: $argv"

lassign [InitLauncher $::argv0 $tcl_path $parameters $usage $argv] directive project project_name group_name repo_path old_path bin_dir top_path commands_path cmd ide list_of_options
array set options $list_of_options

Msg Debug "Returned by InitLauncher: $project $project_name $group_name $repo_path $old_path $bin_dir $top_path $commands_path $cmd"

append usage [GetCustomCommands $commands_path]
append usage "\n** Options:"

######## DEFAULTS #########
set do_implementation 0; set do_synthesis 0; set do_bitstream 0; set do_create 0; set do_compile 0; set do_simulation 0; set recreate 0; set reset 1; set do_ipbus_xml 0; set list_all 2; set list_files_parse 0;

set default_commands {

  \^C(REATE)?$ {
    set do_create 1
    set recreate 1
  }

  \^I(MPL(EMENT(ATION)?)?)?$ {
    set do_implementation 1
    set do_bitstream 1
    set do_compile 1
  }

  \^SYNT(H(ESIS(E)?)?)? {
    set do_synthesis 1
    set do_compile 1
  }

  \^S(IM(ULAT(ION|E)?)?)?$ {
    set do_simulation 1
    set do_create 1
  }

  \^W(ORK(FLOW)?)?$ {
    set do_implementation 1
    set do_synthesis 1
    set do_bitstream 1
    set do_compile 1
  }

  \^(CREATEWORKFLOW|CW)$ {
    set do_implementation 1
    set do_synthesis 1
    set do_bitstream 1
    set do_compile 1
    set recreate 1
  }

  \^X(ML)?$ {
    set do_ipbus_xml 1
  }

  \^V(IEW)?$ {
    set list_files_parse 1
  }


  default {
    Msg Status "ERROR: Unknown directive $directive.\n\n[cmdline::usage $parameters $usage]"
    exit 1
  }
}

set custom_commands [GetCustomCommands $commands_path 1]

Msg Debug "Looking for a $directive in : $default_commands $custom_commands"
switch -regexp -- $directive "$default_commands $custom_commands"

if { $options(all) == 1 } {
  set list_all 1
} else {
  set list_all 2
}

if {$cmd == -1} {
#This is if the project was not found
  Msg Status "\n\nPossible projects are:"
  ListProjects $repo_path $list_all
  Msg Status "\n"
  exit 1
} elseif {$cmd == -2} {
  # Project not given but needed
  Msg Status "ERROR: You must specify a project with directive $directive.\n\n[cmdline::usage $parameters $usage]"
  Msg Status "\n Possible projects are:"
  ListProjects $repo_path $list_all
  Msg Status "\n"
  exit 1

} elseif {$cmd == 0} {
  #This script was launched within the IDE,: Vivado, Quartus, etc
  Msg Info "$::argv0 was launched from the IDE."

} else {
  # This script was launched with Tclsh, we need to check the arguments and if everything is right launch the IDE on this script and return

  #### Commands to be handled in tclsh should be here ###
  if {$do_ipbus_xml == 1} {
    Msg Info "Handling IPbus XMLs for $project_name..."
    #Msg Info "Returned by InitLauncher: $project $project_name $group_name $repo_path $old_path $bin_dir $top_path $commands_path $cmd"

    set proj_dir $repo_path/Top/$project_name

    if { $options(generate) == 1 } {
      set xml_gen 1
    } else {
      set xml_gen 0
    }

    if { $options(xml_dir) != "" } {
      set xml_dst $options(xml_dir)
    } else {
      set xml_dst "../$project\_xml"
      Msg Info "Using default destination $xml_dst..."
    }

    if {[llength [glob -nocomplain $proj_dir/list/*.ipb]] > 0 } {
      if {![file exists $xml_dst]} {
	Msg Info "$xml_dst directory not found, creating it..."
	file mkdir $xml_dst
      }
    } else {
      Msg Error "No .ipb files found in $proj_dir/list/"
      exit
    }

    set ret [GetRepoVersions $proj_dir $repo_path ""]
    set sha [lindex $ret 13]
    set hex_ver [lindex $ret 14]

    set ver [HexVersionToString $hex_ver]
    CopyIPbusXMLs $proj_dir $repo_path $xml_dst $ver $sha 1 $xml_gen

    exit 0
  }

  if {$list_files_parse == 1} {
      set proj_dir $repo_path/Top/$project_name
      Msg Info "The project is set to $proj_dir"
      set proj_list_dir $repo_path/Top/$project_name/list
      lassign [GetHogFiles -print_log -list_files {.src,.sim,.ext,.ipb,.con,.sim} "$proj_list_dir" "$repo_path"] lstlib lstprop lstflst
      set msg "The list files found in the category -"
      PrintDictItems $lstflst $msg
      set msg "The source files found in the list file -"
      #PrintDictItems $lstlib $msg
      set msg "The Hog property of -"
      set msg_appnd "is"
      #PrintDictItems $lstprop $msg $msg_appnd
      Msg Info "All Done."
    exit 0
  }

  #### END of tclsh commands ####
  Msg Info "Launching command: $cmd..."

  # Check if the IDE is actually in the path...
  set ret [catch {exec which $ide}]
  if {$ret != 0} {
    Msg Error "$ide not found in your system. Make sure to add $ide to your PATH enviromental variable."
    exit $ret
  }

  if {[string first libero $cmd] >= 0} {
    # The SCRIPT_ARGS: flag of libero makes tcl crazy...
    # Let's pipe the command into a shell script and remove it later
    set libero_script [open "launch-libero-hog.sh" w]
    puts $libero_script "#!/bin/sh"
    puts $libero_script $cmd
    close $libero_script
    set cmd "sh launch-libero-hog.sh"
  }



  set ret [catch {exec -ignorestderr {*}$cmd >@ stdout} result]

  if {$ret != 0} {
    Msg Error "IDE returned an error state."
  } else {
    Msg Info "All done."
    exit 0
  }

  if {[string first libero $cmd] >= 0} {
    file delete "launch-libero-hog.sh"
  }

  exit $ret
}

#After this line, we are in the IDE
##################################################################################

# We need to Import tcllib if we are using Libero
if {[IsLibero] || [IsDiamond]} {
  if {[info exists env(HOG_TCLLIB_PATH)]} {
    lappend auto_path $env(HOG_TCLLIB_PATH)
  } else {
    puts "ERROR: To run Hog with Microsemi Libero SoC or Lattice Diamond, you need to define the HOG_TCLLIB_PATH variable."
    return
  }
}

if {[catch {package require cmdline} ERROR] || [catch {package require struct::matrix} ERROR]} {
  puts "$ERROR\n Tcllib not found. If you are running this script on tclsh for debuggin purpose ONLY, you can fix this by installing 'tcllib'"
  exit 1
}

set run_folder [file normalize "$repo_path/Projects/$project_name/$project.runs/"]
if {[IsLibero]} {
  set run_folder [file normalize "$repo_path/Projects/$project_name/"]
}

set check_syntax 0
set ext_path ""
set simlib_path ""

#Only for quartus, not used otherwise
set project_path [file normalize "$repo_path/Projects/$project_name/"]


if { $options(no_bitstream) == 1 } {
  set do_bitstream 0
  set do_compile 0
}

if { $options(recreate) == 1 } {
  set recreate 1
}

if { $options(synth_only) == 1} {
  set do_implementation 0
  set do_synthesis 1
  set do_bitstream 0
  set do_create 1
  set do_compile 1
}

if { $options(impl_only) == 1} {
  set do_implementation 1
  set do_synthesis 0
  set do_bitstream 0
  set do_create 0
  set do_compile 1
}


if { $options(no_reset) == 1 } {
  set reset 0
}

if { $options(check_syntax) == 1 } {
  set check_syntax 1
}

if { $do_simulation == 1 } {
  set simsets $options(simset)
}

if { $options(ext_path) != ""} {
  set ext_path $options(ext_path)
}

if {$options(lib)!= ""} {
  set lib_path [file normalize $options(lib)]
} else {
  if {[info exists env(HOG_SIMULATION_LIB_PATH)]} {
    set lib_path $env(HOG_SIMULATION_LIB_PATH)
  } else {
    if {[file exists "$repo_path/SimulationLib"]} {
      set lib_path [file normalize "$repo_path/SimulationLib"]
    } else {
      set lib_path ""
    }
  }
}



if { $options(verbose) == 1 } {
  variable ::DEBUG_MODE 1
}

# Msg Info "Number of jobs set to $options(njobs)."

############## Quartus ########################
set argv ""

############# CREATE or OPEN project ############
if {[IsISE]} {
  cd $tcl_path
  set project_file [file normalize $repo_path/Projects/$project_name/$project.ppr]
} elseif {[IsVivado]} {
  cd $tcl_path
  set project_file [file normalize $repo_path/Projects/$project_name/$project.xpr]
} elseif {[IsQuartus]} {
  if { [catch {package require ::quartus::project} ERROR] } {
    Msg Error "$ERROR\n Can not find package ::quartus::project"
    cd $old_path
    return 1
  } else {
    Msg Info "Loaded package ::quartus::project"
    load_package flow
  }
  set project_file "$project_path/$project.qpf"
} elseif {[IsLibero]} {
  set project_file [file normalize $repo_path/Projects/$project_name/$project.prjx]
} elseif {[IsDiamond]} {
  sys_install version
  set project_file [file normalize $repo_path/Projects/$project_name/$project.ldf]
}

if {[file exists $project_file]} {
  Msg Info "Found project file $project_file for $project_name."
  set proj_found 1
} else {
  Msg Info "Project file not found for $project_name."
  set proj_found 0
}

if {($proj_found == 0 || $recreate == 1) && ($do_synthesis == 1 || $do_create == 1)} {
  Msg Info "Creating (possibly replacing) the project $project_name..."
  lassign [GetConfFiles $repo_path/Top/$project_name] conf sim pre post

  if {[file exists $conf]} {
    #Still not sure of the difference between project and project_name
    CreateProject -simlib_path $lib_path $project_name $repo_path
  } else {
    Msg Error "Project $project_name is incomplete: no hog.conf file found, please create one..."
  }
} else {
  Msg Info "Opening existing project file $project_file..."
  if {[IsXilinx]} {
    file mkdir "$repo_path/Projects/$project_name/$project.gen/sources_1"
  }
  OpenProject $project_file $repo_path
}


########## CHECK SYNTAX ###########
if { $check_syntax == 1 } {
  Msg Info "Checking syntax for project $project_name..."
  CheckSyntax $project_name $repo_path $project_file
}

######### LaunchSynthesis ########
if {$do_synthesis == 1} {
  LaunchSynthesis $reset $do_create $run_folder $project_name $repo_path $ext_path $options(njobs)
}

if {$do_implementation == 1 } {
  LaunchImplementation $reset $do_create $run_folder $project_name $repo_path $options(njobs) $do_bitstream
}


if {$do_bitstream == 1 && ![IsXilinx] } {
  GenerateBitstream $run_folder $repo_path $options(njobs)
}

if {$do_simulation == 1} {
  LaunchSimulation $project_name $lib_path $simsets $repo_path
}

## CLOSE Projects
CloseProject

Msg Info "All done."
cd $old_path
