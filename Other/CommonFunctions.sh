#!/usr/bin/env bash
#   Copyright 2018-2025 The University of Birmingham
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

# Get the directory containing the script
script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source ${script_dir}/HogPrint.sh
. ${script_dir}/Logger.sh

## @file CreateProject.sh
#  @brief Create the specified Vivado or Quartus project

## @var FILE_TYPE
#  @brief Global variable used to distinguish tcl project from hog.conf
#
export FILE_TYPE=""

## @var CMD_ARRAY
#  @brief Global array variable used to contain the command(s) to be used
#
export CMD_ARRAY=()

## @var CMD_OPT_ARRAY
#  @brief Global array variable used to contain the options associated to the command(s) to be used
#
export CMD_OPT_ARRAY=()

## @var POST_CMD_OPT_ARRAY
#  @brief Global array variable used to contain the post command(s) options to be used (e.g. -tclargs)
#
export POST_CMD_OPT_ARRAY=()

## @var TOOL_EXECUTABLE
#  @brief Global variable containing the full path to the FPGA/SoC development tool executable to be used
#
export TOOL_EXECUTABLE=""

## @var HOG_GIT_VERSION
#  @brief Global variable containing the full path of the root project folder
#
export HOG_GIT_VERSION=""

## @var DEBUG_VERBOSE
#  @brief Global variable
#
export DEBUG_VERBOSE=4

## @fn select_command_from_line
#
# @brief Selects which command has to be used based on the first line of the tcl
#
# This function:
# - Checks if the line CONTAINS:
#   * vivado
#     + vivadoHLS
#     + vitis
#   * vitis
#   * quartus
#     + quartusHLS
#   * intelHLS
#   * planahead
#   * libero
#   * diamond
#   * ghdl
#
# @param[in]    $1 the first line of the tcl file or a suitable string
# @param[out]   CMD_ARRAY global array variable: the selected command(s)
# @param[out]   CMD_OPT_ARRAY global array variable: the selected command(s) options
# @param[out]   POST_CMD_OPT_ARRAY global array variable: the post command(s) options
#
# @returns  0 if success, 1 if failure
#
function select_command_from_line() {
  if [ -z ${1+x} ]; then
    Msg Error " missing input! Got: $1!"
    return 1
  fi

  local TCL_FIRST_LINE=$1

  if [[ $TCL_FIRST_LINE =~ 'vivado' ]]; then
    if [[ $TCL_FIRST_LINE =~ 'vivadoHLS' ]]; then
      Msg Info " Recognised VivadoHLS project"
      CMD_ARRAY=("vivado_hls")
      CMD_OPT_ARRAY=("-f")
    elif [[ $TCL_FIRST_LINE =~ 'vitis' ]]; then
      Msg Info " Recognised Vivado-Vitis project"
      CMD_ARRAY=("vivado" "xsct")
      CMD_OPT_ARRAY=("-nojournal -nolog -mode batch -notrace -source " "")
      POST_CMD_OPT_ARRAY=("-tclargs ," "")
    else
      Msg Info " Recognised Vivado project"
      CMD_ARRAY=("vivado")
      CMD_OPT_ARRAY=("-nojournal -nolog -mode batch -notrace -source ")
      POST_CMD_OPT_ARRAY=("-tclargs ")
    fi
  elif [[ $TCL_FIRST_LINE =~ 'vitis' ]]; then
    Msg Info " Recognised Vitis project"
    CMD_ARRAY=("xsct")
    CMD_OPT_ARRAY=("")
    POST_CMD_OPT_ARRAY=("")
  elif [[ $TCL_FIRST_LINE =~ 'quartus' ]]; then
    if [[ $TCL_FIRST_LINE =~ 'quartusHLS' ]]; then
      Msg Error " Intel HLS compiler is not supported!"
      return 1
    else
      Msg Info " Recognised QuartusPrime project"
      CMD_ARRAY=("quartus_sh")
      CMD_OPT_ARRAY=("-t ")
    fi
  elif [[ $TCL_FIRST_LINE =~ 'intelHLS' ]]; then
    Msg Error "Intel HLS compiler is not supported!"
    return 1
  elif [[ $TCL_FIRST_LINE =~ 'planahead' ]]; then
    Msg Info " Recognised planAhead project"
    CMD_ARRAY=("planAhead")
    CMD_OPT_ARRAY=("-nojournal -nolog -mode batch -notrace -source ")
    POST_CMD_OPT_ARRAY=("-tclargs")
  elif [[ $TCL_FIRST_LINE =~ 'libero' ]]; then
    Msg Info "Recognised Libero SoC project"
    CMD_ARRAY=("libero")
    CMD_OPT_ARRAY=("SCRIPT:")
    POST_CMD_OPT_ARRAY=("SCRIPT_ARGS:")
  elif [[ $TCL_FIRST_LINE =~ 'diamond' ]]; then
    Msg Info "Recognised Lattice Diamond project"
    CMD_ARRAY=("diamondc")
    CMD_OPT_ARRAY=(" ")
    POST_CMD_OPT_ARRAY=(" ")
  elif [[ $TCL_FIRST_LINE =~ 'ghdl' ]]; then
    Msg Info "Recognised GHDL project"
    CMD_ARRAY=("ghdl")
    CMD_OPT_ARRAY=("")
    POST_CMD_OPT_ARRAY=(" ")
  else
    Msg Warning " You should write #vivado, #quartus or #planahead as first line in your hog.conf file or project Tcl file, assuming Vivado... "
    Msg Info " Recognised Vivado project"
    CMD_ARRAY=("vivado")
    CMD_OPT_ARRAY=("-mode batch -notrace -source")
    POST_CMD_OPT_ARRAY=("-tclargs")
  fi

  return 0
}

## @fn select_command
#
# @brief Selects which command has to be used based on the first line of the tcl/conf file
#
# This function:
# - checks that the tcl file exists
# - gets the first line using head -1
# - calls select_command_from_line()
#
# @param[in]    $1 full path to the tcl/conf file
# @param[out]   CMD_ARRAY  global array variable: the selected command(s)
# @param[out]   CMD_OPT_ARRAY global array variable: the selected command(s) options
#
# @returns  0 for ok, 1 for error
#
function select_command() {
  proj=$(basename "$1")
  conf="$1"/"hog.conf"
  tcl="$1"/"$proj.tcl"

  if [ -f "$conf" ]; then
    file="$conf"
    FILE_TYPE=CONF
  elif [ -f "$tcl" ]; then
    file="$tcl"
    FILE_TYPE=TCL
  else
    Msg Error "No suitable file found in $1!"
    return 1
  fi


  if ! select_command_from_line "$(head -1 "$file")"; then
    Msg Error "Failed to select CMD_ARRAY, CMD_OPT_ARRAY and POST_CMD_OPT_ARRAY"
    return 1
  fi
  return 0
}

## @fn select_compiler_executable
#
# @brief selects the path to the executable to be used for invoking the FPGA/SoC development tool
#
# This function:
# - checks at least 1 argument is passed
# - uses command -v to select the executable
#   * if no executable is found and the command is vivado it uses XILINX_VIVADO
#   *
# - stores the result in a global variable called TOOL_EXECUTABLE
#
# @param[in]    $1 The command to be invoked
# @param[out]   TOOL_EXECUTABLE global variable: the full path to the FPGA/SoC development tool executable (e.g. vivado, xsct, quartus_sh, libero, etc.)
#
# @returns  0 if success, 1 if failure
#
function select_compiler_executable() {
  if [ "a$1" == "a" ]; then
    Msg Error "select_compiler_executable(): Variable CMD_ARRAY is not set!"
    return 1
  fi

  if [ "$(command -v "$1")" ]; then
    TOOL_EXECUTABLE=$(command -v "$1")
  else
    if [ "$1" == "vivado" ]; then
      if [ -z ${XILINX_VIVADO+x} ]; then
        Msg Error "No vivado executable found and no variable XILINX_VIVADO set\n"
        cd "${OLD_DIR}" || exit
        return 1
      elif [ -d "$XILINX_VIVADO" ]; then
        Msg Info "XILINX_VIVADO is set to '$ XILINX_VIVADO'"
        TOOL_EXECUTABLE="$XILINX_VIVADO/bin/$1"
      else
        Msg Error "Failed locate '$1' executable from XILINX_VIVADO: $XILINX_VIVADO"
        return 1
      fi
    elif [ "$1" == "vitis" ]; then
      if [ -z ${XILINX_VITIS+x} ]; then
        Msg Error "No vitis executable found and no variable XILINX_VITIS set\n"
        cd "${OLD_DIR}" || exit
        return 1
      elif [ -d "$XILINX_VITIS" ]; then
        Msg Info "XILINX_VITIS is set to '$ XILINX_VITIS'"
        TOOL_EXECUTABLE="$XILINX_VITIS/bin/$1"
      else
        Msg Error "Failed locate '$1' executable from XILINX_VITIS: $XILINX_VITIS"
        return 1
      fi
    elif [ "$1" == "quartus_sh" ]; then
      if [ -z ${QUARTUS_ROOTDIR+x} ]; then
        Msg Error "No quartus_sh executable found and no variable QUARTUS_ROOTDIR set\n"
        cd "${OLD_DIR}" || exit
        return 1
      else
        Msg Info "QUARTUS_ROOTDIR is set to '$QUARTUS_ROOTDIR'"
        #Decide if you are to use bin or bin 64
        #Note things like $PROCESSOR_ARCHITECTURE==x86 won't work in Windows because this will return the version of the git bash
        if [ -d "$QUARTUS_ROOTDIR/bin64" ]; then
          TOOL_EXECUTABLE="$QUARTUS_ROOTDIR/bin64/$1"
        elif [ -d "$QUARTUS_ROOTDIR/bin" ]; then
          TOOL_EXECUTABLE="$QUARTUS_ROOTDIR/bin/$1"
        else
          Msg Error "Failed locate '$1' executable from QUARTUS_ROOTDIR: $QUARTUS_ROOTDIR"
          return 1
        fi
      fi
    elif [ "$1" == "libero" ]; then
      Msg Error "No libero executable found."
      cd "${OLD_DIR}" || exit
      return 1
    else
      Msg Error "cannot find the executable for $1."
      echo "Probable causes are:"
      echo "- $1 was not setup"
      echo "- command not available on the machine"
      return 1
    fi
  fi

  return 0
}

## @fn select_executable_from_project
#
# @brief Selects which compiler executable has to be used based on the first line of the conf or tcl file
#
# @param[in]    $1 full path to the project dir
# @param[out]   CMD_ARRAY  global array variable: the selected command(s)
# @param[out]   CMD_OPT_ARRAY global array variable: the selected command(s) options
# @param[out]   POST_CMD_OPT_ARRAY global variable: the post command(s) options
# @param[out]   TOOL_EXECUTABLE global variable: the full path to the FPGA/SoC development tool executable
#
# @returns  0 if success, 1 if failure
#
function select_executable_from_project_dir() {
  if [ -z ${1+x} ]; then
    Msg Error "missing input! Got: $1!"
    return 1
  fi

  if ! select_command "$1"; then
    Msg Error "Failed to select project type: exiting!"
    return 1
  fi

  #select full path to executable and place it in TOOL_EXECUTABLE global variable

  if ! select_compiler_executable $CMD_ARRAY; then
    Msg Error "Failed to get $CMD_ARRAY executable"
    return 1
  fi

  return 0
}

# @fn print_hog
#
# @param[in] $1 path to Hog dir
# @brief prints the hog logo
function print_log_hog() {
  if [ -z ${1+x} ]; then
    Msg Error "Missing input! Got: $1!"
    return 1
  fi
  logo_file=$ROOT_PROJECT_FOLDER/Hog/images/hog_logo.txt
  if [ -f $logo_file ]; then
    while IFS= read -r line; do
      if [[ "$line" == *"Version:"* ]]; then
        version_str="Version: $HOG_VERSION"
        version_len=${#HOG_VERSION}
        # Replace "Version:" and the following spaces with "Version: $HOG_VERSION"
        line=$(echo "$line" | sed -E "s/(Version:)[ ]{0,$((version_len + 1))}/\1 $HOG_VERSION/")
        # Pad or trim to match original line length
        echo -e "$line"
      else
        echo -e "$line"
      fi

    done < "$logo_file"

    export HOG_LOGO_PRINTED=1
  else
    Msg Warning "Logo file $logo_file doesn't exist"
  fi
  return 0
}

# @fn new_print_hog
#
# @param[in] $1 path to Hog dir
# @brief prints the hog logo
function new_print_hog() {
  if [ -z ${1+x} ]; then
    Msg Error "missing input! Got: $1!"
    return 1
  fi
  cd "$1"
  HOG_GIT_VERSION=$(git describe --always)
  while IFS= read -r line; do
    echo -e "$line"
  done < ./images/hog_logo_color.txt
  echo
  echo " Version: ${HOG_GIT_VERSION}"
  echo
  echo "***************************************************"
  cd "${OLDPWD}" || exit >> /dev/null
  return 0
}

## @fn search available projects inside input folder
#
# @brief Search all hog projects inside a folder
#
# @param[in]    $1 full path to the dir containing the projects
# @returns  0 if success, 1 if failure
#
function search_projects() {
  if [ -z ${1+x} ]; then
    Msg Error "missing input! Got: $1!"
    return 1
  fi

  if [[ -d "$1" ]]; then
    for dir in "$1"/*; do
      if [ -f "$dir/hog.conf" ]; then
        subname=${dir#*Top/}
        Msg Info $subname
      else
        search_projects "$dir"
      fi
    done
  fi
  return 0
}

## @fn print_projects
#
# @brief Prints a message with projects names
#
# The print_projects takes the directory to search and since search projects will change directory, it requires the directory to which return.
# This function uses echo to print to screen
#
# @param[in]    $1 search directory
# @param[in]    $2 return directory
#
function print_projects() {
    echo
    echo "Possible projects are:"
    echo ""
    search_projects "$1"
    echo
    cd "$2" || exit

}
