#!/bin/bash
## @file LaunchImplementation.sh
## @brief launch /Tcl/launchers/launch_implementation.tcl using Vivado
## @todo LaunchImplementation.sh: update for Quartus support
## @todo LaunchImplementation.sh: use -h, --help to print help message 
## @todo LaunchImplementation.sh: check is vivado is installed an set-up in the shell (if [ which vivado ]) 
## @todo LaunchImplementation.sh: check arg $1 and $2 before passing it to the Tcl script

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
if [ -z "$1" ]
then
  ##! If no args passed then print help message
    printf "Project name has not been specified. Usage: \n ./Hog/LaunchImplementation.sh <proj_name> [-no_bitstream]\n"
else
  ##! Call vivado to launch script launch_implementation.tcl using args $1 and $2
    vivado -nojournal -nolog -mode batch -notrace -source $DIR/Tcl/launchers/launch_implementation.tcl -tclargs $2 $1 
fi
