#!/bin/bash
## @file LaunchIPSynth.sh
## @brief launch get_ips.tcl and launch_ip_synth.tcl using Vivado
## @todo LaunchIPSynth.sh: update for Quartus support
## @todo LaunchIPSynth.sh: use -h, --help to print help message 
## @todo LaunchIPSynth.sh: check is vivadoi is installed an set-up in the shell (if [ which vivado ]) 
## @todo LaunchIPSynth.sh: check arg $1 before passing it to the script

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
##! If no arg is provided Then print usage message
if [ -z "$1" ]
then
	printf "Project name has not been specified. Usage: \n ./Hog/LaunchIPSynth.sh <proj_name>\n"
else
  ##! use vivado to run get_ips.tcl and launch_ip_synth.tcl
	vivado -nojournal -nolog -mode batch -notrace -source $DIR/Tcl/launchers/get_ips.tcl -tclargs $1
	vivado -nojournal -nolog -mode batch -notrace -source $DIR/Tcl/launchers/launch_ip_synth.tcl -tclargs $1
fi
