# Creating, building and simulating projects

Hog provides a series of bash scripts to create, build and simulate your projects. Of course, you are not obliged to use them and you are free to use the Vivado/Quartus GUI or Tcl console instead.

##Create project

This section assumes that all the Hog list files and the project `.tcl` file have been configured as described in the previous sections.

The project can be created using shell or Vivado/Quartus Tcl console

###Using shell

Open your bash shell, go to your project path and type:

``` bash
  MyProject> ./Hog/CreateProject.sh <project_name>
```

If you don't know the name of your project, simply issue the command without any argument and it will return the list of projects that can be created.

``` bash
  MyProject> ./Hog/CreateProject.sh
```

###Using Vivado/Quartus Tcl console
You can also source your project `.tcl` script directly from the  Vivado/Quartus Tcl console, by issuing this command:

``` tcl
  source Tcl/<project_name>/<project_name>.tcl
```

##Synthesis and Implement the IPs
IP synthesis can be run using shell, Vivado/Quartus GUI or Vivado/Quartus Tcl console.

###Using shell (**Vivado Only**)
Open your bash shell and type:

``` bash
  MyProject> ./Hog/LaunchIPSynth.sh <project_name>
```

###Using Vivado/Quartus GUI
Right click on each IP and click the "Generate Output Products" button.

<img style="float: middle;" width="700" src="../figures/ip.png">


###Using the Tcl console (**Vivado Only**)
Open Vivado Tcl console and type:
``` tcl
 source ./Hog/Tcl/launchers/launch_ip_synth.tcl [-NJOBS <number of jobs>] <project_name>
```
The option *-NJOBS* sets the number of jobs used to run synthesis. The default value is 4.

##Synthesise your project
Project synthesis can be run using shell, Vivado/Quartus GUI or Vivado/Quartus Tcl console.

###Using shell (**Vivado Only**)
Open your bash shell and type:

``` bash
  MyProject> ./Hog/LaunchSynthesis.sh <project_name> [-NJOBS <number of jobs>]
```

The option *-NJOBS* sets the number of jobs used to run synthesis. The default value is 4.

###Using Vivado/Quartus GUI
Click on "Run Synthesis" button (on the left).

<img style="float: middle;" width="700" src="../figures/synthesis.png">


###Using the Tcl console (**Vivado Only**)
Open the Vivado Tcl console and type:

``` tcl
 source ./Hog/Tcl/launchers/launch_synthesis.tcl [-NJOBS <number of jobs>] <project_name>
```
The option *-NJOBS* sets the number of jobs used to run synthesis. The default value is 4.

##Implement your project
Project implementation/bitfile generation can be run using shell, Vivado/Quartus GUI or Vivado/Quartus Tcl console.

###Using shell (**Vivado Only**)
Open your bash shell and type:

``` bash
  ./Hog/LaunchImplementation.sh <project_name> [-NJOBS <number of jobs>] [-no_bitstream]
```
The option *-NJOBS* sets the number of jobs used to run implementation. The default value is 4.
The option *-no_bitstream* is used to skip the bitstream generation phase.

###Using Vivado/Quartus GUI
Click on "Run Implementation" and "Generate Bitstream" buttons (on the left).

<img style="float: middle;" width="700" src="../figures/implementation.png">

###Using the Tcl console (**Vivado Only**)
Open the Vivado Tcl console and type:
``` tcl
 source ./Hog/Tcl/launchers/launch_implementation.tcl [-NJOBS <number of jobs>] [-no_bitstream] <project_name>
```

The option *-NJOBS* sets the number of jobs used to run implementation. The default value is 4.
The option *-no_bitstream* is used to skip the bitstream generation phase.

##Run simulation
Project simulation can be run using shell, Vivado/Quartus GUI or Vivado/Quartus Tcl console.
Hog supports Vivado simulator (xsim), ModelSim and QuestaSim.
The simulation files and properties, such as the selected simulator, eventual wavefiles or do files are set as explained in the section
[Simulation list files](../02-List-files/#simulation-list-files-sim).
If ModelSim or QuestaSim are used, the Vivado libraries must be compiled by the user in a directory.
ModelSim/Questasim libraries can be compiled by using shell command *Hog/Init.sh* or by using the tcl commands [Hog/Tcl/utils/compile_modelsimlib.tcl](../06-Hog-utils/#compile_modelsimlibtcl) or [Hog/Tcl/utils/compile_questalib.tcl](../06-Hog-utils/#compile_questalibtcl).

If this command is used, the simulation libraries will be stored into `./SimulationLib`.

###Using shell (**Vivado only**)
Open your bash shell and type:

``` bash
  ./Hog/LaunchSimulation.sh <project_name> [library path]
```
The option *[library path]* is the path of the compiled simulation libraries. Default: SimulationLib.

This command will launch the simulation for each `.sim` list file in your project with the chosen simulator(s).

###Using Vivado/Quartus GUI
Using the GUI, you can run only one simulation set at the time. First of all select the simulation set you want to run, by right clicking on simulation set name in project sources window.

<img style="float: middle;" width="700" src="../figures/active-sim.png">

Then click on "Run Simulation" button (on the left). Note that using the GUI, Vivado or Quartus will use the simulation software specified in your [project `.tcl` file](../01-Project-Tcl.md)

<img style="float: middle;" width="700" src="../figures/simulation.png">

###Using the Tcl console (**Vivado only**)
Open the Vivado Tcl console and type:
``` tcl
 source ./Hog/Tcl/launchers/launch_implementation.tcl [-lib_path <library path>] <project_name>
```

The option *-lib_path* is the path of the compiled simulation libraries. Default: `SimulationLib`.

This command will launch the simulation for each `.sim` list file in your project with the chosen simulator(s).

