#!/usr/bin/env bash
#   Copyright 2018-2023 The University of Birmingham
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
. $(dirname "$0")/LaunchSimulation.sh



function help_Unic() {
  # echo
  # echo " Hog - Initialise repository"
  echo " ---------------------------"
  echo " USAGE: ./Hog/Hog.sh [GLOBAL OPTIONS] ACTIVITY [ACTIVITY OPTIONS] [PATH TO PROJECT] "
  echo ""
  echo "  HOG OPTIONS"
  echo "    -v / --verbose    : Sets level of verbose"
  echo "    -h / --help       : Show this message" 
  echo "    -o / --colorfull  : enables colorfull logs" 
  echo "" 
  echo "  ACTIVITIES"
  echo "    -I / Init"
  echo "    -C / Create"
  echo "    -W / Workflow"
  echo "    -S / Simulation"
  echo " ---------------------------"
  echo " EXAMPLES:"
  echo " "
  echo "./Hog/Hog.sh -h      : Print this help message"
  echo "./Hog/Hog.sh -C -h   : Print Project Creator help"
  echo ""
  exit 0
}



# function help_Init() {
  #   echo
  #   echo " Hog - Initialise repository"
  #   echo " ---------------------------"
  #   echo " Initialise your Hog-handled firmware repository"
  #   echo " - (optional) Compile questasim/modelsim/riviera libraries (if questasim executable is found)"
  #   echo " - (optional) Create vivado projects (if vivado executable is found)"
  #   echo
  #   exit 0
  # }

# function help_Create() {
  #   echo
  #   echo " Hog - Create HDL project"
  #   echo " ---------------------------"
  #   echo " Create the specified Vivado, Quartus or PlanAhead project"
  #   echo 
  #   echo " The project type is selected using the first line of the hog.conf generating the project"
  #   echo " Following options are available: "
  #   echo " #vivado "
  #   echo " #quartus "
  #   echo " #planahead "
  #   echo
  #   echo " Usage: $1 <project name> [OPTIONS]"
  #   echo " Options:"
  #   echo "          -l/--lib  <sim_lib_path>  Path to simulation library. If not defined it will be set to the HOG_SIMULATION_LIB_PATH environmental library, or if this does not exist to the default $(pwd)/SimulationLib"
  #   echo
  #   echo " Hint: Hog accepts as <project name> both the actual project name and the relative path containing the project configuration. E.g. ./Hog/CreateProject.sh Top/myproj or ./Hog/CreateProject.sh myproj"
  #   exit 0
  # }


ROOT_PROJECT_FOLDER=$(pwd)
LOG_INFO_FILE=$ROOT_PROJECT_FOLDER"/hog_info.log"
LOG_WAR_ERR_FILE=$ROOT_PROJECT_FOLDER"/hog_warning_errors.log"

# msg_counter init

# if [[ -n "$HOG_COLORED" ]]; then
#   new_print_hog $(dirname "$0")
# else
#   print_hog $(dirname "$0")
# fi
# if [[ -n $HOG_LOGGER ]]; then
#   Logger_Init
# fi

# arguments=$*
# new_print_hog $(dirname "$0")
# Logger HogVer $(dirname "$0")

if [ $# == 0 ]; then
  # help_message $0
  help_Unic
  return 1
else 
  #Check if help vist 
  # if [[ "$*" == *"-h"* ]] || [[ "$*" == *"-help"* ]]; then
  #   help_Unic
  #   exit 0
  # fi
  #Check if help vist 
  Msg Warning "$ : $*"
  declare -a args=($*)
  Msg Warning "100 - args : ${args[*]}"

  if [[ "$*" == *"-v"* ]] || [[ "$*" == *"--verbose"* ]]; then
    export DEBUG_VERBOSE=1
    export DEBUG_MODE=1
    Msg Debug "Verbose level"
    delete=("-v" "--verbose")
    for del in "${delete[@]}"
    do
      args=(${args[@]/$del})
    done
    # args="${args[*]/$delete}"
  fi
  ## 
  Msg Debug "Input parameters (${args[*]}) :: ${#args[*]})"

  msg_counter init

  if [[ -n "$HOG_COLORED" ]]; then
    new_print_hog $(dirname "$0")
  else
    print_hog $(dirname "$0")
  fi
  if [[ -n $HOG_LOGGER ]]; then
    Logger_Init
  fi

  # for ((i=0;i<${#$};i++)); do
  #   echo "${i} :: ${$[i]}"
  # done
  # act_finder=0;
  # for arg in "$@"; do
  #   if [[ $arg == "-I" ]] || [[ $arg == "-C" ]] || [[ $arg == "-S" ]] || [[ $arg == "-W" ]] ; then
  #     Msg Debug "Activity detected"
  #     break
  #   fi
  #   if [[ "$arg" == *"-h"* ]] || [[ "$arg" == *"-help"* ]]; then
  #     # echo "Y"
  #     help_Unic
  #     exit 0
  #   fi
  #   # act_ind=act_finder
  #   # fi
  #   # act_finder=$(($act_finder+1))
  #   # echo $arg
  # done
  # exit 0
  
  # if [[ "$*" == *"-h"* ]] || [[ "$*" == *"-help"* ]]; then
  #   # echo "Y"
  #   help_Unic
  #   exit 0
  # fi

  activity=("${args[0]}")
  Msg Warning "activity $activity"

  args=("${args[@]:1}")
  Msg Warning "151 - args : ${args[*]}"
  shift
  case "$activity" in
    -I|Init)
      # echo "Init"
      HogInitFunc "${args[*]}"
      exit 0
    ;;
    -C|Create)
      Msg Info "Create ${args[*]}"
      HogCreateFunc "${args[*]}"
      Hog_exit

    ;;
    -W|Workflow)
      Msg Info " Workflow"
      HogLaunchFunc "${args[*]}"
      # ./Hog/LaunchWorkflow.sh $*
      Hog_exit
    ;;
    -S|Simulation)
      Msg Info " Simulation"
      # ./Hog/LaunchSimulation.sh $*
      HogSimulateFunc "${args[*]}"
      Hog_exit

    ;;
    -h|--help)
      help_Unic
    ;;
    *)
      Msg Error "Activity not recognized"
      help_Unic "$0"
    ;;
  esac
fi


