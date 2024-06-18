#!/bin/bash
#   Copyright 2018-2024 The University of Birmingham
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

## Import common functions from Other/CommonFunctions.sh in a POSIX compliant way
#
# shellcheck source=Other/CommonFunctions.sh
. "$(dirname "$0")"/CommonFunctions.sh


## @function argument_parser()
#  @brief parse arguments and sets environment variables
#  @param[out] SIMLIBPATH   empty or "-lib_path $2"
#  @param[out] QUIET        empty or "-quiet"
#  @param[out] SIMSET       empty or "-simset $2"
#  @param[out] PARAMS       positional parameters
#  @return                  1 if error or help, else 0

function argument_parser() {
    PARAMS=""
    while (("$#")); do
        case "$1" in
        -t | -target)
            TARGET_BRANCH=$2
            shift 2
            ;;
        -n | -number)
            NUMBER=$2
            shift 2
            ;;
        -github)
            GITHUB="1"
            shift 1
            ;;
        -r | -repo)
            REPO_NAME=$2
            shift 2
            ;;
        -h | -help)
            HELP="-h"
            shift 1
            ;;
        --) # end argument parsing
            shift
            break
            ;;
        -* ) # unsupported flags
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

function help_message() {
  echo
  echo " Hog - Changelog.sh"
  echo " ---------------------------"
  echo " Writes a changelog for the current merge/pull request"
  echo
  echo
  echo " Usage: $1 [OPTIONS]"
  echo " Options:"
  echo "          -t/-target  <target_branch>  Target branch of the merge/pull request"
  echo "          -n/-number                   The Merge/Pull request number"
  echo "          -github                      If true, runs the GitHub API, otherwise the GitLab. Default false."
  echo "          -r/-repo                     The GitHub repository name."
  echo "          -h                           Print this message."
  echo
}

argument_parser "$@"
if [ $? = 1 ]; then
    exit 1
fi
eval set -- "$PARAMS"
if [ "$HELP" == "-h" ]; then
    help_message "$0"
    exit 1
fi

if [ "$GITHUB" == "1" ]; then
    echo "## Pull Request Description"
    gh api -H "Accept: application/vnd.github+json" /repos/"$REPO_NAME"/pulls/"$NUMBER" | jq -r ".body"
else
    if [ "$NUMBER" != "" ]; then
        echo "## MR Description"
        glab mr view ${NUMBER} -F json | jq -r ".description"
    fi
fi

if [ -z "$TARGET_BRANCH" ]; then
    TARGET_BRANCH="master"
fi

echo
echo

git rev-parse --verify "$TARGET_BRANCH" >/dev/null 2>&1
SRC_BRANCH=$(git rev-parse --abbrev-ref HEAD)

# shellcheck disable=SC2181
if [ $? -eq 0 ]; then
    echo "## Changelog"
    echo
    git log --no-merges "$SRC_BRANCH" ^origin/"$TARGET_BRANCH" --format=%B -- | grep FEATURE: | sed 's/.*FEATURE: */- /'
    echo
fi
