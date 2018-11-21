#!/bin/env bash
OLD_DIR=`pwd`
THIS_DIR="$(dirname "$0")"
if [ "$1" == "-h" ] || [ "$1" == "-help" ] || [ "$1" == "--help" ] || [ "$1" == "-H" ]; then
    echo
    echo " Hog - Create Vivado project"
    echo " ---------------------------"
    echo " Create the secified Vivado project"
    echo
    echo " Usage: $0 <project name>"
    echo
    exit 0
fi

cd "${THIS_DIR}"
if [ "a$1" == "a" ]
then
    echo " Usage: $0 <project name>"
    echo 
    echo "  Possible projects are:"
    ls -1 ../Top
    echo 
else
    DIR="../Top/$1"
    if [ -d "${DIR}" ]
    then
	if [ `which vivado` ]
	then
	    VIVADO=`which vivado`
	else
	    if [ -z ${VIVADO_PATH+x} ]
	    then
	    echo "ERROR: No vivado executable found and no variable VIVADO_PATH set\n"
	    echo " "
	    cd "${OLD_DIR}"
	    exit 
	    else
		echo "VIVADO_PATH is set to '$VIVADO_PATH'"
		VIVADO="$VIVADO_PATH/vivado"
	    fi
	fi
	
	if [ ! -f "${VIVADO}" ]
	then
	    echo "ERROR: Vivado executable $VIVADO not found"
	    exit
	else
	    echo "INFO: using vivado executable: $VIVADO"
	fi
	
	OUT_DIR="../VivadoProject"
	if [ ! -d "${OUT_DIR}" ]
	then
	    mkdir "${OUT_DIR}"
	    echo "INFO: Creating directory $DIR"
	fi

    	echo "INFO: Creating project $1..."
	cd "${DIR}"
	"${VIVADO}" -mode batch -notrace -source $1.tcl
	if [ $? != 0 ]
	then
	    echo "ERROR: Vivado returned an error state."
	fi

    else
	echo "ERROR: project $1 not found: possible projects are: `ls ../Top`"
	echo
    fi
fi
cd "${OLD_DIR}"
