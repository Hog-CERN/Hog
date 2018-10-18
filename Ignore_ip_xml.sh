#!/bin/env bash
OLD_DIR=`pwd`
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [ "$1" == "-h" ] || [ "$1" == "-help" ] || [ "$1" == "--help" ] || [ "$1" == "-H" ]; then
    echo
    echo " Hog - Ignore IP XML"
    echo " -------------------"
    echo " Locally ignore Xilinx IP xml files using git update-index."
    echo " Modification to XML files located in the same path as an xci file with the same name will be ignored."
    echo " Each XML file will be automatically added to commit if the relative XCI file is modified, thanks to pre-commit git hook."
    echo
    echo " Usage $0 [-undo]"
    echo
    echo "  If -undo option is given, will set all the xml files to be not ignored"
    echo
    exit 0
fi

cd "${DIR}"/..

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
for f in "${xci}"
do
    ext="${f##*.}"
    name="${f%.*}"
    if [ -e "$name.xml" ]
    then
	echo [hog ip xml] Assuming $undo unchanged: $name.xml
	git update-index $command $name.xml
    fi
done

cd "${OLD_DIR}"
