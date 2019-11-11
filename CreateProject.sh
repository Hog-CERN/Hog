#!/usr/bin/env bash
OLD_DIR=`pwd`
THIS_DIR="$(dirname "$0")"
if [ "$1" == "-h" ] || [ "$1" == "-help" ] || [ "$1" == "--help" ] || [ "$1" == "-H" ]; then
    echo
    echo " Hog - Create Vivado project"
    echo " ---------------------------"
    echo " Create the secified Vivado project"
    echo
    echo " Usage: $0 [-hls] <project name>"
    echo
    exit 0
fi

cd "${THIS_DIR}"
if [ -e ../Top ]
then
    DIR=../Top
elif [ -e ../TopHLS ]
then
    DIR=../TopHLS
else
    echo "Hog-ERROR: Top folder not found, Hog is not in a Hog-compatible HDL repository."
    echo
    cd "${OLD_DIR}"
    exit -1
fi

if [ "a$1" == "a" ]
then
    echo " Usage: $0 [-hls] <project name>"
    echo 
    echo "  Possible projects are:"
    ls -1 $DIR
    echo
else
    if [ "$1" == "-hls" ] || [ "$1" == "-HLS" ]
    then
	echo "Hog-INFO: High-Level Synthesis mode"
	PROJ_DIR="../TopHLS"
	viv="vivado_hls"
	VIVADO_OPT="-f"
	if [ "a$2" == "a" ]
	then
	    echo "Hog-ERROR: No HLS project name was specified."
	    echo " Usage: $0 -hls <project name>"
	    echo 
	    echo "  Possible projects are: $DIR"
	    ls -1 $DIR
	    echo	    
	    exit -1
	else
	    PROJ=$2
	fi
    else
	PROJ_DIR="../Top"
	viv="vivado"
	VIVADO_OPT="-mode batch -notrace -source"
	PROJ=$1
    fi
    DIR="$PROJ_DIR/$PROJ"
    
    if [ -d "${DIR}" ]
    then
	if [ `which $viv` ]
	then
	    VIVADO=`which $viv`
	else
	    if [ -z ${VIVADO_PATH+x} ]
	    then
	    echo "Hog-ERROR: No vivado executable found and no variable VIVADO_PATH set\n"
	    echo " "
	    cd "${OLD_DIR}"
	    exit -1
	    else
		echo "VIVADO_PATH is set to '$VIVADO_PATH'"
		VIVADO="$VIVADO_PATH/$viv"
	    fi
	fi
	
	if [ ! -f "${VIVADO}" ]
	then
	    echo "Hog-ERROR: Vivado executable $VIVADO not found"
	    cd "${OLD_DIR}"
	    exit -1
	else
	    echo "Hog-INFO: using executable: $VIVADO"
	fi
	
	OUT_DIR="../VivadoProject"
	if [ ! -d "${OUT_DIR}" ]
	then
	    mkdir "${OUT_DIR}"
	    echo "Hog-INFO: Creating directory $OUT_DIR"
	fi

    	echo "Hog-INFO: Creating project $PROJ..."
	cd "${DIR}"
	"${VIVADO}" $VIV_OPT $PROJ.tcl
	if [ $? != 0 ]
	then
	    echo "Hog-ERROR: Vivado returned an error state."
	    cd "${OLD_DIR}"
	    exit -1
	fi

    else
	echo "Hog-ERROR: project $PROJ not found: possible projects are: `ls $DIR`"
	echo
    fi
fi
cd "${OLD_DIR}"
