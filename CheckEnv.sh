#!/usr/bin/env bash


echo "Hog-INFO: Checking all executables and environment variables needed for Hog"
echo

#################### exectuables
if [ `which vivado 2>/dev/null` ]
then
    CMD=`which vivado`
    echo "Vivado executable found in $CMD"
    echo
    $CMD -version
else
    echo "Hog-ERROR: Vivado executable not found."
fi

echo --------------------------------

if [ `which vsim > /dev/null 2>/dev/null` ]
then
    CMD=`which vsim`
    echo "Modelsim/Questasim executable found in $CMD"
    echo
    $CMD -version
else
    echo "Hog-WARNING: Modelsim/Questasim executable not found."
fi

echo --------------------------------

if [ `which eos > /dev/null 2>/dev/null` ]
then
    CMD=`which eos`
    echo "eos executable found in $CMD"
    echo
    $CMD --version
else
    echo "Hog-ERROR: eos executable not found."
fi
echo ================================
echo

################ variables
echo -n "Variable: HOG_CHECK_SYNTAX"
if [ -z ${HOG_CHECK_SYNTAX+x} ]
then
    echo " is NOT defined."
    echo "Hog will NOT check the syntax. Define this variable if you want Hog to check the syntax after creating the HDL project in Create_Project stage."
else
    echo " is defined"
    echo "Hog will check the syntax just after creating the HDL project in Create_Project stage. The CI job will FAIL if an error is found."
fi
echo --------------------------------

echo -n "Variable: HOG_CHECK_YAMLREF"
if [ -z ${HOG_CHECK_YAMLREF+x} ]
then
    echo " is NOT defined. Define it to enforce coherence between the ref and the Hog."
else
    echo " is defined. Hog will check that the reference to the gitlab-ci.yml file in the Hog repository matches the version of the Hog repository."
fi
echo --------------------------------

echo -n "Variable: HOG_EMAIL"
if [ -z ${HOG_EMAIL+x} ]
then
    echo " is NOT defined. This variable is essential for git to work properly. It should be set to your service's account email."
else
    echo " is defined."
fi
echo --------------------------------

if [ -z ${HOG_IP_EOS_PATH+x} ]
then
    echo "Not defined"
else
    echo "Defined"
fi
echo --------------------------------


if [ -z ${HOG_NO_BITSTREAM+x} ]
then
    echo "Not defined"
else
    echo "Defined"
fi
echo --------------------------------


if [ -z ${HOG_OFFICIAL_BIN_EOS_PATH+x} ]
then
    echo "Not defined"
else
    echo "Defined"
fi
echo --------------------------------


if [ -z ${HOG_PASSWORD+x} ]
then
    echo "Not defined"
else
    echo "Defined"
fi
echo --------------------------------


if [ -z ${HOG_PATH+x} ]
then
    echo "Not defined"
else
    echo "Defined"
fi
echo --------------------------------


if [ -z ${HOG_PUSH_TOKEN+x} ]
then
    echo "Not defined"
else
    echo "Defined"
fi
echo --------------------------------


if [ -z ${EOS_MGM_URL+x} ]
then
    echo "Not defined"
else
    echo "Defined"
fi
echo --------------------------------


if [ -z ${HOG_SIMULATION_LIB_PATH+x} ]
then
    echo "Not defined"
else
    echo "Defined"
fi
echo --------------------------------


if [ -z ${HOG_UNOFFICIAL_BIN_EOS_PATH+x} ]
then
    echo "Not defined"
else
    echo "Defined"
fi
echo --------------------------------


if [ -z ${HOG_USE_DOXYGEN+x} ]
then
    echo "Not defined"
else
    echo "Defined"
fi
echo --------------------------------


if [ -z ${HOG_USER+x} ]
then
    echo "Not defined"
else
    echo "Defined"
fi
echo --------------------------------


if [ -z ${HOG_XIL_LICENSE+x} ]
then
    echo "Not defined"
else
    echo "Defined"
fi
echo ================================
