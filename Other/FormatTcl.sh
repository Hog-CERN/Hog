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

tcl_dir=$1
OLD_DIR=$(pwd)
THIS_DIR="$(dirname "$0")"

if [ -n "$tcl_dir" ]; then
    for f in "$tcl_dir"*; do
        if [ -d "$f" ]; then
            for file in "$f"/*.tcl; do
                echo "[FormatTcl] Formatting $file..."
                tclsh "$THIS_DIR"/../Tcl/utils/reformat.tcl -tab_width 2 "$file"
            done
        fi
        if [[ $f == *.tcl ]]; then
            echo "[FormatTcl] Formatting $f..."
            tclsh "${THIS_DIR}"/../Tcl/utils/reformat.tcl -tab_width 2 "$f"
        fi
    done
else
    printf "Folder name has not been specified. Usage: \n %s <folder> \n" "$0"
fi
cd "$OLD_DIR" || exit
