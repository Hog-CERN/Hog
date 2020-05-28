# List Files
A directory named _list_ must be in each of the top project-folders.
This directory contains the list files, that are plain text files, used to instruct Hog on how to build your project.
Each list file shall contain the list of the files to be added to the *proj_1* project. Properties can also be specified in the list files, adding them after the file name, separated by any number of spaces.

A generic list file looks therefore like this,

```
    source_dir/file1.vhd <prop_1> <prop_2>
    source_dir/file2.vhd <prop_3>
    source_dir/file3.vhd
```

Hog uses different kinds of list files, identified by their extension:

 - `.src` : used to include HDL files belonging to the same library
 - `.sub` : used to include HDL files belonging to a git submodule
 - `.sim` : used to include files use for simulation of the same library
 - `.con` : used to include constraint files
 - `.prop`: used to set some Vivado properties, such as the number of threads used to build the project.
 - `.ext` : used to include HDL files belonging to an external library

__In .src, .sub, .sim, and .con list files, you must use paths relative to the repository location__ to the files to be included in the project.

__.ext list file must use absolute paths__.
To use the Hog CI, this path must be accessible to the machine performing the git CI, e.g. can be on a protected afs folder.

A list file can also contain another list file, whose content will be then included.


## Source list files (.src)

Hog creates a HDL library[^2] for each `.src` list file and assign all the file included in the list file to that library.
Files with the extension are used to include HDL files belonging to a single library and the .xci files of the IPs used in the library.

For example, if there is a lib_1.src file in the list directory like this:

```bash
    source_dir/file1.vhd
    source_dir/file2.vhd
    source_dir/file3.vhd
    IP/ip1.xci
    IP/ip2.xci
```

the files will be included into the Vivado project in the `lib_1` library. Note that if you include another `.src` list in your `.src` file, this will not be included in your library but will keep the original library name.

To use them in VHDL[^3] you should use the following syntax:

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

The following properties can be specified for files in a `.src` list:

-  `93`: (only for `.vhd` and `.vhdl` files) File type is VHDL 93. If not specified Hog will use VHDL2008.
-  `XDC`: File Type is XDC
-  `nosynth`: File will not be used in synthesis
-  `noimpl`: File will not be used in implementation
-  `nosim`: File will not be used in simulation

[^2]: https://www.xilinx.com/support/documentation/sw_manuals/xilinx11/ise_c_working_with_vhdl_libraries.htm
[^3]: Libraries are ignored in Verilog and SystemVerilog

## Submodule list files (.sub)

To add files from a submodule to your project you must list them in a `.sub` list file.
This tells Hog that those files are taken from a submodule rather than from a library belonging to the main HDL repository.
Hog will not try to evaluate the version of those files, but it will evaluate the git SHA of the submodule.

*NOTE* that the list file must be called as the submodule itself.
For example, if you include the submodule `repo/sub_1/` then the corresponding list file must be `repo/Top/proj/list/sub_1.sub`

The same properties as for the `.src` list can be specified.

## Simulation list files (.sim)
For each `.sim` file, Hog creates a simulation set.
In this file are listed all the HDL files used only for the simulation.
The line corresponding to the file containing the top module of your test bench has the following syntax.

In addition to the properties defined for the `.src` list, you can also specify:

- `topsim=<entity_name>`: Tells Hog that the file contains the entity that will be the top level of the simulation;
- `wavefile`: it indicates the name of the entity you want to set as top level in your simulation (Questasim/Modelsim only);
- `dofile`: it indicates the file containing the signal waveforms to be observed in your simulation (Questasim/Modelsim only);

An example `.sim` list file looks like this
```
tb_source_dir/tb_for_lib1.vhd topsim=tb_lib1
wave_source_dir/wave_lib1.tcl wavefile
do_source_dir/dofile_lib1.do dofile
tb_source_dir/another_file.vhd
```

## Constraint list files (.con)

All constraint files must be included by adding them into the `.con` files.
Both `.xdc` (for Vivado) and `.tcl` files can be added here.
The `nosynth` and `noimpl` properties can be specified here, if required.

For example, a `.con` file looks like:
```
constr_source_dir/constr1.xcf     #constraint used for synthesis and implementation
constr_source_dir/constr2.xcf nosynth     #constraint not used in synthesis
constr_source_dir/constr3.xcf noimpl    #constraint used in synthesis only
```

## Properties list files (.prop)

Properties list files (.prop) are used to collect a small and optional set of Vivado properties.

Currently supported properties:

* `maxThreads <N>`: sets the number of threads used to build the project. Multi-threading is disabled by default to improve the reproducibility of firmware builds.


## External proprietary files (.ext)

External proprietary files that are protected by copyright and cannot be published on the repository shall be included using the \*.ext list file.
__.ext list files must use an absolute path__.
To be able to use the firmware CI, this path must be accessible to the machine performing the git CI, e.g. can be on a protected afs folder.
This procedure has to be used __ONLY__ in the exceptional case of files that can not be published because of copyright.

The \*.ext list file has a special syntax since the md5 hash of each file must be added after the file name, separated by one or more spaces:

```
/afs/cern.ch/project/p/project/restricted/file_1.vhd  725cda057150d688c7970cfc53dc6db6
/afs/cern.ch/project/p/project/restricted/file_2.xci  c15f520db4bdef24f976cb459b1a5421
```

The md5 hash can be obtained by running the md5sum command on a bash shell

```bash
	md5sum <filename>
```

the same checksum can be obtained on the Vivado or QuartusPrime tcl shell by using:

```tcl
md5::md5 -filename <file name>
```

Hog, at synthesis time, checks that all the files are there and that their md5 hash matches the one contained in the list file.

