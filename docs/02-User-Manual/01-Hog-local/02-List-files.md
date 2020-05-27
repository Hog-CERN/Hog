# List Files

This section contains the full instructions on how to build your list files. List files are used to create the project, and must contain the list of all the files (vhdl, verilog, testbenches, IPs, constraints, etc.) used in the project, plus some properties.
There are several kinds of list files, depending on the extension: .src, .sim, .con, .sub, .prop, .ext.

## Source list files (.src)

**.src files** contain HDL files used for synthesis taken from the repository.
Files with the .src extension are used to include HDL files belonging to a single library[^2] and the .xci files of the IPs used in the library.
Hog will generate a new library for each .src file[^3].
For example if there is a lib_1.src file in the list directory like this:

```bash
    source_dir/file1.vhd
    source_dir/file2.vhd
    source_dir/file3.vhd
    IP/ip1.xci
    IP/ip2.xci
```

the files will be included into the Vivado project in the `lib_1` library. 
To use them in VHDL[^3] you should use the following syntax:

[^2]: https://www.xilinx.com/support/documentation/sw_manuals/xilinx11/ise_c_working_with_vhdl_libraries.htm
[^3]: Libraries are ignored in verilog and systemVerilog

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
Properties, like VHDL 2008 compatibility, can be specified after the file name in the list file, separated by any number of spaces. 
Returning to our example, if *file_3.vhd* requires VHDL 2008, then you should specify it like this:

```
    source_dir/file1.vhd 
    source_dir/file2.vhd
    source_dir/file3.vhd 2008
```



## Simulation list files (.sim)

In this file are listed all the HDL files used for simulation only.
The line corresponding to the file containing the top module of your test bench has the following syntax:

```
<path_to_tb>/<test_bench>.vhd topsim=<test_top_level_entity> wavefile=<simulation_set_up>.tcl dofile=<waves>.do
```

* The first entry the file containing your test-bench complete with its relative path from the `Top/<project_name>` folder;
* the second entry is preceded by `topsim=`, it indicates the name of the entity you want to set as top level in your simulation;
* the third entry is preceded by `wavefile=`, it indicates the file containing the tcl script used to launch your simulation;
* the fourth entry is preceded by `dofile=`, it indicates the file containing the signal waveforms to be observed in your simulation.

The resulting file should look like this:
```
tb_source_dir/tb_for_lib1.vhd topsim=tb_lib1 wavefile=wave_source_dir/wave_lib1.tcl dofile=do_source_dir/dofile_lib1.do
tb_source_dir/FileReader.vhd
tb_source_dir/FileWriter.vhd
```

Hog compiles the Questasim or Modelsim libraries when launching the Hog/Init.sh script.
The simulation libraries are now compiled into the *SimulationLib* folder by default.

## Constraint list files (.con)

All constraint files must be included by adding them to the \*.con files.
Both xdc (for Vivado) and tcl files can be added.
By specifying the property `nosynth` (after the file name, separated by any number of spaces) we can tell Vivado not to use this specific constraint file in synthesis. 
Viceversa, `noimpl` is used to use the constraint in synthesis only.
E.g.: *constr1.con*
```
constr_source_dir/constr1.xcf     #constraint used for synthesis and implementation
constr_source_dir/constr2.xcf nosynth     #constraint not used in synthesys
constr_source_dir/constr3.xcf noimpl    #constraint used in synthesys only
```
## Submodule list files (.sub)

To add files coming from a submodule to your project you must list them in a .sub list file.
This tells Hog that those files are taken from a submodule rather than from a library belonging to the main HDL repository.
Hog will not try to evaluate the version of those files, but it will evaluate the git SHA of the submodule.

*NOTE* that the list file must be called as the submodule itself. 
Id est, if you include the submodule `repo/sub_1/` then the corresponding list file must be `repo/Top/proj/list/sub_1.sub`

## Properties list files (.prop)

Properties list files (.prop) are used to collect a small and optional set of Vivado properties. 
Currently supported properties:

* `maxThreads <N>`: sets the number of threads used to build the project. Multithreading is disabled by default to improve the reproducibility of firmware builds. 


## External proprietary files (.ext)

External proprietary files that are protected by copyright and cannot be published on the repository shall be included using the \*.ext list file.
__.ext list filse must use an absoute path__.
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

