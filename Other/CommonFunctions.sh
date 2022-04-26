#!/usr/bin/env bash
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

## @file CreateProject.sh
#  @brief Create the specified Vivado or Quartus project

## @var FILE_TYPE
#  @brief Global variable used to distinguis tcl project from hog.conf
#
export FILE_TYPE=""

## @var COMMAND
#  @brief Global variable used to contain the command to be used
#
export COMMAND=""

## @var COMMAND_OPT
#  @brief Global variable used to contain the options associated to the command to be used
#
export COMMAND_OPT=""

## @var POST_COMMAND_OPT
#  @brief Global variable used to contain the post command options to be used (e.g. -tclargs)
#
export POST_COMMAND_OPT=""

## @var HDL_COMPILER
#  @brief Global variable contianing the full path to the HDL compiler to be used
#
export HDL_COMPILER=""

## @var COLORED
#  @brief Global variable used to contain the colorer
if [[ -z ${CONSOLE_COLORER} ]]; then
  export CONSOLE_COLORER=""
else
  echo "there is a colorer : ${CONSOLE_COLORER}"
fi

# exit 0

## @function LogColorVivado()
# brief save output logs of vivado to files and colors the output
# @param[in] execution line to process

function LogColorVivado(){
  # colorizer="xcol"
  echo "LogColorVivado : $1"
  echo_info=1
  echo_warnings=1
  echo_errors=1
  ${1} |& while IFS= read -r line
      do
        # echo "${line}"
        # echo $line >> $logfile
        # string=$line
        # echo "$line" | xcol warning: critical error: info: hog: 
        case "$line" in
          *'WARNING:'* | *'Warning:'* | *'warning:'*)
            if [ $echo_warnings == 1 ]; then
              echo "w : $line" 
              #| $(${colorizer} warning: critical error: info: hog: )
            fi
            # echo $line >> $warningfile
          ;;
          *'ERROR:'* | *'Error:'* | *'error:'*)
            if [ $echo_errors == 1 ]; then
              echo "e : $line" 
              #| xcol warning: critical error info: hog: 
            fi
            # echo "e : $line"
            # echo $line >> $errorfile
          ;;
          *'INFO:'*)
            if [ $echo_info == 1 ]; then
              echo "i : $line" 
              #| xcol warning: critical error: info: hog: 
            fi
            # echo "i : $line"
          ;;
          *'vcom'*)
              echo "i : $line" #| xcol warning critical error vcom hog 
          ;;
          *'Errors'* | *'Warnings'* | *'errors'* | *'warnings'*)
              echo "i : $line" #| xcol warnings critical errors vcom hog 
          ;;
          *)
            if [ $echo_info == 1 ]; then
              echo "i : $line" #| xcol warning: critical error: info: hog: 
            fi
            # echo "default (none of above)"
            # echo "line : $string"
          ;;
        esac
      
      done
}

# @function Msg
#
# @param[in] messageLevel: it can be Info, Warning, CriticalWarning, Error
# @param[in] message: the error message to be printed
#
# @return  '1' if missing argumets else '0'
function Msg() {
  #check input variables
  if [ "a$1" == "a" ]; then
    Msg Error "messageLevel not set!"
    return 1
  fi

  if [ "a$2" == "a" ]; then
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

  echo "$Colour HOG:$1 ${FUNCNAME[1]}()  $2 $Default"

  return 0
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
# @param[out]   POST_COMMAND_OPT global variable: the post command options
#
# @returns  0 if success, 1 if failure
#
function select_command_from_line() {
  if [ -z ${1+x} ]; then
    Msg Error " missing input! Got: $1!"
    return 1
  fi

  local TCL_FIRST_LINE=$1

  if [[ $TCL_FIRST_LINE =~ 'vivado' ]]; then
    if [[ $TCL_FIRST_LINE =~ 'vivadoHLS' ]]; then
      Msg Info " Recognised VivadoHLS project"
      COMMAND="vivado_hls"
      COMMAND_OPT="-f"
    else
      Msg Info " Recognised Vivado project"
      COMMAND="vivado"
      COMMAND_OPT="-nojournal -nolog -mode batch -notrace -source"
      POST_COMMAND_OPT="-tclargs"
    fi
  elif [[ $TCL_FIRST_LINE =~ 'quartus' ]]; then
    if [[ $TCL_FIRST_LINE =~ 'quartusHLS' ]]; then
      Msg Error " Intel HLS compiler is not supported!"
      return 1
    else
      Msg Info " Recognised QuartusPrime project"
      COMMAND="quartus_sh"
      COMMAND_OPT="-t"
    fi
  elif [[ $TCL_FIRST_LINE =~ 'intelHLS' ]]; then
    Msg Error "Intel HLS compiler is not supported!"
    return 1
  elif [[ $TCL_FIRST_LINE =~ 'planahead' ]]; then
    Msg Info " Recognised planAhead project"
    COMMAND="planAhead"
    COMMAND_OPT="-nojournal -nolog -mode batch -notrace -source"
    POST_COMMAND_OPT="-tclargs"
  else
    Msg Warning " You should write #vivado, #quartus or #planahead as first line in your hog.conf file or project Tcl file, assuming Vivado... "
    Msg Info " Recognised Vivado project"
    COMMAND="vivado"
    COMMAND_OPT="-mode batch -notrace -source"
    POST_COMMAND_OPT="-tclargs"
  fi

  return 0
}

## @fn select_command
#
# @brief Selects which command has to be used based on the first line of the tcl/conf file
#
# This function:
# - checks that the tcl file exists
# - gets the first line using head -1
# - calls select_command_from_line()
#
# @param[in]    $1 full path to the tcl/conf file
# @param[out]   COMMAND  global variable: the selected command
# @param[out]   COMMAND_OPT global variable: the selected command options
#
# @returns  0 for ok, 1 for error
#
function select_command() {
  proj=$(basename $1)
  conf="$1"/"hog.conf"
  tcl="$1"/"$proj.tcl"

  if [ -f "$conf" ]; then
    file="$conf"
    FILE_TYPE=CONF
  elif [ -f "$tcl" ]; then
    file="$tcl"
    FILE_TYPE=TCL
  else
    Msg Error "No suitable file found in $1!"
    return 1
  fi

  select_command_from_line "$(head -1 $file)"
  if [ $? != 0 ]; then
    Msg Error "Failed to select COMMAND, COMMAND_OPT and POST_COMMAND_OPT"
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
# - uses command -v to select the executable
#   * if no executable is found and the command is vivado it uses XILINX_VIVADO
#   *
# - stores the result in a global variable called HDL_COMPILER
#
# @param[in]    $1 The command to be invoked
# @param[out]   HDL_COMPILER gloabal variable: the full path to the HDL compiler executable
#
# @returns  0 if success, 1 if failure
#
function select_compiler_executable() {
  if [ "a$1" == "a" ]; then
    Msg Error "select_compiler_executable(): Variable COMMAND is not set!"
    return 1
  fi

  if [ $(command -v $1) ]; then
    HDL_COMPILER=$(command -v $1)
  else
    if [ $1 == "vivado" ]; then
      if [ -z ${XILINX_VIVADO+x} ]; then
        Msg Error "No vivado executable found and no variable XILINX_VIVADO set\n"
        cd "${OLD_DIR}"
        return 1
      elif [ -d "$XILINX_VIVADO" ]; then
        Msg Info "XILINX_VIVADO is set to '$ XILINX_VIVADO'"
        HDL_COMPILER="$XILINX_VIVADO/bin/$1"
      else
        Msg Error "Failed locate '$1' executable from XILINX_VIVADO: $XILINX_VIVADO"
        return 1
      fi
    elif [ $1 == "quartus_sh" ]; then
      if [ -z ${QUARTUS_ROOTDIR+x} ]; then
        Msg Error "No quartus_sh executable found and no variable QUARTUS_ROOTDIR set\n"
        cd "${OLD_DIR}"
        return 1
      else
        Msg Info "QUARTUS_ROOTDIR is set to '$QUARTUS_ROOTDIR'"
        #Decide if you are to use bin or bin 64
        #Note things like $PROCESSOR_ARCHITECTURE==x86 won't work in Windows because tyhis will return the version of the git bash
        if [ -d "$QUARTUS_ROOTDIR/bin64" ]; then
          HDL_COMPILER="$QUARTUS_ROOTDIR/bin64/$1"
        elif [ -d "$QUARTUS_ROOTDIR/bin" ]; then
          HDL_COMPILER="$QUARTUS_ROOTDIR/bin/$1"
        else
          Msg Error "Failed locate '$1' executable from QUARTUS_ROOTDIR: $QUARTUS_ROOTDIR"
          return 1
        fi
      fi
    else
      Msg Error "cannot find the executable for $1."
      echo "Probable causes are:"
      echo "- $1 was not setup"
      echo "- command not available on the machine"
      return 1
    fi
  fi

  return 0
}

## @fn select_executable_from_project
#
# @brief Selects which ompiler executable has to be used based on the first line of the conf or tcl file
#
# @param[in]    $1 full path to the project dir
# @param[out]   COMMAND  global variable: the selected command
# @param[out]   COMMAND_OPT global variable: the selected command options
# @param[out]   POST_COMMAND_OPT global variable: the post command options
# @param[out]   HDL_COMPILER gloabal variable: the full path to the HDL compiler executable
#
# @returns  0 if success, 1 if failure
#
function select_executable_from_project_dir() {
  if [ -z ${1+x} ]; then
    Msg Error "missing input! Got: $1!"
    return 1
  fi
  select_command $1
  if [ $? != 0 ]; then
    Msg Error "Failed to select project type: exiting!"
    return 1
  fi

  #select full path to executable and place it in HDL_COMPILER global variable
  select_compiler_executable $COMMAND
  if [ $? != 0 ]; then
    Msg Error "Failed to get HDL compiler executable for $COMMAND"
    return 1
  fi

  return 0
}

# @fn print_hog
#
# @param[in] $1 path to Hog dir
# @brief prints the hog logo
function print_hog() {
  if [ -z ${1+x} ]; then
    Msg Error "missing input! Got: $1!"
    return 1
  fi
  cd "$1"
  ver=$(git describe)
  echo
  cat ./images/hog_logo.txt
  echo " Version: ${ver}"
  echo
  cd -
  return 0
}

## @fn search available projects inside input folder
#
# @brief Search all hog projects inside a folder
#
# @param[in]    $1 full path to the dir containing the projects
# @returns  0 if success, 1 if failure
#
function search_projects() {
  if [ -z ${1+x} ]; then
    Msg Error "missing input! Got: $1!"
    return 1
  fi

  if [[ -d "$1" ]]; then
    for dir in $1/*; do
      project_name=$(basename $dir)
      if [ -f "$dir/hog.conf" ]; then
        subname=${dir#*Top/}
        echo $subname
      else
        search_projects $dir
      fi
    done
  fi
  return 0
}
