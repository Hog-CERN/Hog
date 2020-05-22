# How to convert an existing project to Hog

Converting an existing project to Hog means: copying the source files into a git repository, adding Hog as a submodule, creating the Hog list files (text files containing the names of your source files), and creating a Tcl script able to create the Vivado/Quartus project.

## Before starting
We will assume that you are starting from a clean repository and you want to convert a Vivado project stored in a local folder.

If you are migrating beween two git repositories and you want to retain the history of your old repository have a look [here](https://medium.com/@ayushya/move-directory-from-one-repository-to-another-preserving-git-history-d210fa049d4b)

If you are migrating to Hog but you are not changing repository, you can follow the instructions below ignoring the creation of the new local repository. In this case you might want to work in a new branch of your reposiutory.

Let's suppose your new repository called `new_repo` with url `new_repo_url`, your project is named `myproject` is currently stored in some local folder `mypath`. If you don't have a new repository you can go on Gitlab (gitlab.cern.ch) and create one.

## Creating the git repository
First of all create a new folder where you will store your firmware, initialise it as a git repository and connect it to the remote repository:

```bash
  > mkdir new_repo
  > cd new_repo
  new_repo> git init
  new_repo> git remote add origin new_repo_url
```

For now we will work on the master branch, that is the default one. If you want you can create a branch and work on that:

```bash
  git checkout -b first_branch
  git push origin first_branch
```

## Add Hog to your project
Hog repository should be included as a submodule in the root path of your repository.
To do this type:

```console
  git submodule add ssh://git@gitlab.cern.ch:7999/hog/Hog.git
```
Here we assumed that you want to use the ssh protocol, if you want to use https enter
```console
  git submodule add https://gitlab.cern.ch/hog/Hog.git
```

If you like krb5:
```console
  git submodule add https://:@gitlab.cern.ch:8443/hog/Hog.git
```

However, it is good idea not to include the submodule protocol explicitly, but to let it be inherited from the repository Hog is
included into.
To obtain this edit a file called `.gitmodules` with your favourite text editor (say emacs):

```console
  emacs .gitmodules
```

In that file you should find a section as in the following. Modify the url value by replacing it with a relative path. Note that the url that must be specified relatively to the path of your repository:

```
[submodule "Hog"]
	path = Hog
	url = ../../hog/Hog.git	
```

Now from your repository:
```console
  git submodule update
```
This should trigger an error if you made a mistake when editing the repository path.

## Copying some templates from Hog and committing
Now that you have Hog locally, you can start setting up your repository.
Hog provides a set of templates that you can use, you can add a `.gitignore`[^4]  to your repository with the following command:

```console
  cp Hog/Templates/gitignore .gitignore
```

[^4]:You might need to modify your `.gitignore` file if you want to do a more complicated directory structure, especially with the IP and BD files. For example, Hog template assumes that you store your IPs in `IP/ip_name/ip_name.xci`. If you do, this file would be enuogh for you. If you need a more omplicated structure, you can edit the file or you can use several .gitignore files the subfolders of the main IP directory.

Let's now make our first commit:

```console
  git add .gitignore .gitmodules Hog
  git commit -m "Adding Hog to the repository"
  git push origin master
```

If you are working in a branch that is not master, please replace the last instruction with:
```console
  git push origin your_branch_name
```

## Early tagging your repository

Hog assumes that at least a version tag of the form **vM.m.p** is present in your repository.
Let's now crreate the first Hog tag: 

```console
git tag v0.0.0
git push --tags
```


## Generating Hog directory structure

You have now to generate a directory structure similar to this one:

![](../01-Getting-Started/figures/directory_structure.jpg)

A complete description of the meaning of each folder can be found in THE [Hog User Manual](../02-User-Manual)

### Top folder
Every Hog-handled HDL repository must have a directory called `Top`. In here, each subdirectory - that we call the **project top-direcotry** - represents a HDL project in the repository. 
You can start by creating your project top-directory:


```bash
  mkdir -p Top/myproject
```

Every project top-directory, must contain a subdirectory called `list` where the so-called hog list file are stored. Let's create it:

```bash
  mkdir Top/myproject/list
```


Moreover a tcl script, with the same name of the projecty (plus the .tcl extension) must be in the project top-directory. Hog runs this script, called the project tcl script, to create a project.
This is a recap of what we have learned up to now:

- A `Top` folder must be in the repository
- Inside this folder there is one subfolder for each project in the repository, called the project top-directory
- Inside each project's top-directory there is 1. a `list` sub-direcotry containing: the list files of the project and 2. a tcl script used to create the project

For more advanced Hog features, additional files and folder are located in the `Top` folder, but we don not discuss them now for simplicity.

In order to create the project's tcl script, we will start from the template provided in the `Hog/Templates` folder:

```bash
  cp Hog/Templates/top.tcl Top/myproject/myproject.tcl
```

Use your favourite text editor to modify the template Tcl file. There are several things you can edit, depending on your needs, for example the FPGA name or the synthesis or implementation strategies. The template contains comments to guide you through the process.

Now you can commit everything you just did:

```bash
  git add Top
  git commit -m "Adding Hog Top folder"
```

# Importing source files to the project

You are now ready to import the files needed to build your project[^1].

[^1]: Hog gives you the possibility to organise the source files in different VHDL libraries (Verilog doesn't have the concept of library). You can add your source files into several .src files in the list directory, each of these .src files will correspond to a different library with the same name as the .src file (excluding the .src extension). For simplicity, in this chapter we will assume the presence of a unique library with the same name of your project.

First of all, copy the files from your local folder into the folder that contains the git repository.
Exception made for some reserved directory (e.g. Top, IP, BD) you can put your files wherever you feel like inside your repository, orgasnising them as you see fit.

In this example we will create a directory named `lib_myproject` where we will store all the source, simulation and constraint files.

```bash
  mkdir -p lib_myproject/source lib_myproject/simulation lib_myproject/constraint
  cp ../old_repo/source_1.vhd lib_myproject/source
  cp ../old_repo/source_2.vhd lib_myproject/source
  ...
  cp ../old_repo/simulation_1.vhd lib_myproject/simulation
  cp ../old_repo/simulation_2.vhd lib_myproject/simulation
  ...
  cp ../old_repo/constraint_1.vhd lib_myproject/constraint
  cp ../old_repo/constraint_2.vhd lib_myproject/constraint
  ...
```

After having added all the relevant files in your folders you have to add their path and file names to the appropriate list files. In this example, we will create:

- One source list-file called `Top/myproject/list/myproject.src`, containing the source files of your project
- One simulation list-file called `Top/myproject/list/myproject.sim`, containing the files used in the simulation (e.g. test benches, modules that read/write files, etc.)
- One constraint list-file called `Top/myproject/list/myproject.con`, containing your constraints (.xdc, .tcl, etc.)

You can copy and modify this bash script to ease this quite tedious part of the work:
```bash
  for i in $( ls lib_myproject/source/* ); do \
    echo $i >>  Top/myproject/list/myproject.src; \
  done
  for i in $( ls lib_myproject/simulation/* ); do \
    echo $i >>  Top/myproject/list/myproject.sim; \
  done
  for i in $( ls lib_myproject/constraint/* ); do \
    echo $i >>  Top/myproject/list/myproject.con; \
  done
```

Note that the path of the file is specified with respect to the main folder of the repository.

If you want, you can add comment lines in the list-files starting with a `#` and you can leave empy lines (or lines containing an arbitrary number of spaces). All of these will be ignored by Hog.

At this point, you might want to check that the files are correctly picked up by regenerating the Hog project: `./Hog/CreateProject.sh myproject`, Hog will give you an error if a file is not found.
You can open the created project in  `VivadoProject/myproject/myproject.xpr` or `QuartusProject/myproject/myproject.qpf` with the GUI and check that all the files are there. If not, modifiy the list files and create the project again. When you are satisfied, you can commit your work:

```bash
  git add lib_myproject
  git add Top/myproject/list/myproject.src
  git add Top/myproject/list/myproject.sim
  git add Top/myproject/list/myproject.con
  git commit -m "Adding source files"
```

### Submodules
If your project uses source or simulation files hosted in a separate repository you can add that repository as a git submodule.

```bash
  git my_submodule add my_submodule_url
```
You must add all your submodules in the root directory of your repository.

Files taken from a submodule must be added to a special list-file having the .sub exstension. Moreover the name of the file must be the same of the submodule directory[^2].
[^2]: In case this naming limitations complicate your work too much, please note that the submodule folder name can differ from the submodule url.

Add the relevant source files to the submodule list-file. You can copy and modify the following script if you want:

```bash
for i in $( ls submodule/* ); do \
    echo $i >> Top/myproject/list/my_submodule.sub; \
  done
```

Now commit the newly created .sub file:

```bash
git add Top/myproject/list/my_submodule.sub
git commit -m "Add a new my submodule"
```

### IP files

IP files must go in a special folder called `IP` in the root of your repository.
The IP direwctory can contain all the subdirectories you want, but there is a rule: each ip file (.xci for Vivado) must be contained in a sub-folder called with the same name as the .xci file (extension excluded).

Basically for each IP in your project run:

```bash
  mkdir -p IP/ip_name/
  cp ../old_repo/ip_name.xci IP/ip_name/
```

Then you can add the xci files to the .src list file you want, in this case we will use a separate file called `IP.src`[^3]. You can use the following script if you like:
[^3]: There is no concept of library for the IPs, so we prefer to put them in a separate .src file. You can put them in the same list file as your other source files if you wish. Just open `Top/myproject/list/myproject.src` with a text editor and add them there.


 ```bash
  for i in $( ls IP/* ); do \
    echo $i/$i.xci >> Top/myproject/list/myproject.src;
  done
```

As usual, you can check that the files are correctly picked up by regenerating the project `./Hog/CreateProject.sh myproject`
If you are satisfied with the changes, you can commit your work.

```bash
  git add IP
  git add Top/myproject/list/IP.src
  git commit -m "Adding IP Files"
```

#### IP initialization files (.coe)

Please note that the `.gitignore` template provided by Hog adds constraints on the IP folder.
Out of all the files contained in *repo*/*IP*/, git will pick up only *.xci files.
Files with different extensions will be ignored.
If you have *.coe files for RAM initialization or analogous files please make sure that you store these files in a separate folder and point to them in the IP one by using a relative path.


## The top file of your project
Your project must conmtain a module called `top_myproject`, i.e. your project's name preceded by `top_`. Hog will pick up such module and set it as the Top of your project.

Since Hog will back annotate your project to track the source code used in each build, extra generics will be provided to your top file at the beginning of the synthesis
You can add the following generics to your top file in order to store those values in some registers:

```vhdl
generic (
  -- Global Generic Variables
  GLOBAL_FWDATE       : std_logic_vector(31 downto 0);
  GLOBAL_FWTIME       : std_logic_vector(31 downto 0);
  TOP_FWVERSION       : std_logic_vector(31 downto 0);
  TOP_FWHASH          : std_logic_vector(31 downto 0);  
  XML_VERSION         : std_logic_vector(31 downto 0);
  XML_HASH            : std_logic_vector(31 downto 0);
  GLOBAL_FWVERSION    : std_logic_vector(31 downto 0);
  GLOBAL_FWHASH       : std_logic_vector(31 downto 0);  
  XML_HASH            : std_logic_vector(31 downto 0);
  XML_VERSION         : std_logic_vector(31 downto 0);

  HOG_HASH          : std_logic_vector(31 downto 0);
  HOG_VERSION       : std_logic_vector(31 downto 0);

  -- Project Specific Lists (One for each .src file in your Top/myproj/list folder)
  <MYLIB0>_FWVERSION    : std_logic_vector(31 downto 0);
  <MYLIB0>_FWHASH       : std_logic_vector(31 downto 0);
  <MYLIB1>_FWVERSION    : std_logic_vector(31 downto 0);
  <MYLIB1>_FWHASH       : std_logic_vector(31 downto 0);

  -- Submodule Specific variables (only if you have a submodule, one per submodule)
  <MYSUBMODULE0>_FWHASH : std_logic_vector(31 downto 0);
  <MYSUBMODULE1>_FWHASH : std_logic_vector(31 downto 0);

  -- External library specific variables (only if you have an external library)
  <MYEXTLIB>_FWHASH       : std_logic_vector(31 downto 0);

  -- Project flavour
  FLAVOUR             : integer
);

```

In our case, there is only one library called myproject, possibly a submodule, and no XML_VERSION, flavour or external libs. Thess are more advanced Hog features that are not treated in this guide.

All your source files are now compiled as a separate library called according to the .src file they are contained in.
So if you are using multiple .src files, you have to add the library to your project:

```vhdl
library myproject;
use myproject.all;

```

If you are using a module that is included in a different .src file with respect to your top module, you will have to specify the library when you use it:

```vhdl
u_1 : entity myproject.a_component_in_lib1 
port map(
  clk => clk,
  din => din,
  dout => dout
);

```
If you work within the same library (i.e. .src file) you can normally use the `work` library.


## Create your project
As you know, if you run `./Hog/CreateProject.sh myproject`, Hog will create your project in `VivadoProject/myproject/myproject.xpr` or `QuartusProject/myproject/myproject.qpf`. You can open the project with the GUI and check that everything looks alright.
The `.gitignore` template, that you copied in your repository, takes care of ignoring the VivadoProject directory (or QuestusProject) as we do not want to comit Vivado/Quartus files to the repository. If you decided not to use the provided template you should take care of ignoring this directory.
Also you should try to run the complete workflow as something might have gone wrong with your IPs or the libraries.
If something is indeed wrong, try to fix it by modifying: the source files, the list files, the project tcl file. If you modify the list files or the project tcl file, you have to re create the project to see if the modifications had the desired effect. 


## Code documentation
Hog can be used to automatically generate and deploy documentation for your code.
Hog works with [Doxygen](http://www.doxygen.nl/) version 1.8.13 or later.
If your code already uses Doxygen style comments, you can easily generate Doxygen documentation.
You just have to create a directory named `doxygen` containing the files used to generate the HDL documentation.
A file named `doxygen.conf` should be in this directory together with all the files needed to generate your Doxygen documentation.
You can copy a template configuration from `Hog/Templates/doxygen.conf` and modify it.

## Wrapper scripts
There are three scripts that can be used to run synthesis, implementation and bitstream generation without opening the Vivado GUI. The commands to launch them are

```console
	./Hog/LaunchSynthesis.sh <proj_name>
	./Hog/LaunchImplementation.sh <proj_name>
	./Hog/LaunchWriteBistream.sh <proj_name>
```

Launching the implementation or the bistream generation without having launched the synthesis beforehand will run the synthesis stage too.
