#!/usr/bin/env tclsh
# @file
#   Copyright 2018-2026 The University of Birmingham
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

# Developers Tip for new commands
# Add a hashtag sign # after the curly brake (e.g. \^C(REATE)?$ {# ...}) if the command requires a project name as an argument

# Add this bit above!
#  \^NEW_DIRECTIVE?$ {
#    set do_new_directive 1
#  }

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
  # OPTIONS: ext_path.arg, lib.arg, vivado_only, vitis_only, verbose
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
  # NAME*: WORKFLOW or W
  # DESCRIPTION: Runs the full workflow, creates the project if not existing.
  # OPTIONS: bitstream_only, check_syntax, ext_path.arg, impl_only, njobs.arg, no_bitstream, recreate, synth_only, verbose, vitis_only, xsa.arg
  }

  \^(CREATEWORKFLOW|CW)?$ {#
    set do_implementation 1
    set do_synthesis 1
    set do_bitstream 1
    set do_compile 1
    set do_create 1
    set recreate 1
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

  \^VHDL(LS)?$ {#
    set do_vhdl_ls 1
  # NAME: VHDL-LS or VHDL
  # DESCRIPTION: Create a VHDL-LS configuration file for the chosen project.
  # OPTIONS: verbose
  }

  \^COCOTB$ {#
    set do_cocotb 1
  # NAME: COCOTB
  # DESCRIPTION: Create a cocotb Python script to build VHDL/Verilog libraries using runner.build().
  # OPTIONS: verbose, lib.arg
  }

  \^VER(SION)?$ {#
    set do_version 1
  # NAME*: VERSION or VER
  # DESCRIPTION: Print the version of the chosen Hog project. With -describe, prints the Hog describe string instead.
  # OPTIONS: describe, verbose
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