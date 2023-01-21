#!/bin/bash
#   Copyright 2018-2023 The University of Birmingham
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

## @file LaunchSimulation.sh
# @brief launch /Tcl/launchers/launch_simulation.tcl using Vivado
# @todo LaunchSimulation.sh: update for Quartus support
# @todo LaunchSimulation.sh: check if vivado is installed an set-up in the shell (if [ command -v vivado ])
# @todo LaunchSimulation.sh: check arg $1 and $2 before passing it to the Tcl script


## Import common functions from Other/CommonFunctions.sh in a POSIX compliant way
#
# shellcheck source=Other/CommonFunctions.sh
. $(dirname "$0")/Other/CommonFunctions.sh



# print_hog $(dirname "$0")

# DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

## @function sim_argument_parser()
#  @brief parse arguments and sets environment variables
#  @param[out] SIMLIBPATH   empty or "-lib_path $2"
#  @param[out] QUIET        empty or "-quiet"
#  @param[out] SIMSET       empty or "-simset $2"
#  @param[out] PARAMS       positional parameters
#  @return                  1 if error or help, else 0

function sim_argument_parser() {
  PARAMS=""
  while (("$#")); do
    case "$1" in
    -l | -lib_path)
      SIMLIBPATH="-lib_path $2"
      shift 2
      ;;
    -quiet)
      QUIET="-quiet"
      shift 1
      ;;
    -simset)
      SIMSET="-simset $2"
      shift 2
      ;;    
    -recreate)
            RECREATE="-recreate"
            shift 1
            ;;
    -h | -help)
      HELP="-h"
      shift 1
      ;;
    --) # end argument parsing
      shift
      break
      ;;
    -*) # unsupported flags
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

function help_simulation_message() {
  echo
  echo " Hog - LaunchSimulation"
  echo " ---------------------------"
  echo " Launch the simulation for the specified project"
  echo
  echo " The project type is selected using the first line of the hog.conf generating the project"
  echo " Following options are available: "
  echo " #vivado "
  echo " #quartus "
  echo " #planahead "
  echo
  echo " Usage: $1 <project name> [OPTIONS]"
  echo " Options:"
  echo "          -l/--lib  <sim_lib_path>  Path to simulation library. If not defined it will be set to the HOG_SIMULATION_LIB_PATH environmental library, or if this does not exist to the default $(pwd)/SimulationLib"
  echo "          -simset <simset>          Launch the simulation only for the specified simulation set"
  echo "          -quiet                    If set, it runs the simulation in quiet mode"
  echo "          -recreate                 If set, Hog will recreate the HDL project before running the workflow"
  echo 
  echo " Hint: Hog accepts as <project name> both the actual project name and the relative path containing the project configuration. E.g. ./Hog/LaunchSimulation.sh Top/myproj or ./Hog/LaunchSimulation.sh myproj"
}

function SimulateProject(){
  # exit 0
  DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  sim_argument_parser "$@"

  if [ $? = 1 ]; then
    exit 1
  fi
  eval set -- "$PARAMS"
  if [ -z "$1" ]; then
    help_simulation_message "$0"
    cd "${OLD_DIR}" || exit
    echo
    echo "Possible projects are:"
    echo ""
    search_projects "$DIR/../Top"
    echo
    cd "${OLD_DIR}" || exit
    exit 0
  else
    if [ "$HELP" == "-h" ]; then
      help_simulation_message "$0"
      search_projects "$DIR/../Top"
      echo
      cd "${OLD_DIR}" || exit 
      exit 0
    fi

    PROJ=$1
    if [[ $PROJ == "Top/"* ]]; then
      PROJ=${PROJ#"Top/"}
    fi
    PROJ_DIR="$DIR/../Top/"$PROJ
    if [ -d "$PROJ_DIR" ]; then

      #Choose if the project is quartus, vivado, vivado_hls [...]
      
      if ! select_command "$PROJ_DIR"; then
        Msg Error "Failed to select project type: exiting!"
        exit 1
      fi

      #select full path to executable and place it in HDL_COMPILER global variable
      
      if ! select_compiler_executable "$COMMAND"; then
        Msg Error "Failed to get HDL compiler executable for $COMMAND"
        exit 1
      fi

      if [ ! -f "${HDL_COMPILER}" ]; then
        Msg Error "HDL compiler executable $HDL_COMPILER not found"
        cd "${OLD_DIR}" || exit 
        exit 1
      else
        Msg Info "Using executable: $HDL_COMPILER"
      fi

      if [ "$COMMAND" = "quartus_sh" ]; then
        Msg Error "Quartus is not yet supported by this script!"
        #echo "Running:  ${HDL_COMPILER} $COMMAND_OPT $DIR/Tcl/launchers/launch_simulation.tcl $SIMLIBPATH $1"
        #"${HDL_COMPILER}" $COMMAND_OPT $DIR/Tcl/launchers/launch_simulation.tcl $SIMLIBPATH $1

      elif [ "$COMMAND" = "libero" ]; then
        Msg Error "Libero is not yet supported by this script!"
      else
        if [[ -z $HOG_COLORED ]]; then
          if [ -z "${SIMLIBPATH}" ]; then
            if [ -z "${HOG_SIMULATION_LIB_PATH}" ]; then
              "${HDL_COMPILER}" $COMMAND_OPT $DIR/Tcl/launchers/launch_simulation.tcl -tclargs $SIMSET $QUIET $RECREATE $PROJ
            else
              "${HDL_COMPILER}" $COMMAND_OPT $DIR/Tcl/launchers/launch_simulation.tcl -tclargs -lib_path $HOG_SIMULATION_LIB_PATH $SIMSET $QUIET $RECREATE $PROJ
            fi
          else
            "${HDL_COMPILER}" $COMMAND_OPT $DIR/Tcl/launchers/launch_simulation.tcl -tclargs $SIMLIBPATH $SIMSET $QUIET $RECREATE $PROJ
          fi
        else
          if [ -z "${SIMLIBPATH}" ]; then
            if [ -z "${HOG_SIMULATION_LIB_PATH}" ]; then
              Logger "${HDL_COMPILER}" $COMMAND_OPT $DIR/Tcl/launchers/launch_simulation.tcl -tclargs $SIMSET $QUIET $RECREATE $PROJ
            else
              Logger "${HDL_COMPILER}" $COMMAND_OPT $DIR/Tcl/launchers/launch_simulation.tcl -tclargs -lib_path $HOG_SIMULATION_LIB_PATH $SIMSET $QUIET $RECREATE $PROJ
            fi
          else
            Logger "${HDL_COMPILER}" $COMMAND_OPT $DIR/Tcl/launchers/launch_simulation.tcl -tclargs $SIMLIBPATH $SIMSET $QUIET $RECREATE $PROJ
          fi
        fi
      fi
    else
      Msg Error "Project $PROJ not found: possible projects are: $(search_projects "$DIR/../Top")"
      cd "${OLD_DIR}" || exit 
      exit 1
    fi
  fi

}

#
#

function HogSimulateFunc(){
  # init $@
  Msg Info "HogInitFunc ($*)"
  Msg Debug "pwd : $(pwd)"

  SimulateProject $*
  # exit 0
}
if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
#   printf "script '%s' is sourced in\n" "${BASH_SOURCE[0]}"
# else
  repoPath=$(dirname "$0")
  echo "pwd : $(pwd)"
  print_hog "$repoPath"
  SimulateProject "$@"
fi
