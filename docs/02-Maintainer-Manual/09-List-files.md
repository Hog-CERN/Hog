# List Files

This section conatinds the full instructions on how to build your list files.

## .src files

Files with the .src extension are used to include HDL files belonging to a single library and the .xci files of the IPs used in the library.
HOG will generate a new library for each .src file.
For example if we have a lib_1.src file in our list directory, containing 5 filenames inside, like this:

```
    ../../lib_1/hdl/file1.vhd
    ../../lib_1/hdl/file2.vhd
    ../../lib_1/hdl/file3.vhd
```

they will be included into the Vivado project in the lib_1 library. 
This means in VHDL to use them you should use the following syntax:

```vhdl
library lib_1
use lib_1.all

...

u_1 : entity lib_1.a_component_in_lib1 
port map(
  clk => clk,
din => din,
dout => dout
):
```
Properties, like VHDL 2008 compatibility, can be specified afer the file name in the list file, separated by any number of spaces. 
Returning to our example, if _file_3.vhd_ requires VHDL 2008, then you should specify it like this:

    ../../lib_1/hdl/file1.vhd 
    ../../lib_1/hdl/file2.vhd
    ../../lib_1/hdl/file3.vhd 2008

IP to be included in you project can be 

## .sub files

To add files from a submodule to your Project you must list them in a .sub list file.
This tells HOG that those files are taken from a submodule rather than from a library belonging to the main HDL repository.
HOG will not try to evaluate the version of those files, but it will evaluate the git SHA of the submodule.

## .sim files

In this file are listed all the HDL files used for simulation only.
Each line in these files has the following synthax:

```
<path_to_tb>/<test_bench>.vhd topsim=<test_top_level_entity> wavefile=<symulation_set_up>.tcl dofile=<waves>.do
```

* The first entry the file containing yout test-bench complete with its relative path from the `Top/<project_name>` folder.
* The second entry is preceded by `topsim=`, it indicates the name of the entity you want to set as top level in your simulation.
* The third entry is preceded by `wavefile=`, it indicates the file containing the tcl script used to lauch your simulation. *NOTE* the path assumes the default position is `<repo>/sim/`, any relative path must assume this as default location.
* The fourth entry is preceded by `dofile=`, it indicates the file containing the signal waveforms to be observed in your simulation.

## .con files

All contratint files (.xdc ) must be included by adding them to the .con files

## .ext files

External proprietary files can be included using the .ext list file.
__.ext list filse must use an absoute path__.
To use the firmware CI this path must be accessible to the machine performing the git CI, e.g. can be on a protected afs folder.
This file has to be used __ONLY__ in the exceptionalcase of files that cannot be published because of copyright.
This file has a special synthax since md5 hash of each file must bne added after the file name, separated by one or more spaces.
The md5 hash can be obtained by running

```console
	md5sum <filename>
```
HOG, at synthesis time, checks that all the files are there and that their md5 hash matches the one in the list file.
