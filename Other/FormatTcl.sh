# @Author: Davide Cieri
# @Email : davide.cieri@cern.ch
# @Date:   2020-04-24
# @Last Modified by:   Davide Cieri
# @Last Modified time: 2020-04-27
#!/bin/bash

tcl_dir=$1
OLD_DIR=`pwd`
THIS_DIR="$(dirname "$0")" 

if [ ! -z "${tcl_dir}" ];then
    for f in ${tcl_dir}*; do
        if [ -d "$f" ]; then
            for file in $f/*.tcl; do
                echo "[FormatTcl] Formatting $file..."
                tclsh "${THIS_DIR}"/../Tcl/utils/reformat.tcl -tab_width 2 $file
            done
        fi
        if [[ $f == *.tcl ]]; then
            echo "[FormatTcl] Formatting $f..."
            tclsh "${THIS_DIR}"/../Tcl/utils/reformat.tcl -tab_width 2 $f
        fi
    done
else
    printf "Folder name has not been specified. Usage: \n $0 <folder> \n"
fi
cd "${OLD_DIR}"
