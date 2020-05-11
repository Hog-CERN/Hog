#!/bin/bash
## @file LaunchImplementation.sh
# @brief launch /Tcl/launchers/launch_implementation.tcl using Vivado
# @todo LaunchImplementation.sh: update for Quartus support
# @todo LaunchImplementation.sh: check is vivado is installed an set-up in the shell (if [ which vivado ]) 
# @todo LaunchImplementation.sh: check arg $1 and $2 before passing it to the Tcl script

DIR="$( cd "$( dirname "${BASH_SOURCE[1]}" )" && pwd )"

##! if called with -h or, -help or, --help or, -H optiins print help message and exit 
if [ "$1" == "-h" ] || [ "$1" == "-help" ] || [ "$1" == "--help" ] || [ "$1" == "-H" ]; then
  echo
  echo " Hog - Launch Implementation"
  echo " ---------------------------"
  echo " Use Vivado to launch implementation for a specified project"
  echo
  echo "Usage:"
  echo -e "\t ./Hog/LaunchImplementation.sh <proj_name> [-no_bitstream]\n"
  echo
  echo "Arguments:"
  echo -e "\t -no_bitstream \t do not create a binary file"
  echo
  exit 0
fi

if [ -z "$1" ]
then
  ##! If no args passed then print help message
    printf "Project name has not been specified. Usage: \n ./Hog/LaunchImplementation.sh <proj_name> [-no_bitstream]\n"
else
  ##! Call vivado to launch script launch_implementation.tcl using args $1 and $2
    vivado -nojournal -nolog -mode batch -notrace -source $DIR/Tcl/launchers/launch_implementation.tcl -tclargs $2 $1 
fi
