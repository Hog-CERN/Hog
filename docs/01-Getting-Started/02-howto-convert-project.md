# How to convert an existing project to Hog

Converting an existing project to Hog means creating the Hog list files (text files containing the names of your source files), creating the project Tcl files and possibly move somes file in the appropriate directory.

We will assume that you are starting from a clean repository and you want to convert a Vivado project stored in a local folder.

If you are migrating beween two git repositories and you want to retain the history of your old repository have a look [here](https://medium.com/@ayushya/move-directory-from-one-repository-to-another-preserving-git-history-d210fa049d4b)

If you are migrating to Hog but you are not changing repository, you can follow the instructions below ignoring the creation of the new local repository. In this case you might want to work in a new branch of your reposiutory.

Let's suppose your new repository called `new_repo` with url `new_repo_url`, your project is named `fancy_project` is currently stored in some local folder `fancy_path`. If you don't have a new repository you can go on Gitlab (gitlab.cern.ch) and create one.

## Preliminary actions
First of all create a new folder where you will store your firmware, initialize it as a git repository and connect it to the remote repository:

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

In that file you should find a section as in the following. Modify the url value by replacing it with a relative path. Pay attention to the url that must be specified relatively to the path of your repository:

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
Hog provides a set of templates that you can use, we suggesgt that you add a `.gitignore` to your repository with the following command:

```console
  cp Hog/Templates/gitignore .gitignore
```

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

A complete description of the meaning of each folder can be found in in section [Setting up a HDL repository with Hog]().

### Top folder
As you can see the top level of your project is stored in a folder named `Top/fancy_project`.
You can start by creating the new directory and adding the top file to it:


```bash
  mkdir -p Top/<fancy_name>/list
  cp ../<old_repo>/top_file.vhd Top/<fancy_name>/top_<fancy_name>.vhd
```

to create a new project Hog will use a tcl script.
Please use the Template provided in the Template folder:

```bash
  cp Hog/Templates/top.tcl Top/<fancy_name>/<fancy_name>.tcl
```

Use your favourite text editor to modify the template tcl file.
This will give you a minimal configuration to generate an empty project.
You can try running `./Hog/CreateProject.sh fancy_name`.
This will give you an empty project under `<HDL_Compiler>Project/<fancy_name>` where `<HDL_Compiler>` should match the HDL compiler you use in your project.

Do not forget to commit everything you just did:

```bash
  git add Top/<fancy_name>/top_<fancy_name>.vhd
  git add Top/<fancy_name>/<fancy_name>.tcl
  git commit -m "Adding top file and tcl script to the Top folder"
```

You are now ready to import the files needed to build your project.

*NOTE* Source files can be split in libraries.
Each *.src file in the list folder of your project will generate a new library.
This guide will assume the presence of a unique library with the same name of your project.

### IP files

IP files must go in a separate IP folder.
The IP folder is expected to contain a separate sub-folder for each IP.
The name of the sub-folder must be the same as the *.xci file.
This will effectively tell Hog to take the due care when evaluating the versioning of these files.
For each IP in your project run:

```bash
  mkdir -p IP/<ip_name>/
  cp ../<old_repo>/<ip_name>.xci IP/<ip_name>/.
 ```

then you can run:
 
 ```bash
  for i in $( ls IP/* ); do \
    echo '../../'$i/$i.xci >> Top/<fancy_name>/list/<fancy_name>.src; \
  done
```

Check that all your IPs are copied over in the IP folder.
You can also check that the files are correctly picked up by  regenerating the Hog project.
If you are satisfied with the changes commit all the files.

```bash
  git add IP/*.xci
  git add Top/<fancy_name>/list/<fancy_name>.src
  git commit -m "Adding IP Files"
```

#### IP initialization files (.coe)

Please note that the `.gitignore` template provided by Hog adds constraints on the IP folder.
Out of all the files contained in *repo*/*IP*/, git will pick up only *.xci files.
Files with different extensions will be ignored.
If you have *.coe files for RAM initialization or analogous files please make sure that you store these files in a separate folder and point to them in the IP one by using a relative path.

### Source, simulation and constraint files

It is now time to copy over all your source files.
In principle you can put your files wherever you feel like but we strongly encourage you to be as methodical as possible.
We therefore suggest the source files for each library to be contained in a separate folder with the name of the library.

In the current case this means creating a `lib_<fancy_name>` folder where to store all the source, simulation and constraint files

```bash
  mkdir -p lib_<fancy_name>/source lib_<fancy_name>/simulation lib_<fancy_name>/constraint
  cp ../<old_repo>/<source_1>.vhd lib_<fancy_name>/source
  cp ../<old_repo>/<source_2>.vhd lib_<fancy_name>/source
  ...
  cp ../<old_repo>/<simulation_1>.vhd lib_<fancy_name>/simulation
  cp ../<old_repo>/<simulation_2>.vhd lib_<fancy_name>/simulation
  ...
  cp ../<old_repo>/<constraint_1>.vhd lib_<fancy_name>/constraint
  cp ../<old_repo>/<constraint_2>.vhd lib_<fancy_name>/constraint
  ...
```

*NOTE* we suggest you to use longer names for directories since shorter names might be reserved under some Operating Systems, e.g. *con* is reserved under Windows.

Double check you added all the relevant files in your folders and add it to the correct list files

```bash
  for i in $( ls lib_<fancy_name>/source/* ); do \
    echo '../../'$i >> Top/<fancy_name>/list/<fancy_name>.src; \
  done
  for i in $( ls lib_<fancy_name>/simulation/* ); do \
    echo '../../'$i >> Top/<fancy_name>/list/<fancy_name>.sim; \
  done
  for i in $( ls lib_<fancy_name>/constraint/* ); do \
    echo '../../'$i >> Top/<fancy_name>/list/<fancy_name>.con; \
  done
```

You can also check that the files are correctly picked up by regenerating the Hog project.
If you are satisfied with the changes commit all the files.

```bash
  git add lib_<fancy_name>
  git add Top/<fancy_name>/list/<fancy_name>.src
  git add Top/<fancy_name>/list/<fancy_name>.sim
  git add Top/<fancy_name>/list/<fancy_name>.con
  git commit -m "Adding source files from "
```

### Submodules

If your project uses source or simulation files hosted in a separate repository you can add that repository as a git submodule.

```bash
  git submodule add <submodule_url>
  for i in $( ls <submodule>/* ); do \
    echo '../../'$i >> Top/<fancy_name>/list/<fancy_name>.sub; \
  done
```

Do not forget to add the relevant source files to the suitable list file and to commit everything.

### Proprietary files

External proprietary files can be included using the .ext list file. .ext list files must use an absolute path.
To use the firmware Continuous Integration this path must be accessible to the machine performing the git CI, e.g. can be on a protected afs folder.
This file has to be used **ONLY** in the exceptional case of files that can not be published because of copyright.
This file has a special syntax since md5 hash of each file must be added after the file name, separated by one or more spaces.
The md5 hash can be obtained by running the following command:

```bash
  md5sum <filename>
```

Hog, at synthesis time, checks that all the files are there and that the md5 hash matches the one in the list file.

## Updating your top file

Since Hog will back annotate your project to track the source code used in each build, extra generics will need to be added to your top file.
You can add the following generics to your top file:

```vhdl
generic (
  -- Global Generic Variables
  GLOBAL_FWDATE       : std_logic_vector(31 downto 0);
  GLOBAL_FWTIME       : std_logic_vector(31 downto 0);
  TOP_FWHASH          : std_logic_vector(31 downto 0);
  XML_HASH            : std_logic_vector(31 downto 0);
  GLOBAL_FWVERSION    : std_logic_vector(31 downto 0);
  TOP_FWVERSION       : std_logic_vector(31 downto 0);
  XML_VERSION         : std_logic_vector(31 downto 0);
  Hog_FWHASH          : std_logic_vector(31 downto 0);
  Hog_FWVERSION       : std_logic_vector(31 downto 0);
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

All your source files are now compiled as a separate library called accordingly to the *.src file they are contained in.
Therefore you have to add the library to your project:

```vhdl
library <fancy_name>;
use <fancy_name>.all;

```

do not forget to test and commit your changes. 

## Optional directories

### Code documentation
Hog can also be used to automatically generating and deploying some documentation for your code.
Hog works with (Doxygen)[http://www.doxygen.nl/] version 1.8.13 or later.
If your code already uses Doxygen style comments, then you can easily generate Doxygen documentation.
You just have to create a directory named `doxygen` containing the files used to generate the HDL documentation.
A file named `doxygen.conf` should be in this directory together with all the files needed to generate your Doxygen documentation.
You can copy a template configuration from `Hog/Templates/doxygen.conf`.

## Wrapper scripts
There are three scripts that can be used to run synthesis, implementation and bitstream generation without opening the Vivado GUI. The commands to launch them are

```console
	./Hog/LaunchSynthesis.sh <proj_name>
	./Hog/LaunchImplementation.sh <proj_name>
	./Hog/LaunchWriteBistream.sh <proj_name>
```

Launching the implementation or the bistream generation without having launched the synthesis beforehand will run the synthesis stage too.

### Is it all?

You just created a new project compatible with the Hog CI methodology.
You can now continue reading the [How to setup Hog-CI](../02-Maintainer-Manual/01-setupCI.md) section. 
