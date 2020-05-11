#!/bin/bash
## @file LaunchSynthesis.sh
## @brief launch /Tcl/launchers/launch_synthesis.tcl using Vivado
## @todo LaunchSynthesis.sh: update for Quartus support
## @todo LaunchSynthesis.sh: use -h, --help to print help message
## @todo LaunchSynthesis.sh: check is vivado is installed an set-up in the shell (if [ which vivado ])
## @todo LaunchSynthesis.sh: check arg $1 and $2 before passing it to the Tcl script  

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
if [ -z "$1" ]
then
  ##! If no args èassed then print help message
	printf "Project name has not been specified. Usage: \n ./Hog/LaunchSynthesis.sh <proj_name>\n"
else
  ##! Call vivado to launch launch_synthesis.tcl script passing $1 as arg
	vivado  -nojournal -nolog -mode batch -notrace -source $DIR/Tcl/launchers/launch_synthesis.tcl -tclargs $1
fi
