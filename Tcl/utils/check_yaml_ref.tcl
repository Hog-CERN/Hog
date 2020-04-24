# @file
# Checks that the hog submodule sha matches the ref in the .gitlab-ci.yml file
 
set Name LaunchCheckYamlRef
set path [file normalize "[file dirname [info script]]/.."]
set yamlPath $path/../..

set old_path [pwd]
cd $path
source ./hog.tcl


Msg Info "Checking if \"ref\" in .gitlab-ci.yml actually matches the gitlab-ci file in the Hog submodule"

CheckYmlRef $yamlPath false

cd $old_path

