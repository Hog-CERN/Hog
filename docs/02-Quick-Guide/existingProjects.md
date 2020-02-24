# Working with an existing HDL project

In this section we describe how to get up to speed to work in a repository that is already [set up](./setupNewHogProject.md) with Hog.
All the instructions below can be executed both on a LINUX shell, or on a a git bash[^1] on a Windows machine. We will call *repo* the repsitory that you are trying to work with.

[^1]: To open a git bash session navigate to the directory where you want to open the bash (the root folder of your project). Right click on the folder and select open git bash here.

Another requirement is that a Vivado (or Quartus) executable must be in the PATH: i.e. if you type `vivado` the program must run. If you intend to use Modelsim or Questasim, also the vsim executable must be in the PATH: i.e. if you type `vsim` the simulator should start.

So a recap of the requirements:

- Have git installed and know how to use it (git bash for windows)
- Have Vivado or Quartus installed and in the PATH (and be familiar with it)
- Optionally have Questasim installed and vsim in the PATH

We recommend that you read all of this section as it contains all you need to know to start working straight away without having to waste time later on.
We also suggest that you learn git basics, there is plenty of useful resources online. This will ensure a fruitful usage of a very powerful tool and heavily reduce your frustration.

## Cloning the repository
First of all, you have to clone the repository[^2]:

```console
	git clone --recursive <protocol>://gitlab.cern.ch/<group>/<repo>
```

Now you have all the source code and scripts you need in the *repo* folder.

[^2]: You will have to chose the *protocol* that works for you: ssh, https, or krb5. We used the `--recursive` option to automatically clone all the submodules included. In general a HDL repository may or may not include other submodules, but the Hog scripts are always included as submodules. If you have cloned the repository without the recursive options, you will have to go inside it and initialise the submodules `git submodule init` and update them `git submodule update` 


## Create all Vivado/Quartus projects
Now to start working, you need to create the Vivado/Quartus projects contained in the repository. To do that, jsut cd into the repository (`cd <repo>`) and type:

```console

	./Hog/Init.sh

```

this script will guide you through the process and compile Questasim library and create all the projects in the *repo*/VivadoProject or *repo*/QuartusProject directory.

## Create one Vivado/Quartus projects
Alternatively you might want to create only the project you are interested in, say it's called *project1*.
To do that, cd into the repository (`cd <repo>`) and type:

```console

	./Hog/CreateProject.sh <project name>

```

in our example the project name is *project1*.

This will create a Vivado or Quartus project under VivadoProjects/*project1* or QuartusProjects/*project1* that can be opened and modified with the GUI normally.
If you don't know the project name, just run `./Hog/CreateProject.sh` and you will get a list of the existing projects on the repository.

Alternatively, you can type `cd Top` (the Top folder is always present in a Hog handled HDL repository) and type `ls`: each directory in this path corrensponds to a Vivado/Quartus project in the repository.

Now you can open your project with Vivado or Quartus and work normally with the GUI.

There is one exception to this: you **must not** add a new file to the project[^3] using the GUI (HDL code, constraint, IP, etc.). You **must add** the file name in one of Hog's list files and re create the project, as descirbed in the following paragraph.

[^3]: If you add the file normally, your project will work locally, of course. Also, if you add the file with `git add` the new file will also be correctly stored in the repository remotely . The new file will not be part of the project remotely, this is why you have to follow the instractions explained in the following paragraph to assure that everything you do locally is correctly propagated remotely.

## Adding or renaming a file to the project
Let's now suppose that you want to add a new file to the project and that this file is lpacated in *repo*/*dir1*/ and is called *file1.hdl*. Let's also assume that you know how to add a new file to a git repository, so we will just explain what to do as far as Hog is concerned.

This is a new file, unkown to Hog for now, but we want it to be included into the project then next time that we run the CreateProject.sh script described above. To do this, we must add the file name and path of *file1.vhd* into a Hog list file. These list files are located in *repo*/Top/*project1*/list/. Let's assume that the source file we want to add our file to is *lib1.src*.

Open the file with a text editor and add the file name and path in a new line. Please make the path relative to the list directory so in our case it should be ../../*dir1*/*file1.vhd*.

This is typically easier than it seems, beacuse you can look at the other files listed in the src file and do exactly the same.

Now that the new file is included in a list file, you can close the Vivado/Quartus project and re create it by typing `./Hog/CreateProject.sh <project name>` again. You will have to do this every time you add a new file to ther project. It seems like a lot of work but it actually happens quite rarely in the work process, most of the time you just modify existing files, in whichd case you don't have to do any of this.

This procedure is valid for any kind of source file, if your file is a constraint file, just add it to a .con file in the list directory.

If you need to rename a file, do so (also on git) and then change the name in the proper list file accordingly.

### Adding a new IP 
If you want to add a new IP core, please create it in out of context mode and save the .xci file (and only that one!) it in the repository in *repo*/IP/*ip_name*/*ip_name*.xci. Yes, the name of the folder must be the same as the xci file.
Now you can add the .xci normally to any source list file in the list folder of your project.


## A couple of things before getting to work

### Commit before starting the workflow
All the Hog scripts handling version control will be automatically added to your project: this means that you have the possibility to create a certified (reproducible and traceable) bitfile. There is a little price to pay though, **you must commit your local changes before running synthesys**. You don't have to push! Just commit locally, then you can push when you are sure that your work is good enough.
If you don't commit, Hog will alert you with a Critical Warning at the beginnign of the synthesis.


### Different souce files
Source files taken from different list files will be added to your project in diffferent "libraries": the name of each library being the name of the list file. This is nice to keep things tidy and separated but it also comes at a little cost: when working with files coming from different list files, you will need to formally include the libraries. For example, in VHDL:

```vhdl
	library lib_1
	use lib_1.all

	...

	u_1 : entity lib_1.a_component_in_lib1 
	port map(
		clk => clk,
		din => din,
		dout => dout
	);
```

If working within the same library, you can normwally use the "work" library.


## Other useful Hog features

### Wrapper scripts

There is a set of scripts that can be used to run synthesis, implementation and bitstream writing without opening the vivado gui. The commands to launch them are
```console
	./Hog/LaunchSynthesis.sh <proj_name>
	./Hog/LaunchIPSynth.sh <proj_name>	
	./Hog/LaunchImplementation.sh <proj_name>
	./Hog/LaunchWriteBistream.sh <proj_name>
```

These scripts actually call the Tcl scripts contained in Hog/Tcl/launchers that are used in the continuous integration. But as the work perfectly even locally, we wrapped them in these shell scripts so that you can use them locally if you don't want to open the GUI.

Launching the implementation or the bistream writing without having launched the synthesis beforehand will run all the previous stages, exactly as if you clicked the GUI button.

### Why so many list files
There are several kinds of list files, depending on the extension: src, sub, sim, con[^4].
[^4]: Also .ext files exist. They are used to handle external files that are protected by copyright and cannot be published on the repository. Will will not discuss that in this quick guide.

**.src files** contain HDL files used for synthesis taken from the repository. HDL files coming from one .src list-file, are  included into the Vivado project in the same library, named after the .src file itself. For example if we have a lib_1.src file in our list directory, containing filenames inside, like this:

    ../../lib_1/hdl/file1.vhd
    ../../lib_1/hdl/file2.vhd
    ../../lib_1/hdl/file3.vhd

they will be included into the Vivado project in the lib_1 library, as we have already discussed.

Properties, like VHDL 2008 compatibility, can be specified after the file name in the list file, separated by any number of spaces. If _file_3.vhd_  requires VHDL 2008, for example, you should specify it like this:

    ../../lib_1/hdl/file1.vhd 
    ../../lib_1/hdl/file2.vhd
    ../../lib_1/hdl/file3.vhd 2008

**.con** files contain constraint files. Both xdc (for Vivado) and Tcl files can be added. By specifying the property `nosynth` (after the file name, separated by any number of spaces) we can tell Vivado not to use this specific constraint file in synthesis. Viceversa, `noimpl` is used to use the constraint in synthesis only. 

Each **.sim files** represent a simulation set and contains HDL files used for simulation only. More importantly, each simulation set (hence each .sim file) must incliude the HDL file containing the top module of the simulation. The name top module must be specified as a property with the keyword `topsim=`. Moreover the .do file and the wave file can be specified, as in the following example:

```

../../lib_1/tb/hdl/tb_for_lib1.vhd topsim=tb_lib1 wavefile=lib1/wave_lib1.tcl dofile=lib1/dofile_lib1.do
../../lib_1/tb/hdl/FileReader.vhd
../../lib_1/tb/hdl/FileWriter.vhd


```

**.sub files** contain HDL files used for synthesis taken from git submodules in the project. As described in detail in the more advanced documentation, Hog extracts the version and the git SHA for every library in the project. For the files coming from a submodule though, this is not possible as the subomdule may not have tags in the Hog format. This is why files coming from a submodule must be listed in a .sub file having exactly the same name as the submodule. In this case Hog will only extract the git SHA of the submodule and embed it in the firmware.