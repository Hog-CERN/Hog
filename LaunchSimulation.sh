#!/bin/bash
#   Copyright 2018-2020 The University of Birmingham
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

## @file LaunchSimulation.sh
# @brief launch /Tcl/launchers/launch_simulation.tcl using Vivado
# @todo LaunchSimulation.sh: update for Quartus support
# @todo LaunchSimulation.sh: check is vivado is installed an set-up in the shell (if [ which vivado ])
# @todo LaunchSimulation.sh: check arg $1 and $2 before passing it to the Tcl script


DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

##! if called with -h or, -help or, --help or, -H optiins print help message and exit 
if [ "$1" == "-h" ] || [ "$1" == "-help" ] || [ "$1" == "--help" ] || [ "$1" == "-H" ]; then
  echo
  echo " Hog - Launch Simulation"
  echo " ---------------------------"
  echo " Use Vivado to launch simulation for a specified project"
  echo
  echo "Usage:"
  echo -e "\t Hog/LaunchSimulation.sh <proj_name> [library path]\n"
  echo
  exit 0
fi

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
