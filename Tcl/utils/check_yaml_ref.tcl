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

# @file
# Checks that the hog submodule sha matches the ref in the .gitlab-ci.yml file

set Name LaunchCheckYamlRef
set hog_path [file normalize "[file dirname [info script]]/.."]

set repo_path [pwd]
cd $hog_path
source ./hog.tcl


Msg Info "Checking if \"ref\" in .gitlab-ci.yml actually matches the included yml file in Hog submodule"

CheckYmlRef $repo_path false

cd $repo_path
