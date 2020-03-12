#!/usr/bin/env bash


echo "Hog-INFO: Checking all executables and environment variables needed for Hog"

#################### exectuables
if [ `which vivado` ]
then
    CMD=`which vivado`
    echo "Vivado executable found in $CMD"
    $CMD -version
else
    echo "Hog-ERROR: Vivado executable not found."
fi

if [ `which vsim` ]
then
    CMD=`which vsim`
    echo "Modelsim/Questasim executable found in $CMD"
    $CMD -version
else
    echo "Hog-WARNING: Modelsim/Questasim executable not found."
fi

if [ `which eos` ]
then
    CMD=`which eos`
    echo "eos executable found in $CMD"
    $CMD --version
else
    echo "Hog-ERROR: eos executable not found."
fi

################ variables
if [ -z ${EOS_MGM_URL+x} ]
then
    echo "Not defined"
else
    echo "Defined"
fi

if [ -z ${HOG_CHECK_SYNTAX+x} ]
then
    echo "Not defined"
else
    echo "Defined"
fi

if [ -z ${HOG_CHECK_YAMLREF+x} ]
then
    echo "Not defined"
else
    echo "Defined"
fi

if [ -z ${HOG_EMAIL+x} ]
then
    echo "Not defined"
else
    echo "Defined"
fi

if [ -z ${HOG_IP_EOS_PATH+x} ]
then
    echo "Not defined"
else
    echo "Defined"
fi

if [ -z ${HOG_NO_BITSTREAM+x} ]
then
    echo "Not defined"
else
    echo "Defined"
fi

if [ -z ${HOG_OFFICIAL_BIN_EOS_PATH+x} ]
then
    echo "Not defined"
else
    echo "Defined"
fi

if [ -z ${HOG_PASSWORD+x} ]
then
    echo "Not defined"
else
    echo "Defined"
fi

if [ -z ${HOG_PATH+x} ]
then
    echo "Not defined"
else
    echo "Defined"
fi

if [ -z ${HOG_PUSH_TOKEN+x} ]
then
    echo "Not defined"
else
    echo "Defined"
fi

if [ -z ${HOG_SIMULATION_LIB_PATH+x} ]
then
    echo "Not defined"
else
    echo "Defined"
fi

if [ -z ${HOG_UNOFFICIAL_BIN_EOS_PATH+x} ]
then
    echo "Not defined"
else
    echo "Defined"
fi

if [ -z ${HOG_USE_DOXYGEN+x} ]
then
    echo "Not defined"
else
    echo "Defined"
fi

if [ -z ${HOG_USER+x} ]
then
    echo "Not defined"
else
    echo "Defined"
fi

if [ -z ${HOG_XIL_LICENSE+x} ]
then
    echo "Not defined"
else
    echo "Defined"
fi

