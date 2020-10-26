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

#DIR="$( dirname "${BASH_SOURCE[0]}" )/../.."
#OLDDIR="$( pwd )"

if [ -z "$1" ]
then
    echo "Usage: GetArtifactsAndRename.sh <push token> <Gitlab api url> <project id> <merge request number> <job>"
else
    push_token=$1
    api=$2
    proj=$3
    mr=$4
    job=$5

    # GET all alrifacts
    echo "Hog-INFO: downloading artifacts..."
    ref=refs/merge-requests%2F$mr%2Fhead
    curl --location --header "PRIVATE-TOKEN: ${push_token}" "$api"/projects/"${proj}"/jobs/artifacts/"$ref"/download?job="$job" -o output.zip

    echo "Hog-INFO: unzipping..."
    unzip output.zip

    if [ -d bin ]
    then
        # Project names:
        cd bin/ || exit
        PRJ_DIRS=("$(ls -d ./*/)")
        for PRJ_DIR in ${PRJ_DIRS[@]}; do
            PRJ_DIR=$(basename "$PRJ_DIR")
            PRJ_NAME="${PRJ_DIR%.*}"
            PRJ_NAME="${PRJ_NAME%-*}"
            PRJ_SHA="${PRJ_DIR##*-g}"
            TAG=$(git tag --sort=creatordate --contain "$PRJ_SHA" -l "v*.*.*" | head -1)
            PRJ_BINS=("$(ls "$PRJ_DIR"/"${PRJ_DIR}"*)")
            echo "Hog-INFO: Found project $PRJ_NAME"
            for PRJ_BIN in ${PRJ_BINS[@]}; do
                EXT="${PRJ_BIN##*.}"
                DST=$PRJ_DIR/${PRJ_NAME}-$TAG.$EXT
                echo "Hog-INFO: renaming file $PRJ_BIN --> $DST"
                mv "$PRJ_BIN" "$DST"
            done
            DST=${PRJ_NAME}-$TAG
            echo "Hog-INFO: renaming directory $PRJ_DIR --> $DST"
            mv "$PRJ_DIR" "$DST"
        done
        cd ..
    fi
    rm output.zip
fi
