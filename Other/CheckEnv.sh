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

echo "Hog-INFO: Checking all executables and environment variables needed for Hog-CI (not to run Hog locally)"
echo

#################### exectuables
echo ========= EXECUTABLES ==========

THIS_DIR="$(dirname "$0")"
TOP_DIR=$(realpath $THIS_DIR/../../Top)

. $THIS_DIR/CommonFunctions.sh

if [ -z ${HOG_COMPILER+x} ]; then
    COMPILERS_TO_CHECK=("vivado")
else
    COMPILERS_TO_CHECK=$(echo $HOG_COMPILER | tr -d '[:space:]' | tr ";" "\n")
fi

for HDL_COMPILER in ${COMPILERS_TO_CHECK[@]}; do
    select_command_from_line $HDL_COMPILER
    if [ $? != 0 ]; then
        echo "Failed to select project type: exiting!"
        exit -1
    fi

    if [ $(command -v $COMMAND) ]; then
        CMD=$(command -v $COMMAND)
        echo "HDL env executable found in $CMD"
        echo
        $CMD -version
    else
        echo "$COMMAND executable not found. Hog-CI cannot run."
        FAIL=1
    fi
done

echo --------------------------------

if [ $(command -v vsim) ]; then
    CMD=$(command -v vsim)
    echo "Modelsim/Questasim executable found in $CMD"
    echo
    $CMD -version
else
    echo "Modelsim/Questasim executable not found."
fi

echo --------------------------------

if [ $(command -v eos) ]; then
    CMD=$(command -v eos)
    echo "eos executable found in $CMD"
    echo
    $CMD --version
else
    echo "EOS executable not found."
fi

echo --------------------------------

if [ $(command -v git) ]; then
    CMD=$(command -v git)
    echo "git executable found in $CMD"
    echo
    VER=$($CMD --version)
    echo $VER
    # check the version here!
else
    echo "git executable not found. Hog-CI cannot run."
    FAIL=1
fi
echo ================================
echo

echo ===== ESSENTIAL VARIABLES =====
echo -n "Variable: HOG_USER is "
if [ -z ${HOG_USER+x} ]; then
    echo "NOT defined. This variable is essential for git to work properly. It should be set to the username for your service account (a valid git account)."
    FAIL=1
else
    echo "defined."
fi
echo --------------------------------

echo -n "Variable: HOG_EMAIL is "
if [ -z ${HOG_EMAIL+x} ]; then
    echo "NOT defined. This variable is essential for git to work properly. It should be set to your service's account email."
    FAIL=1
else
    echo "defined."
fi
echo --------------------------------

if ( ! ([ -z ${EOS_MGM_URL+x} ] && [ -z ${HOG_OFFICIAL_BIN_EOS_PATH+x} ])); then
    echo -n "Variable: EOS_PASSWORD is "
    if [ -z ${EOS_PASSWORD+x} ]; then
        if [ -z ${HOG_PASSWORD+x} ]; then
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
    if [ -z ${EOS_USER+x} ]; then
        if [ -z ${HOG_USER+x} ]; then
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

echo -n "Variable: HOG_PUSH_TOKEN is "
if [ -z ${HOG_PUSH_TOKEN+x} ]; then
    echo "NOT defined. This variable is essential for git to work properly. It should be set to a gitlab push token for your service account."
    FAIL=1
else
    echo "defined."
fi

echo ================================
echo

# Almost necessary
echo === SEMI-ESSENTIAL VARIABLES ===
if [[ " ${COMPILERS_TO_CHECK[@]} " =~ "vivado" || " ${COMPILERS_TO_CHECK[@]} " =~ "planAhead" ]]; then

    echo -n "Variable: HOG_XIL_LICENSE is "
    if [ -z ${HOG_XIL_LICENSE+x} ]; then
        echo "NOT defined. If this variable is not set to the license servers separated by comas, you need some alternative way of getting your Xilinx licence (for example a licence file on the machine)."
    else
        echo "defined."
    fi
    echo --------------------------------
fi

if [[ " ${COMPILERS_TO_CHECK[@]} " =~ "quartus" ]]; then
    echo --------------------------------

    echo -n "Variable: LM_LICENSE_FILE is "
    if [ -z ${LM_LICENSE_FILE+x} ]; then
        echo "NOT defined. This variable should be set the Quartus license servers separated by semicolon. If not, you need an alternative way of getting your Quartus licence."
    else
        echo "defined."
    fi
    echo --------------------------------
fi

echo -n "Variable: EOS_MGM_URL is "
if [ -z ${EOS_MGM_URL+x} ]; then
    echo "NOT defined. This variable is essential for EOS to work properly. Hog-Ci will use the deafule value of root://eosuser.cern.ch"
else
    echo "defined."
fi
echo --------------------------------

echo -n "Variable: HOG_PATH is "
if [ -z ${HOG_PATH+x} ]; then
    echo "NOT defined. Hog might work as long as all the necessary executable are in the PATH variable."
else
    echo "defined."
fi
echo "This Variable will be added in front of the regular PATH so it will override in case of conflicts. You can use it to point to the version of Vivado/Quartus and Questasim/Modelsim you want"
echo --------------------------------

echo -n "Variable: HOG_LD_LIBRARY_PATH is "
if [ -z ${HOG_LD_LIBRARY_PATH+x} ]; then
    echo "NOT defined. Hog might work as long as all the necessary library are found."
else
    echo "defined."
fi
echo "This variable will be added in front of the regular LD_LIBRARY_PATH so it will override in case of conflicts."
echo --------------------------------

echo -n "Variable: HOG_SIMULATION_LIB_PATH is "
if [ -z ${HOG_SIMULATION_LIB_PATH+x} ]; then
    echo "NOT defined. Hog-CI will not be able to run Questasim/Modelsim."
else
    echo "defined."
fi
echo --------------------------------

echo -n "Variable: HOG_OFFICIAL_BIN_EOS_PATH is "
if [ -z ${HOG_OFFICIAL_BIN_EOS_PATH+x} ]; then
    echo "NOT defined. Hog-CI will not be able to copy official bitfile to EOS."
else
    echo "defined."
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
if [ -z ${HOG_IP_PATH+x} ]; then
    echo -n "NOT defined. Hog-CI will NOT"
else
    echo -n "defined. Hog-CI will"
fi
echo " use an EOS/LOCAL IP repository to speed up the IP synthesis."
echo --------------------------------

echo -n "Variable: HOG_RESET_FILES is "
if [ -z ${HOG_RESET_FILES+x} ]; then
    echo "NOT defined. Hog-CI will NOT reset any files"
else
    echo "defined. Hog-CI will reset the following files before synthesis, before implementation, and before bitstream: \n $HOG_RESET_FILES"
fi
echo --------------------------------

echo -n "Variable: HOG_TARGET_BRANCH is "
if [ -z ${HOG_TARGET_BRANCH+x} ]; then
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
if [ -z ${HOG_NJOBS+x} ]; then
    echo "NOT defined. Hog-CI will run synthesis and implementation with default number of jobs (4)"
else
    echo "defined. Hog-CI will run synthesis and implementation with $HOG_NJOBS jobs"
fi
echo --------------------------------

echo -n "Variable: HOG_IP_NJOBS is "
if [ -z ${HOG_IP_NJOBS+x} ]; then
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
echo

if [ -z ${FAIL+x} ]; then
    echo "Hog-INFO: Check successfull, you can run Hog-CI on this machine"
else
    echo "Hog-ERROR: At least one essential variable or executable was not defined, Hog-CI cannot start. Check above for details."
    exit 1
fi
