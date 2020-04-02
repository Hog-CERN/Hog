#!/bin/bash
## @file LaunchIPSynth.sh
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
if [ -z "$1" ]
then
	printf "Project name has not been specified. Usage: \n ./Hog/LaunchIPSynth.sh <proj_name>\n"
else
	vivado -nojournal -nolog -mode batch -notrace -source $DIR/Tcl/launchers/get_ips.tcl -tclargs $1
	vivado -nojournal -nolog -mode batch -notrace -source $DIR/Tcl/launchers/launch_ip_synth.tcl -tclargs $1
fi
