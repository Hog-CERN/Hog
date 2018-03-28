#!/bin/bash
echo [Init] Initialising repository...
OLD_DIR=`pwd`
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $DIR/..

echo [Init] Initialising ipbus submodule...
git submodule init
echo [Init] Updating ipbus submodule...
git submodule update

if [ `which vivado` ]
then
    VIVADO=`which vivado`
    if [ `which vsim` ]
    then
	echo [Init] Compiling Modelsim libraries into ./ModelsimLib...
	$VIVADO -mode batch -notrace -source ./Hog/Tcl/compile_library.tcl
	rm -f ./Hog/Tcl/.cxl.questasim.version
	rm -f ./Hog/Tcl/compile_simlib.log
	rm -f ./Hog/Tcl/modelsim.ini
    else
	echo [Init] "WARNING: No modelsim executable found, will not compile libraries\n"
    fi

    cd ./Top
    proj=`ls`
    cd ..
    echo [Init] Creating projects for: $proj...
    for f in $proj
    do
	echo [Init] Creating Vivado project: $f...
	./Hog/CreateProject.sh $f
    done
else
    echo [Init] "WARNING: No vivado executable found\n"
fi

echo [Init] All done.
cd $OLD_DIR
