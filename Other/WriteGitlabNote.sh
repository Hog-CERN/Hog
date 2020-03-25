#!/bin/bash 
if [ -z "$1" ]                                          
then                                                    
        echo "Usage: WriteGilabNote.sh <push token> <Gitlab api url> <projec id> <mr id> <file.md>"
else                                                                                                                          
    push_token=$1
    api=$2
    proj=$3
    mr=$4
    file=$5
    
    curl --request POST --header "PRIVATE-TOKEN: ${push_token}" --header "Content-Type: application/json" --data '{"body":"'"`sed -e ':a' -e 'N' -e '$!ba' -e 's/\n/\\\\n/g' $file`"'"}' $api/projects/${proj}/merge_requests/${mr}/notes
fi
