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

# shellcheck disable=SC2181

#  @brief pase aguments and sets environment variables
#  @param[out] TARGET_BRANCH   master or $2
#  @return                  1 if error or help, else 0

function argument_parser() {
    PARAMS=""
    while (("$#")); do
        case "$1" in
        -b | -branch)
            TARGET_BRANCH=$1
            shift 2
            ;;
        -\? | -h | -help)
            HELP="-h"
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

if [ $# -eq 0 ]; then
    TARGET_BRANCH=master
else
    argument_parser "$@"
fi

if [ $HELP == "-h" ]; then
    printf "Changelog.sh: Usage: \n"
    printf " Changelog.sh [-b <target_branch>]"
    printf "<target_branch> branch with respect to which the changes are checked. If not specified, it will be set to master."
    cd "${OLD_DIR}" || exit
    exit 255
fi

git rev-parse --verify "$TARGET_BRANCH" >/dev/null 2>&1
SRC_BRANCH=$(git rev-parse --abbrev-ref HEAD)

if [ $? -eq 0 ]; then
    echo "## Changelog"
    echo
    git log --no-merges "$SRC_BRANCH" ^origin/"$TARGET_BRANCH" --format=%B -- | grep FEATURE: | sed 's/.*FEATURE: */- /'
    echo
fi
