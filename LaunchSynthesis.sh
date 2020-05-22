#!/bin/bash
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
