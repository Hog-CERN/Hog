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
  echo " ------------------------------------------------------ "
  echo " USAGE: ./Hog/Hog.sh [GLOBAL OPTIONS] ACTIVITY PATH_TO_PROJECT [ACTIVITY_OPTIONS]"
  echo ""
  echo "  HOG OPTIONS:"
  echo "    -h , --help     Show this message" 
  echo "    -v LEVEL , --verbose LEVEL "
  echo "                    Sets level of verbose to debug"
  echo "                    If no value is passed verbose is set to 5 - debug"
  echo "    -l , --logger   Enables logger to file"
  echo "                    To make it permanenet and not need to add this option in the calling, please export HOG_LOGGER=1" 
  echo "    -o , --color    Enables colorful logs" 
  echo "                    To make it permanent and not need to add this option in the calling, please export HOG_COLORED=1" 
  echo "" 
  echo "  ACTIVITIES:"
  echo "    -I  PATH_TO_PROJECT [ACTIVITY_OPTIONS] , Init  PATH_TO_PROJECT [ACTIVITY_OPTIONS]"
  echo "                    Initializes the Hog repository" 
  echo "    -C  PATH_TO_PROJECT [ACTIVITY_OPTIONS] , Create  PATH_TO_PROJECT [ACTIVITY_OPTIONS]"
  echo "                    Creates a Projects" 
  echo "    -W  PATH_TO_PROJECT [ACTIVITY_OPTIONS] , Workflow  PATH_TO_PROJECT [ACTIVITY_OPTIONS]"
  echo "                    Launches the tasks to build, synthesize or implement the project " 
  echo "    -S  PATH_TO_PROJECT [ACTIVITY_OPTIONS] , Simulation  PATH_TO_PROJECT [ACTIVITY_OPTIONS]"
  echo "                    Launches the simulation of the project"  
  echo " ------------------------------------------------------ "
  echo " EXAMPLES:"
  echo " "
  echo "./Hog/Hog.sh -h     Print this help message"
  echo "./Hog/Hog.sh -C -h  Print Project Creator help"
  echo "./Hog/Hog.sh -v 2 -l -C Top/MainBlocks/BA3_ucm_divIP/ "
  echo "                    Creates project with logger, and verbosing errors, critical warnings and warnings"
  echo "./Hog/Hog.sh -o -v 6 -l -C Top/MainBlocks/BA3_ucm_divIP/"
  echo "                    Creates project with logger, and verbosing all messages including debug and extra information"
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

msg_counter init
ROOT_PROJECT_FOLDER=$(pwd)
LOG_INFO_FILE=$ROOT_PROJECT_FOLDER"/hog_info.log"
LOG_WAR_ERR_FILE=$ROOT_PROJECT_FOLDER"/hog_warning_errors.log"

if [ $# == 0 ]; then
  # help_message $0
  help_Unic
  return 1
else 

  declare -a args=($*)

  ind_verb=("-v" "--verbose")
  if [[ "$*" == *"-v "* ]] || [[ "$*" == *"--verbose "* ]]; then
    pos_arg=0
    for pos_i_arg in "${args[@]}"; do
      if [[ "$pos_i_arg" == $ind_verb ]]; then break; fi
      pos_arg=$(($pos_arg+1))
    done
    if [[ ${args[$((pos_arg+1))]} == "-"* ]]; then
      DEBUG_VERBOSE=5
      # DEBUG_MODE=5
      Msg Warning "No level of verbose fixed, level will be set to 5(debug)"
      unset -v 'args[pos_arg]'
    else
      DEBUG_VERBOSE=${args[$((pos_arg+1))]}
      # DEBUG_MODE=5
      Msg Debug "Level of verbose set to ($DEBUG_VERBOSE)"
      unset -v 'args[pos_arg]'
      unset -v 'args[$((pos_arg+1))]'
    fi
    Msg Debug "Verbose level debug"
    delete=("-v" "--verbose")
    for del in "${delete[@]}"
    do
      args=(${args[@]/$del})
    done
  else
    DEBUG_VERBOSE=4
    # DEBUG_MODE=0
  fi

  if [[ "$*" == *"-o "* ]] || [[ "$*" == *"--color "* ]]; then
    export HOG_COLORED=1
    Msg Debug "Verbose with colors"
    delete=("-o" "--color")
    for del in "${delete[@]}"
    do
      args=(${args[@]/$del})
    done
  fi

  if [[ "$*" == *"-l"* ]] || [[ "$*" == *"--logger"* ]]; then
    export HOG_LOGGER=1
    Msg Debug "logger to file"
    delete=("-l" "--logger")
    for del in "${delete[@]}"
    do
      args=(${args[@]/$del})
    done
  fi

  ## 
  Msg Debug "Input parameters (${args[*]}) :: ${#args[*]})"

  

  if [[ -n "$HOG_COLORED" ]]; then
    new_print_hog "$(dirname "$0")"
  else
    print_hog "$(dirname "$0")"
  fi
  if [[ -n $HOG_LOGGER ]]; then
    Logger_Init "$*"
  fi

  activity=("${args[0]}")

  args=("${args[@]:1}")

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


