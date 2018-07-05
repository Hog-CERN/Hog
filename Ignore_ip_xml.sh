#!/bin/bash
OLD_DIR=`pwd`
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $DIR/..

if [ "$1" == "-undo" ]; then
    command="--no-assume-unchanged"
    undo="not"
else
    echo [hog ip xml] To undo ignoring ip xml, run with -undo option
    undo=""
    command="--assume-unchanged"
fi

echo [hog ip xml] Ignoring Xilinx IP xml locally
xci=`find . -name *.xci`
for f in $xci
do
    ext="${f##*.}"
    name="${f%.*}"
    if [ -e "$name.xml" ]
    then
	echo [hog ip xml] Assuming $undo unchanged: $name.xml
	git update-index $command $name.xml
    fi
done

cd $OLD_DIR
