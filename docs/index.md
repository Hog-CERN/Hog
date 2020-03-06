# Our site is coming soon!!
Here's a taste of what it will contain!

![](./custom/assets/images/hog.png) 

# Hog: HDL on git

## Introduction
Coordinating firmware development among many international collaborators is becoming a very widespread problem in particle physics. Guaranteeing firmware synthesis with P&R **reproducibility** and assuring **traceability** of binary files is paramount.

Hog tackles these issues by exploiting advanced git features and being integrated with HDL IDE (Vivado or Quartus) to try not to add useless overhead work and let developers do their job as they are used to.

## Rationale
For synthesis and P&R **reproducibility**, we need absolute control of:

- HDL source files
- Constraint files
- Vivado/Quartus settings (such as synthesis and implementation strategies)

For **traceability**, every time we produce a binary firmware file, we must:

- Know exactly how the binary file was produced
- Be able to go back to that point in the repository

To do this, Hog **automatically** embeds the git **commit SHA** into the binary file together with a more understandable **numeric version** __M.m.p__. Moreover, it automatically renames the file, including the version and inserts the hexadecimal value of the SHA so that it can be retrieved (using a text editor) in case the file gets renamed.

Avoiding errors is impossible, but Hog's goal is to leave as little room as possible.

Another important Hog's principle is to **reduce to the minimum** the time needed for an external developer to **get up to speed** to work on a HDL project. For this reason, Hog **does not rely on any external tool** or library, only on those you must have to syntehsise, implement (Vivado/Quartus) and simulate (Modelsim/Questasim) the design.

To start working on any project[^1] contained in a git repository handled with Hog, you just need to:

```console
git clone --recursive <HDL repository>
cd <HDL repository>
./Hog/CreateProject <project_name>
```
The project will appear in ./VivadoProject/<project>  (or ./QuartusProject/<project>) and you can open it with your Vivado GUI!

[^1]: If you don't know the project name, just run `./Hog/CreateProject` and a list will be displayed.


## What is Hog
Hog is a set of Tcl/Shell scripts plus a suitable methodology to handle HDL designes on a git repository.


Hog is included as a submodule in the HDL repository (a `Hog` directory is always present in Hog-handled repository) and allows developers to create the Vivado/Quartus project(s) locally and synthesise and implement it or start working on it.

A folder called `Top` is in the root of repository and it contains a subfolder for each Vivado/Quartus project in the repository. Every one of these directory has a fixed -easy to understand- structure and contains everything that is needed to re-create the Vivado/Quartus project locally, apart from the source files[^2] that are stored anywhere in the repository.
[^2]:Source files are the HDL files (.vhd, .v) but also constraint files (.xdc, .sdc, .qsf, .tcl, ...). IP files (.xci, .ip, .qip, ...) and Board Design files must be stored in special folders, as explained later.

An `IP` (and possibly a `BD`) folder is used to store intellectual properties (and Board Design). Apart from this restrictions, any structure of subdirectories can be created in the IP (and BD) folder.

## What's in the Hog folder?
Plenty of scripts! Please run
```console
	./Hog/Init.sh
```
to initialise the repository locally, and follow the instructions.

And you can always have a look yourself. Type `cd Hog` and run what you want to see what happens. Most of the scripts have a -h option to give you detailed instructions.
However, the most important script is `Hog/CreateProject.sh` that serves to create the Vivado/Quartus project locally. When creating the project, Hog integrates a set of Tcl scripts to handle the issues described above and guarantee reproducibility and traceability.

Everything is as transparent as we could think of, designed to make you waste just little bit of time and get you to work to the HDL design as soon as possible.


## HOG user manual

In this website you can find a quick guide to learn how to work in a [Hog-handled repository](01-Getting-Started/01-existingProjects) or to [setup a new one](01-Getting-Started/03-setupNewHogProject) and a complete user manual to understand all the details and learn how to maintain a Hog-handled repository.

Would you like to have fun with git and a Tcl? Please join us and read the [Contributing](03-Contributing) section.

## Contacts

To report an issue use the git issues in the [HOG git repository](https://gitlab.cern.ch/hog/Hog).
Please check in existing and solved issues before submitting a new issue.

For questions related to the HOG package, please get in touch with [HOG support](mailto:hog@cern.ch).

For anything related to this site, please get in touch with [Nicolò Biesuz](mailto:nbiesuz@cern.ch).

