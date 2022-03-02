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

file=$1
current_badges=$(curl --header "PRIVATE-TOKEN: $HOG_PUSH_TOKEN" "$CI_API_V4_URL/projects/${CI_PROJECT_ID}/badges" --request GET)
image_url=$(curl -s --request POST --header "PRIVATE-TOKEN: ${HOG_PUSH_TOKEN}" --form "file=@$file" ${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/uploads | jq -r '.full_path')
echo "Uploaded file $file to $image_url"
badge_name=$(basename -s .svg $file)
badge_exists=0
for badge in $(echo "${current_badges}" | jq -r '.[] | @base64'); do
  _jq() {
    echo ${badge} | base64 --decode | jq -r ${1}
  }
  name=$(_jq '.name')
  id=$(_jq '.id')
  echo $name
  echo $id
  if [[ "$badge_name" == *"$name"* ]]; then
    badge_exists=1
    echo "Badge $badge_name exists, updating it..."
    curl --header "PRIVATE-TOKEN: $HOG_PUSH_TOKEN" "$CI_API_V4_URL/projects/${CI_PROJECT_ID}/badges/1486" --request PUT --data "image_url=https://gitlab.cern.ch/${image_url}"
  fi
done

if [[ $badge_exists == 0 ]]; then
  echo "Badge $badge_name does not exist yet. Creating it..."
  curl --header "PRIVATE-TOKEN: $HOG_PUSH_TOKEN" --request POST --data "link_url=https://gitlab.cern.ch/hog/test/TestFirmware/-/releases&image_url=https://gitlab.cern.ch/${image_url}&name=${badge_name}" "$CI_API_V4_URL/projects/${CI_PROJECT_ID}/badges"
fi
