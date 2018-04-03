#!/bin/bash
OLD_DIR=`pwd`
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $DIR

if [ `which vivado` ]
then
    VIVADO=`which vivado`
    if [ `which vsim` ]
    then
	echo [hog init] Compiling Modelsim libraries into ../ModelsimLib...
	$VIVADO -mode batch -notrace -source ./Tcl/compile_library.tcl
	rm -f ./Tcl/.cxl.questasim.version
	rm -f ./Tcl/compile_simlib.log
	rm -f ./Tcl/modelsim.ini
    else
	echo [hog init] "WARNING: No modelsim executable found, will not compile libraries\n"
    fi

    cd ../Top
    proj=`ls`
    cd ..
    echo [hog init] Creating projects for: $proj...
    for f in $proj
    do
	echo [hog init] Creating Vivado project: $f...
	./Hog/CreateProject.sh $f
    done
else
    echo [hog init] "WARNING: No vivado executable found\n"
fi

echo [hog init] All done.
cd $OLD_DIR
