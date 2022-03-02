#!/bin/bash
#   Copyright 2018-2022 The University of Birmingham
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
#   limitations under the License.
## @file MakeSigasiCSV.sh
# brief Creates Sisgasi csv file

. "$(dirname "$0")"/CommonFunctions.sh

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
usage="Usage: MakeSigasiCSV.sh <project name>"

if [ "$1" == "-h" ] || [ "$1" == "-help" ] || [ "$1" == "--help" ] || [ "$1" == "-H" ]; then
    echo
    echo " Hog - Make Sigasi CSV file"
    echo " ---------------------"

    echo "Creates CSV file containing all the project files used to create Sigasi project."
    echo " This script will create 2 csv file, one for simulation and one for synthesis called respectively:"
    echo " <project name>_sigasi_sim.csv and <project name>_sigasi_synth.csv"
    echo "$usage"
    exit 0
fi

if [ -z "$1" ]; then
    ##! If no args passed then print help message
    echo "$usage"
else
    PROJ=$1
    PROJ_DIR="$DIR/../../Top/"$PROJ
    if [ -d "$PROJ_DIR" ]; then
        #Choose if the project is quastus, vivado, vivado_hls [...]

        if ! select_command "$PROJ_DIR"; then
            echo "Failed to select project type: exiting!"
            exit 1
        fi
        #select full path to executable and place it in HDL_COMPILER global variable

        if ! select_compiler_executable "$COMMAND"; then
            echo "Hog-ERROR: cannot find Vivado or Quartus to execute this script"
            exit 1
        fi

        if [ ! -f "${HDL_COMPILER}" ]; then
            echo "Hog-ERROR: HLD compiler executable $HDL_COMPILER not found."
            exit 1
        else
            echo "Hog-INFO: using executable: $HDL_COMPILER"
        fi
        "$HDL_COMPILER" $COMMAND_OPT "$DIR/../Tcl/utils/make_sigasi_csv.tcl" -tclargs $@
    else
        echo "Hog-ERROR could not find $PROJ_DIR"
    fi
fi
