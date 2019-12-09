#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
if [ -z "$1" ]
then
    printf "Project name has not been specified. Usage: \n ./Hog/               LaunchWriteBitstream.sh <proj_name>\n"
else
	vivado -mode batch -notrace -source $DIR/Tcl/launchers/launch_write_bitstream.tcl -tclargs $1
fi
