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
	vivado -nojournal -nolog -mode batch -notrace -source $DIR/Tcl/launchers/launch_synthesis.tcl -tclargs $NJOBS $1
fi
