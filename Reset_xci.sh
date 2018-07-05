#!/bin/bash
OLD_DIR=`pwd`
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $DIR/..

echo [hog reset xci] Checking out commited version of all modified xci files
git checkout -- `git ls-files -m *.xci`

echo [hog reset xci] All done.
cd $OLD_DIR
