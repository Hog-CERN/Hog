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
  echo "Usage: MakeGitlabRelease.sh <tag> <file.md> [-load_artifacts] [-b]"
  echo " Options:"
  echo "  -b Write beta instead of official in release note title"
else
  tag=$1
  file=$2

  if [ "$BETA" == "1" ]; then
    version_type="Beta"
  else
    version_type="Official"
  fi

  echo "Creating $version_type release $tag"
  release_name="$version_type version $tag"

  DESC=$(sed -e ':a' -e 'N' -e '$!ba' -e 's/\n/\\\\n/g' "$file")
  DESC="$DESC \n\n ---\n Release note automatically generated by **Hog**."
  # Create Release
  glab release create $tag -n $release_name -N $DESC
fi
