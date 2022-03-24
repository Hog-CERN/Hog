#!/bin/bash
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

#DIR="$( dirname "${BASH_SOURCE[0]}" )/../.."
#OLDDIR="$( pwd )"

if [ -z "$1" ]; then
    echo "Usage: GetArtifactsAndRename.sh <push token> <Gitlab api url> <project id> <merge request number> <job>"
else
    push_token=$1
    api=$2
    proj=$3
    mr=$4
    job=$5

    # GET all artifacts from collect_artifacts
    echo "Hog-INFO: downloading artifacts..."
    ref=refs/merge-requests%2F$mr%2Fhead
    curl --location --header "PRIVATE-TOKEN: ${push_token}" "$api"/projects/"${proj}"/jobs/artifacts/"$ref"/download?job="$job" -o output.zip

    # GET all artifacts from user_post stage
    pipeline=$(curl --globoff --header "PRIVATE-TOKEN: ${push_token}" "$api/projects/${proj}/merge_requests/$mr/pipelines" | jq '.[0].id')
    
    job=$(curl --globoff --header "PRIVATE-TOKEN: ${push_token}" "$api/projects/${proj}/pipelines/${pipeline}/jobs" | jq -r '.[0].name')
    
    if [ "$job" != "$5" ]; then
        curl --location --header "PRIVATE-TOKEN: ${push_token}" "$api"/projects/"${proj}"/jobs/artifacts/"$ref"/download?job="$job" -o output1.zip
    fi

    echo "Hog-INFO: unzipping artifacts from $5 job..."
    unzip -oq output.zip
    if [ "$job" != "$5" ]; then
        echo "Hog-INFO: unzipping artifacts from $job job..."
        unzip -oq output1.zip
        rm output1.zip
    fi

    if [ -d bin ]; then
        # Project names:
        cd bin/ || exit
        PRJ_BITS=$(find . -iname "versions.txt")

        for PRJ_BIT in ${PRJ_BITS}; do
            PRJ_DIR=$(dirname "$PRJ_BIT")
            PRJ_BASE=$(basename $PRJ_DIR)
            PRJ_NAME="${PRJ_DIR%.*}"
            PRJ_NAME="${PRJ_NAME%-*}"
            PRJ_NAME_BASE=$(basename $PRJ_NAME)
            PRJ_SHA="${PRJ_DIR##*-hog}"
            PRJ_SHA=$(echo $PRJ_SHA | sed -e 's/-dirty$//')
	    TAG=$(git tag --sort=creatordate --contain "$PRJ_SHA" -l "v*.*.*" | head -1)
            PRJ_BINS=("$(ls "$PRJ_DIR"/"${PRJ_BASE}"*)")
            echo "Hog-INFO: Found project $PRJ_NAME"
            for PRJ_BIN in ${PRJ_BINS[@]}; do
                regex="($PRJ_NAME_BASE)-(.*v[0-9]+\.[0-9]+\.[0-9]+)-hog([0-9,a-f,A-F]{8})(-dirty)?(.+)"
                if [[ $PRJ_BIN =~ $regex ]]
                then
                    re_proj="${BASH_REMATCH[1]}"
                    re_ver="${BASH_REMATCH[2]}"
                    re_hash="${BASH_REMATCH[3]}"
                    re_dirty="${BASH_REMATCH[4]}"
                    re_suffix="${BASH_REMATCH[5]}"
                    EXT=$re_suffix
                else
                    EXT=".${PRJ_BIN##*.}"
                fi
                DST=$PRJ_DIR/${PRJ_NAME_BASE}-$TAG$EXT
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
