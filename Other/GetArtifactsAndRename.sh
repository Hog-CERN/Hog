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

    # GET all alrifacts
    ref=refs/merge-requests%2F$mr%2Fhead
    curl --location --header "PRIVATE-TOKEN: ${push_token}" $api/projects/${proj}/jobs/artifacts/$ref/download?job=$job -o output.zip
    unzip output.zip


    # Project names:
    PROJECTS=(`ls $DIR/Top`)
    for PROJECT in ${PROJECTS[@]}; do
        PRJ_DIR=`ls bin | grep $PROJECT`
        if [ "$PRJ_DIR" == "" ]; then
            echo "Project $PROJECT binaries not found, skipping it"
            continue
        fi 
        #extract binary from git describe 
        PRJ_BINS=(`ls bin/$PRJ_DIR/${PRJ_DIR}*`)

        for PRJ_BIN in ${PRJ_BINS[@]}; do
            echo "#### $PRJ_BIN"
            EXT="${PRJ_BIN##*.}"
            mv $PRJ_BIN bin/$PRJ_DIR/${PROJECT}-$tag.$EXT
        done
        mv bin/$PRJ_DIR bin/${PROJECT}-$tag  

    done
  

fi
