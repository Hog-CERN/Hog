#!/usr/bin/env bash
#   Copyright 2018-2022 The University of Birmingham
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


. $(dirname "$0")/Other/CommonFunctions.sh
. $(dirname "$0")/Init.sh
. $(dirname "$0")/CreateProject.sh
. $(dirname "$0")/LaunchWorkflow.sh

function help_Unic() {
  # echo
  # echo " Hog - Initialise repository"
  echo " ---------------------------"
  echo " USAGE: ./Hog/Hog.sh ACTIVITY [OPTIONS] "
  echo ""
  echo " Activities"
  echo " -I, Init"
  echo " -C, Create"
  echo " -W, Workflow"
  echo " -S, Simulation"
  echo
  exit 0
}

function help_Init() {
  echo
  echo " Hog - Initialise repository"
  echo " ---------------------------"
  echo " Initialise your Hog-handled firmware repository"
  echo " - (optional) Compile questasim/modelsim/riviera libraries (if questasim executable is found)"
  echo " - (optional) Create vivado projects (if vivado exacutable is found)"
  echo
  exit 0
}

function help_Create() {
  echo
  echo " Hog - Create HDL project"
  echo " ---------------------------"
  echo " Create the specified Vivado, Quartus or PlanAhead project"
  echo 
  echo " The project type is selected using the first line of the hog.conf generating the project"
  echo " Following options are available: "
  echo " #vivado "
  echo " #quartus "
  echo " #planahead "
  echo
  echo " Usage: $1 <project name> [OPTIONS]"
  echo " Options:"
  echo "          -l/--lib  <sim_lib_path>  Path to simulation library. If not defined it will be set to the HOG_SIMULATION_LIB_PATH environmnetal library, or if this does not exist to the default $(pwd)/SimulationLib"
  echo
  echo " Hint: Hog accepts as <project name> both the actual project name and the relative path containing the project configuration. E.g. ./Hog/CreateProject.sh Top/myproj or ./Hog/CreateProject.sh myproj"
  exit 0
}


## executed when run
echo " Input parameters ($#) :: $*"
arguments=$*
print_hog $(dirname "$0")


if [ $# == 0 ]; then
  # help_message $0
  help_Unic
  return 1
else 
  activity=$1
  shift
  case "$activity" in
    -I|Init)
      # echo "Init"
      Logger HogInitFunc $@
      exit 0
    ;;
    -C|Create)
      echo " Create $*"
      Logger HogCreateFunc $*
    ;;
    -W|Workflow)
      echo " Workflow"
      Logger HogLaunchFunc $*
      # ./Hog/LaunchWorkflow.sh $*
    ;;
    -S|Simulation)
      echo " Simulation"
      ./Hog/LaunchSimulation.sh $*
    ;;
    *)
      Msg Error "Activity not recognized"
      help_Unic $0
    ;;
  esac
fi