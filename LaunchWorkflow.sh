#!/bin/bash
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

## @file LaunchImplementation.sh
# @brief launch /Tcl/launchers/launch_implementation.tcl using Vivado

## Import common functions from Other/CommonFunctions.sh in a POSIX compliant way
#
. $(dirname "$0")/Other/CommonFunctions.sh;
print_hog $(dirname "$0")
## @function argument_parser()
#  @brief pase aguments and sets evvironment variables
#  @param[out] IP_PATH      empty or "-eos_ip_path $2"
#  @param[out] NJOBS        empty or "-NJOBS $2"
#  @param[out] NO_BITSTREAM empty or "-no_bitstream"
#  @param[out] SYNTH_ONLY   empty or "-synth_only"
#  @param[out] IMPL_ONLY    empty or "-impl_only"
#  @param[out] NO_RECREATE  empty or "-no_recreate"
#  @param[out] RESET        empty or "-reset"
#  @param[out] CHECK_SYNTAX empty or "-check_syntax"
#  @param[out] EXT_PATH     empty or "-ext_path $2"
#  @param[out] PARAMS       positional parameters
#  @return                  1 if error or help, else 0


function argument_parser() {
PARAMS=""
while (( "$#" )); do
    case "$1" in
	-njobs)
	    NJOBS="-njobs $2"
	    shift 2
	    ;;
	-ip_eos_path)
	    IP_PATH="-ip_eos_path $2"
	    shift 2
	    ;;
	-impl_only)
	    IMPL_ONLY="-impl_only"
	    shift 1
	    ;;
	-no_recreate)
	    NO_RECREATE="-no_recreate"
	    shift 1
	    ;;
	-ext_path)
	    EXT_PATH="-ext_path $2"
	    shift 2
	    ;;
	-no_bitstream)
	    NO_BITSTREAM="-no_bitstream"
	    shift 1
	    ;;
	-synth_only)
	    SYNTH_ONLY="-synth_only"
	    shift 1
	    ;;
	-reset)
	    RESET="-reset"
	    shift 1
	    ;;
	-check_syntax)
	    CHECK_SYNTAX="-check_syntax"
	    shift 1
	    ;;
	-?|-h|-help)
	    HELP="-h"
	    shift 1
	    ;;
	--) # end argument parsing
	    shift
	    break
	    ;;
	-*|--*=) # unsupported flags
	    Msg Error "Unsupported flag $1" >&2
	    return 1
	    ;;
	*) # preserve positional arguments
	    PARAMS="$PARAMS $1"
	    shift
	    ;;
    esac
done
# set positional arguments in their proper place
}

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
argument_parser $@
if [ $? = 1 ]; then
  exit 1
fi
eval set -- "$PARAMS"
if [ -z "$1" ]
then
  printf "Project name has not been specified. Usage: \n"
  printf " LaunchWorkflow.sh <project name> [-reset] [-check_syntax] [-no_bitstream | -synth_only] [-impl_only] [-no_recreate] [-njobs <number of jobs>] [-ext_path <external path>] [-ip_eos_path <path to IP repository on EOS>]\n\n"
  printf " For a detailed explanation of all the option, type LaunchWorkflow.sh <project name> -h.\n"
  printf " The project name is needed by Hog to tell which HDL software to use: Vivado, Quartus, etc.\n\n"
  printf "Possible projects are:"
  printf "`ls $DIR/../Top`"
  cd "${OLD_DIR}"
  exit -1
else
  PROJ=$1
  PROJ_DIR="$DIR/../Top/"$PROJ
  if [ -d "$PROJ_DIR" ]
  then

    #Choose if the project is quastus, vivado, vivado_hls [...]
    select_executable_form_file "$PROJ_DIR/$PROJ.tcl"
    if [ $? != 0 ]
    then
      Msg Error "Failed to get HDL compiler executable for $PROJ_DIR/$PROJ.tcl"
      exit -1
    fi

    if [ ! -f "${HDL_COMPILER}" ]
    then
      Msg Error "HLD compiler executable $HDL_COMPILER not found"
      cd "${OLD_DIR}"
      exit -1
    else
      Msg Info "Using executable: $HDL_COMPILER"
    fi
    if [ $COMMAND = "quartus_sh" ]
    then
      if [ "a$IP_PATH" != "a" ]
      then
        Msg Warning "IP eos path not supported in Quartus mode"
      fi
      ${HDL_COMPILER} $COMMAND_OPT $DIR/Tcl/launchers/launch_quartus.tcl $HELP $RESET $NO_BITSTREAM $SYNTH_ONLY $NJOBS $CHEK_SYNTAX $NO_RECREATE $EXT_PATH $IMPL_ONLY -project $1
    elif [ $COMMAND = "vivado_hls" ]
    then
      Msg Error "Vivado HLS is not yet supported by this script!"
    else
      ${HDL_COMPILER} $COMMAND_OPT $DIR/Tcl/launchers/launch_workflow.tcl -tclargs $HELP $RESET $NO_BITSTREAM $SYNTH_ONLY $IP_PATH $NJOBS $CHEK_SYNTAX $NO_RECREATE $EXT_PATH $IMPL_ONLY $1
    fi
  else
    Msg Error "Project $PROJ not found. Possible projects are:"
    echo "`ls ./Top`"
    cd "${OLD_DIR}"
    exit -1
  fi
fi
