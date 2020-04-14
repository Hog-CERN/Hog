#!/bin/bash

function argument_parser() {
	PARAMS=""
	while (( "$#" )); do
	  case "$1" in
		-NJOBS)
		  NJOBS="-NJOBS $2"
		  shift 2
		  ;;
		-no_bitstream)
		  NO_BITSTREAM="-no_bitstream"
		  shift 1
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
    printf "Project name has not been specified. Usage: \n ./Hog/LaunchImplementation.sh <proj_name> [-no_bitstream] [-NJOBS <number of jobs>]\n"
else
    vivado -nojournal -nolog -mode batch -notrace -source $DIR/Tcl/launchers/launch_implementation.tcl -tclargs $NO_BITSTREAM $NJOBS $1
fi
