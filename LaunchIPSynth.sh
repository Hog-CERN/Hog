#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
if [ -z "$1" ]
then
	printf "Project name has not been specified. Usage: \n ./Hog/LaunchIPSynth.sh <proj_name>\n"
else
	vivado -mode batch -notrace -source $DIR/Tcl/launchers/get_ips.tcl -tclargs $1
	#vivado -mode batch -notrace -source $DIR/../Top/$1/$1.tcl
	vivado -mode batch -notrace -source $DIR/Tcl/launchers/launch_ip_synth.tcl -tclargs $1
fi
