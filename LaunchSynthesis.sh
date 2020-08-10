#!/bin/bash
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

## @file LaunchSynthesis.sh
# @brief launch /Tcl/launchers/launch_synthesis.tcl using Vivado
# @todo LaunchSynthesis.sh: update for Quartus support
# @todo LaunchSynthesis.sh: check is vivado is installed an set-up in the shell (if [ which vivado ])

## Import common functions from CommonFunctions.sh in a POSIX compliant way
#
. $(dirname "$0")/CommonFunctions.sh;


## @function argument_parser()
#  @brief pase aguments and sets evvironment variables
#  @param[out] NJOBS        empty or "-NJOBS $2"
#  @param[out] NO_BITSTREAM empty or "-no_bitstream"
#  @param[out] PARAMS       positional parameters
#  @return                  1 if error or help, else 0
function argument_parser() {
	PARAMS=""
	while (( "$#" )); do
	  case "$1" in
		-NJOBS)
		  NJOBS="-NJOBS $2"
		  shift 2
		  ;;
		--) # end argument parsing
		  shift
		  break
		  ;;
		-*|--*=) # unsupported flags
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

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
argument_parser $@
if [ $? = 1 ]; then
	exit 1
fi
eval set -- "$PARAMS"
if [ -z "$1" ]
then
	printf "Project name has not been specified. Usage: \n ./Hog/LaunchSynthesis.sh <proj_name> [-NJOBS <number of jobs>]\n"
else
  PROJ=$1
  PROJ_DIR="./Top/"$PROJ
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

    if [ $COMMAND = "quartus_sh" ]
    then
      ${HDL_COMPILER} $COMMAND_OPT $DIR/Tcl/launchers/launch_synthesis.tcl $NJOBS $1
    else
      ${HDL_COMPILER} $COMMAND_OPT $DIR/Tcl/launchers/launch_synthesis.tcl -tclargs $NJOBS $1
    fi
  else
    echo "Hog-ERROR: project $PROJ not found: possible projects are: `ls ./Top`"
    echo
    cd "${OLD_DIR}"
    exit -1
  fi

fi
