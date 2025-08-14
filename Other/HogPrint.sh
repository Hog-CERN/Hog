#!/usr/bin/env bash
#   Copyright 2018-2025 The University of Birmingham
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



# @fn print_hog
#
# @param[in] $1 path to Hog dir
# @brief prints the hog logo
function print_hog() {
  if [ -z ${1+x} ]; then
    echo "Error: missing input! Got: $1!"
    return 1
  fi
  cd "$1" || exit
  ver=$(git describe --always)
  HOG_GIT_VERSION=$(git describe --always)

  if [[ -v "HOG_COLOR" && "${HOG_COLOR}" =~ ^[0-9]+$ && "${HOG_COLOR}" -gt 0 ]]; then
    if [[ "${HOG_COLOR}" =~ ^[0-9]+$ && "${HOG_COLOR}" -gt 1 ]]; then
      logo_file=./images/hog_logo_full_color.txt
    else
      logo_file=./images/hog_logo_color.txt
    fi
  else
    logo_file=./images/hog_logo.txt
  fi
  if [ -f $logo_file ]; then
    while IFS= read -r line; do
      if [[ "$line" == *"Version:"* ]]; then
        version_str="Version: $HOG_VERSION"
        version_len=${#HOG_VERSION}
        # Replace "Version:" and the following spaces with "Version: $HOG_VERSION"
        line=$(echo "$line" | sed -E "s/(Version:)[ ]{0,$((version_len + 1))}/\1 $HOG_VERSION/")
        # Pad or trim to match original line length
        echo -e "$line"
      else
        echo -e "$line"
      fi
    done < "$logo_file"
    # export HOG_LOGO_PRINTED=1
  # else
  #   Msg Warning "Logo file $logo_file doesn't exist"
  fi
  # echo
  # cat ./images/hog_logo.txt
  # echo " Version: ${ver}"
  # echo
  cd "${OLDPWD}" || exit >> /dev/null
  HogVer "$1"

  return 0
}

function HogVer() {
  echo "Info: Checking the latest available Hog version..."
  if ! check_command timeout
  then
    return 1
  fi

  if [ -z ${1+x} ]; then
    echo "Error: Missing input! You should give the path to your Hog submodule. Got: $1!"
    return 1
  fi

  if [[ -d "$1" ]]; then
    cd "$1" || exit
    current_version=$(git describe --always)
    current_sha=$(git log "$current_version" -1 --format=format:%H)
    timeout 5s git fetch
    master_version=$(git describe origin/master)
    master_sha=$(git log "$master_version" -1 --format=format:%H)
    merge_base=$(git merge-base "$current_sha" "$master_sha")

    # The next line checks if master_sha is an ancestor of current_sha
    if [ "$merge_base" != "$master_sha" ]; then
      echo
      echo "Info: Version $master_version has been released (https://gitlab.cern.ch/hog/Hog/-/releases/$master_version)"
      echo "Info: You should consider updating Hog submodule with the following instructions:"
      echo
      echo "Info: cd Hog && git checkout master && git pull"
      echo
      echo "Info: Remember also to update the ref: in your .gitlab-ci.yml to $master_version"
      echo
    else
      echo "Info: Latest official version is $master_version, nothing to do."
    fi

  fi
  cd ${OLDPWD} || exit >> /dev/null
}

#
# @brief Check if a command is available on the running machine
#
# @param[in]    $1 Command name
# @returns  0 if success, 1 if failure
#
function check_command() {
  if ! command -v "$1" &> /dev/null
  then
    echo "Error: Command $1 could not be found"
    return 1
  fi
  return 0
}
