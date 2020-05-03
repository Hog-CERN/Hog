# Other useful Hog features

## Wrapper scripts

There is a set of scripts that can be used to run synthesis, implementation and bitstream generation without opening the vivado gui. The commands to launch them are

```console
	./Hog/LaunchSynthesis.sh <proj_name>
	./Hog/LaunchIPSynth.sh <proj_name>	
	./Hog/LaunchImplementation.sh <proj_name>
	./Hog/LaunchWriteBistream.sh <proj_name>
```

These scripts call the Tcl scripts contained in Hog/Tcl/launchers that are used in the continuous integration. But as the work perfectly even locally, we wrapped them in these shell scripts so that you can use them locally if you don't want to open the GUI.

Launching the implementation or the bistream generation without having launched the synthesis beforehand will run all the previous stages, exactly as if you clicked the GUI button.

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
