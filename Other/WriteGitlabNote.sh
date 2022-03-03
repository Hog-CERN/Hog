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
    echo "Usage: WriteGitlabNote.sh <push token> <Gitlab api url> <project id> <mr id> <file.md>"
else
    push_token=$1
    api=$2
    proj=$3
    mr=$4
    file=$5

    curl --request POST --header "PRIVATE-TOKEN: ${push_token}" --header "Content-Type: application/json" --data '{"body":"'"`sed -e ':a' -e 'N' -e '$!ba' -e 's/\n/\\\\n/g' $file`"'"}' $api/projects/${proj}/merge_requests/${mr}/notes
fi
