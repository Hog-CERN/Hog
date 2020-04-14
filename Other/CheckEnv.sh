#!/usr/bin/env bash
echo "Hog-INFO: Checking all executables and environment variables needed for Hog-CI (not to run Hog locally)"
echo

#################### exectuables
echo ========= EXECUTABLES ==========
if [ `which vivado 2>/dev/null` ]
then
    CMD=`which vivado`
    echo "Vivado executable found in $CMD"
    echo
    $CMD -version
else
    echo "Vivado executable not found. Hog-CI cannot run."
    FAIL=1
fi

echo --------------------------------

if [ `which vsim 2>/dev/null` ]
then
    CMD=`which vsim`
    echo "Modelsim/Questasim executable found in $CMD"
    echo
    $CMD -version
else
    echo "Modelsim/Questasim executable not found."
fi

echo --------------------------------

if [ `which eos 2>/dev/null` ]
then
    CMD=`which eos`
    echo "eos executable found in $CMD"
    echo
    $CMD --version
else
    echo "EOS executable not found."
fi

echo --------------------------------

if [ `which git 2>/dev/null` ]
then
    CMD=`which git`
    echo "git executable found in $CMD"
    echo
    VER=`$CMD --version`
    echo $VER
    # check the version here!
else
    echo "git executable not found. Hog-CI cannot run."
    FAIL=1
fi
echo ================================
echo

echo ===== ESSENTIAL  VARIABLES =====
echo -n "Variable: HOG_USER is "
if [ -z ${HOG_USER+x} ]
then
    echo "NOT defined. This variable is essential for git to work properly. It should be set to the username for your service account (a valid CERN account)."
    FAIL=1
else
    echo "defined."
fi
echo --------------------------------

echo -n "Variable: HOG_EMAIL is "
if [ -z ${HOG_EMAIL+x} ]
then
    echo "NOT defined. This variable is essential for git to work properly. It should be set to your service's account email."
    FAIL=1
else
    echo "defined."
fi
echo --------------------------------

echo -n "Variable: HOG_PASSWORD is "
if [ -z ${HOG_PASSWORD+x} ]
then
    echo "NOT defined. This variable is essential for git to work properly. It should be set to your service's account password and masked."
    FAIL=1
else
    echo "defined"
fi
echo --------------------------------

echo -n "Variable: HOG_PUSH_TOKEN is "
if [ -z ${HOG_PUSH_TOKEN+x} ]
then
    echo "NOT defined. This variable is essential for git to work properly. It should be set to a gitlab push token for your service account."
    FAIL=1
else
    echo "defined."
fi
echo --------------------------------

echo -n "Variable: HOG_XIL_LICENSE is "
if [ -z ${HOG_XIL_LICENSE+x} ]
then
    echo "NOT defined. You need to set this variable to the license servers separated by comas."
    FAIL=1
else
    echo "defined."
fi
echo ================================
echo

# Almost necessary
echo === SEMI-ESSENTIAL VARIABLES ===
echo -n "Variable: EOS_MGM_URL is "
if [ -z ${EOS_MGM_URL+x} ]
then
    echo "NOT defined. This variable is essential for EOS to work properly. Hog-Ci will use the deafule value of root://eosuser.cern.ch"
else
    echo "defined."
fi
echo --------------------------------

echo -n "Variable: HOG_PATH is "
if [ -z ${HOG_PATH+x} ]
then
    echo "NOT defined. Hog might work as long as all the necessary executable are in the PATH variable."
else
    echo "Defined."
fi
echo "This Variabkle will be added in front of the regular PATH so it will override in case of conflicts. You can use it to point to the version of Vivado/Quartus and Questasim/Modelsim you want"
echo --------------------------------

echo -n "Variable: HOG_SIMULATION_LIB_PATH is "
if [ -z ${HOG_SIMULATION_LIB_PATH+x} ]
then
    echo "NOT defined. Hog-CI will not be able to run Questasim/Modelsim."
else
    echo "Defined."
fi
echo --------------------------------

echo -n "Variable: HOG_UNOFFICIAL_BIN_EOS_PATH is "
if [ -z ${HOG_UNOFFICIAL_BIN_EOS_PATH+x} ]
then
    echo "NOT defined. Hog-CI will not be able to copy bitfile to EOS."
else
    echo "Defined"
fi
echo --------------------------------

echo -n "Variable: HOG_OFFICIAL_BIN_EOS_PATH is "
if [ -z ${HOG_OFFICIAL_BIN_EOS_PATH+x} ]
then
    echo "NOT defined. Hog-CI will not be able to copy official bitfile to EOS."
else
    echo "Defined."
fi
echo ================================
echo

echo ==== OPTIONAL ENV VARIABLES ====
echo -n "Variable: HOG_CHECK_SYNTAX is "
if [[ ${HOG_CHECK_SYNTAX} != 1 ]]
then
    echo "NOT defined."
    echo "Hog will NOT check the syntax. Set this variable to '1' if you want Hog to check the syntax after creating the HDL project in Create_Project stage."
else
    echo "defined"
    echo "Hog will check the syntax just after creating the HDL project in Create_Project stage. The CI job will FAIL if an error is found."
fi
echo --------------------------------

echo -n "Variable: HOG_CHECK_YAMLREF is "
if [[ ${HOG_CHECK_YAMLREF} != 1 ]]
then
    echo "NOT defined. Set this variable to '1' to make CI fail if there is not coherence between the ref and the Hog."
else
    echo "defined. Hog will check that the reference to the gitlab-ci.yml file in the Hog repository matches the version of the Hog repository."
fi
echo --------------------------------

echo -n "Variable: HOG_NO_BITSTREAM is "
if [[ ${HOG_NO_BITSTREAM} != 1 ]]
then
    echo "NOT defined. Hog-CI will run the implementation up to the write_bitstream stage and create bit files."
else
    echo "defined.  Hog-CI will run the implementation but will NOT run the write_bitstream stage and will NOT create bit files."
fi
echo --------------------------------

echo -n "Variable: HOG_IP_EOS_PATH is "
if [ -z ${HOG_IP_EOS_PATH+x} ]
then
    echo -n "NOT defined. Hog-CI will NOT"
else
    echo -n "defined. Hog-CI will"
fi
echo " use EOS as a synthesised IP respository to speed up IP synthesis."
echo --------------------------------

echo -n "Variable: HOG_TARGET_BRANCH is "
if [ -z ${HOG_TARGET_BRANCH+x} ]
then
    echo -n "NOT defined. Default branch for merge is \"master\""
else
    echo -n "Defined. Will merge to ${HOG_TARGET_BRANCH}"
fi
echo --------------------------------

echo -n "Variable: HOG_CREATE_OFFICIAL_RELEASE is "
if [[ ${HOG_CREATE_OFFICIAL_RELEASE} != 1 ]]
then
    echo -n "NOT defined. Hog-CI will NOT"
else
    echo -n "defined. Hog-CI will"
fi
echo " create an official release note using the version and timing summaries taken from the artifact of the projects."
echo --------------------------------

echo -n "Variable: HOG_SYNTH_NJOBS is "
if [ -z ${HOG_SYNTH_NJOBS+x} ]
then
    echo -n "NOT defined. Hog-CI will run synthesis with default number of jobs (4)"
else
    echo -n "defined. Hog-CI will run synthesis with $HOG_SYNTH_NJOBS jobs"
fi
echo --------------------------------

echo -n "Variable: HOG_IMPL_NJOBS is "
if [ -z ${HOG_IMPL_NJOBS+x} ]
then
    echo -n "NOT defined. Hog-CI will run implementation with default number of jobs (4)"
else
    echo -n "defined. Hog-CI will run implementation with $HOG_IMPL_NJOBS jobs"
fi
echo --------------------------------

echo -n "Variable: HOG_USE_DOXYGEN is "
if [[ ${HOG_USE_DOXYGEN} != 1 ]]
then
    echo "NOT defined. Set this variable to 1 to make Hog-CI run Doxygen and copy the official documentation over when you merge to the official branch."
else
    echo "defined. Hog-CI will run Doxygen and copy the official documentation over when you merge to the official branch."
fi
echo ================================
echo



if [ -z ${FAIL+x} ]
then
    echo "Hog-INFO: Check successfull, you can run Hog-CI on this machine"
else
    echo "Hog-ERROR: At least one essitial variable or executable was not defined, Hog-CI cannot start. Check above for details."
    exit -1
fi
