#!/usr/bin/env bash
#   Copyright 2018-2024 The University of Birmingham
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
# shellcheck source=CommonFunctions.sh
. $(dirname "$0")/CommonFunctions.sh

## @fn help_message
#
# @brief Prints an help message
#
# The help message contains both the options available for the first line of the tcl, both the command usage
# This function uses echo to print to screen
#
# @param[in]    $1 the invoked command
#
function help_message() {
  echo
  echo " Hog - Check Project Configurations"
  echo " ---------------------------"
  echo
  echo " Usage: $1 <project name> [OPTIONS]"
  echo " Options:"
  echo "          -ext_path <path>          It sets the absolute path for the external libraries"
  echo "          -recreate                 If set, Hog will recreate the list files and hog.conf, from the current project settings"
  echo "          -recreate_conf                 If set, Hog will recreate the hog.conf file, from the current project settings"
  echo "          -force                    Force the overwriting of List Files. To be used together with \"-recreate\""
  echo
}

## @function argument_parser()
#  @brief parse arguments and sets environment variables
#  @param[in] RECREATE          empty or "-recreate"
#  @param[in] RECREATE_CONF     empty or "-recreate"
#  @param[in] FORCE             empty or "-force"
#  @param[in] EXT_PATH          empty or "-ext_path $2"
#  @param[out] PARAMS       positional parameters
#  @return                  1 if error or help, else 0

function argument_parser() {
  PARAMS=""
  while (("$#")); do
    case "$1" in
    -ext_path)
      EXT_PATH="-ext_path $2"
      shift 2
      ;;
    -h | -help)
      HELP="-h"
      shift 1
      ;;
    -recreate )
      RECREATE="-recreate"
      shift 1
      ;;
    -recreate_conf )
      RECREATE_CONF="-recreate_conf"
      shift 1
      ;;
    -force )
      FORCE="-force"
      shift 1
      ;;
    --) # end argument parsing
      shift
      break
      ;;
    -* ) # unsupported flags
      echo "Error: Unsupported flag $1" >&2
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

## @fn CheckProjConfs
#
# @ brief The CheckProjConfs function
#
# This function sources the check_list_files.tcl, which checks that the project configuration files (hog.conf and list files) matches the current settings in the Vivado Project
# This script is available only for Vivado at the moment.
#
# @param[in]    $@ all the inputs to this script
function CheckProjConfs() {
  # Define directory variables as local: only main will change directory
  local OLD_DIR
  OLD_DIR=$(pwd)
  local THIS_DIR
  THIS_DIR="$(dirname "$0")"
  if [ "a$1" == "a" ]; then
    help_message "$0"
    exit 1
  fi

  argument_parser "$@"
  if [ $? = 1 ]; then
    exit 1
  fi
  eval set -- "$PARAMS"

  if [ "$HELP" == "-h" ]; then
    help_message "$0"
    exit 0
  fi

  cd "${THIS_DIR}" || exit

  if [ -e ../../Top ]; then
    local DIR="../../Top"
  else
    echo "Hog-ERROR: Top folder not found, Hog is not in a Hog-compatible HDL repository."
    echo
    cd "${OLD_DIR}" || exit
    exit 1
  fi


  PROJ=$1
  if [[ $PROJ == "Top/"* ]]; then
    PROJ=${PROJ#"Top/"}
  fi
  PROJ_DIR="$DIR/../Top/"$PROJ

  if [ -d "$PROJ_DIR" ]; then

    #Choose if the project is quartus, vivado, vivado_hls [...]
    local PROJ_DIR="$PWD/$PROJ_DIR"

    if ! select_command "$PROJ_DIR"; then
      echo "Hog-ERROR: Failed to select project type: exiting!"
      exit 1
    fi

    #select full path to executable and place it in HDL_COMPILER global variable
    if ! select_compiler_executable "$COMMAND"; then
      echo "Hog-ERROR: failed to get HDL compiler executable for $COMMAND"
      exit 1
    fi

    if [ ! -f "${HDL_COMPILER}" ]; then
      echo "Hog-ERROR: HDL compiler executable $HDL_COMPILER not found"
      cd "${OLD_DIR}" || exit
      exit 1
    else
      echo "Hog-INFO: using executable: $HDL_COMPILER"
    fi

    if [ "$COMMAND" = "vivado" ]; then
      echo "Hog-INFO: Executing:  ${HDL_COMPILER} $COMMAND_OPT $DIR/../../Hog/Tcl/utils/check_list_files.tcl ${POST_COMMAND_OPT} $EXT_PATH $RECREATE_CONF $RECREATE $FORCE -proj $PROJ"
      ${HDL_COMPILER} $COMMAND_OPT $DIR/../Hog/Tcl/utils/check_list_files.tcl ${POST_COMMAND_OPT} $EXT_PATH $RECREATE_CONF $RECREATE $FORCE -project $PROJ
    else
      echo "This script is supported only by Xilinx Vivado for the moment, exiting..."
    fi
  fi
}

CheckProjConfs "$@"
