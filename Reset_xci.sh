#!/usr/bin/env bash
## @file Reset_xci.sh
# brief Reset all modified xci files in the repository to their committed version.

OLD_DIR=`pwd`
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

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
git checkout -- `git ls-files -m *.xci`

echo [hog reset xci] All done.
cd "${OLD_DIR}"
