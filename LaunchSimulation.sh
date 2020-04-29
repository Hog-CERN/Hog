#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
if [ -z "$1" ]
then
    printf "Project name has not been specified. Usage: \n Hog/LaunchSimulation.sh <proj_name> [library path]\n"
else
	if [ ! -z "$2" ]
	then
		LIBPATH="-lib_path $2"
	fi	

    vivado -nojournal -nolog -mode batch -notrace -source $DIR/Tcl/launchers/launch_simulation.tcl -tclargs $LIBPATH $1 
fi
