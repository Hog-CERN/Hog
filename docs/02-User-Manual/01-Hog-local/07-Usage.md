#Usage

This section contains the full instructions on how to create the project and to run synthesis and implementation.

##Create project
This section assumes you already followed all the instructions previously detailed in this chapter. 
Follow the instructions to recreate a Vivado/Quartus project locally, including all the source files/IP cores decleared as explained in the section [04-Project-Tcl]. 
###Using shell 

Open your bash shell and type:

``` bash
  ./Hog/CreateProject.sh <project_name>
```
To know the list of available projects, simply type:
``` bash
  ./Hog/CreateProject.sh 
```

###Using Vivado Tcl console  

Open Vivado Tcl console and type:
``` tcl
  cd Tcl/<project_name>/
  source ./<project_name>.tcl 
```

