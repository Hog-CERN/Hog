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
#
declare -g COMMAND=""

## @var COMMAND_OPT
#  @brief Global variable used to contain the options associated to the command to be used
#
declare -g COMMAND_OPT=""

## @var HDL_COMPILER
#  @brief Global variable contianing the full path to the HDL compiler to be used
#
declare -g HDL_COMPILER=""

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
