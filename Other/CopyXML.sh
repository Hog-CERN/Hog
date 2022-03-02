#!/usr/bin/env bash
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

## @file CopyXML.sh
# brief Copy IPbus xml and process them
. $(dirname "$0")/CommonFunctions.sh

OLD_DIR=$(pwd)
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
usage="Usage: CopyXML.sh  \[-generate\] <project> <destination directory>"

if [ "$1" == "-h" ] || [ "$1" == "-help" ] || [ "$1" == "--help" ] || [ "$1" == "-H" ]; then
    echo
    echo " Hog - Copy IPbus XML files"
    echo " ---------------------"

    echo "Copy IPBus XML files listed in a XML list file of a project and replace the version"
    echo "and SHA placeholders if they are present in any of the XML files."
    echo $usage
    exit 0
fi

cd "${DIR}"/..

if [ -z "$1" ] || [ -z "$2" ] || ! [ -z "$4" ]; then
    ##! If no args passed then print help message
    echo $usage
else

    if [ -z "$3" ]; then
        ARGS="$1 $OLD_DIR/$2"
        PROJ=$1
    else
        ARGS="$1 $2 $OLD_DIR/$3"
        PROJ=$2
    fi

    PROJ_DIR="$DIR/../../Top/"$PROJ
    if [ -d "$PROJ_DIR" ]; then
        #Choose if the project is quastus, vivado, vivado_hls [...]
        select_command $PROJ_DIR
        if [ $? != 0 ]; then
            echo "Failed to select project type: exiting!"
            exit 1
        fi
        #select full path to executable and place it in HDL_COMPILER global variable
        select_compiler_executable $COMMAND
        if [ $? != 0 ]; then
            echo "Hog-WARNING: failed to get HDL compiler executable for $COMMAND"
            echo "Hog-INFO: will optimistically try Tcl shell..."
            tclsh $DIR/../Tcl/utils/copy_xml.tcl $ARGS
            exit 0
        fi

        if [ ! -f "${HDL_COMPILER}" ]; then
            echo "Hog-ERROR: HLD compiler executable $HDL_COMPILER not found."
            exit 1
        else
            echo "Hog-INFO: using executable: $HDL_COMPILER"
        fi
        "${HDL_COMPILER}" $COMMAND_OPT $DIR/../Tcl/utils/copy_xml.tcl -tclargs $ARGS
    else
        echo "Hog-ERROR could not find $PROJ_DIR"
    fi
fi
