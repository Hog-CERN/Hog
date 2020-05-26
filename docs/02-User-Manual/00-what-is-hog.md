# Hog general overview

In this section we will describe how a project is set-up using Hog locally and for the Continuous Integration (CI).
In this section  we will make no assumptions on the code you already have.
If you already have a repository with code in it, you can also refer to this guide: [How to convert existing project to hog](../../01-Getting-Started/02-howto-convert-project/) section.

## Project directory structure
Hog relies on some fixed directories and file names in the HDL repository. A typical directory structure is shown in figure: 

![](../01-Getting-Started/figures/directory_structure.jpg)

HDL source files, together with constraint files and simulation files can be located anywhere in the repository. In the example shown in the figure above, they are located in the `myproj` directory and, possibly, in the `library_1` and `library_2` directories.

A Hog-handled repository can contain multiple (Vivado/Quartus) projects, each of them corresponding to a subdirectory of the __Top__ folder. Each one of these subfolders, is referred to as the "top project-directory". In the figure above we have just one project called __myproj__. 
Each top project-directory **must** contain all of the following:

- A [tcl file](../01-Hog-local/04-Project-Tcl) that **must** have the same name as top project-folder (plus the .tcl extension). We will call this file the "project tcl file" or "project tcl script".
- A [__list__ subdirectory](../01-Hog-local/05-List-files) containing the so-called list files i.e. special text files containing the names of the source files to be included in the project.


In figure, the project is called __myproj__ hence the project tcl file is called __myproj.tcl__.

When you create the project, running the [`Hog/CreateProject.sh`](../01-Hog-local/07-Usage/#create-project), Hog runs the project tcl file using Vivado or Quartus and creates the complete project in another directory, in our case `VivadoProject/myproj` or `QuartusProject/myproj`. In this directory you will find the typical Vivado or Quartus file structure.


## Multiple projects or multiple repositories?
As is now clear, a Hog-handled repository can contain multiple
projects. You may wonder when it is the case of having many projects
in the same repository and when you want to create different
repositories.

### Using different projects in the same git repository
You should use many projects in the same repository when they share a
significant amount of code.
In this case, the version of the repository will be shared among all the
projects. This is meaningful if the projects are strongly
interconnected and it is unlikely for a project to change version
without any modification to the others.

A typical use case is when the projects are intended for different devices (FPGAs) mounted on the same board.

To keep different parts of the project conceptually separated, it is possible to use many **libraries** as explained in the following. 
In this case, Hog evaluates the version (and the SHA) independently for each library, so it is possible to tell at a glance if two binary files share the same library.

For example you can have an FPGA with a "infrastructure" library
containing all the circuitry to handle communication with the external
world, and an "algorithm" library, containing the actual part of the
design that processes data. Hog libraries will allow you to tell if two
different binary files are generated using exactly the same source code
for the algorithm but they have a different infrastructure.

### Using different git repositories
If you don't have any code sharing between two HDL projects, or if the
shared code is minimal, you may think of having different
repositories.

In this case, everything will be decoupled, as the two repository are
two completely unlinked things. All that is explained in this guide
will have to be done with both repositories and you can also, in
principle, use two different versions of Hog.

In case you have a shared part of the code, in order to avoid code
repetition, you can include the shared code as a git submodule.
This must be a third git repository, also independent from the
previous two.

If the code contained in the submodule is not meant to be working
stand alone, it is not necessary to include Hog in it.


## Hog directory
The Hog repository should be included as a submodule into your HDL
repository, following these rules:

1. Hog must be in the root path of your repository
2. The directory name must be "Hog"

Moreover it is recommended not to include the submodule protocol
explicitly, it is much better to inherit it from the repository Hog is
included into.

To obtain this you can run the following commands in the root folder of your repository.

```bash
	git submodule add <protocol>://gitlab.cern.ch/Hog/Hog.git
	git config --file=.gitmodules submodule.Hog.url ../Hog/Hog.git
	git submodule sync
	git submodule update --init --recursive --remote
```

Remember to chose your protocol among ssh, https, git, or krb5.
Also note that `../Hog/Hog.git` must be replaced with the correct path, relative to your repository. 
A git error will be generated by `git submodule update --init --recursive --remote` if the path is not properly set.
Alternatively you could add the submodule normally and then edit the `.gitmodules` file, as explained [here](../../01-Getting-Started/02-howto-convert-project#add-hog-to-your-project).


## Source directories
Source directories contain HDL files used for synthesis.
HDL files can be placed anywhere in your repository, but it is advised to arrange them according to their library[^1].
We suggest to put HDL files belonging to separate libraries in separate folders although this is not mandatory.
The exact structure or name of this folder is not enforced.

[^1]: The concept of library does not exist in Verilog and SystemVerilog


## Top level entity
The top module of your project **must** be called `top_<project_name>`.
This module can be contained is any file stored anywhere in the repository as long as it is linked in a [`.src` file](#list-directory).

Hog extracts repository information (git commit 7-digit SHA and numeric version stored in git tags) and feeds the resulting values to the design using VHDL generics or Verilog parameters.
A full list of these can be found in the [Hog generics](../01-Hog-local/03-Hog-generics) section.
A template for the top level file (in VHDL and Verilog) is available in the [Hog/Template](https://gitlab.cern.ch/hog/Hog/-/tree/master/Templates) directory.
A full description of the templates can be found in the [available templates](../01-Hog-local/02-available-templates) section.


## Git submodules
Hog is designed to handle git submodules, i.e. if you use some code contained in a git repository you can simply add it to your project using:

```bash
    git submodule add <submodule_url>
```

All the submodules **must** be placed in the root directory iof your repository.
Suppose that you have 2 submodules called _sub_1_ and _sub_2_:

```
    Repo/sub_1
    Repo/sub_2
```
When you add files contained in a submodules you have to use the `.sub` list files described [here](#list-directory).


## Top directory
The __Top__ directory must be located in the root folder of the repository:
```
    Repo/Top
```

It contains one directory for each of your projects (say proj_1, proj_2, proj_3):

```
    Repo/Top/proj_1
    Repo/Top/proj_2
    Repo/Top/proj_3
```
As previously mentioned, these 3 directories are called the "top project-directories".


### Top project-directory
Each of the project directories must contain the tcl file that generates the project.
The .tcl file contained in the project directory must contain the instructions to build your project.
They must be named as follows:

```
    Repo/Top/<project_name>/<project_name>.tcl
```

To trigger all Hog functionalities, the last line of the tcl script must be: 

```tcl
source $path_repo/Hog/Tcl/create_project.tcl
```

A template for the `<project_name>.tcl` file is available in the [Hog/Template](https://gitlab.cern.ch/hog/Hog/-/tree/master/Templates) directory.
A full description of the template can be found in the [available templates](../01-Hog-local/02-available-templates) section.
More information on the tcl script can be found in the [project tcl file](../01-Hog-local/04-Project-Tcl) section.

If you want some custom operation to be performed before the project creation (e.g. you want create a source file using a Tcl script), you can insert your instruction before this line. If you want some custom operation to be performed after the project is created, you can add the Tcl instruction after the `create_project.tcl` call. Do this at your own risk.


### List directory
A directory named _list_ must be in each of the top project-folders.
This directory contains the list files, that are plain text files, used to instruct Hog on how to build your project.
Each list file contains the  names to be added to the *proj_1* project.
Hog uses different kinds of list files, identified by their extension:

 - `.src` : used to include HDL files belonging to the same library
 - `.sub` : used to include HDL files belonging to a git submodule
 - `.sim` : used to include files use for simulation of the same library
 - `.con` : used to include constraint files
 - `.prop`: used to set some Vivado properties, such as the number of threads used to build the project.
 - `.ext` : used to include HDL files belonging to an external library

 __In .src, .sub, .sim, and .con list files, you must use paths relative to the repository location__ to the files to be included in the project.

 __.ext list file must use absolute paths__. 
 To use the firmware Continuous Integration this path must be accessible to the machine performing the git CI, e.g. can be on a protected afs folder.

More information on the list file can be found in the dedicated [list files](../01-Hog-local/05-List-files) section.


### IP directory
All the IPs xci files __must__ be stored in the *repo*/*IP*/ repository.
To add a new IP core, that must be created in out-of-context mode.  The .xci file (and only that one!) must be saved and committed to in the repository in *repo*/*IP*/*ip_name*/*ip_name*.xci. 
Please note that the name of the folder must be the same as the xci file.
Now you can add the .xci normally to any .src list file in the list folder of your project.


#### IP initialisation files (.coe)
Please note that the `.gitignore` template provided by Hog adds constraints on the IP folder.
Out of all the files contained in *repo*/*IP*/, git will pick up only xci files.
Files with different extensions will be ignored.
If you have .coe files for RAM initialisation or analogous files please make sure to store these files in a separate folder and point to them in the IP directory by using a relative path.

## Auto-generated directories
The following directories are generated at different stages of library compilation or synthesis/implementation time.
These directories should never be committed to the repository, for this reason they are listed in the .gitingore file.
You can always delete any of these directories with no big consequences: they can always be regenerated by Vivado/Quartus or Hog scripts.

### VivadoProject or QuartusProject
When you generate a project with Hog, it will create a sub-directory here. When everything is generated, this directory contains one subdirectory for each project in the repository, containing the Vivado (Quartus) project-file `.xpr` (`.qpf`). The name of the sub-directory and of the project file are always matching. In our case:

```
    Repo/VivadoProject/proj_1/proj_1.xpr
    Repo/VivadoProject/proj_2/proj_2.xpr
    Repo/VivadoProject/proj_3/proj_3.xpr
```

The _Repo/VivadoProjects/proj_3/_ directory also contains Vivado automatically generated files, among which the Runs directory:

```
    Repo/VivadoProjects/proj_1/proj_1.runs/
```

That contains one sub-folder for every Vivado run with all the IPs in your project, the default Vivado synthesis run (synth_1) and implementation run (impl_1).
Hog will also copy IPbus XMLs and generated binary files into _Repo/VivadoProjects/proj_1/proj_1.runs/_ at synthesis/implementation time.

### SimulationLib
Modelsim or Questasim compiled libraries will be placed here and automatically linked to your project. The library compilation can be done automatically if the `vsim` executable is in your PATH and you launch the `hog/Init.sh` script.

## Optional directories

### Doxygen
The `doxygen` directory contains the files used to generate the HDL documentation.
A file named _doxygen.conf_ should be in this directory, together with all the files needed to generate your Doxygen documentation.
VHDL is well supported with Doxygen version 1.8.13 ore later, so Hog will not use any older version.

## Wrapper scripts
There are launcher scripts in the Hog directory that can be used to run simulation synthesis, implementation and bitstream writing without opening the Vivado GUI. The commands to launch them are

```bash
	./Hog/LaunchSimulation.sh <proj_name>
	./Hog/LaunchSynthesis.sh <proj_name>
	./Hog/LaunchImplementation.sh <proj_name>
	./Hog/LaunchWriteBistream.sh <proj_name>
```

Launching the implementation will run the synthesis and IP synthesis stages too if not previously launched.
More information on these scripts can be found in the dedicated [How to create and build project](../01-Hog-local/07-Usage) section.
