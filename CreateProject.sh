#!/usr/bin/env bash
#   Copyright 2018-2020 The University of Birmingham
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
## @var COMMAND
#  @brief Global variable used to contain the command to be used
COMMAND=""

## @var COMMAND_OPT
#  @brief Global variable used to contain the options associated to the command to be used
COMMAND_OPT=""

## @var HDL_COMPILER
#  @brief Global variable contianing the full path to the HDL compiler to be used
HDL_COMPILER=""

## @fn select_command
#
# @brief Prints an help message
#
# The help message contais both the options availble for the first line of the tcl, both the command usage
# This function uses echo to print to screen
#
# @param[in]    $1 the invoked command
#
function help_message()
{
  echo
  echo " Hog - Create HDL project"
  echo " ---------------------------"
  echo " Create the specified Vivado or Quartus project"
  echo " The project type is selected using the first line of the tcl script generating the project"
  echo " Following options are available: "
  echo " #vivado "
  echo " #vivadoHLS "
  echo " #quartus "
  echo " #quartusHLS "
  echo
  echo " Usage: $1 <project name>"
  echo
}

## @fn select_command
#
# @brief Selects which command has to be used based on the first line of the tcl
#
# This function:
# - checks that the tcl file exists
# - gets the first line using head -1
# - checks if the line CONTAINS:
#   * vivado
#     + vivadoHLS
#   * quartus
#     + quartusHLS
#   * intelHLS
#
# @param[in]    $1 full path to the tcl file
# @param[out]   COMMAND  global variable: the selected command
# @param[out]   COMMAND_OPT global variable: the selected command options
#
# @returns  0 if success, 1 if failure
#
function select_command()
{
  if [ ! -f $1 ]
  then
    echo "File: $1 not found!"
    return 1
  fi

  local TCL_FIRST_LINE=$(head -1 $1)

  if [[ $TCL_FIRST_LINE =~ 'vivado' ]];
  then
    if [[ $TCL_FIRST_LINE =~ 'vivadoHLS' ]];
    then
      echo "Hog-INFO: Recognised VivadoHLS project"
      COMMAND="vivado_hls"
      COMMAND_OPT="-f"
    else
      echo "Hog-INFO: Recognised Vivado project"
      COMMAND="vivado"
      COMMAND_OPT="-nojournal -nolog -mode batch -notrace -source"
    fi
  elif [[ $TCL_FIRST_LINE =~ 'quartus' ]];
  then
    if [[ $TCL_FIRST_LINE =~ 'quartusHLS' ]];
    then
      echo "Hog-ERROR: Intel HLS compiler is not supported!"
      return 1
    else
      echo "Hog-INFO: Recognised QuartusPrime project"
      COMMAND="quartus_sh"
      COMMAND_OPT="-t"
    fi
  elif [[ $TCL_FIRST_LINE =~ 'intelHLS' ]];
  then
    echo "Hog-ERROR: Intel HLS compiler is not supported!"
    return 1
  else
    echo "Hog-WARNING: You should write #vivado or #quartus in your project Tcl file, assuming Vivado... "
    echo "Hog-INFO: Recognised Vivado project"
    COMMAND="vivado"
    COMMAND_OPT="-mode batch -notrace -source"
  fi

  return 0
}

## @fn select_compiler_executable
#
# @brief selects the path to the executable to be used for invoking the HDL compiler
#
# This function:
# - checks at least 1 argoument is passed
# - uses which to select the executable
#   * if no executable is found and the command is vivado it uses VIVADO_PATH
#   *
# - stores the result in a global variable called HDL_COMPILER
#
# @param[in]    $1 The command to be invoked
# @param[out]   HDL_COMPILER gloabal variable: the full path to the HDL compiler executable
#
# @returns  0 if success, 1 if failure
#
function select_compiler_executable ()
{
  if [ "a$1" == "a" ]
  then
    echo "Hog-ERROR: Variable COMMAND is not set!"
    return 1
  fi

  if [ `which $1` ]
  then
    HDL_COMPILER=`which $1`
  else
    if [$1 = "vivado" ]
    then
      if [ -z ${VIVADO_PATH+x} ]
      then
        echo "Hog-ERROR: No vivado executable found and no variable VIVADO_PATH set\n"
        echo " "
        cd "${OLD_DIR}"
        return 1
      else
        echo "VIVADO_PATH is set to '$VIVADO_PATH'"
        HDL_COMPILER="$VIVADO_PATH/$viv"
      fi
    else
      echo  "Hog-ERROR: I can not find the executable for $1. "
      echo  "Probable causes are:"
      echo  "- $1 was not setup"
      echo  "- which not available on the machine"
      return 1
    fi
  fi

  return 0
}

## @fn main
#
# @ brief The main function
#
# This function invokes the previous functions in the correct order, passing the expected inputs and then calls the execution of the create_project.tcl script
#
# @param[in]    $@ all the inputs to this script
function create_project ()
{
  # Define directory variables as local: only main will change directory

  local OLD_DIR=`pwd`
  local THIS_DIR="$(dirname "$0")"

  if [ "$1" == "-h" ] || [ "$1" == "-help" ] || [ "$1" == "--help" ] || [ "$1" == "-H" ]; then
    help_message $0
    exit 0
  fi

  cd "${THIS_DIR}"

  if [ -e ../Top ]
  then
    local DIR="../Top"
  else
    echo "Hog-ERROR: Top folder not found, Hog is not in a Hog-compatible HDL repository."
    echo
    cd "${OLD_DIR}"
    exit -1
  fi

  if [ "a$1" == "a" ]
  then
    echo " Usage: $0 <project name>"
    echo
    echo "  Possible projects are:"
    ls -1 $DIR
    echo
    cd "${OLD_DIR}"
    exit -1
  else
    local PROJ=$1
    local PROJ_DIR="../Top/"$PROJ
  fi

  if [ -d "$PROJ_DIR" ]
  then

    #Choose if the project is quastus, vivado, vivado_hls [...]
    select_command $PROJ_DIR"/"$PROJ".tcl"
    if [ $? != 0 ]
    then
      echo "Failed to select project type: exiting!"
      exit -1
    fi

    #select full path to executable and place it in HDL_COMPILER global variable
    select_compiler_executable $COMMAND
    if [ $? != 0 ]
    then
      echo "Hog-ERROR: failed to get HDL compiler executable for $COMMAND"
      exit -1
    fi

    if [ ! -f "${HDL_COMPILER}" ]
    then
      echo "Hog-ERROR: HLD compiler executable $HDL_COMPILER not found"
      cd "${OLD_DIR}"
      exit -1
    else
      echo "Hog-INFO: using executable: $HDL_COMPILER"
    fi

    echo "Hog-INFO: Creating project $PROJ..."
    cd "${PROJ_DIR}"
    "${HDL_COMPILER}" $COMMAND_OPT $PROJ.tcl
    if [ $? != 0 ]
    then
      echo "Hog-ERROR: HDL compiler returned an error state."
      cd "${OLD_DIR}"
      exit -1
    fi

  else
    echo "Hog-ERROR: project $PROJ not found: possible projects are: `ls $DIR`"
    echo
    cd "${OLD_DIR}"
    exit -1
  fi

  cd "${OLD_DIR}"

  exit 0

}

create_project $@
