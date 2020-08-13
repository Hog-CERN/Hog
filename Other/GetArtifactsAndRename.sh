#!/bin/bash
#   Copyright 2018-2020 The University of Birmingham
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

DIR="$( dirname "${BASH_SOURCE[0]}" )/../.."
OLDDIR="$( pwd )"

if [ -z "$1" ]
then
    echo "Usage: GetArtifactsAndRename.sh <push token> <Gitlab api url> <project id> <merge request number> <job> <tag>"
else
    push_token=$1
    api=$2
    proj=$3
    mr=$4
    job=$5
    tag=$6

    cd $DIR
    # GET all alrifacts
    ref=refs/merge-requests%2F$mr%2Fhead
    curl --location --header "PRIVATE-TOKEN: ${push_token}" $api/projects/${proj}/jobs/artifacts/$ref/download?job=$job -o output.zip
    unzip output.zip

    if [ -d bin ]
    then
	# Project names:
	cd bin/
	PRJ_DIRS=(`ls -d */`)
	for PRJ_DIR in ${PRJ_DIRS[@]}; do
	    PRJ_DIR=`basename $PRJ_DIR`
	    PRJ_NAME="${PRJ_DIR%.*}"
	    PRJ_NAME="${PRJ_NAME%-*}"
	    echo "$PRJ_DIR ----> $PRJ_NAME"
	    PRJ_BINS=(`ls $PRJ_DIR/${PRJ_DIR}*`)
	    for PRJ_BIN in ${PRJ_BINS[@]}; do
		echo "#### $PRJ_BIN"
		EXT="${PRJ_BIN##*.}"
		mv $PRJ_BIN $PRJ_DIR/${PRJ_NAME}-$tag.$EXT
	    done
	    mv $PRJ_DIR ${PRJ_NAME}-$tag
	done

	cd $OLDDIR
    fi

    rm output.zip
fi
