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

function argument_parser() {
  PARAMS=""
  while (("$#")); do
    case "$1" in
    -load_artifacts)
      LOAD=1
      shift 1
      ;;
    -b)
      BETA=1
      shift 1
      ;;
    --) # end argument parsing
      shift
      break
      ;;
    -*) # unsupported flags
      echo "Error: Unsupported flag $1" >&2
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

LOAD=""
BETA=""

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
argument_parser "$@"
if [ $? = 1 ]; then
  exit 1
fi
eval set -- "$PARAMS"

if [ -z "$1" ]; then
  echo "Usage: MakeGitlabRelease.sh <push token> <Gitlab api url> <project id> <tag> <file.md> [-load_artifacts] [-b]"
  echo " Options:"
  echo "  -b Write beta instead of official in release note title"
  echo "  -load_artifacts <project url> Uploads binary files to the release"
else
  push_token=$1
  api=$2
  proj=$3
  tag=$4
  file=$5

  if [ "$BETA" == "1" ]; then
    version_type="Beta"
  else
    version_type="Official"
  fi

  echo "Creating $version_type release $tag"

  if [ "$LOAD" == "" ]; then
    # shellcheck disable=SC2006
    curl -s --request POST --header "PRIVATE-TOKEN: ${push_token}" --header "Content-Type: application/json" --data '{ "name": "'"$version_type"' version: '"$tag"'", "tag_name": "'"$tag"'", "description": "'"`sed -e ':a' -e 'N' -e '$!ba' -e 's/\n/\\\\n/g' "$file"`"' \n\n ---\n Release note automatically generated by **Hog**."}' "$api/projects/${proj}/releases"
  else
    # shellcheck disable=SC2006
    DESC=`sed -e ':a' -e 'N' -e '$!ba' -e 's/\n/\\\\n/g' "$file"`" \n\n### Downloads\nIn case [multipart archives](https://koenaerts.ca/unzip-multi-part-archives-in-linux/) are created (e.g. .z01, .z02, etc.), join the files together, for example with cat and unzip the resulting file.\n\n"
    # escape double quotes
    DESC=$(echo "$DESC" | sed 's/"/\\"/g')

    # READ THE LINK FILE
    input="$DIR/../../project_links.txt"
    OLDIFS=$IFS
    while IFS= read -r line; do
      if [ -z "$line" ]; then
        continue
      elif [ "$line" == " " ]; then
        continue
      fi
      IFS=' '
      LINKS=($line) # convert line into an array
      ext="${LINKS[1]##*.}"
      DESC=$DESC"\n- [${LINKS[0]}.$ext](${LINKS[1]})"
    done <"$input"
    DESC=$DESC"\n\n---\n Release note automatically generated by **Hog**.\n"
    IFS=$OLDIFS
    #- # mark release and link builds in release message
    curl -s --request POST --header "PRIVATE-TOKEN: ${push_token}" --header "Content-Type: application/json" --data '{ "name": "'"$version_type"' version: '"$tag"'", "tag_name": "'"$tag"'", "description": "'"$DESC"'"}' "$api/projects/${proj}/releases"

  fi
fi
