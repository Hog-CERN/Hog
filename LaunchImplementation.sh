#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
vivado -mode batch -notrace -source $DIR/Tcl/launchers/launch_implementation.tcl -tclargs $1
