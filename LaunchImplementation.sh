#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
if [ -z "$1" ]
then
    printf "Project name has not been specified. Usage: \n ./Hog/LaunchImplementation.sh <proj_name> [-no_bitstream]\n"
else
    vivado -nojournal -nolog -mode batch -notrace -source $DIR/Tcl/launchers/launch_implementation.tcl -tclargs $2 $1 
fi
