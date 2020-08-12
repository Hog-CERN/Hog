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


## @file LaunchIPSynth.sh
# @brief launch get_ips.tcl and launch_ip_synth.tcl using Vivado
# @todo LaunchIPSynth.sh: update for Quartus support
# @todo LaunchIPSynth.sh: check is vivado is installed an set-up in the shell (if [ which vivado ]) 
# @todo LaunchIPSynth.sh: check arg $1 before passing it to the script
## Import common functions from CommonFunctions.sh in a POSIX compliant way
#
. $(dirname "$0")/CommonFunctions.sh;


DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

##! if called with -h or, -help or, --help or, -H optiins print help message and exit 
if [ "$1" == "-h" ] || [ "$1" == "-help" ] || [ "$1" == "--help" ] || [ "$1" == "-H" ]; then
  echo
  echo " Hog - Launch IP Synthesis"
  echo " ---------------------------"
  echo " Use Vivado to launch synthesis for all IPs included in a specified project"
  echo
  echo "Usage:"
  echo -e "\t ./Hog/LaunchIPSynth.sh <proj_name>\n"
  echo
  exit 0
fi

##! If no arg is provided Then print usage message
if [ -z "$1" ]
then
	printf "Project name has not been specified. Usage: \n ./Hog/LaunchIPSynth.sh <proj_name>\n"
else
  ##! use vivado to run get_ips.tcl and launch_ip_synth.tcl
  PROJ=$1
  PROJ_DIR="./Top/"$PROJ
  if [ -d "$PROJ_DIR" ]
  then

    #Choose if the project is quastus, vivado, vivado_hls [...]
    select_command $PROJ_DIR"/"$PROJ".tcl"
    if [ $? != 0 ]
    then
      echo "Failed to select project type: exiting!"
      exit -1
    fi

    #select full path to executable and place it in HDL_COMPILER global variable
    select_compiler_executable $COMMAND
    if [ $? != 0 ]
    then
      echo "Hog-ERROR: failed to get HDL compiler executable for $COMMAND"
      exit -1
    fi
    
    if [ ! -f "${HDL_COMPILER}" ]
    then
      echo "Hog-ERROR: HLD compiler executable $HDL_COMPILER not found"
      cd "${OLD_DIR}"
      exit -1
    else
      echo "Hog-INFO: using executable: $HDL_COMPILER"
    fi
    
    if [ "$COMMAND" = "quartus_sh" ]
    then
      echo "Hog-ERROR: Quartus Prime is not yet supportd by this script!"
      #${HDL_COMPILER} $COMMAND_OPT $DIR/Tcl/utils/get_ips.tcl $1
      #${HDL_COMPILER} $COMMAND_OPT $DIR/Tcl/launchers/launch_ip_synth.tcl $1
    else
      ${HDL_COMPILER} $COMMAND_OPT $DIR/Tcl/utils/get_ips.tcl -tclargs $1
      ${HDL_COMPILER} $COMMAND_OPT $DIR/Tcl/launchers/launch_ip_synth.tcl -tclargs $1
    fi
  else
    echo "Hog-ERROR: project $PROJ not found: possible projects are: `ls ./Top`"
    echo
    cd "${OLD_DIR}"
    exit -1
  fi
fi
