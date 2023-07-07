#!/bin/bash
OLD_DIR=`pwd`
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "${DIR}/.."
echo "Hog [Warning]: $0 is obsolete, you should use ./Hog/Do now!"

if [ "$#" -eq 0 ]; then
    ./Hog/Hog LIST
else
    ./Hog/Hog CREATE $@
fi

cd "${OLD_DIR}"
