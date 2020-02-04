# Handle existing project

In this section we describe how to create a project file, launch synthesis, launch implementation or create a bitstream from command line.
This section assumes your project is already structured according to what is described in the [set up new project](./setupNewHogProject.md) section.
All the instructions below can be executed bith on a LINUX shell, both on a machine running on WINDOWS by using a git bash<sup>[1](#myfootnote1)</sup>.
Once you cloned your repository:

```console
	git clone --recursive <path-to-repo>
```

you should obtain all the source code and scripts you need.\
Please note you have to clone the repository using recursive since Hoog is included as a submodule. 

<a name="myfootnote1">1</a>: to open a git bash session navigate to the directory where you want to open the bash (the root folder of your project). Right click on the folder and select open git bash here.

## Create a project file

To create a project file run:
```console

./Hog/CreateProject.sh example

```
This will create a Vivado/Quartus project under VivadoProjects/proj_name or QuartusProjects/proj_name that can be opened with the gui.
All the Hog scripts handling version control will be automatically added to your project.
This means you will have to commit your local changes bevore running synthesys or HOG-Warinings will be triggered.

## Wrapper scripts

There are three scripts that can be used to run synthesis, implementation and bitstream writing without opening the vivado gui. The commands to launch them are
```console

	./Hog/LaunchSynthesis.sh <proj_name>
	./Hog/LaunchImplementation.sh <proj_name>
	./Hog/LaunchWriteBistream.sh <proj_name>

```
Launching the implementation or the bistream writing without having launched the synthesis beforehand will run the synthesis stage too.



