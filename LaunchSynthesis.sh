#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
if [ -z "$1" ]
then
	printf "Project name has not been specified. Usage: \n ./Hog/LaunchSynthesis.sh <proj_name>\n"
else
	vivado  -nojournal -nolog -mode batch -notrace -source $DIR/Tcl/launchers/launch_synthesis.tcl -tclargs $1
fi
