#!/bin/bash
## @file LaunchSimulation.sh
## @brief launch /Tcl/launchers/launch_simulation.tcl using Vivado
## @todo LaunchSimulation.sh: update for Quartus support
## @todo LaunchSimulation.sh: use -h, --help to print help message
## @todo LaunchSimulation.sh: check is vivado is installed an set-up in the shell (if [ which vivado ])
## @todo LaunchSimulation.sh: check arg $1 and $2 before passing it to the Tcl script


DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
if [ -z "$1" ]
then
  ##! If no args passed then print help message 
  printf "Project name has not been specified. Usage: \n Hog/LaunchSimulation.sh <proj_name> [library path]\n"
else
  if [ ! -z "$2" ]
  then
    LIBPATH="-lib_path $2"
  fi	
  ##! invoke vivado to launch launch_simulation.tcl script using args: '-lib_path $2 $1'
  vivado -nojournal -nolog -mode batch -notrace -source $DIR/Tcl/launchers/launch_simulation.tcl -tclargs $LIBPATH $1 
fi
