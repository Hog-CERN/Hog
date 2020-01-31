#!/usr/bin/env bash

OLD_DIR=`pwd`
THIS_DIR="$(dirname "$0")"

if [ "$1" == "-h" ] || [ "$1" == "-help" ] || [ "$1" == "--help" ] || [ "$1" == "-H" ]; then
  echo
  echo " Hog - Create HDL project"
  echo " ---------------------------"
  echo " Create the secified Vivado or Quartus project"
  echo
  echo " Usage: $0 <project name>"
  echo
  exit 0
fi

cd "${THIS_DIR}"
if [ -e ../Top ]
then
  DIR=../Top
else
  echo "Hog-ERROR: Top folder not found, Hog is not in a Hog-compatible HDL repository."
  echo
  cd "${OLD_DIR}"
  exit -1
fi

if [ "a$1" == "a" ]
then
  echo " Usage: $0 <project name>"
  echo 
  echo "  Possible projects are:"
  ls -1 $DIR
  echo
  cd "${OLD_DIR}"
  exit -1
else
  PROJ=$1
  PROJ_DIR="../Top/"$PROJ
fi

TCL_FIRST_LINE=$(head -1 $PROJ_DIR"/"$PROJ".tcl)

if [[ $TCL_FIRST_LINE =~ 'vivado' ]];
then
  if [[ $TCL_FIRST_LINE =~ 'vivadoHLS' ]];
  then
    echo "Hog-INFO: Recognised VivadoHLS project"
    COMMAND="vivado_hls"
    COMMAND_OPT="-f"
  else
    echo "Hog-INFO: Recognised Vivado project"
    COMMAND="vivado"
    COMMAND_OPT="-mode batch -notrace -source"
  fi
elif [[ $TCL_FIRST_LINE =~ 'quartus' ]];
then
  if [[ $TCL_FIRST_LINE =~ 'quartusHLS' ]];
  then
    echo "Hog-ERROR: Intel HLS compiler is not supported!"
    exit -1
  else
    echo "Hog-INFO: Recognised QuartusPrime project"
    COMMAND="quartus_sh"
    COMMAND_OPT="-t"
  fi
elif [[ $TCL_FIRST_LINE =~ 'intelHLS' ]];
then
  echo "Hog-ERROR: Intel HLS compiler is not supported!"
  exit -1
else
  echo "Hog-WARNING: Running in backward compatibility mode"
  echo "Hog-INFO: Recognised Vivado project"
  COMMAND="vivado"
  COMMAND_OPT="-mode batch -notrace -source"
fi

if [ -d "$PROJ_DIR" ]
then
  if [ `which $COMMAND` ]
  then
    HDL_COMPILER=`which $COMMAND`
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

  if [ ! -f "${HDL_COMPILER}" ]
  then
    echo "Hog-ERROR: HLD compiler executable $HDL_COMPILER not found"
    cd "${OLD_DIR}"
    exit -1
  else
    echo "Hog-INFO: using executable: $HDL_COMPILER"
  fi

  echo "Hog-INFO: Creating project $PROJ..."
  cd "${PROJ_DIR}"
  "${HDL_COMPILER}" $COMMAND_OPT $PROJ.tcl
  if [ $? != 0 ]
  then
    echo "Hog-ERROR: HDL compiler returned an error state."
    cd "${OLD_DIR}"
    exit -1
  fi

else
  echo "Hog-ERROR: project $PROJ not found: possible projects are: `ls $DIR`"
  echo
  cd "${OLD_DIR}"
  exit -1
fi

cd "${OLD_DIR}"
exit 0
