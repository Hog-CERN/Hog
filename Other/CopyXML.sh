#!/usr/bin/env bash
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

## @file CopyXML.sh
# brief Copy IPbus xml and process them

OLD_DIR=`pwd`
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
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

if [ -z "$1" ] && [ -z "$2" ]
then
  ##! If no args passed then print help message
  echo $usage
else
    vivado -nojournal -nolog -mode batch -notrace -source ../Tcl/utils/copy_xml.tcl -tclargs $@
fi

