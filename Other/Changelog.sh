#!/bin/bash
if [ $# -eq 0 ]; then
    TARGET_BRANCH=master
else
    TARGET_BRANCH=$1
fi

git rev-parse --verify ${TARGET_BRANCH} >/dev/null 2>&1
SRC_BRANCH=`git rev-parse --abbrev-ref HEAD`

if [ $? -eq 0 ]; then
    echo "## Changelog"
    echo
    git log --no-merges ${SRC_BRANCH} ^${TARGET_BRANCH} --format=%B | grep FEATURE: | sed 's/FEATURE: */- /'
    echo 
fi
