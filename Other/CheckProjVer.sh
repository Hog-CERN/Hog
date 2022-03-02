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

## Import common functions from Other/CommonFunctions.sh in a POSIX compliant way
#
. $(dirname "$0")/CommonFunctions.sh

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
  echo " Hog - Check Project Version"
  echo " ---------------------------"
  echo
  echo " Usage: $1 <project name>"
  echo
}

## @function argument_parser()
#  @brief pase aguments and sets evvironment variables
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
    -? | -h | -help)
      HELP="-h"
      shift 1
      ;;
    --) # end argument parsing
      shift
      break
      ;;
    -* | --*=) # unsupported flags
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
  local OLD_DIR=$(pwd)
  local THIS_DIR="$(dirname "$0")"

  if [ "a$1" == "a" ]; then
    help_message $0
    exit 1
  fi

  argument_parser $@
  if [ $? = 1 ]; then
    exit 1
  fi
  set -- "${PARAMS[@]}"

  if [ "$HELP" == "-h" ]; then
    help_message $0
    exit 0
  fi

  cd "${THIS_DIR}"

  if [ -e ../../Top ]; then
    local DIR="../../Top"
  else
    echo "Hog-ERROR: Top folder not found, Hog is not in a Hog-compatible HDL repository."
    echo
    cd "${OLD_DIR}"
    exit 1
  fi

  local PROJ=$(echo $1)
  local PROJ_DIR="$DIR/$PROJ"

  if [ -d "$PROJ_DIR" ]; then

    #Choose if the project is quastus, vivado, vivado_hls [...]
    local PROJ_DIR="$PWD/$PROJ_DIR"
    select_command $PROJ_DIR
    if [ $? != 0 ]; then
      echo "Hog-ERROR: Failed to select project type: exiting!"
      exit 1
    fi

    #select full path to executable and place it in HDL_COMPILER global variable
    select_compiler_executable $COMMAND
    if [ $? != 0 ]; then
      echo "Hog-ERROR: failed to get HDL compiler executable for $COMMAND"
      exit 1
    fi

    if [ ! -f "${HDL_COMPILER}" ]; then
      echo "Hog-ERROR: HDL compiler executable $HDL_COMPILER not found"
      cd "${OLD_DIR}"
      exit 1
    else
      echo "Hog-INFO: using executable: $HDL_COMPILER"
    fi

    if [ $COMMAND = "quartus_sh" ]; then
      echo "Hog-INFO: Executing:  ${HDL_COMPILER} $COMMAND_OPT $DIR/../../Hog/Tcl/CI/check_proj_ver.tcl $EXT_PATH $SIM $PROJ"
      "${HDL_COMPILER}" $COMMAND_OPT $DIR/../Hog/Tcl/CI/check_proj_ver.tcl $EXT_PATH $SIM $PROJ
    elif [ $COMMAND = "vivado_hls" ]; then
      echo "Hog-ERROR: Vivado HLS is not yet supported by this script!"
    else
      echo "Hog-INFO: Executing:  ${HDL_COMPILER} $COMMAND_OPT $DIR/../../Hog/Tcl/CI/check_proj_ver.tcl -tclargs $EXT_PATH $SIM $PROJ"
      "${HDL_COMPILER}" $COMMAND_OPT $DIR/../Hog/Tcl/CI/check_proj_ver.tcl -tclargs $EXT_PATH $SIM $PROJ
    fi
  fi
}

main $@
