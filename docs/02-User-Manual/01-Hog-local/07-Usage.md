#Usage

This section contains the instructions on how to create the project and how to run synthesis, implementation and simulation.

##Create project
This section assumes you already followed all the instructions previously detailed in this chapter. 
Follow the instructions to recreate a Vivado/Quartus project locally, including all the source files/IP cores decleared as explained in the section [List Files](../05-List-files). 
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
  ./Hog/LaunchSynthesis.sh <project_name> [-NJOBS <number of jobs>]
```

The option *-NJOBS* sets the number of jobs used to run synthesis. The default value is 4.
**Quartus projects are not yet supported**

###Using Vivado/Quartus GUI
Click on "Run Synthesis" button (on the left).

###Using Vivado/Quartus Tcl console
Open Vivado/Quartus Tcl console and type:
``` tcl
 source ./Hog/Tcl/launchers/launch\_synthesis.tcl [-NJOBS <number of jobs>] <project_name> 
```
The option *-NJOBS* sets the number of jobs used to run synthesis. The default value is 4.

**Quartus projects are not yet supported**


##Run implementation
Project implementation/bitfile generation can be run using shell, Vivado/Quartus GUI or Vivado/Quartus Tcl console.

###Using shell
Open your bash shell and type:

``` bash
  ./Hog/LaunchImplementation.sh <project_name> [-NJOBS <number of jobs>] [-no_bitstream]
```
The option *-NJOBS* sets the number of jobs used to run implementation. The default value is 4.
The option *-no_bitstream* is used to skip generate bitstream phase.
**Quartus projects are not yet supported**

###Using Vivado/Quartus GUI
Click on "Run Implementation" and "Generate Bitstream" buttons (on the left).

###Using Vivado/Quartus Tcl console
Open Vivado/Quartus Tcl console and type:
``` tcl
 source ./Hog/Tcl/launchers/launch\_implementation.tcl [-NJOBS <number of jobs>] [-no_bitstream] <project_name>
```

The option *-NJOBS* sets the number of jobs used to run implementation. The default value is 4.
The option *-no_bitstream* is used to skip generate bitstream phase.
**Quartus projects are not yet supported**

##Run simulation
Project simulation can be run using shell, Vivado/Quartus GUI or Vivado/Quartus Tcl console.
Hog supports Vivado simulator (xsim), ModelSim and QuestaSim. 
The simulation files and properties, such as the selected simulator, eventual wavefiles or do files are set as explained in the section
[Simulation list files](../05-List-files/#simulation-list-files-sim).
If ModelSim or QuestaSim are used, the Vivado libraries must be compiled by the user in a directory. 
ModelSim/Questasim libraries can be compiled by using shell command:

``` bash
  ./Hog/Init.sh 
```

If this command is used, the simulation libraries will be stored into "./SimulationLib".

###Using shell
Open your bash shell and type:

``` bash
  ./Hog/LaunchSimulation.sh <project_name> [library path]
```
The option *[library path]* is the path of the compiled simulation libraries. Default: SimulationLib.
**Quartus projects are not yet supported**

###Using Vivado/Quartus GUI
Click on "Run Simulation" button (on the left).

###Using Vivado/Quartus Tcl console
Open Vivado/Quartus Tcl console and type:
``` tcl
 source ./Hog/Tcl/launchers/launch\_implementation.tcl [-lib_path <library path>] <project_name>
```

The option *-lib_path* is the path of the compiled simulation libraries. Default: SimulationLib.
**Quartus projects are not yet supported**

