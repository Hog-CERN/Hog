#!/bin/bash
#   Copyright 2018-2021 The University of Birmingham
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

## Import common functions from Other/CommonFunctions.sh in a POSIX compliant way
#
. $(dirname "$0")/Other/CommonFunctions.sh;

print_hog $(dirname "$0")

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

  PROJ=$1
  PROJ_DIR="$DIR/../Top/"$PROJ
  if [ -d "$PROJ_DIR" ]
  then

    #Choose if the project is quastus, vivado, vivado_hls [...]
    select_command $PROJ_DIR"/"$PROJ".tcl"
    if [ $? != 0 ]
    then
      Msg Error "Failed to select project type: exiting!"
      exit -1
    fi

    #select full path to executable and place it in HDL_COMPILER global variable
    select_compiler_executable $COMMAND
    if [ $? != 0 ]
    then
      Msg Error "Failed to get HDL compiler executable for $COMMAND"
      exit -1
    fi

    if [ ! -f "${HDL_COMPILER}" ]
    then
      Msg Error "HLD compiler executable $HDL_COMPILER not found"
      cd "${OLD_DIR}"
      exit -1
    else
      Msg Info "Using executable: $HDL_COMPILER"
    fi

    if [ $COMMAND = "quartus_sh" ]
    then
      Msg Error "Quartus is not yet supported by this script!"
      #echo "Running:  ${HDL_COMPILER} $COMMAND_OPT $DIR/Tcl/launchers/launch_simulation.tcl $LIBPATH $1"
      #"${HDL_COMPILER}" $COMMAND_OPT $DIR/Tcl/launchers/launch_simulation.tcl $LIBPATH $1

    elif [ $COMMAND = "vivado_hls" ]
    then
      Msg Error "Vivado HLS is not yet supported by this script!"
    else
      "${HDL_COMPILER}" $COMMAND_OPT $DIR/Tcl/launchers/launch_simulation.tcl -tclargs $LIBPATH $1
    fi
  else
    Msg Error "Project $PROJ not found: possible projects are: `ls $DIR/../Top`"
    cd "${OLD_DIR}"
    exit -1
  fi
fi
