#!/usr/bin/env bash
#   Copyright 2018-2024 The University of Birmingham
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


## @fn help_message
#
# @brief Prints an help message
#
# The help message contains both the options available for the first line of the tcl, both the command usage
# This function uses echo to print to screen
#
# @param[in]    $1 the invoked command
#
function help_message() {
  echo
  echo " Hog - CheckEnv for project"
  echo " ---------------------------"
  echo " Check the environment for the specified project"
  echo
  echo " The project type is selected using the first line of the hog.conf generating the project"
  echo " Following options are available: "
  echo " #vivado "
  echo " #quartus "
  echo " #planahead "
  echo
  echo " Usage: $1 <project name>"
  echo
  echo " Hint: Hog accepts as <project name> both the actual project name and the relative path containing the project configuration. E.g. ./Hog/CreateProject.sh Top/myproj or ./Hog/CreateProject.sh myproj"
}


echo "Hog-INFO: Checking all executables and environment variables needed for Hog-CI (not to run Hog locally)"
echo

OLD_DIR=$(pwd)
THIS_DIR="$(dirname "$0")"
TOP_DIR=$(realpath "$THIS_DIR"/../../Top)
APPTAINER_IMAGE="none"

# shellcheck source=Other/CommonFunctions.sh
. "$THIS_DIR"/CommonFunctions.sh

#Argument parsing
if [[ $# == 0 ]] || [[ $1 == -* ]] ;  then
    help_message "$0"
    print_projects "$TOP_DIR" "$OLD_DIR"
    if [ "$1" == "-h" ] || [ "$1" == "-help" ] || [ "$1" == "--help" ] || [ "$1" == "-H" ]; then
	exit 0;
    else
	echo "Hog-ERROR: no project name was given."
	exit 1;
    fi;
else
    PROJ=$1
    if [[ $PROJ == "Top/"* ]]; then
      PROJ=${PROJ#"Top/"}
    fi
    PROJ_DIR="$TOP_DIR/$PROJ"
    shift
fi;

#Options parsing
while getopts ah: op
do
    case $op in
        a)  if [[ ${*:$OPTIND} == /* ]] ; then
                APPTAINER_IMAGE=${*:$OPTIND}
                OPTIND=$((OPTIND+1))
            else
                echo "Hog-INFO: Apptainer argument expects and absolute path, assuming no image was given"
            fi;;
    	h|*) help_message "$0"
	     print_projects "$TOP_DIR" "$OLD_DIR"
	     exit 0;;
    esac
done

if [ ! "$APPTAINER_IMAGE" == "none" ]; then
    echo ================ APPTAINER ================
    if [ -f "$APPTAINER_IMAGE" ]; then
        if [ "$(command -v apptainer)" ]; then
            CMD=$(command -v apptainer)
            echo "apptainer executable found in $CMD"
            echo
            $CMD --version
            echo
            apptainer exec -H "$(realpath "$THIS_DIR"/../..)" "$APPTAINER_IMAGE" /bin/bash -c "${THIS_DIR}/CheckEnv.sh $PROJ";
            exit $?
        else
            echo "Hog-Warning: apptainer executable not found."
        fi
    else
        echo "Hog-Warning: Apptainer image could not be found in this machine"
    fi
    echo "Hog-INFO: unsetting Apptainer image, trying to run without it"
    echo
    "${THIS_DIR}"/CheckEnv.sh "$PROJ"
    exit $?
fi

cd "${THIS_DIR}" || exit


#################### exectuables
echo ========= EXECUTABLES ==========


if [ -d "$PROJ_DIR" ]; then

    #Choose if the project is quartus, vivado, vivado_hls [...]

    if ! select_command "$PROJ_DIR" ; then
        Msg Error "Failed to select project type: exiting!"
        exit 1
    fi

    #select full path to executable and place it in HDL_COMPILER global variable

    if ! select_compiler_executable "$COMMAND" ; then
        Msg Error "Failed to get HDL compiler executable for $COMMAND"
        exit 1
    fi

    if [ ! -f "${HDL_COMPILER}" ]; then
        Msg Error "HDL compiler executable $HDL_COMPILER not found"
        cd "${OLD_DIR}" || exit
        exit 1
    else
        Msg Info "Using executable: $HDL_COMPILER"
    fi
fi

echo "--------------------------------"

if [ "$(command -v vsim)" ]; then
    CMD=$(command -v vsim)
    echo "Modelsim/Questasim executable found in $CMD"
    echo
    $CMD -version
else
    echo "Modelsim/Questasim executable not found."
fi

echo "--------------------------------"

if [ "$(command -v eos)" ]; then
    CMD=$(command -v eos)
    echo "eos executable found in $CMD"
    echo
    $CMD --version
else
    echo "EOS executable not found."
fi

echo --------------------------------

if [ "$(command -v git)" ]; then
    CMD=$(command -v git)
    echo "git executable found in $CMD"
    echo
    VER=$($CMD --version)
    echo "$VER"
    # check the version here!
else
    echo "git executable not found. Hog-CI cannot run."
    FAIL=1
fi
echo ================================
echo

echo ===== ESSENTIAL VARIABLES =====
echo -n "Variable: HOG_USER is "
if [ -z "$HOG_USER" ]; then
    echo "NOT defined. This variable is essential for git to work properly. It should be set to the username for your service account (a valid git account)."
    FAIL=1
else
    echo "defined."
fi
echo --------------------------------

echo -n "Variable: HOG_EMAIL is "
if [ -z "$HOG_EMAIL" ]; then
    echo "NOT defined. This variable is essential for git to work properly. It should be set to your service's account email."
    FAIL=1
else
    echo "defined."
fi
echo --------------------------------

echo -n "Variable: HOG_PUSH_TOKEN is "
if [ -z "$HOG_PUSH_TOKEN" ]; then
    echo "NOT defined. This variable is essential for git to work properly. It should be set to a gitlab push token for your service account."
    FAIL=1
else
    echo "defined."
fi

if [ -n "$HOG_OFFICIAL_BIN_EOS_PATH" ] || [[ $HOG_OFFICIAL_BIN_PATH == /eos/* ]]; then
    echo -n "Variable: EOS_PASSWORD is "
    if [ -z "$EOS_PASSWORD" ]; then
        if [ -z "$HOG_PASSWORD" ]; then
            echo "NOT defined. This variable is essential to communicate with the CERN EOS cloud, to store IPs and official bitfiles."
            FAIL=1
        else
            echo "NOT defined. Hog will use the variable HOG_PASSWORD instead."
        fi
    else
        echo "defined"
    fi
    echo --------------------------------
    echo -n "Variable: EOS_USER is "
    if [ -z "$EOS_USER" ]; then
        if [ -z "$HOG_USER" ]; then
            echo "NOT defined. This variable is essential to communicate with the CERN EOS cloud, to store IPs and official bitfiles."
            FAIL=1
        else
            echo "NOT defined. Hog will use the variable HOG_PASSWORD instead."
        fi
    else
        echo "defined."
    fi
    echo --------------------------------
fi

if [[ " ${COMPILERS_TO_CHECK[*]} " =~ "libero" ]]; then
    echo -n "Variable: HOG_TCLLIB_PATH is "
    if [ -z "$HOG_TCLLIB_PATH" ]; then
        echo "NOT defined. This variable is essential to run Hog with Tcllib. Please, refer to https://hog.readthedocs.io/en/latest/02-User-Manual/01-Hog-local/13-Libero.html."
        FAIL=1
    else
        echo "defined."
    fi
fi

echo ================================
echo

# Almost necessary
echo "=== SEMI-ESSENTIAL VARIABLES ==="


if [[ " ${COMPILERS_TO_CHECK[*]} " =~ "vivado" || " ${COMPILERS_TO_CHECK[*]} " =~ "planAhead" ]]; then

    echo -n "Variable: HOG_XIL_LICENSE is "
    if [ -z "$HOG_XIL_LICENSE" ]; then
        echo "NOT defined. If this variable is not set to the license servers separated by comas, you need some alternative way of getting your Xilinx license (for example a license file on the machine)."
    else
        echo "defined."
    fi
    echo --------------------------------
fi

if [[ " ${COMPILERS_TO_CHECK[*]} " =~ "quartus" || " ${COMPILERS_TO_CHECK[*]} " =~ "libero" ]]; then
    echo --------------------------------

    echo -n "Variable: LM_LICENSE_FILE is "
    if [ -z "$LM_LICENSE_FILE" ]; then
        echo "NOT defined. This variable should be set the Quartus/Libero license servers separated by semicolon. If not, you need an alternative way of getting your Quartus/Libero license."
    else
        echo "defined."
    fi
    echo --------------------------------
fi

echo -n "Variable: EOS_MGM_URL is "
if [ -z "$EOS_MGM_URL" ]; then
    echo "NOT defined. This variable is essential for EOS to work properly. Hog-Ci will use the default value of root://eosuser.cern.ch"
else
    echo "defined."
fi
echo --------------------------------

echo -n "Variable: HOG_PATH is "
if [ -z "$HOG_PATH" ]; then
    echo "NOT defined. Hog might work as long as all the necessary executable are in the PATH variable."
else
    echo "defined."
fi
echo "This Variable will be added in front of the regular PATH so it will override in case of conflicts. You can use it to point to the version of Vivado/Quartus and Questasim/Modelsim you want"
echo --------------------------------

echo -n "Variable: HOG_LD_LIBRARY_PATH is "
if [ -z "$HOG_LD_LIBRARY_PATH" ]; then
    echo "NOT defined. Hog might work as long as all the necessary library are found."
else
    echo "defined."
fi
echo "This variable will be added in front of the regular LD_LIBRARY_PATH so it will override in case of conflicts."
echo --------------------------------

echo -n "Variable: HOG_SIMULATION_LIB_PATH is "
if [ -z "$HOG_SIMULATION_LIB_PATH" ]; then
    echo "NOT defined. Hog-CI will not be able to run Questasim/Modelsim."
else
    echo "defined."
fi
echo --------------------------------

echo -n "Variable: HOG_OFFICIAL_BIN_PATH is "
if [ -z "$HOG_OFFICIAL_BIN_PATH" ]; then
    echo "NOT defined."
    if [ -z "$HOG_OFFICIAL_BIN_EOS_PATH" ]; then
        echo "Hog-CI will not be able to copy official bitfile to EOS."
    else
        echo "Variable: HOG_OFFICIAL_BIN_EOS_PATH is defined. From Hog2024.1 this variable will be deprecated. Please, use HOG_OFFICIAL_BIN_PATH instead."
    fi
else
    echo "defined. Hog-CI will copy the official bitfiles to $HOG_OFFICIAL_BIN_PATH"
fi
echo ================================
echo

echo ==== OPTIONAL ENV VARIABLES ====
echo -n "Variable: HOG_CHECK_PROJVER is "
if [[ ${HOG_CHECK_PROJVER} != 1 ]]; then
    echo "NOT defined."
    echo "Hog will NOT check the CI project version. Set this variable to '1' if you want Hog to check the CI project version before creating the HDL project in Create_Project stage. If the project has not been changed with respect to the target branch, the CI will skip this project"
else
    echo "defined"
    echo "Hog will check the project version just before creating the HDL project in Create_Project stage. The CI job will SKIP the project pipeline, if it the project has not been modified with respect to the target branch."
fi
echo --------------------------------

echo -n "Variable: HOG_CHECK_SYNTAX is "
if [[ ${HOG_CHECK_SYNTAX} != 1 ]]; then
    echo "NOT defined."
    echo "Hog will NOT check the syntax. Set this variable to '1' if you want Hog to check the syntax after creating the HDL project in Create_Project stage."
else
    echo "defined"
    echo "Hog will check the syntax just after creating the HDL project in Create_Project stage. The CI job will FAIL if an error is found."
fi
echo --------------------------------

echo -n "Variable: HOG_CHECK_YAMLREF is "
if [[ ${HOG_CHECK_YAMLREF} != 1 ]]; then
    echo "NOT defined. Set this variable to '1' to make CI fail if there is not coherence between the ref and the Hog."
else
    echo "defined. Hog will check that the reference to the gitlab-ci.yml file in the Hog repository matches the version of the Hog repository."
fi
echo --------------------------------

echo -n "Variable: HOG_NO_BITSTREAM is "
if [[ ${HOG_NO_BITSTREAM} != 1 ]]; then
    echo "NOT defined. Hog-CI will run the implementation up to the write_bitstream stage and create bit files."
else
    echo "defined.  Hog-CI will run the implementation but will NOT run the write_bitstream stage and will NOT create bit files."
fi
echo --------------------------------

echo -n "Variable: HOG_NO_RESET_BD is "
if [[ ${HOG_NO_RESET_BD} != 1 ]]; then
    echo "NOT defined or not equal to 1. Hog will reset .bd files (if any) before starting synthesis."
else
    echo "defined.  Hog-CI will not reset the .bd files"
fi
echo --------------------------------

echo -n "Variable: HOG_IP_PATH is "
if [ -z "$HOG_IP_PATH" ]; then
    echo -n "NOT defined. Hog-CI will NOT"
else
    echo -n "defined. Hog-CI will"
fi
echo " use an EOS/LOCAL IP repository to speed up the IP synthesis."
echo --------------------------------

echo -n "Variable: HOG_RESET_FILES is "
if [ -z "$HOG_RESET_FILES" ]; then
    echo "NOT defined. Hog-CI will NOT reset any files"
else
    printf "defined. Hog-CI will reset the following files before synthesis, before implementation, and before bitstream: \n %s" "$HOG_RESET_FILES"
fi
echo --------------------------------

echo -n "Variable: HOG_TARGET_BRANCH is "
if [ -z "$HOG_TARGET_BRANCH" ]; then
    echo "NOT defined. Default branch for merge is \"master\""
else
    echo "defined. Will merge to ${HOG_TARGET_BRANCH}"
fi
echo --------------------------------

echo -n "Variable: HOG_CREATE_OFFICIAL_RELEASE is "
if [[ ${HOG_CREATE_OFFICIAL_RELEASE} != 1 ]]; then
    echo -n "NOT defined. Hog-CI will NOT"
else
    echo -n "defined. Hog-CI will"
fi
echo " create an official release note using the version and timing summaries taken from the artifact of the projects."
echo --------------------------------

echo -n "Variable: HOG_NJOBS is "
if [ -z "$HOG_NJOBS" ]; then
    echo "NOT defined. Hog-CI will run synthesis and implementation with default number of jobs (4)"
else
    echo "defined. Hog-CI will run synthesis and implementation with $HOG_NJOBS jobs"
fi
echo --------------------------------

echo -n "Variable: HOG_IP_NJOBS is "
if [ -z "$HOG_IP_NJOBS" ]; then
    echo "NOT defined. Hog-CI will build IPs with default number of jobs (4)"
else
    echo "defined. Hog-CI will build IPs with $HOG_IP_NJOBS jobs"
fi
echo --------------------------------

echo -n "Variable: HOG_USE_DOXYGEN is "
if [[ ${HOG_USE_DOXYGEN} != 1 ]]; then
    echo "NOT defined. Set this variable to 1 to make Hog-CI run Doxygen and copy the official documentation over when you merge to the official branch."
else
    echo "defined. Hog-CI will run Doxygen and copy the official documentation over when you merge to the official branch."
fi
echo ================================

echo -n "Variable: HOG_APPTAINER_IMAGE is "
if [ -z "$HOG_APPTAINER_IMAGE" ]; then
    echo "NOT defined. Hog-CI will not run in an Apptainer container."
else
    echo "defined. Hog-CI will run inside the Apptainer container: $HOG_APPTAINER_IMAGE"
    if [ -n "$HOG_APPTAINER_EXTRA_PATH" ]; then
        echo -n "Variable: HOG_APPTAINER_EXTRA_PATH is defined. Folder $HOG_APPTAINER_EXTRA_PATH will be passed to the Apptainer container."
    fi
fi
echo --------------------------------

echo

if [ -z ${FAIL+x} ]; then
    echo "Hog-INFO: Check successful, you can run Hog-CI on this machine"
else
    echo "Hog-ERROR: At least one essential variable or executable was not defined, Hog-CI cannot start. Check above for details."
    exit 1
fi
