# Hog: HDL on git
## Introduction
Coordinating firmware development among many international collaborators is becoming a very widespread problem in particle physics. Guaranteeing firmware synthesis with P&R reproducibility and assuring traceability of binary files is paramount. Hog tackles these issues by exploiting advanced Git features and being deeply integrated with HDL IDE, with particular attention to Intellectual Properties (IP) handling.

## Rationale
In order to guarantee firmware synthesis and P&R reproducibility, we need absolute control of:
- HDL source files
- Constraint files
- Vivado settings (such as synthesis and implementation strategies)

Every time we produce a bit file, we must know exactly how it was produced
- Consistent automatically calculated version number embedded in firmware registers
- Never merge a “broken” commit to official branch
	- If this happens, developers starting from official commit will have a broken starting point
	- To avoid this the Automatic Workflow system was designed

## What is Hog
Hog is a set of Tcl/Shell scripts plus a suitable methodology to allow a fruitful use of Git as a HDL repository and guarantee synthesis reproducibility and binary file traceability. Tcl scripts, able to recreate the projects are committed to the repository. This permits the build to be Vivado-version independent and ensures that all the modifications done to the project (synthesis/implementation strategies, new files, settings) are propagated to the repository, allowing reproducibility.
In order to make the system more user friendly, all the source files used in each project are listed in special list files, together with properties (such as VHDL 2008 compatibility) that are read out by the Tcl scripts and imported into the project as different libraries, helping readability.

To guarantee binary file traceability, we link it permanently to a specific git commit. Thus, the git-commit hash (SHA) is embedded into the binary file via VHDL generic and stored into firmware registers. This is done by means of a pre-synthesis script which interacts with the git repository. Both the project creation script and the pre/post synthesis scripts are written in Tcl (compatible with Xilnx and Altera) and make use of a utility library designed for this purpose, including functions to handle git, parse tags, read list files, etc.

# Hog features
## Project creation shell script
Developers must re-create the Vivado project every time a file is added or removed to project, or when a file is renamed.

## Pre-synthesis Tcl script
Integrate git SHA and version into the firmware via VHDL generics

## Post write-bitstream Tcl script
Automatically copy and rename bitfiles

## Vivado IP handling
Git hooks to ignore locally ignore xml files
All IPs should be sotred in the path:

    Repo/IP

This is done to have a single path for the updload/downald of artefacts in Hog-CI.

# HDL repository structure and methodology
This repository (Hog) should be included as a submodule into your HDL repository.
Hog relies on the following assumptions:
- Hog must be in the root path of your repository
- The directory name must be "Hog"
- The repository should not include the protocol explicitely, instead it must be added with a relative path.

E.g. in .gitmouldes you sould write:

    [submodule "Hog"]
	path = Hog
    url = ../../hog/Hog.git
    
rather than:

    [submodule "Hog"]
	path = Hog
	url = ssh://git@gitlab.cern.ch:7999/hog/Hog.git    

Let's assume the your HDL repository is called Repo, then Hog must be in:

    Repo/Hog

HDL source files, together with constraint files, simulation files can be located anywhere in the repository, even if a directory structure that reflects the __libraries__ in the project is advised.
A Hog-based repository can contain many projects. You should use many projects in the same repository when they share a significant amount of code: e.g. many FPGAs on the same board. If this is not the case you may think of having different repositories. In this case, you may include the little amount of shared code as a git submodule, that is also handled by Hog.
Hog is a simple project, meant to be useful to speed up work. It is not extremely configuralbe: the scripts rely on special directory structure and file naming to be respected as explained in the following paragraphs.

## Top directory
The __Top__ directory is located in the root folder of the repository:

    Repo/Top

It contains one directory for every project (say proj_1, proj_2, proj_3) in the repository:

    Repo/Top/proj_1
    Repo/Top/proj_2
    Repo/Top/proj_3

Each of these directories must contain:
- the top vhdl file of the project
- the tcl file that generates the project

They must be named as follows:

    Repo/Top/proj_1/proj_1.tcl
    Repo/Top/proj_1/top_proj_1.vhd

A directory named _list_ must be in the __Top__ directory as well. This directory contains the list files which in turn contain the filenames to be added to the _proj_1_ project.
There are 4 kinds of list files, depending on the extension: src, sub, sim, con.
An example of list files for _proj_1_ is listed here:

    Repo/Top/proj_1/list/lib_a.src
    Repo/Top/proj_1/list/lib_b.src
    Repo/Top/proj_1/list/lib_c.src
    Repo/Top/proj_1/list/lib_a.sim
    Repo/Top/proj_1/list/lib_b.sim
    Repo/Top/proj_1/list/sub_1.sub
    Repo/Top/proj_1/list/xdc.con

#### .src files
HDL files used for synthesis taken from the repository. HDL files coming from one .src list-file, are  included into the Vivado project in the same library, named after the .src file itself. For example if we have a lib_1.src file in our list directory, containing 5 filenames inside, like this:

    ../../lib_1/hdl/file1.vhd
    ../../lib_1/hdl/file2.vhd
    ../../lib_1/hdl/file3.vhd

they will be included into the Vivado project in the lib_1 library, so for example in VHDL to use them in the top file you should use the following syntax:

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
Properties, like VHDL 2008 compatibility, can be specified afer the file name in the list file, separated by any number of spaces. If _file_3.vhd_  requires VHDL 2008, for example, you should specify it like this:

    ../../lib_1/hdl/file1.vhd 
    ../../lib_1/hdl/file2.vhd
    ../../lib_1/hdl/file3.vhd 2008


### .sub files
HDL files used for synthesis taken from git submodules in the project.
### .sim files
HDL files used for simulation only.
### .con files
Constraint files


## Git submodules
Hog can handle Git submodules. The must be placed anywhere in your repository, but it is advised to place them in the root directory. Subbose that you have 2 submodules called _sub_1_ and _sub_2_:

    Repo/Top/sub_1
    Repo/Top/sub_2

To add files from a submodule to your Project you must list them in a .sub list file. This is to explain Hog that those files are taken from a submodule rather than from a library belonging to the main HDL repository. Hog will not try to evaluate the version of those files, but it will evaluate the git SHA of the submodule.

## doxygen
The doxygen directory contains the files used to generate the HDL documentation.
A file named _doxygen.conf_ should be in this directory, together with all the files needed to generate your doxygen documentation.
Hog works with Doxygen version 1.8.13 ore later.

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


## Hog Continuous integration (Hog-CI)

[HOG-CI](./VM/README.md)