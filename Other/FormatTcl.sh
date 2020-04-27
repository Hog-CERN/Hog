# @Author: Davide Cieri
# @Email : davide.cieri@cern.ch
# @Date:   2020-04-24
# @Last Modified by:   Davide Cieri
# @Last Modified time: 2020-04-27
#!/bin/bash

tcl_dir=$1

if [ ! -z "${tcl_dir}" ];then
    for f in ${tcl_dir}*; do
        if [ -d "$f" ]; then
            for file in $f/*.tcl; do
                echo "[FormatTcl] Formatting $file..."
                tclsh Tcl/utils/reformat.tcl -tab_width 2 $file
            done
        fi
        if [[ $f == *.tcl ]]; then
            echo "[FormatTcl] Formatting $f..."
            tclsh Tcl/utils/reformat.tcl -tab_width 2 $f
        fi
    done
else
    printf "Project name has not been specified. Usage: \n ./Other/FormatTcl.sh <folder> \n"
fi