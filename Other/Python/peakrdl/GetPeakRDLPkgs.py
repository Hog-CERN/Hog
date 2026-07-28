#!/usr/bin/env python

import peakrdl_regblock_vhdl
import sys
import os

try:
    from importlib import resources as impresources
except ImportError:
    # Try backported to PY<37 `importlib_resources`.
    import importlib_resources as impresources

project_name = sys.argv[1]
repo_path = sys.argv[2]

out_path = repo_path + "/Projects/" + project_name + "/" + project_name + ".peakrdl"

try:
    os.mkdir(out_path)
except FileExistsError:
    os.rmdir(out_path)
    os.mkdir(out_path)


# use impresources to pull out path the vhdl package src files
ref = impresources.files(peakrdl_regblock_vhdl) / "hdl_src"
with impresources.as_file(ref) as path:
    for entry in path.iterdir():
        pkg_file = impresources.files(peakrdl_regblock_vhdl) / str("hdl_src/" + entry.name)
        with impresources.as_file(pkg_file) as pkg_path:
            filename, file_extension = os.path.splitext(pkg_path)
            if file_extension == ".vhd":
                print (pkg_path)
                os.symlink(pkg_path, os.path.join(out_path, entry.name))