#!/usr/bin/env bash
#   Copyright 2018-2021 The University of Birmingham
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

## @file Init.sh
. $(dirname "$0")/Other/CommonFunctions.sh

## @fn help_message
#
# @brief Prints an help message
#
# The help message contais both the options availble for the first line of the tcl, both the command usage
# This function uses echo to print to screen
#
# @param[in]    $1 the invoked command
#
function help_message() {
  echo
  echo " Hog - Initialise repository"
  echo " ---------------------------"
  echo " Initialise your Hog-handled firmware repository"
  echo " - (optional) Compile questasim/modelsim/riviera libraries (if questasim executable is found)"
  echo " - (optional) Create vivado projects (if vivado exacutable is found)"
  echo
  exit 0
}

## @fn init
#
# @brief main function, initialize the repository by compiling  simulation libraries and creating projects
#
#
function init() {

  local OLD_DIR=$(pwd)
  local DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

  if [ "$1" == "-h" ] || [ "$1" == "-help" ] || [ "$1" == "--help" ] || [ "$1" == "-H" ]; then
    help_message $0
    exit 0
  fi

  cd "${DIR}"

  COMPILER_FOUND=false

  ##! The script checks if Vivado is installed and set uop on the shell.
  ##! NOTE that these checks are performed using 'which'
  if [ $(which vivado) ]; then
    COMPILER_FOUND=true
    local VIVADO=$(which vivado)
    ##! If Vivado is installed it checks if vsim command is defined (Questasim or Modelsim is installed and set-up in the shell).
    ##! NOTE that these checks are performed using 'which'
    if [ $(which vsim) ]; then
      echo
      ##! If Questasim or Modelsim is installed ask user if he wants to compile
      ##! NOTE use read to grab user input
      ##! NOTE if the user input contains Y or y then is accepted as yes
      read -p "Do you want to compile Questasim libraries for Vivado (this might take some time)? " -n 1 -r
      echo
      if [[ "${REPLY}" =~ ^[Yy]$ ]]; then
        echo [hog init] Compiling Questasim libraries into SimulationLib...
        "${VIVADO}" -mode batch -notrace -source ./Tcl/utils/compile_questalib.tcl
        rm -f ./Tcl/.cxl.questasim.version
        rm -f ./Tcl/compile_simlib.log
        rm -f ./Tcl/modelsim.ini
      else
        read -p "Do you want to compile Modelsim libraries for Vivado (this might take some time)? " -n 1 -r
        echo
        if [[ "${REPLY}" =~ ^[Yy]$ ]]; then
          echo [hog init] Compiling Modelsim libraries into SimulationLib...
          "${VIVADO}" -mode batch -notrace -source ./Tcl/utils/compile_modelsimlib.tcl
          rm -f ./Tcl/.cxl.modelsim.version
          rm -f ./Tcl/compile_simlib.log
          rm -f ./Tcl/modelsim.ini
        else
          ## Riviera
          if [ $(which riviera) ]; then
            echo
            ##! If Riviera is installed ask user if he wants to compile
            ##! NOTE use read to grab user input
            ##! NOTE if the user input contains Y or y then is accepted as yes
            read -p "Do you want to compile Riviera libraries for Vivado (this might take some time)? " -n 1 -r
            echo
            if [[ "${REPLY}" =~ ^[Yy]$ ]]; then
              echo [hog init] Compiling Riviera libraries into SimulationLib...
              "${VIVADO}" -mode batch -notrace -source ./Tcl/utils/compile_riviera.tcl
              rm -f ./Tcl/.cxl.questasim.version
              rm -f ./Tcl/compile_simlib.log
              rm -f ./Tcl/modelsim.ini
            fi
          fi
        fi
      fi
    else
      echo [hog init] "WARNING: No modelsim/questa/riviera executable found, will not compile libraries"
    fi
  fi

  # REpeat compilation using Quartus
  if [ $(which quartus_sh) ]; then
    COMPILER_FOUND=true
    local QUARTUS=$(which quartus_sh)
    ##! If Quartus is installed it checks if vsim command is defined (Questasim or Modelsim is installed and set-up in the shell).
    ##! NOTE that these checks are performed using 'which'
    if [ $(which vsim) ]; then
      echo
      ##! If Questasim or Modelsim is installed ask user if he wants to compile
      ##! NOTE use read to grab user input
      ##! NOTE if the user input contains Y or y then is accepted as yes
      read -p "Do you want to compile Questasim libraries for Quartus (this might take some time)? " -n 1 -r
      echo
      if [[ "${REPLY}" =~ ^[Yy]$ ]]; then
        echo [hog init] Compiling Questasim libraries into SimulationLib...
        mkdir -p "${OLD_DIR}/SimulationLib_quartus/verilog/"
        mkdir -p "${OLD_DIR}/SimulationLib_quartus/vhdl/"
        "${QUARTUS}" --simlib_comp -suppress_messages -tool questasim -language verilog -family all -directory "${OLD_DIR}/SimulationLib_quartus/verilog/"
        "${QUARTUS}" --simlib_comp -suppress_messages -tool questasim -language vhdl -family all -directory "${OLD_DIR}/SimulationLib_quartus/vhdl/"
      else
        read -p "Do you want to compile Modelsim libraries for Quartus (this might take some time)? " -n 1 -r
        echo
        if [[ "${REPLY}" =~ ^[Yy]$ ]]; then
          echo [hog init] Compiling Modelsim libraries into SimulationLib...
          mkdir -p "${OLD_DIR}/SimulationLib_quartus/verilog/"
          mkdir -p "${OLD_DIR}/SimulationLib_quartus/vhdl/"
          "${QUARTUS}" --simlib_comp -suppress_messages -tool modelsim -language verilog -family all -directory "${OLD_DIR}/SimulationLib_quartus/verilog/"
          "${QUARTUS}" --simlib_comp -suppress_messages -tool modelsim -language vhdl -family all -directory "${OLD_DIR}/SimulationLib_quartus/vhdl/"
        fi
      fi
    else
      Msg Warning "No modelsim executable found, will not compile libraries"
    fi
  fi

  if ! $COMPILER_FOUND; then
    Msg Warning "No Vivado or Quartus executable found!"
  fi

  ##! Scan for existing Vivado projects and ask user to automatically create listFiles
  ##! NOTE projects already in Projects directory have already a Hog structure, ignore them
  ##! NOTE use read to grab user input
  ##! NOTE if the user input contains Y or y then is accepted as yes

  Vivado_prjs=$(find $DIR/.. -path $DIR/../Projects -prune -false -o -name *.xpr)

  for Vivado_prj in $Vivado_prjs; do
    echo
    Vivado_prj_base=$(basename $Vivado_prj)
    read -p "Found existing Vivado project $Vivado_prj_base. Do you want to convert it to a Hog compatible project? (creates listfiles and Project tcl file) " -n 1 -r
    echo # (optional) move to a new line
    if [[ "${REPLY}" =~ ^[Yy]$ ]]; then
      Force=""
      if [ -d "$DIR/../Top/${Vivado_prj_base%.*}" ]; then
        read -p "Directory \"Top/${Vivado_prj_base%.*}\" exists. Do you want to overwrite it? " -n 1 -r
        echo # (optional) move to a new line
        if [[ "${REPLY}" =~ ^[Yy]$ ]]; then
          Force=" -force "
        else
          continue
        fi
      fi
      vivado -mode batch -notrace -source $DIR/Tcl/utils/check_list_files.tcl $Vivado_prj -tclargs -recreate $Force -recreate_conf
    fi
  done

  ##! Ask user if he wants to create all projects in the repository
  ##! NOTE use read to grab user input
  ##! NOTE if the user input contains Y or y then is accepted as yes
  echo
  read -p "Do you want to create projects now (can be done later with CreateProject.sh)? " -n 1 -r
  echo # (optional) move to a new line
  if [[ "${REPLY}" =~ ^[Yy]$ ]]; then
    cd ..
    proj=$(search_projects Top)
    echo [hog init] Creating projects for: $proj...
    for f in $proj; do
      echo [hog init] Creating Vivado project: $f...
      ./Hog/CreateProject.sh "${f}"
    done
  fi

  ##! Ask user if he wants to add custom Vivado gui button to automatically update listfiles
  ##! NOTE use read to grab user input
  ##! NOTE if the user input contains Y or y then is accepted as yes
  if [ $(which vivado) ]; then
    echo
    read -p "Do you want to add two buttons to the Vivado GUI to update the list files and the project hog.conf file automatically? " -n 1 -r
    echo # (optional) move to a new line
    if [[ "${REPLY}" =~ ^[Yy]$ ]]; then
      vivado -mode batch -notrace -source $DIR/Tcl/utils/add_hog_custom_button.tcl
    fi
  fi

  ##! Check if v0.0.1 tag exists, and if not ask user if he/she wants to create it.
  cd $DIR/..
  if git rev-parse "v0.0.1" >/dev/null 2>&1; then
    echo "Initial Tag v0.0.1 already exists"
  else
    read -p "Your repository does not have an initial tag v0.0.1 yet. Do you want to create it?" -n 1 -r
    echo # (optional) move to a new line
    if [[ "${REPLY}" =~ ^[Yy]$ ]]; then
      git tag v0.0.1
    fi
  fi

  echo [hog init] All done.
  cd "${OLD_DIR}"
}

print_hog $(dirname "$0")
init $@
