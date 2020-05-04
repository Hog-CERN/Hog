# Project Tcl file

As previously stated Hog uses a TCL script located in `./Top/<my_project>/<my_project>.tcl` to generate the HDL project.

The `<my_project>.tcl` is expected to define few basic variables containing the information needed to build your project.
The tcl script is expected to call the `./Hog/Tcl/create-project.tcl` script after setting the needed environment variables.
The latter script will read back the variables and generate the HDL project.
This section contains a full recipe to build the tcl script for your project.

A template for a Vivado project can be found under `./Hog/Templates/top.tcl`.

## Telling HOG the HDL compiler to be used

The first line of your tcl script is expected to indicate HOG which HDL compiler to be used to generate your project.
To do this the first line in the tcl script file mus be a comment containing the name of the tool to be used. 
The following tools are recognised:

- \#vivado
- \#vivadoHLS
- \#quartus 
- \#intelHLS

If this line is not available HOG will assume your project runs under Vivado.

*NOTE*: 'vivadoHLS' and 'quartus' options are currently under development. If you are willing to use the corresponding feature branch. Note that no support is guaranteed.
*NOTE*: 'intelHLS' is not supported will simply return an error message.

## TCL Variables

The `./Hog/Tcl/create-project.tcl` uses the following variables to build your project.

| Variable Name     | description                                                                                               | comments                                                  |
|:------------------|:----------------------------------------------------------------------------------------------------------|:----------------------------------------------------------|
| FPGA              | the device code, to be chosen among the ones provided by the chosen HDL compiler                          | optional                                                 |
| FAMILY            | the device family, to be chosen among the ones provided by the chosen HDL compiler                        |                                                           |
| SYNTH_STRATEGY    | synthesis strategy to be used, to be chosen among the ones provided by the chosen HDL compiler            |                                                           |
| SYNTH_FLOW        | synthesis flow to be used, to be chosen among the ones provided by the chosen HDL compiler                |                                                           |
| IMPL_STRATEGY     | implementation strategy to be used, to be chosen among the ones provided by the chosen HDL compiler       |                                                           |
| IMPL_FLOW         | implementation flow to be used, to be chosen among the ones provided by the chosen HDL compiler           |                                                           |
| DESIGN            | name of your project                                                                                      | `[file rootname [file tail [info script]]]`               |
| PROPERTIES        | optional additional properties to be set to create your project                                          | optional                                                  |
| path_repo         | path to the root folder of your repository                                                                | `[file normalize [file dirname [info script]]]/../../`    |
| bin_file          | if '1', creates a binary file (.bin) containing only device programming data, without the header information found in the standard bitstream file (.bit). | optional, default 0 |                                                                                                       |
