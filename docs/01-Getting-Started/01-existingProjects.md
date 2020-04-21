# Working with a HDL repository handled with Hog

In this section we describe how to work with a repository that is already [set up](./02-setupNewHogProject.md) with Hog.

All the instructions below can be executed both on a Linux shell, or on git bash[^1] on a Windows machine.

[^1]: To open a git bash session navigate to the directory where you want to open the bash (the root folder of your project). Right click on the folder and select open git bash here.

For all of the following to work, Vivado (or Quartus) executable must be in your PATH: i.e. if you type `vivado` the program must run. If you intend to use Modelsim or Questasim, also the vsim executable must be in the PATH: i.e. if you type `vsim` the simulator should start.

This is a recap of the requirements:

- Have git installed and know how to use it (git bash for windows)
- Have Vivado or Quartus installed and in the PATH (and be familiar with it)
- Optionally have Questasim installed and vsim in the PATH

We recommend that you read all of this section as it contains all you need to know to start working straight away without having to waste time later on.

We also suggest that you learn git basics, there is plenty of useful resources online. This will ensure a fruitful usage of a very powerful tool and heavily reduce your frustration.

## Cloning the repository
First of all, you have to clone the repository[^2], let's call it *repo* from now on:

```console
	git clone --recursive <protocol>://gitlab.cern.ch/<group>/<repository name>
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

Now you can open your project with Vivado or Quartus and **work almost normally** with the GUI, while Hog -that is now integrated in your project- will automatically provide information on the status of the repository and integrate it in the final binary file.

[^5]: The CreateProject script, integrates Hog's Tcl scripts in the Vivado/Quartus project without you noticing it. From now on, Hog scripts will run automatically, every time you start the sysnthesis or any other step in the workflow. The most important script is the pre-synthesis one that interacts with your local git repository and integrates its version and git commit SHA into your HDL project by means of HDL generic parameters.

We said almost normally because there is one exception: you **must not** add a new file to the project[^3] using the GUI (HDL code, constraint, IP, etc.). You **must add** the file name in one of Hog's list files and re create the project, as descirbed in the following paragraph.

[^3]: If you add the file normally, your project will work locally, of course. Also, if you add the file with `git add` the new file will also be correctly stored in the repository remotely . The new file will not be part of the project remotely, this is why you have to follow the instractions explained in the following paragraph to assure that everything you do locally is correctly propagated remotely.

## Adding or renaming a file to the project
Let's now suppose that you want to add a new file to the project and that this file is loacated in *repo*/*dir1*/ and is called *file1.hdl*. Let's also assume that you know how to add a new file to a git repository (`git add <file name>; git commit -m "add new file"; git push`) and focus on Hog.

This is a new file, unknown to Hog for now, and we want it to be included into the project then next time that we run the CreateProject.sh script described above. To do this, you must add the file name and path of *file1.vhd* into a Hog list file. The list files are located in *repo*/Top/*project1*/list/. Let's assume that the list file you want to add our file to is *lib1.src*.

Open the file with a text editor and add the file name and path in a new line. Please make the path relative to the list directory so in our case it should be ../../*dir1*/*file1.vhd*.

This is typically easier than it seems, beacuse you can look at how the path of the other files listed in the src file is specified.

Now that the new file is included in a list file, you can close the Vivado/Quartus project and re-create it by typing `./Hog/CreateProject.sh <project name>` again.

Yes, you will have to do this every time you add a new file to ther project. It seems like a lot of work, but it's actually quite rare in the work process, most of the time you just modify existing files, in which case you don't have to do any of this.

This procedure is valid for any kind of source file, if your file is a constraint file, just add it to a .con list file in the list directory.

If you need to rename a file, do so (also on git `git mv <old_name> <new_name>; git commit -m "Renamed that file"; git push) and change the name in the proper list file accordingly.

If you do something wrong (e.g. you add a name of a non-existing file, create a list file with an invalid extension, etc.) you will get an error when you run the CreateProject script. In this case read Hog's error message and try to fix it, hopefully it's just a typo.

### Adding a new IP 
If you want to add a new IP core, please create it in out of context mode and save the .xci file (and only that one!) it in the repository in *repo*/IP/*ip_name*/*ip_name*.xci. Yes, the name of the folder must be the same as the xci file.
Now you can add the .xci normally to any source list file in the list folder of your project.

#### IP initialization files (.coe)

Please note that the `.gitignore` template provided by HOG adds constraints on the IP folder.
Out of all the files contained in *repo*/IP/, git will pick up only xci files.
Files with different extensions will be ignored.
If you have *.coe files for RAM initialization or analogous files please make sure the rules in the `.gitignore` file are set correctly or store these files in a separate folder.


## A couple of things before getting to work

### Commit before starting the workflow
All the Hog scripts handling version control will be automatically added to your project: this means that you have the possibility to create a certified (reproducible and traceable) bitfile. There is a little price to pay though, **you must commit your local changes before running synthesys**. You don't have to push! Just commit locally, then you can push when you are sure that your work is good enough.
If you don't commit, Hog will alert you with a Critical Warning at the beginnign of the synthesis.


### Different list files
Source files taken from different list files will be added to your project in different "libraries": the name of each library being the name of the list file. This is nice to keep things tidy and separated but it also comes at a little cost: when working with files coming from different list files, you will need to formally include the libraries. For example, in VHDL:

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
