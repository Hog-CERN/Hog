#!/bin/bash
echo [Init] Initialising repository...
OLD_DIR=`pwd`
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $DIR

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
	$VIVADO -mode batch -notrace -source ./Tcl/compile_library.tcl
	rm -f Tcl/.cxl.questasim.version
	rm -f Tcl/compile_simlib.log
	rm -f Tcl/modelsim.ini
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
	./CreateProject.sh $f
    done
else
    echo [Init] "WARNING: No vivado executable found\n"
fi

echo [Init] All done.
cd $OLD_DIR
