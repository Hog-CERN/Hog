#!/usr/bin/env tclsh
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

# @file
# Creates two custom buttons in Vivado gui with Hog logo, to update automatically list files and hog.conf

#parsing command options
set parameters {
}

set usage   "Creates two custom buttons in Vivado gui with Hog logo, to update automatically list files and hog.conf.\nUSAGE: $::argv0"


set hog_path [file normalize "[file dirname [info script]]/../.."]


remove_gui_custom_commands -quiet Hog_check
create_gui_custom_command -name Hog_check -description "Check Hog listFiles and hog.conf" -show_on_toolbar -toolbar_icon $hog_path/images/hog_check.png -command "if {\[info exists env(HOG_EXTERNAL_PATH)\]} {set argv \[list \"-ext_path\" \"\$env(HOG_EXTERNAL_PATH)\"]} else { set argv \"\" }; set proj_file \[get_property DIRECTORY \[current_project\]\]; set index \[string last \"Projects/\" \$proj_file\]; set index \[expr \$index - 2\]; set repo_path \[string range \$proj_file 0 \$index\];
source -notrace \$repo_path/Hog/Tcl/utils/check_list_files.tcl; set argv \[list\]"


remove_gui_custom_commands -quiet Hog_listFiles
create_gui_custom_command -name Hog_listFiles -description "Recreate Hog listFiles (overwrites the old ones)" -show_on_toolbar -toolbar_icon $hog_path/images/hog_list.png -command "if {\[info exists env(HOG_EXTERNAL_PATH)\]} {set argv \[list \"-recreate\" \"-force\"\  \"-ext_path\" \"\$env(HOG_EXTERNAL_PATH)\"]} else { set argv \[list \"-recreate\" \"-force\"\] }; set proj_file \[get_property DIRECTORY \[current_project\]\]; set index \[string last \"Projects/\" \$proj_file\]; set index \[expr \$index - 2\]; set repo_path \[string range \$proj_file 0 \$index\];
source -notrace \$repo_path/Hog/Tcl/utils/check_list_files.tcl; set argv \[list\]"


remove_gui_custom_commands -quiet Hog_conf
create_gui_custom_command -name Hog_conf -description "Recreate hog.conf (overwrites the old ones)" -show_on_toolbar -toolbar_icon $hog_path/images/hog_cfg.png -command "if {\[info exists env(HOG_EXTERNAL_PATH)\]} {set argv \[list \"-recreate_conf\" \"-force\"\  \"-ext_path\" \"\$env(HOG_EXTERNAL_PATH)\"]} else { set argv \[list \"-recreate_conf\" \"-force\"\] }; set proj_file \[get_property DIRECTORY \[current_project\]\]; set index \[string last \"Projects/\" \$proj_file\]; set index \[expr \$index - 2\]; set repo_path \[string range \$proj_file 0 \$index\]; source -notrace \$repo_path/Hog/Tcl/utils/check_list_files.tcl; set argv \[list\]"
