#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
if [ -z "$1" ]
then
    printf "Project name has not been specified. Usage: \n ./Hog/LaunchImplementation.sh <proj_name> [1|0]\n A 1 as second argument will stop implementation before write bitstream. Default is 0.\n"
else
	vivado -nojournal -nolog -mode batch -notrace -source $DIR/Tcl/launchers/launch_implementation.tcl -tclargs $@
fi
