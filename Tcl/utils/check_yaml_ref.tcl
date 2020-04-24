# @file
# Checks that the hog submodule sha matches the ref in the .gitlab-ci.yml file

set Name LaunchCheckYamlRef
set hog_path [file normalize "[file dirname [info script]]/.."]

set repo_path [pwd]
cd $hog_path
source ./hog.tcl


Msg Info "Checking if \"ref\" in .gitlab-ci.yml actually matches the gitlab-ci file in the Hog submodule"

CheckYmlRef $repo_path false

cd $repo_path

