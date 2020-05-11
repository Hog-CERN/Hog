#!/bin/bash
## @file LaunchIPSynth.sh
## @brief launch get_ips.tcl and launch_ip_synth.tcl using Vivado
## @todo LaunchIPSynth.sh: update for Quartus support
## @todo LaunchIPSynth.sh: check is vivado is installed an set-up in the shell (if [ which vivado ]) 
## @todo LaunchIPSynth.sh: check arg $1 before passing it to the script

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
	vivado -nojournal -nolog -mode batch -notrace -source $DIR/Tcl/launchers/get_ips.tcl -tclargs $1
	vivado -nojournal -nolog -mode batch -notrace -source $DIR/Tcl/launchers/launch_ip_synth.tcl -tclargs $1
fi
