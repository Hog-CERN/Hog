#Usage

This section contains the instructions on how to create the project and how to run synthesis and implementation.

##Create project
This section assumes you already followed all the instructions previously detailed in this chapter. 
Follow the instructions to recreate a Vivado/Quartus project locally, including all the source files/IP cores decleared as explained in the section [List Files](./05-List-files). 
The project can be created using shell or Vivado/Quartus Tcl console
###Using shell 

Open your bash shell and type:

``` bash
  ./Hog/CreateProject.sh <project_name>
```
To know the list of available projects, simply type:
``` bash
  ./Hog/CreateProject.sh 
```

###Using Vivado/Quartus Tcl console  

Open Vivado/Quartus Tcl console and type:
``` tcl
  cd Tcl/<project_name>/
  source ./<project_name>.tcl 
```

##Run synthetis
Project synthesis can be run using shell, Vivado/Quartus GUI or Vivado/Quartus Tcl console

###Using shell
Open your bash shell and type:

``` bash
  ./Hog/LaunchSynthesis.sh <project_name>
```

###Using Vivado/Quartus GUI
Click on "Run Synthesis" button (on the left).

###Using Vivado/Quartus Tcl console
Open Vivado/Quartus Tcl console and type:
``` tcl
 source ./Hog/Tcl/launchers/launch\_synthesis.tcl <project_name>
```
**Quartus projects are not yet supported**


##Run implementation
Project implementation/generate bitfile can be run using shell, Vivado/Quartus GUI or Vivado/Quartus Tcl console

###Using shell
Open your bash shell and type:

``` bash
  ./Hog/LaunchImplementation.sh <project_name>
```

###Using Vivado/Quartus GUI
Click on "Run Implementation" and "Generate Bitstream" buttons (on the left).

###Using Vivado/Quartus Tcl console
Open Vivado/Quartus Tcl console and type:
``` tcl
 source ./Hog/Tcl/launchers/launch\_implementation.tcl <project_name>
```
**Quartus projects are not yet supported**

