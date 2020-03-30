#!/bin/bash 
if [ -z "$1" ]                                          
then                                                    
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
