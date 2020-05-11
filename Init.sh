#!/usr/bin/env bash
## @file Init.sh
# @brief Scrit to create all the project in this repository and compiling Questasim or Modelsim libraries
# @todo Init.sh: update for Quartus support

OLD_DIR=`pwd`
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

##! if called with -h or, -help or, --help or, -H optiins print help message and exit 
if [ "$1" == "-h" ] || [ "$1" == "-help" ] || [ "$1" == "--help" ] || [ "$1" == "-H" ]; then
  echo
  echo " Hog - Initialise repository"
  echo " ---------------------------"
  echo " Initialise your Hog-handled firmware repository"
  echo " - (optional) Compile questasim libraries (if questasim executable is found)"
  echo " - (optional) Create vivado projects (if vivado exacutable is found)"
  echo
  exit 0
fi

cd "${DIR}"

##! The script checks if Vivado is installed and set uop on the shell. 
##! NOTE that these checks are performed using 'which'
if [ `which vivado` ]
then
  VIVADO=`which vivado`
  ##! If Vivado is installed it checks if vsim command is defined (Questasim or Modelsim is installed and set-up in the shell). 
  ##! NOTE that these checks are performed using 'which'
  if [ `which vsim` ]
  then
    echo
    ##! If Questasim or Modelsim is installed ask user if he wants to compile
    ##! NOTE use read to grab user input
    ##! NOTE if the user input contains Y or y then is accepted as yes
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

  ##! If Vivado is installed ask user if he wants to create all projects in the repository
  ##! NOTE use read to grab user input
  ##! NOTE if the user input contains Y or y then is accepted as yes
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
