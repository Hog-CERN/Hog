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

if [ -z "$1" ]; then
    echo "Usage: GetGitlabArtifact.sh <push token> <Gitlab api url> <project id> <merge request number> <file> <job>"
else
    push_token=$1
    api=$2
    proj=$3
    mr=$4
    file=$5
    job=$6

    ref=refs/merge-requests%2F$mr%2Fhead
    echo $api/projects/${proj}/jobs/artifacts/$ref/raw/$file?job=$job
    curl --header "PRIVATE-TOKEN: ${push_token}" $api/projects/${proj}/jobs/artifacts/$ref/raw/$file?job=$job
fi
