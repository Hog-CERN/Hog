#!/usr/bin/env bash
OLD_DIR=`pwd`
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [ "$1" == "-h" ] || [ "$1" == "-help" ] || [ "$1" == "--help" ] || [ "$1" == "-H" ]; then
    echo
    echo " Hog - Initialise repository"
    echo " ---------------------------"
    echo " Initialise your Hog-handled firmware repository"
    echo " - Initialise and update your submodules"
    echo " - (optional) Compile questasim libraries (if questasim executable is found)"
    echo " - (optional) Create vivado projects (if vivado exacutable is found)"
    echo
    exit 0
fi

cd "${DIR}"

if [ `which vivado` ]
then
    VIVADO=`which vivado`
    if [ `which vsim` ]
    then
		echo
		read -p "Do you want to compile Questasim libraries (this might take some time)? " -n 1 -r
		echo  
		if [[ "${REPLY}" =~ ^[Yy]$ ]]
			then
	    	echo [hog init] Compiling Questasim libraries into ../SimulationLib...
	    	"${VIVADO}" -mode batch -notrace -source ./Tcl/compile_questalib.tcl
	    	rm -f ./Tcl/.cxl.questasim.version
	    	rm -f ./Tcl/compile_simlib.log
	    	rm -f ./Tcl/modelsim.ini
		else
			read -p "Do you want to compile Modelsim libraries (this might take some time)? " -n 1 -r
    		echo  
		    if [[  "${REPLY}" =~ ^[Yy]$ ]]
		    then
        		echo [hog init] Compiling Modelsim libraries into ../SimulationLib...
		        "${VIVADO}" -mode batch -notrace -source ./Tcl/compile_modelsimlib.tcl
        		rm -f ./Tcl/.cxl.modelsim.version
		        rm -f ./Tcl/compile_simlib.log
		        rm -f ./Tcl/modelsim.ini
    		fi
		fi
    else
		echo [hog init] "WARNING: No modelsim executable found, will not compile libraries" 
	fi

    echo
    read -p "Do you want to create projects now (can be done later with CreateProject.sh)? " -n 1 -r
    echo    # (optional) move to a new line
    if [[ "${REPLY}" =~ ^[Yy]$ ]]
    then
	cd ../Top
	proj=`ls`
	cd ..
	echo [hog init] Creating projects for: $proj...
	for f in $proj
	do
	    echo [hog init] Creating Vivado project: $f...
	    ./Hog/CreateProject.sh "${f}"
	done
    fi
else
    echo [hog init] "WARNING: No vivado executable found"
fi

echo [hog init] All done.
cd "${OLD_DIR}"
