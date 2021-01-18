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
export COMMAND=""

## @var COMMAND_OPT
#  @brief Global variable used to contain the options associated to the command to be used
#
export COMMAND_OPT=""

## @var HDL_COMPILER
#  @brief Global variable contianing the full path to the HDL compiler to be used
#
export HDL_COMPILER=""


# @function Msg
#
# @param[in] messageLevel: it can be Info, Warning, CriticalWarning, Error
# @param[in] message: the error message to be printed
#
# @return  '1' if missing argumets else '0'
function Msg ()
{
  #check input variables
  if [ "a$1" == "a" ]
  then
    Msg Error "messageLevel not set!"
    return 1
  fi
  
  if [ "a$2" == "a" ]
  then
    Msg Warning "message not set!"
    return 1
  fi

  #Define colours
  Red=$'\e[0;31m'
  Green=$'\e[0;32m'
  Orange=$'\e[0;33m'
  LightBlue=$'\e[0;36m'
  Default=$'\e[0m'

  case $1 in
    "Info")
      Colour=$Default
      ;;
    "Warning")
      Colour=$LightBlue
      ;;
    "CriticalWarning")
      Colour=$Orange
      ;;
    "Error")
      Colour=$Red
      ;;
    *)
      Msg Error "messageLevel: $1 not supported! Use Info, Warning, CriticalWarning, Error"
      ;;
  esac
  
  echo "$Colour HOG:$1 ${FUNCNAME[1]}()  $2 $Default";

  return 0;
}


## @fn select_command_from_line
#
# @brief Selects which command has to be used based on the first line of the tcl
#
# This function:
# - checks if the line CONTAINS:
#   * vivado
#     + vivadoHLS
#   * quartus
#     + quartusHLS
#   * intelHLS
#   * planahead
#
# @param[in]    $1 the first line of the tcl file or a suitable string 
# @param[out]   COMMAND  global variable: the selected command
# @param[out]   COMMAND_OPT global variable: the selected command options
#
# @returns  0 if success, 1 if failure
#
function select_command_from_line()
{
  if [ -z ${1+x} ]
  then
    Msg Error " missing input! Got: $1!"
    return 1
  fi

  local TCL_FIRST_LINE=$1

  if [[ $TCL_FIRST_LINE =~ 'vivado' ]];
  then
    if [[ $TCL_FIRST_LINE =~ 'vivadoHLS' ]];
    then
      Msg Info " Recognised VivadoHLS project"
      COMMAND="vivado_hls"
      COMMAND_OPT="-f"
    else
      Msg Info " Recognised Vivado project"
      COMMAND="vivado"
      COMMAND_OPT="-nojournal -nolog -mode batch -notrace -source"
    fi
  elif [[ $TCL_FIRST_LINE =~ 'quartus' ]];
  then
    if [[ $TCL_FIRST_LINE =~ 'quartusHLS' ]];
    then
      Msg Error " Intel HLS compiler is not supported!"
      return 1
    else
      Msg Info " Recognised QuartusPrime project"
      COMMAND="quartus_sh"
      COMMAND_OPT="-t"
    fi
  elif [[ $TCL_FIRST_LINE =~ 'intelHLS' ]];
  then
    Msg Error "Intel HLS compiler is not supported!"
    return 1
  elif [[ $TCL_FIRST_LINE =~ 'planahead' ]];
  then
    Msg Info  " Recognised planAhead project"
    COMMAND="planAhead"
    COMMAND_OPT="-nojournal -nolog -mode batch -notrace -source"
  else
    Msg Warning " You should write #vivado or #quartus in your project Tcl file, assuming Vivado... "
    Msg Info " Recognised Vivado project"
    COMMAND="vivado"
    COMMAND_OPT="-mode batch -notrace -source"
  fi

  return 0
}

## @fn select_command
#
# @brief Selects which command has to be used based on the first line of the tcl
#
# This function:
# - checks that the tcl file exists
# - gets the first line using head -1
# - calls select_command_from_line()
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
    Msg Error "File: $1 not found!"
    return 1
  fi

  select_command_from_line $(head -1 $1)
  if [ $? != 0 ]
  then
    Msg Error "Failed to select COMMAND and COMMAND_OPT"
    return 1
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
    Msg Error "select_compiler_executable(): Variable COMMAND is not set!"
    return 1
  fi

  if [ `which $1` ]
  then
    HDL_COMPILER=`which $1`
  else
    if [$1 == "vivado" ]
    then
      if [ -z ${VIVADO_PATH+x} ]
      then
        Msg Error "No vivado executable found and no variable VIVADO_PATH set\n"
        cd "${OLD_DIR}"
        return 1
      else
        Msg Info "VIVADO_PATH is set to '$VIVADO_PATH'"
        HDL_COMPILER="$VIVADO_PATH/$viv"
      fi
    else
      Msg Error  "cannot find the executable for $1."
      echo  "Probable causes are:"
      echo  "- $1 was not setup"
      echo  "- which not available on the machine"
      return 1
    fi
  fi

  return 0
}

## @fn select_executable_form_file
#
# @brief Selects which ompiler executable has to be used based on the first line of the project.tcl file
#
# @param[in]    $1 full path to the tcl file
# @param[out]   COMMAND  global variable: the selected command
# @param[out]   COMMAND_OPT global variable: the selected command options
# @param[out]   HDL_COMPILER gloabal variable: the full path to the HDL compiler executable
#
# @returns  0 if success, 1 if failure
#
function select_executable_form_file ()
{
  if [ -z ${1+x} ]
  then
    Msg Error "missing input! Got: $1!"
    return 1
  fi
  select_command $1
  if [ $? != 0 ]
  then
    Msg Error "Failed to select project type: exiting!"
    return 1
  fi

  #select full path to executable and place it in HDL_COMPILER global variable
  select_compiler_executable $COMMAND
  if [ $? != 0 ]
  then
    Msg Error "Failed to get HDL compiler executable for $COMMAND"
    return 1
  fi
  
  return 0
}
