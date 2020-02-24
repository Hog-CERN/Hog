# Working with an existing HDL project

In this section we describe how to get up to speed to work in a repository that is already [set up](./setupNewHogProject.md) with Hog.
All the instructions below can be executed both on a LINUX shell, or on a a git bash<sup>[1](#myfootnote1)</sup> if you qare using a Windows machine. We will call <repo> the repsitory that you are trying to work with.

We strongly recommend that you read all this section, it's quite short and it includes all you need to know to start working straight away without having to waste time later on.


## Cloning the repository
First of all, you have to clone the repository<sup>[2](#myfootnote2)</sup>:

```console
	git clone --recursive <path-to-repo>
```

Now you have all the source code and scripts you need in the <repo> folder.

<a name="myfootnote1">1</a>: to open a git bash session navigate to the directory where you want to open the bash (the root folder of your project). Right click on the folder and select open git bash here.
<a name="myfootnote2">2</a>: We used the --recursive option to automatically clone all the submodules included. In general a HDL repository may or may not include other submodules, but the Hog scripts are always included as submodules. If you have cloned the repository without the recursive options, you will have to go inside it and initialise the submodules (`git submodule init`) and update them (`git submoduke update`) 


## Create all Vivado/Quartus projects
Now to start working, you need to create the Vivado/Quartus projects contained in the repository. To do that, jsut cd into the repository (`cd <repo>`) and type:

```console

	./Hog/Init.sh

```

this script will guide you through the process and compile Questasim library and create all the projects in the <repo>/VivadoProject or <repo>/QuartusProject directory.

## Create one Vivado/Quartus projects
Alternatively you might want to create only the project you are interested in, say it's called <project name>.
To do that, cd into the repository (`cd <repo>`) and type:

```console

	./Hog/CreateProject.sh <project name>

```

This will create a Vivado/Quartus project under VivadoProjects/<project name> or QuartusProjects/<project name> that can be opened and modified with the gui normally.
If you don't know the project name, just run `./Hog/CreateProject.sh` and you will get a list of the existing projects on the repository.


Alternatively, you can go into the `Top` folder (that is always present in  Hog handled HDL project) and type `ls`: each directory in this path corrensponds to a Vivado/Quartus project in the repository.
There is one exception to this: you must not add a new file to the project ()source code, constraint, IP, etc.)  using the GUI. You have to add the file name in one of Hog list files as descirbed in the following paragraph.

## Adding a new file to the project or renamining a file
Let's now suppose that you want to add a new file to the project and that this file is lpacated in <repo>/<dir1>/ and is called <file1.hdl>. Let's also assume that you know how to add a new file to a Git repository, so we will just explain what to do as far as Hog is concerned.

This is a new file, unkown to Hog for now, but we want it to be included into the project next time that we run the CreateProject.sh script described above. To do this, we must add the file name and path of <file1.vhd> into a Hog list file. These list files are located in <repo>/Top/<project name>/list/ and may have different extensions: for now let's assume that the source file we want to add our file to is <lib1.src>.

Open the file with a text editor and just add the file name and path in a new line. Please make the path relative to the list directory so in our case it should be:

```
	../../<dir1>/<file1.vhd>

```

this is easier than it seems beacuse you can look at the other files listed in the src file and do exactly the same.

Now that the new file is included in a list file, you can close the Vivado/Quartus project and re create it by typing `./Hog/CreateProject.sh <project name>` again. You will have to do this every time you add a new file to ther project. It seems like a lot of work but it actually happens quite rarely in the work process, most of the time you just modify existing files, in whichd case you don't have to do any of this.

This procedure is valid for any kind of source file, if your file is a constraint file, just add it to a .con file in the list directory.

### Adding a new IP 
If you want to add a new IP core, please create it in out of context mode and save the .xci file (and only that one!) it in the repository in <repo>/IP/<new ip name>/<new ip name>.xci.
Now you can add the .xci normally to any source list file in the list folder of your project.


## A couple of things before getting to work

### Commit before starting the workflow
All the Hog scripts handling version control will be automatically added to your project: this means that you have the possibility to create a certified (reproducible and traceable) bitfile. There is a little price to pay though, you must commit your local changes before running synthesys. You don't have to push! Just commit locally, then you can push when you are sure that your work is good enough.
If you don't commit, Hog will alert you with a Critical Warning at the beginnign of the synthesis.


### Different souce files
Source files taken from  different list files, will be added to your project in diffferent "libraries": the name of each library being the name of the list file. This is nice to keep things tidy and separated but it also comes at a little cost: when working with files coming from different list files, you will need to formally include the libraries. For example, in VHDL:

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


## Other useful Hog things

### Wrapper scripts

There is a set of scripts that can be used to run synthesis, implementation and bitstream writing without opening the vivado gui. The commands to launch them are
```console
	./Hog/LaunchSynthesis.sh <proj_name>
	./Hog/LaunchIPSynth.sh <proj_name>	
	./Hog/LaunchImplementation.sh <proj_name>
	./Hog/LaunchWriteBistream.sh <proj_name>
```

Launching the implementation or the bistream writing without having launched the synthesis beforehand will run the synthesis stage too.

### The flavour


## Understading Hog a bit better
If you want to go deeper and better understand how the Hog system works, you may be interested in the following.


### Why so many list files
You might have noticed that there are different kind of list files: .src, .sub. ...
