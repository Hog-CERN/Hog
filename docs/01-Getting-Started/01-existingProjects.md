# Working with a HDL repository handled with Hog

This section is intended for a firmware developer that starts to work to an existing HDL project that is managed with Hog.

All the instructions below can be executed both on a Linux shell, or on git bash[^1] on a Windows machine.

[^1]: To open a git bash session navigate to the directory where you want to open the bash. Right click on the folder and select open git bash here.

For all of the following to work, Vivado (or Quartus) executable must be in your PATH environment varible: i.e. if you type `vivado` the program must run. If you intend to use Modelsim or Questasim, also the `vsim` executable must be in the PATH: i.e. if you type `vsim` the simulator should start.

##Requirements
This is a list of the requirements:

- Have git (version 2.7.2 or greater) installed and know git basics
- Have Vivado or Quartus installed and in the PATH
- Optionally have Questasim installed and vsim in the PATH

## Cloning the repository
First of all, you have to clone the repository[^2], let's call it *repo* from now on. Go to the website of the repository, choose the protocol (ssh, git, https, krb5) and copy the clone the link.

```console
	git clone --recursive <protocol>://gitlab.cern.ch/repo.git
```

Now you have all the source code and scripts you need in the *repo* folder.

[^2]: You will have to chose the *protocol* that works for you: ssh, https, or krb5. We used the `--recursive` option to automatically clone all the submodules included. In general a HDL repository may or may not include other submodules, but the Hog scripts are always included as submodules. If you have cloned the repository without the recursive options (or if that option does not work, we heard that it happens on Windows), you will have to go inside it and initialise the submodules `git submodule init` and update them `git submodule update`. 

## Create Vivado/Quartus projects
To start working you can now create the Vivado (or Quartus) project you are interested in, say it's called *project1*.
To do that, go into the repository (`cd repo`) and type:

```console
	./Hog/CreateProject.sh project1
```

This will styart a Hog script that creates the Vivado (or Quartus) project in the directory `VivadoProjects/project1` (or `QuartusProjects/project1`).
inside this directory you will find the Vivado xpr file (or the Quartus qpf file).

If you don't know the project name, just run `./Hog/CreateProject.sh` and you will get a list of the existing projects present on the repository.

Alternatively, you can type `cd Top` (the Top folder is always present in a Hog handled HDL repository) and type `ls`: each directory in this path corrensponds to a Vivado/Quartus project in the repository.

To create all the projects in the repository, you can run the Hog initialisation script, like this:
```console
	./Hog/Init.sh
```
This script will also, if you wish, compile Modelsim/Questasim libraries.

Now you can open *project1* with Vivado or Quartus and **work almost normally** with the GUI.

The CreateProject script, that you have just run, has integrated Hog's Tcl scripts in the Vivado/Quartus project. From now on, Hog scripts will run automatically, every time you start the synthesis or any other step in the workflow. In particular, the pre-synthesis script will interact with your local git repository and integrate its version and git commit SHA into your HDL project.

We said **almost normally** because there is one exception: adding a new file  (HDL code, constraint, IP, etc.) to the project using the GUI is not enough. You **must also add** the file name in one of Hog's list files as explenied in the next paragraph.

## Adding a new file to the project
Let's now suppose that you want to add a new file to the project and that this file is located in `repo/dir1/` and is called `file1.hdl`.

First of all, the new file (that is unkown to git) must be added to the repository:

```shell
cd repo
git add ./dir1/file1.hdl 
git commit -m "add new file file1.hdl"
git push
```
Now that the file is safely on git, we have to add it to the Hog project, so that if another developer clones the repository, as you did at the beginning of this guide, the file will appear in the project[^a].
[^a]:Not all the files stored in the git repository are part of a project: there can be non hdl files, obsolete files that are stored just in case, new files that are not ready to be used. Moreover some files could be part of a project and not of another. In our example, the repository could contain project2 and project3 that use different subsets of files in the repository.

This is a new file, unknown to Hog for now, and we want it to be included into the project the next time that we run the CreateProject script described above. To do this, you must add the file name and path of `file1.vhd` into a Hog list file. The list files are located in `repo/Top/project1/list/`. Let's assume that the list file you want to add your file to is `lib1.src`.

Open the file with a text editor and add the file name and path in a new line.

Now that the new file is included in a list file, you can close the Vivado/Quartus project and re-create it by typing `./Hog/CreateProject.sh <project name>` again.

Do you really have to do this every time you add a new file to the project? There is a quicker way. You can add the file with the GUI and **also** add the file to a .src list file. If you choose to do this, in Vivado, you have to choose the correct library when adding the file. The library must have the same name of the .src file to which you added the surce file. In our example, the hdl file was added to a list file called `lib1.src`, so the library that you have to choose is *lib1*. You can select the library in the Vivado GUI from a drop-down menu when you add the file.

This procedure is valid for any kind of source file. If your file is a constraint file, just add it to a .con list file in the list directory, e.g. `repo/Top/project1/list/lib1.con`. If your file comes form a submodule in the repository, you have to add it in the proper .sub list file.

### Renaming a file already in the project
If you need to rename or move a file, say from `path1/f1.hdl` to `path2/f2.hdl` do so and change the name in the proper list file accordingly.
Don't forget to rename the file on git as well:

```shell
git mv path1/f1.hdl path2/f2.hdl
git commit -m "Renamed f1 into f2"
git push
```

### What can go wrong?
If you do something wrong (e.g. you add a name of a non-existing file, create a list file with an invalid extension, etc.) you will get an error when you run the CreateProject script. In this case read Hog's error message and try to fix it.
If you do something wrong with Vivado library, the error will at synthesis time beacuse Vivado will not be able to find the component.

## Adding a new IP 
If you want to add a new IP core, say it's called **my_ip1**, you must create it in out-of-context mode and save the .xci file (and only that) in the repository in a subfolder of the special IP folder `repo/IP`.

Moreover, the xci file must be in a folder with the same name as the file, like this: `repo/IP/my_ip1/my_ip1.xci`.

If you want to keep different sets of IPs separate you can use additional subfolders in the IP directory, for example: `repo/IP/some_folder/my_ip1/my_ip1.xci`. Now you can add the .xci normally to any source list file in the list folder of your project.

When Vivado synthesises the IPs, it creates plenty of additional files whete the .xci file is located. To avoid to commit those file to the repository, a `.gitignore` file is used. This file specifies to git that every file that is not a .xci file inside the IP directory must be ignored.

#### Vivado IP initialization coefficient files (.coe)
If you have a .coe file for RAM initialization, you cannot store it inside the IP folder, otherwise it will be ignored as explained earlier. You can store it enywhere else in the reposiutory.
Pay attantion to specify the path to this file as a **relative path**. This must be done in the text box in vivado GUI when you customise the IP.

## A couple of things before getting to work
Here you can find a couple of details and suggestions that can be useful when working with Hog-handled repository.

### Commit before starting the workflow
All the Hog scripts handling version control are automatically added to your project: this means that you have the possibility to create a reproducible and traceable bitfile, even when you run locally.
This will happen **only if you commit your local changes before running synthesys**. You don't have to push! Just commit locally, then you can push when you are sure that your work is good enough.
If you don't commit, Hog will alert you with a Critical Warning at the beginning of the synthesis.

### Different list files
As we have explained above, source files taken from different list files will be added to your project in different "libraries": the name of each library is the name of the list file. When working with components coming from different list files, you will need to formally include the libraries and call the component from the library it belongs to. For example, in VHDL:

```vhdl
	library lib1
	use lib1.all

	...

	u_1 : entity lib1.a_component_in_lib1
	port map(
		clk => clk,
		din => din,
		dout => dout
	);
```

If working within the same library, you can normally use the "work" library.

### Wrapper scripts
A set of bash scripts can be used to run IP synthesis, project synthesis, implementation and bitstream generation without opening the vivado gui. The commands to launch are:

```console
	./Hog/LaunchSynthesis.sh <proj_name>
	./Hog/LaunchIPSynth.sh <proj_name>
	./Hog/LaunchImplementation.sh <proj_name>
```

These scripts call the Tcl scripts contained in `Hog/Tcl/launchers` that are used in the continuous integration. But as they work perfectly even locally, we wrapped them in these shell scripts so that you can use them locally if you don't want to open the GUI.
Launching the implementation without having launched the synthesis beforehand will run all the previous stages, exactly as if you clicked the GUI button.