#!/bin/bash
#   Copyright 2018-2023 The University of Birmingham
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

function argument_parser() {
    PARAMS=""
    while (("$#")); do
        case "$1" in
        -doxygen)
            get_doxygen="1"
            shift 1
            ;;
        -token)
            push_token="$2"
            shift 2
            ;;
        -url)
            api="$2"
            shift 2
            ;;
        -proj_id)
            proj="$2"
            shift 2
            ;;
        -mr)
            mr="$2"
            shift 2
            ;;
        -github)
            github="1"
            shift 1
            ;;
        --) # end argument parsing
            shift
            break
            ;;
        -*) # unsupported flags
            Msg Error "Unsupported flag $1" >&2
            return 1
            ;;
        *) # preserve positional arguments
            PARAMS="$PARAMS $1"
            shift
            ;;
        esac
    done
    # set positional arguments in their proper place
}

## @fn help_message
#
# @brief Prints an help message
#
# @param[in]    $1 the invoked command
#
function help_message() {
  echo
  echo " Hog - GetArtifactsAndRename "
  echo " ---------------------------"
  echo " Get the artifacts from collect_artifacts job of the chosen MR"
  echo 
  echo " Usage: $1 [OPTIONS]"
  echo " Options:"
  echo "          -token <push_token>        The GitLab Push Token"
  echo "          -url <gitlab url>          The GitLab CI URL "
  echo "          -proj_id <id>              The ID of the GitLab project "
  echo "          -mr <Merge Request Number> The MR number  "
  echo "          -doxygen                   If sets, get also the artifacts from make_doxygen job."
  echo "          -github                    If sets, use the github API"
  echo

  exit 0
}

argument_parser "$@"

if [ -z "$1" ]; then
    help_message "$0"
else
    if [ "$1" == "-h" ] || [ "$1" == "-help" ] || [ "$1" == "--help" ] || [ "$1" == "-H" ]; then
        help_message "$0"
    fi

    # GET all artifacts from collect_artifacts
    echo "Hog-INFO: downloading artifacts..."
    if [[ $github == "1" ]]; then
        artifact_id=$(curl -H "Accept: application/vnd.github+json" -H "Authorization: token ${push_token}" "$api/repos/$proj/actions/runs/$mr/artifacts" | jq '.artifacts[] | select (.name=="Collect-Artifacts") .id')
        curl -L -H "Accept: application/vnd.github+json" -H "Authorization: token ${push_token}" "$api/repos/$proj/actions/artifacts/$artifact_id/zip" -o collect_artifacts.zip
        echo "Hog-INFO: unzipping artifacts from collect_artifacts job..."
        unzip -oq collect_artifacts.zip -d bin
    else
        ref=refs/merge-requests%2F$mr%2Fhead
        curl --location --header "PRIVATE-TOKEN: ${push_token}" "$api"/projects/"${proj}"/jobs/artifacts/"$ref"/download?job=collect_artifacts -o collect_artifacts.zip
        echo "Hog-INFO: unzipping artifacts from collect_artifacts job..."
        unzip -oq collect_artifacts.zip
    fi

    rm collect_artifacts.zip

    
    # Get artifacts from make_doxygen stage
    if [ "$get_doxygen" == "1" ]; then
        if [[ $github == "1" ]]; then
            artifact_id=$(curl -H "Accept: application/vnd.github+json" -H "Authorization: token ${push_token}" "$api/repos/$proj/actions/runs/$mr/artifacts" | jq '.artifacts[] | select (.name=="Doxygen-Artifacts") .id')
            curl -L -H "Accept: application/vnd.github+json" -H "Authorization: token ${push_token}" "$api/repos/$proj/actions/artifacts/$artifact_id/zip" -o doxygen.zip
            echo "Hog-INFO: unzipping artifacts from make_doxygen job..."
            unzip -oq doxygen.zip -d Doc
        else
            curl --location --header "PRIVATE-TOKEN: ${push_token}" "$api"/projects/"${proj}"/jobs/artifacts/"$ref"/download?job=make_doxygen -o doxygen.zip
            echo "Hog-INFO: unzipping artifacts from make_doxygen job..."
            unzip -oq doxygen.zip 
        fi

        rm doxygen.zip
    fi

    if [[ $github != "1" ]]; then
        # GET all artifacts from user_post stage
        pipeline=$(curl --globoff --header "PRIVATE-TOKEN: ${push_token}" "$api/projects/${proj}/merge_requests/$mr/pipelines" | jq '.[0].id')
        
        job=$(curl --globoff --header "PRIVATE-TOKEN: ${push_token}" "$api/projects/${proj}/pipelines/${pipeline}/jobs" | jq -r '.[0].name')
        
        if [ "$job" != "collect_artifacts" ]; then
            curl --location --header "PRIVATE-TOKEN: ${push_token}" "$api"/projects/"${proj}"/jobs/artifacts/"$ref"/download?job="$job" -o user_post.zip
            echo "Hog-INFO: unzipping artifacts from $job job..."
            unzip -oq user_post.zip
            rm user_post.zip
        fi
    fi

    if [ -d bin ]; then
        # Project names:
        cd bin/ || exit
        PRJ_BITS=$(find . -iname "versions.txt")

        for PRJ_BIT in ${PRJ_BITS}; do
            PRJ_DIR=$(dirname "$PRJ_BIT")
            PRJ_BASE=$(basename "$PRJ_DIR")
            PRJ_NAME="${PRJ_DIR%.*}"
            PRJ_NAME="${PRJ_NAME%-*}"
            PRJ_NAME_BASE=$(basename "$PRJ_NAME")
            PRJ_SHA="${PRJ_DIR##*-hog}"
            PRJ_SHA=${PRJ_SHA/-dirty/} 
	        TAG=$(git tag --sort=creatordate --contain "$PRJ_SHA" -l "v*.*.*" | head -1)
            echo "Hog-INFO: Found project $PRJ_NAME"
            if ! ls "$PRJ_DIR"/"${PRJ_BASE}"* > /dev/null 2>&1; then
                echo "Hog-INFO: Project $PRJ_NAME does not contain any bitfile..."
                PRJ_BINS=""
            else 
                PRJ_BINS=("$(ls "$PRJ_DIR"/"${PRJ_BASE}"*)")
            fi
            # shellcheck disable=SC2048
            for PRJ_BIN in ${PRJ_BINS[*]}; do
                regex="($PRJ_NAME_BASE)-(.*v[0-9]+\.[0-9]+\.[0-9]+)-hog([0-9,a-f,A-F]{7})(-dirty)?(.+)"
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
fi
