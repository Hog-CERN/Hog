# List Files

This section contains the full instructions on how to build your list files.

## .src files

Files with the .src extension are used to include HDL files belonging to a single library and the .xci files of the IPs used in the library.
HOG will generate a new library for each .src file.
For example if we have a lib_1.src file in our list directory, containing 5 file names inside, like this:

```bash
    ../../lib_1/hdl/file1.vhd
    ../../lib_1/hdl/file2.vhd
    ../../lib_1/hdl/file3.vhd
```

they will be included into the Vivado project in the `lib_1` library. 
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
Properties, like VHDL 2008 compatibility, can be specified after the file name in the list file, separated by any number of spaces. 
Returning to our example, if *file_3.vhd* requires VHDL 2008, then you should specify it like this:

```bash
    ../../lib_1/hdl/file1.vhd 
    ../../lib_1/hdl/file2.vhd
    ../../lib_1/hdl/file3.vhd 2008
```

IP to be included in you project can be 

## .sub files

To add files coming from a submodule to your project you must list them in a .sub list file.
This tells HOG that those files are taken from a submodule rather than from a library belonging to the main HDL repository.
HOG will not try to evaluate the version of those files, but it will evaluate the git SHA of the submodule.

*NOTE* that the list file must be called as the submodule itself. 
Id est, if you include the submodule `repo/sub_1/` then the corresponding list file must be `repo/Top/proj/list/sub_1.sub`

## .sim files

In this file are listed all the HDL files used for simulation only.
The line corresponding to the file containing the top module of your test bench has the following syntax:

```
<path_to_tb>/<test_bench>.vhd topsim=<test_top_level_entity> wavefile=<simulation_set_up>.tcl dofile=<waves>.do
```

* The first entry the file containing your test-bench complete with its relative path from the `Top/<project_name>` folder.
* The second entry is preceded by `topsim=`, it indicates the name of the entity you want to set as top level in your simulation.
* The third entry is preceded by `wavefile=`, it indicates the file containing the tcl script used to launch your simulation.*NOTE* the path assumes the default position is `<repo>/sim/`, any relative path must assume this as default location.
* The fourth entry is preceded by `dofile=`, it indicates the file containing the signal waveforms to be observed in your simulation.

The resulting file should look like this:
```
../../lib_1/tb/hdl/tb_for_lib1.vhd topsim=tb_lib1 wavefile=lib1/wave_lib1.tcl dofile=lib1/dofile_lib1.do
../../lib_1/tb/hdl/FileReader.vhd
../../lib_1/tb/hdl/FileWriter.vhd
```

Hog compiles the Questasim or Modelsim libraries when launching the Hog/Init.sh script.
The simulation libraries are now compiled into the SimulationLib folder by default.

## .con files

All constraint files must be included by adding them to the \*.con files.
Both xdc (for Vivado) and tcl files can be added.
By specifying the property `nosynth` (after the file name, separated by any number of spaces) we can tell Vivado not to use this specific constraint file in synthesis. 
Viceversa, `noimpl` is used to use the constraint in synthesis only

## .ext files

External proprietary files can be included using the \*.ext list file.
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

HOG, at synthesis time, checks that all the files are there and that their md5 hash matches the one contained in the list file.

# NEXT PARTE USED TO BE SOMEWHERE ESLE

## Why so many list files
There are several kinds of list files, depending on the extension: .src, .sub, .sim, .con[^4].
[^4]: Also .ext files exist. They are used to handle external files that are protected by copyright and cannot be published on the repository. Will will not discuss that in this quick guide.

### Source list files
**.src files** contain HDL files used for synthesis taken from the repository. HDL files coming from one .src list-file, are  included into the Vivado project in the same library, named after the .src file itself. For example if we have a lib_1.src file in our list directory, containing file names inside, like this:

```
    ../../lib_1/hdl/file1.vhd
    ../../lib_1/hdl/file2.vhd
    ../../lib_1/hdl/file3.vhd
```

they will be included into the Vivado project in the lib_1 library, as we have already discussed.

Properties, like VHDL 2008 compatibility, can be specified after the file name in the list file, separated by any number of spaces. If _file_3.vhd_  requires VHDL 2008, for example, you should specify it like this:

```
    ../../lib_1/hdl/file1.vhd 
    ../../lib_1/hdl/file2.vhd
    ../../lib_1/hdl/file3.vhd 2008
```

### Constraint list files
**.con** files contain constraint files. Both .xdc (for Vivado) and .tcl files can be added.
By specifying the property `nosynth` (after the file name, separated by any number of spaces) we can tell Vivado not to use this specific constraint file in synthesis.
Viceversa, `noimpl` is used to use the constraint in synthesis only. 


### Simulation list files
Each **.sim files** represent a simulation set and contains HDL files used for simulation only. More importantly, each simulation set (hence each .sim file) must include the HDL file containing the top module of the simulation. The name of the top module must be specified as a property with the keyword `topsim=`. Moreover the .do file and the wave file can be specified, as in the following example:

```
../../lib_1/tb/hdl/tb_for_lib1.vhd topsim=tb_lib1 wavefile=lib1/wave_lib1.tcl dofile=lib1/dofile_lib1.do
../../lib_1/tb/hdl/FileReader.vhd
../../lib_1/tb/hdl/FileWriter.vhd
```

### Submodule list files
**.sub files** contain HDL files used for synthesis taken from git submodules in the project. As described in detail in the more advanced documentation, Hog extracts the version and the git SHA for every library in the project. For the files coming from a submodule though, this is not possible as the subomdule may not have tags in the Hog format. This is why files coming from a submodule must be listed in a .sub file having exactly the same name as the submodule. In this case Hog will only extract the git SHA of the submodule and embed it in the firmware.
