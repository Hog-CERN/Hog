#!/bin/bash
if [ $# -eq 0 ]; then
    TARGET_BRANCH=master
else
    TARGET_BRANCH=$1
fi

git rev-parse --verify ${TARGET_BRANCH} 2>1 >/dev/null

if [ $? -eq 0 ]; then
    echo "## Changelog"
    echo
    git log --no-merges 53-hog-tcl-cleanup ^${TARGET_BRANCH} --format=%B | grep FEATURE: | sed 's/FEATURE: */- /'
    echo 
fi

