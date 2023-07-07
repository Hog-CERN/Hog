#!/bin/bash
 OLD_DIR=`pwd`
 DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
 cd "${DIR}/.."
 echo "Hog [Warning]: $0 is obsolete, you should use ./Hog/Do now!"
 ./Hog/Do "${@:1:$#-1}" SIMULATE "${!#}"
 cd "${OLD_DIR}"
