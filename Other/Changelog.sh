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

if [ -z "$1" ]
then
        echo "Usage: Changelog.sh <push token> <Gitlab api url> <project id> <mr id> <file.md> <target_branch>"
else
    push_token=$1
    api=$2
    proj=$3
    mr=$4
    TARGET_BRANCH=$5

    echo "$push_token"
    echo "$api"
    echo "$proj"
    echo "$mr"
    echo "$TARGET_BRANCH"

    git rev-parse --verify "$TARGET_BRANCH" >/dev/null 2>&1
    SRC_BRANCH=$(git rev-parse --abbrev-ref HEAD)

    if [ $? -eq 0 ]; then
        echo "## MR Description"
        curl --request GET --header "PRIVATE-TOKEN: ${push_token}" "$api/projects/${proj}/merge_requests/${mr}" | jq -r ".description"
        echo
        echo 
        echo "## Changelog"
        echo
        git log --no-merges "$SRC_BRANCH" ^origin/"$TARGET_BRANCH" --format=%B -- | grep FEATURE: | sed 's/.*FEATURE: */- /'
        echo
    fi

fi
