#!/bin/bash
#   Copyright 2018-2022 The University of Birmingham
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

## @file LaunchImplementation.sh
# @brief launch /Tcl/launchers/launch_implementation.tcl using Vivado

## Import common functions from Other/CommonFunctions.sh in a POSIX compliant way
#
. $(dirname "$0")/Other/CommonFunctions.sh
print_hog $(dirname "$0")
## @function argument_parser()
#  @brief pase aguments and sets evvironment variables
#  @param[out] IP_PATH      empty or "-ip_path $2"
#  @param[out] SIMLIBPATH   empty or "-simlib_path $2"
#  @param[out] NJOBS        empty or "-NJOBS $2"
#  @param[out] NO_BITSTREAM empty or "-no_bitstream"
#  @param[out] SYNTH_ONLY   empty or "-synth_only"
#  @param[out] IMPL_ONLY    empty or "-impl_only"
#  @param[out] RECREATE     empty or "-recreate"
#  @param[out] NO_RESET     empty or "-no_reset"
#  @param[out] CHECK_SYNTAX empty or "-check_syntax"
#  @param[out] EXT_PATH     empty or "-ext_path $2"
#  @param[out] PARAMS       positional parameters
#  @return                  1 if error or help, else 0

function argument_parser() {
    PARAMS=""
    while (("$#")); do
        case "$1" in
        -njobs)
            NJOBS="-njobs $2"
            shift 2
            ;;
        -l | --lib)
            SIMLIBPATH="-simlib_path $2"
            shift 2
            ;;
        -ip_path)
            IP_PATH="-ip_path $2"
            shift 2
            ;;
        -impl_only)
            IMPL_ONLY="-impl_only"
            shift 1
            ;;
        -recreate)
            RECREATE="-recreate"
            shift 1
            ;;
        -ext_path)
            EXT_PATH="-ext_path $2"
            shift 2
            ;;
        -no_bitstream)
            NO_BITSTREAM="-no_bitstream"
            shift 1
            ;;
        -synth_only)
            SYNTH_ONLY="-synth_only"
            shift 1
            ;;
        -no_reset)
            NO_RESET="-no_reset"
            shift 1
            ;;
        -check_syntax)
            CHECK_SYNTAX="-check_syntax"
            shift 1
            ;;
        -? | -h | -help)
            HELP="-h"
            shift 1
            ;;
        --) # end argument parsing
            shift
            break
            ;;
        -* | --*=) # unsupported flags
            Msg Error "Unsupported flag $1" >&2
            return 1
            ;;
        *) # preserve positional arguments
            PARAMS="$PARAMS $1"
            shift
            ;;
        esac
    done
    # set positional arguments in their proper place
}

function help_message() {
  echo
  echo " Hog - LaunchWorkflow"
  echo " ---------------------------"
  echo " Launch the place&route workflow for the specified Vivado, Quartus or PlanAhead project"
  echo 
  echo " The project type is selected using the first line of the hog.conf generating the project"
  echo " Following options are available: "
  echo " #vivado "
  echo " #quartus "
  echo " #planahead "
  echo
  echo " Usage: $1 <project name> [OPTIONS]"
  echo " Options:"
  echo "          -l/--lib  <sim_lib_path>  Path to simulation library. If not defined it will be set to the HOG_SIMULATION_LIB_PATH environmnetal library, or if this does not exist to the default $(pwd)/SimulationLib"
  echo "          -njobs <value>            The number of parallel jobs to run. Default: 4"
  echo "          -ip_path <path>           If set, the synthesised IPs will be copied to the specified IP repository path"
  echo "          -impl_only                If set, only the implementation will be run, assuming that synthesis has already been completed"
  echo "          -recreate                 If set, Hog will recreate the HDL project before running the workflow"
  echo "          -ext_path <path>          It sets the absolute path for the external libraries"
  echo "          -no_bitstream             If set, no binary file will be produced"
  echo "          -synth_only               If set, it runs only the synthesis"
  echo "          -no_reset                 If set, the workflow will not be reset before running it"
  echo "          -check_syntax             If set, the HDL syntax will be checked before running the workflow"
  echo 
  echo " Hint: Hog accepts as <project name> both the actual project name and the relative path containing the project configuration. E.g. ./Hog/LaunchWorkflow.sh Top/myproj or ./Hog/LaunchWorkflow.sh myproj"
}

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
argument_parser $@
if [ $? = 1 ]; then
    exit 1
fi
eval set -- "$PARAMS"
if [ -z "$1" ]; then
    help_message $0
    echo "Possible projects are:"
    echo ""
    search_projects $DIR/../Top
    echo
    cd "${OLD_DIR}"
    exit -1
else
    if [ "$1" == "-h" ] || [ "$1" == "-help" ] || [ "$1" == "--help" ] || [ "$1" == "-H" ]; then
        help_message $0
        exit 0
    fi

    PROJ=$1
    if [[ $PROJ == "Top/"* ]]; then
      PROJ=${PROJ#"Top/"}
    fi
    PROJ_DIR="$DIR/../Top/"$PROJ
    if [ -d "$PROJ_DIR" ]; then

        #Choose if the project is quastus, vivado, vivado_hls [...]
        select_executable_from_project_dir "$PROJ_DIR"
        if [ $? != 0 ]; then
            Msg Error "Failed to get HDL compiler executable for $PROJ_DIR"
            exit -1
        fi

        if [ ! -f "${HDL_COMPILER}" ]; then
            Msg Error "HLD compiler executable $HDL_COMPILER not found"
            cd "${OLD_DIR}"
            exit -1
        else
            Msg Info "Using executable: $HDL_COMPILER"
        fi

        if [ -z ${SIMLIBPATH+x} ]; then
            if [ -z ${HOG_SIMULATION_LIB_PATH+x} ]; then
                SIMLIBPATH=""
            else
                SIMLIBPATH="-simlib_path ${HOG_SIMULATION_LIB_PATH}"
            fi
        fi

        if [ $COMMAND = "quartus_sh" ]; then
            if [ "a$IP_PATH" != "a" ]; then
                Msg Warning "IP eos path not supported in Quartus mode"
            fi
            ${HDL_COMPILER} $COMMAND_OPT $DIR/Tcl/launchers/launch_quartus.tcl $HELP $NO_BITSTREAM $SYNTH_ONLY $NJOBS $CHECK_SYNTAX $RECREATE $EXT_PATH $IMPL_ONLY -project $PROJ
        elif [ $COMMAND = "vivado_hls" ]; then
            Msg Error "Vivado HLS is not yet supported by this script!"
        else
            ${HDL_COMPILER} $COMMAND_OPT $DIR/Tcl/launchers/launch_workflow.tcl -tclargs $HELP $NO_RESET $NO_BITSTREAM $SYNTH_ONLY $IP_PATH $NJOBS $CHECK_SYNTAX $RECREATE $EXT_PATH $IMPL_ONLY $SIMLIBPATH $PROJ
        fi
    else
        Msg Error "Project $PROJ not found. Possible projects are:"
        search_projects Top
        cd "${OLD_DIR}"
        exit -1
    fi
fi
