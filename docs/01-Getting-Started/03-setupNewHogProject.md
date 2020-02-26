# HDL repository structure and methodology

In order to use HOG in your repository you will have to create the following directory structure.

![](./figures/directory_structure.jpg)

HDL source files, together with constraint files, simulation files can be located anywhere in the repository, even if a directory structure that reflects the __libraries__ in the project is advised.\
A Hog-based repository can contain many projects.
You should use many projects in the same repository when they share a significant amount of code: e.g. many FPGAs on the same board. 
If this is not the case you may think of having different repositories.
In this case, you may include the little amount of shared code as a git submodule, that is also handled by Hog.

Hog is a simple project, meant to be useful to speed up work.
It is not extremely configuralbe: the scripts rely on special directory structure and file naming to be respected as explained in the following paragraphs.

A detailed description of the content of each directory can be found below.

## HOG directory
This repository (Hog) should be included as a submodule into your HDL repository.
Hog relies on the following assumptions:
- Hog must be in the root path of your repository
- The directory name must be "Hog"
- The repository should not include the protocol explicitely, instead it must be added with a relative path.

To obtain this you can run the following commands in the root folder of your repository.

```console
	
	git submodule add https://gitlab.cern.ch/hog/Hog.git
	git config --file=.gitmodules submodule.Hog.branch <branch_to_track>
	git config --file=.gitmodules submodule.Hog.url ../hog/Hog.git
	git submodule sync
	git submodule update --init --recursive --remote

```

Please note `../hog/Hog.git` must be replaced with the correct relative path for your repository. 
Git will give you an error on `git submodule update --init --recursive --remote` if this path is not properly set.


## library_X directories

library_X directories contain HDL files used for synthesis.
HDL files can be placed anywhere in your repository, but it is advised to place them in the root/library_X directory.
We suggest to put HDL files belonging to separate libraries in separate folders although this is not mandatory.
The exact structure or name of this folder is not enforced.


## Git submodules
Hog can handle Git submodules, i.e. if you have some module contained on a git repository you can simply add it to your project using:

```console
	
	git submodule add <submodule_url>

```
They can be placed anywhere in your repository, but it is advised to place them in the root directory.
Suppose that you have 2 submodules called _sub_1_ and _sub_2_:

    Repo/sub_1
    Repo/sub_2


## Top directory

The __Top__ directory must be located in the root folder of the repository:

    Repo/Top

It contains one directory for each of your projects (say proj_1, proj_2, proj_3):

    Repo/Top/proj_1
    Repo/Top/proj_2
    Repo/Top/proj_3

### project directory

Each of the project directories must contain:
- the top vhdl file of the project
- the tcl file that generates the project

They must be named as follows:

    Repo/Top/<proj_1>/<proj_1>.tcl
    Repo/Top/<proj_1>/top_<proj_1>.vhd

### .tcl file

The .tcl file contained in the project directory must contain the instructions to build your project.
This can be a minimal tcl setup specifing only the general project settings.
The last line of the tcl scipt is expected to be 
```console

source $path_repo/Hog/Tcl/create-project.tcl

```

This commant will instruct HOG to add all your files to the generated project.

One example for a Vivado project is :

```console

############# modify these to match project ################
set bin_file 1
set use_questa_simulator 0
### FPGA and Vivado strategies and flows
set FPGA xc7a35tcpg236-1
set SYNTH_STRATEGY "Flow_AreaOptimized_High"
set SYNTH_FLOW "Vivado Synthesis 2018"
set IMPL_STRATEGY "Performance_ExplorePostRoutePhysOpt"
set IMPL_FLOW "Vivado Implementation 2018"
set DESIGN    "[file rootname [file tail [info script]]]"
set path_repo "[file normalize [file dirname [info script]]]/../../"
source $path_repo/Hog/Tcl/create-project.tcl

```

### list directory

A directory named _list_ must be in each of the project folders.
This directory contains the list files, that are plain text files, used to instruct HoG on how to build your project.
Each list file contain the list filenames to be added to the _proj_1_ project.
Hog uses different kinds of list files, identified by their extension: 
 - src
 - sub
 - sim
 - con
 - ext
 __.src, .sub, .sim, and .con list files must use relative paths__ to the files to be included in the project./
 __.ext list filse must use an absoute path__. To use the firmware CI this path must be accessible to the machine performing the git CI, e.g. can be on a protected afs folder.

#### .src files

Files with the .src extension are used to include HDL files belonging to a single library and the .xci files of the IPs used in the library.
Hog will generate a new library for each .src file.
For example if we have a lib_1.src file in our list directory, containing 5 filenames inside, like this:

    ../../lib_1/hdl/file1.vhd
    ../../lib_1/hdl/file2.vhd
    ../../lib_1/hdl/file3.vhd

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

### .sub files

To add files from a submodule to your Project you must list them in a .sub list file.
This tells Hog that those files are taken from a submodule rather than from a library belonging to the main HDL repository.
Hog will not try to evaluate the version of those files, but it will evaluate the git SHA of the submodule.

### .sim files

HDL files used for simulation only.

### .con files

All contratint files (.xdc ) must be included by adding them to the .con files

### .ext files

External proprietary files can be included using the .ext list file.
__.ext list filse must use an absoute path__.
To use the firmware CI this path must be accessible to the machine performing the git CI, e.g. can be on a protected afs folder.
This file has to be used __ONLY__ in the exceptionalcase of files that cannot be published because of copyright.
This file has a special synthax since md5 hash of each file must bne added after the file name, separated by one or more spaces.
The md5 hash can be obtained by running
```console
	md5sum <filename>
```
Hog, at synthesis time, checks that all the files are there and that their md5 hash matches the one in the list file.


## Auto-generated directories
The following directories are generated at different stages of library compilation or synthesis/implementation time.
These directories should never be committed to the repository, for this reason they are listed in the .gitingore file.
You can always delete any of these directory with no bog consequences: they can always be regenerated by Hog scripts.

### VivadoProjects
When you generate a project with Hog, it will create a sub-directory here. When everything is generated,  this directory contains one subdirectory for each project in the repository, containing the Vivado project-file. The name of the sub-directory and of the project file are always matching. In our case:

    Repo/VivadoProjects/proj_1/proj_1.xpr
    Repo/VivadoProjects/proj_2/proj_2.xpr
    Repo/VivadoProjects/proj_3/proj_3.xpr

The _Repo/VivadoProjects/proj_3/_ directory also contains Vivado automatically generated files, among which the Runs directory:

    Repo/VivadoProjects/proj_1/proj_1.runs/

That contains one subfolder for every Vivado run: alle the IPs in your project, the default Vivado synthesis run (synth_1) and implementation run (impl_1).
Hog will also copy ipbus XMLs and generated bitfiles into _Repo/VivadoProjects/proj_1/proj_1.runs/_ at synthesis/implementation time.

### ModelsimLib
Modelsim compiled libraries will be placed here

## Optional directories

### doxygen
The doxygen directory contains the files used to generate the HDL documentation.
A file named _doxygen.conf_ should be in this directory, together with all the files needed to generate your doxygen documentation.
Hog works with Doxygen version 1.8.13 ore later.


## Wrapper scripts
There are three scripts that can be used to run synthesis, implementation and bitstream writing without opening the vivado gui. The commands to launch them are
```console
	./Hog/LaunchSynthesis.sh <proj_name>
	./Hog/LaunchImplementation.sh <proj_name>
	./Hog/LaunchWriteBistream.sh <proj_name>
```
Launching the implementation or the bistream writing without having launched the synthesis beforehand will run the synthesis stage too.
