Hog doxygen documentation     {#mainpage}
============

# General information
Here you can find information on how Hog functionalities are implemented.
The documentation is automatically generated from the code comments using [doxygen](https://www.doxygen.nl/index.html).

Hog consist of a series of Tcl scrips that are contained in the `Tcl` directory.
Inside this directory you will find the main library file `hog.tcl` containing most of Hog functions.
An exhaustive list of Hog's functions can be found [here](./globals.html).

Hog integrates a set of Tcl scripts in the firmware workflow, these scripts are located in the `Tcl/integrated` directory.
Tcl script used to launch specific firmware tasks (synthesis, implementation, simulation, etc.) are located in the `Tcl/launchers` directory.
Additional utilities scripts are located in the `Tcl/utils` directory.
Tcl scripts used only in Hog-CI are located in the `Tcl/CI` directory. 

Bash scripts located in the main Hog directory are used to execute the launcher tcl scripts and to launch the project creation with Vivado/Quartus.
Additional shell scripts are located in the `Others` directory

Many Hog Tcl scripts can be run in debug mode using tcl shell (`tclsh`), this feature is extremely useful for developing. To do that you need to install the `tcllib` library available on yum and apt-get.

Hog user documentation can be found in the [user documentation website](../)

# Become a member of the Hog community
You are very welcome to become an active Hog developer!

Get in contact with one of us (e.g. [Francesco Gonnella](mailto:francesco.gonnella@cern.ch) or [Davide Cieri](mailto:davide.cieri@cern.ch)), such that we can have a quick feedback of your background and your expertise.

Please also have a look to the [contributing](../04-Developing-for-Hog/01-contributing/) section of the user manual.

## License
Hog is distributed under the [Apache License, Version 2.0](http://www.apache.org/licenses/LICENSE-2.0).
