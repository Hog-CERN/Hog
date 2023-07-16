#!/bin/bash
OLD_DIR=`pwd`
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "${DIR}/.."
echo "Hog [Warning]: $0 is obsolete, you should use ./Hog/Hog now!"
./Hog/Hog WORKFLOW "$@"
cd "${OLD_DIR}"
