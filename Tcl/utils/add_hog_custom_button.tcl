#!/usr/bin/env tclsh
#   Copyright 2018-2020 The University of Birmingham
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
# Creates a custom command in Vivado gui with Hog logo

#parsing command options
set parameters {
}

set usage   "Creates a custom command in Vivado gui with Hog logo.\nUSAGE: $::argv0"


set hog_path [file normalize "[file dirname [info script]]/../.."]

remove_gui_custom_commands -quiet Hog_listFiles
create_gui_custom_command -name Hog_listFiles -description "Recreate Hog listFiles (overwrites the old ones)" -show_on_toolbar -toolbar_icon $hog_path/images/hog.png -command "set argv \[list \"-recreate\" \"-force\"\]; source -notrace \[get_property DIRECTORY \[current_project\]\]/../../Hog/Tcl/utils/check_list_files.tcl; set argv \[list\]"
