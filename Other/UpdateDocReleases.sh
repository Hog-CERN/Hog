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

if [ -z "$1" ]; then
    echo "Usage: UpdateDocReleases.sh <note> <tag> [-b]"
    echo " Options:"
    echo "  -b Write beta instead of official in release note title"
else
    file=$1
    tag=$2
    git clone https://$HOG_USER:${EOS_ACCOUNT_PASSWORD}@gitlab.cern.ch/hog/hog-docs.git
    cd hog-docs
    ls
    if [ "$3" == "-b" ]; then
        cp ../$file docs/05-Releases/02-Beta-Releases/$tag.md
        echo -e "# Beta Release $tag\n$(cat docs/05-Releases/02-Beta-Releases/${tag}.md)" >docs/05-Releases/02-Beta-Releases/$tag.md
        git add docs/05-Releases/02-Beta-Releases/$tag.md
        git commit -m "New Beta Release $tag"
        git push
    else
        cp ../$file docs/05-Releases/01-Stable-Releases/$tag.md
        echo -e "# Stable Release $tag \n$(cat docs/05-Releases/01-Stable-Releases/${tag}.md)" >docs/05-Releases/01-Stable-Releases/$tag.md
        git add docs/05-Releases/01-Stable-Releases/$tag.md
        git commit -m "New Stable Release $tag"
        git push
    fi
fi
