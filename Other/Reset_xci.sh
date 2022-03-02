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

## @file Reset_xci.sh
# brief Reset all modified xci files in the repository to their committed version.

OLD_DIR=$(pwd)
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ "$1" == "-h" ] || [ "$1" == "-help" ] || [ "$1" == "--help" ] || [ "$1" == "-H" ]; then
    echo
    echo " Hog - Reset XCI files"
    echo " ---------------------"
    echo " Reset all modified xci files in the repository to their committed version."
    echo " Can be used when xci files are modified automatically by Vivado and you do not want to commit the changes."
    echo " e.g. When you upgrade IPs to a different Vivado version"
    echo
    exit 0
fi

cd "${DIR}"/..

echo [hog reset xci] Checking out commited version of all modified xci files
git checkout -- $(git ls-files -m *.xci)

echo [hog reset xci] All done.
cd "${OLD_DIR}"
