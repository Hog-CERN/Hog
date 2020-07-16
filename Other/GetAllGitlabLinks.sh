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

get_link () {
    OLDIFS=$IFS
    IFS=',' # comma is set as delimiter
    read -ra ADDR <<< "$1" # str is read into an array as tokens separated by IFS
    for LINE in "${ADDR[@]}"; do # access each element of array
        IFS=':' # colomn is set as delimiter
        read -ra DATA <<< "$LINE"
        if [ "${DATA[0]}" == "\"description\"" ]; then
            IFS="
    "
            DESC=$(printf $LINE)
            for L in $DESC; do
                #printf $L
                if [[ "$L" == *"[$2]"* ]]; then
                    echo "$L" | cut -d "(" -f2 | cut -d ")" -f1
                fi
            done
        fi

    done

    IFS=$OLDIFS
}

if [ -z "$1" ]                                          
then                                                    
        echo "Usage: GetAllGitlabLinks.sh <push token> <Gitlab api url> <project id> <merge request number> <job> <project url>"
else                                                                                                                          
    push_token=$1
    api=$2
    proj=$3
    mr=$4
    job=$5
    prj_url=$6
    tag=$7

    # GET all alrifacts
    ref=refs/merge-requests%2F$mr%2Fhead
    echo $api/projects/${proj}/jobs/artifacts/$ref/raw/$file?job=$job
    curl --location --header "PRIVATE-TOKEN: ${push_token}" $api/projects/${proj}/jobs/artifacts/$ref/download?job=$job -o output.zip
    unzip output.zip

    # Project names:
    #cho "" > $DIR/project_versions.txt
    echo "" > $DIR/project_links.txt
    PROJECTS=(`ls $DIR/Top`)
    for PROJECT in ${PROJECTS[@]}; do
        vivado -mode batch -notrace -source $DIR/Hog/Tcl/CI/get_links.tcl -tclargs $DIR/Top/$PROJECT/$PROJECT.tcl
    done
    
    #read version file
    input="$DIR/project_versions.txt"
    while IFS= read -r line
    do
        strarray=($line)
		if [ "${strarray[1]}" == "0" -o "${strarray[1]}" == "$tag" ]; then
            #need to create link for release
            PRJ_BIT=`find $DIR/bin -name ${strarray[0]}\*.bit`
            if [ -z "$PRJ_BIT" ]; then
                echo "Error, cannot find ${strarray[0]} binaries in artifacts"
                continue
            fi
            #zipping files
            PRJ_PATH=`dirname $PRJ_BIT`
            PRJ_DIR=`basename $PRJ_PATH`
            cd $DIR
            zip -r $DIR/${strarray[0]}.zip bin/$PRJ_DIR 
            cd $OLDDIR
            #creating file link
            content=`curl --request POST --header "PRIVATE-TOKEN: ${push_token}" --form "file=@$DIR/${strarray[0]}.zip" ${api}/projects/${proj}/uploads`
            # get the url from the json return
            url=$(jq -r '.url' <<<"$content")
            absolute_url=${prj_url}${url}
            echo "${strarray[0]} $absolute_url" >> $DIR/project_links.txt
        elif [ "${strarray[1]}" = "-1" ]; then
            echo "Error, something wrong with ${strarray[0]} version"
            continue
        else
            #retrieve link from its release
            RELEASE=`curl --header "PRIVATE-TOKEN: ${push_token}" "${api}/projects/${proj}/releases/${strarray[1]}"`
            LINK= get_link $RELEASE ${strarray[0]}.zip
            echo "${strarray[0]} $LINK" >> $DIR/project_links.txt
        fi
    done < "$input"

fi
