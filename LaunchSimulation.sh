#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
if [ -z "$1" ] || [  -z "$2" ]
then
	printf "Project name has not been specified. Usage: \n Hog/LaunchSimulation.sh <proj_name> <simulator> [library path]\n"
	printf "Possible choices for <simulator> are: vivadosim, modelsim\n"
else
	if [ $2 == "vivadosim" ] 
	then
		vivado -mode batch -notrace -source $DIR/Tcl/launchers/launch_vivado_simulation.tcl -tclargs $1 $3
	else
        vivado -mode batch -notrace -source $DIR/Tcl/launchers/launch_simulation.tcl -tclargs $1 $3
	fi
fi
