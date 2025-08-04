#!/usr/bin/env bash
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
  echo " Hog - Check Project Version"
  echo " ---------------------------"
  echo
  echo " Usage: $1 <project name>"
  echo
}

## @function argument_parser()
#  @brief parse arguments and sets environmental variables
#  @param[out] IP_PATH      empty or "-eos_ip_path $2"
#  @param[out] NJOBS        empty or "-NJOBS $2"
#  @param[out] NO_BITSTREAM empty or "-no_bitstream"
#  @param[out] SYNTH_ONLY   empty or "-synth_only"
#  @param[out] IMPL_ONLY    empty or "-impl_only"
#  @param[out] NO_RECREATE  empty or "-no_recreate"
#  @param[out] RESET        empty or "-reset"
#  @param[out] CHECK_SYNTAX empty or "-check_syntax"
#  @param[out] EXT_PATH     empty or "-ext_path $2"
#  @param[out] PARAMS       positional parameters
#  @return                  1 if error or help, else 0

function argument_parser() {
  PARAMS=""
  while (("$#")); do
    case "$1" in
    -sim)
      SIM="-sim"
      shift 1
      ;;
    -ext_path)
      EXT_PATH="-ext_path $2"
      shift 2
      ;;
    -h | -help)
      HELP="-h"
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

## @fn main
#
# @ brief The main function
#
# This function invokes the previous functions in the correct order, passing the expected inputs and then calls the execution of the create_project.tcl script
#
# @param[in]    $@ all the inputs to this script
function main() {
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

  local PROJ
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

    #select full path to executable and place it in TOOL_EXECUTABLE global variable

    for ((i=0; i<${#CMD_ARRAY[@]}; i++)); do
      if ! select_compiler_executable "${CMD_ARRAY[$i]}"; then
        echo "Hog-ERROR: Failed to get ${CMD_ARRAY[$i]} executable"
        exit 1
      fi

      if [ ! -f "${TOOL_EXECUTABLE}" ]; then
        echo "Hog-ERROR: Failed to find $TOOL_EXECUTABLE executable"
        cd "${OLD_DIR}" || exit
        exit 1
      else
        echo "Hog-INFO: Using executable: $TOOL_EXECUTABLE"
      fi

      if [ "${CMD_ARRAY[$i]}" = "quartus_sh" ]; then
        echo "Hog-INFO: Executing:  ${TOOL_EXECUTABLE} $CMD_OPT_ARRAY[$i] $DIR/../../Hog/Tcl/CI/check_proj_ver.tcl $EXT_PATH $SIM $PROJ"
        ${TOOL_EXECUTABLE} $CMD_OPT_ARRAY[$i] $DIR/../Hog/Tcl/CI/check_proj_ver.tcl $EXT_PATH $SIM $PROJ
      elif [ "${CMD_ARRAY[$i]}" = "vivado_hls" ]; then
        echo "Hog-ERROR: Vivado HLS is not yet supported by this script!"
      elif [ "${CMD_ARRAY[$i]}" = "libero" ]; then
        echo "Hog-INFO: Executing:  ${TOOL_EXECUTABLE} $CMD_OPT_ARRAY[$i] $DIR/../../Hog/Tcl/CI/check_proj_ver.tcl ${POST_CMD_OPT_ARRAY[$i]}$EXT_PATH $SIM $PROJ"
        ${TOOL_EXECUTABLE} ${CMD_OPT_ARRAY[$i]}$DIR/../Hog/Tcl/CI/check_proj_ver.tcl ${POST_CMD_OPT_ARRAY[$i]}$PROJ
      elif [ "${CMD_ARRAY[$i]}" = "ghdl" ]; then
        echo "Hog-INFO: Executing: tclsh Hog/Tcl/CI/check_proj_ver.tcl $EXT_PATH $SIM $PROJ"
        tclsh $DIR/../Hog/Tcl/CI/check_proj_ver.tcl $EXT_PATH $SIM $PROJ
      else
        echo "Hog-INFO: Executing:  ${TOOL_EXECUTABLE} $CMD_OPT_ARRAY[$i] $DIR/../../Hog/Tcl/CI/check_proj_ver.tcl ${POST_CMD_OPT_ARRAY[$i]}$EXT_PATH $SIM $PROJ"
        ${TOOL_EXECUTABLE} ${CMD_OPT_ARRAY[$i]}$DIR/../Hog/Tcl/CI/check_proj_ver.tcl ${POST_CMD_OPT_ARRAY[$i]} $EXT_PATH $SIM $PROJ
      fi
    done
  fi
}

main "$@"