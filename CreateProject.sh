#!/usr/bin/env bash
#   Copyright 2018-2021 The University of Birmingham
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

## @file CreateProject.sh
#  @brief Create the specified Vivado or Quartus project

## Import common functions from Other/CommonFunctions.sh in a POSIX compliant way
#
. $(dirname "$0")/Other/CommonFunctions.sh

## @fn help_message
#
# @brief Prints an help message
#
# The help message contais both the options availble for the first line of the tcl, both the command usage
# This function uses echo to print to screen
#
# @param[in]    $1 the invoked command
#
function help_message() {
  echo
  echo " Hog - Create HDL project"
  echo " ---------------------------"
  echo " Create the specified Vivado or Quartus project"
  echo " The project type is selected using the first line of the hog.conf generating the project"
  echo " Following options are available: "
  echo " #vivado "
  echo " #vivadoHLS "
  echo " #quartus "
  echo " #quartusHLS "
  echo " #planahead "
  echo
  echo " Usage: $1 <project name> [OPTIONS]"
  echo " Options:"
  echo "          -l/--lib  <sim_lib_path>  Path to simulation library. If not defined it will be set to the HOG_SIMULATION_LIB_PATH environmnetal library, or if this does not exist to the default $(pwd)/SimulationLib"
  echo
}

## @fn main
#
# @ brief The main function
#
# help_messageThis function invokes the previous functions in the correct order, passing the expected inputs and then calls the execution of the create_project.tcl script
#
# @param[in]    $@ all the inputs to this script
function create_project() {
  # Define directory variables as local: only main will change directory

  local OLD_DIR=$(pwd)
  local THIS_DIR="$(dirname "$0")"

  if [ "$1" == "-h" ] || [ "$1" == "-help" ] || [ "$1" == "--help" ] || [ "$1" == "-H" ]; then
    help_message $0
    exit 0
  fi

  cd "${THIS_DIR}"

  if [ -e ../Top ]; then
    local DIR="../Top"
  else
    Msg Error "Top folder not found, Hog is not in a Hog-compatible HDL repository."
    cd "${OLD_DIR}"
    exit -1
  fi

  if [ "a$1" == "a" ]; then
    help_message $0
    echo "  Possible projects are:"

    search_projects $DIR
    echo
    cd "${OLD_DIR}"
    exit -1
  else
    local PROJ=$1
    local PROJ_DIR="$DIR/$PROJ"
  fi

  POSITIONAL=()
  while [[ $# -gt 0 ]]; do
    key="$2"

    case $key in
    -l | --lib)
      LIBPATH="$3"
      shift # past argument
      shift # past value
      ;;
    *)                   # unknown option
      POSITIONAL+=("$1") # save it in an array for later
      shift              # past argument
      ;;
    esac
  done
  set -- "${POSITIONAL[@]}" # restore positional parameters

  if [ -d "$PROJ_DIR" ]; then

    #Choose if the project is quastus, vivado, vivado_hls [...]
    select_command $PROJ_DIR
    if [ $? != 0 ]; then
      Msg Error "Failed to select project type: exiting!"
      exit -1
    fi

    #select full path to executable and place it in HDL_COMPILER global variable
    select_compiler_executable $COMMAND
    if [ $? != 0 ]; then
      Msg Error "Failed to get HDL compiler executable for $COMMAND"
      exit -1
    fi

    if [ ! -f "${HDL_COMPILER}" ]; then
      Msg Error "HLD compiler executable $HDL_COMPILER not found"
      cd "${OLD_DIR}"
      exit -1
    else
      Msg Info "Using executable: $HDL_COMPILER"
    fi

    if [ $FILE_TYPE == "CONF" ]; then
      cd "${DIR}"
      Msg Info "Creating project $PROJ using hog.conf..."
      if [ -z ${LIBPATH+x} ]; then
        if [ -z ${HOG_SIMULATION_LIB_PATH+x} ]; then
          "${HDL_COMPILER}" $COMMAND_OPT ../Hog/Tcl/create_project.tcl $POST_COMMAND_OPT $PROJ
        else
          "${HDL_COMPILER}" $COMMAND_OPT ../Hog/Tcl/create_project.tcl $POST_COMMAND_OPT -simlib_path ${HOG_SIMULATION_LIB_PATH} $PROJ
        fi
      else
        "${HDL_COMPILER}" $COMMAND_OPT ../Hog/Tcl/create_project.tcl $POST_COMMAND_OPT -simlib_path ${LIBPATH} $PROJ
      fi
    elif [ $FILE_TYPE == "TCL" ]; then
      cd "${PROJ_DIR}"
      PROJ_NAME=$(basename $PROJ_DIR)
      Msg Warning "Creating project $PROJ using $PROJ.tcl, this is deprecated and will not be supported in future Hog releases..."
      "${HDL_COMPILER}" $COMMAND_OPT $PROJ_NAME.tcl
    else
      Msg Error "Unknown file type: $FILE_TPYE"
      exit 1
    fi

    if [ $? != 0 ]; then
      Msg Error "HDL compiler returned an error state."
      cd "${OLD_DIR}"
      exit -1
    fi

  else
    Msg Error "Project $PROJ not found: possible projects are:"
    search_projects "${OLD_DIR}/Top"
    echo
    cd "${OLD_DIR}"
    exit -1
  fi

  cd "${OLD_DIR}"

  exit 0

}

print_hog $(dirname "$0")
create_project $@
