# Project Tcl file

As previously stated Hog uses a TCL script located in `./Top/<my_project>/<my_project>.tcl` to generate the HDL project.

The `<my_project>.tcl` is expected to define few basic variables containing the information needed to build your project.
The tcl script is expected to call the `./Hog/Tcl/create_project.tcl` script after setting the needed environment variables.
The latter script will read back the variables and generate the HDL project.
This section contains a full recipe to build the tcl script for your project.

A template for a Vivado project can be found under `./Hog/Templates/top.tcl`.

## Telling Hog the HDL compiler to be used

The first line of your tcl script is expected to indicate Hog which HDL compiler to be used to generate your project.
To do this the first line in the tcl script file must be a comment containing the name of the tool to be used. 
The following tools are recognised:

- \#vivado
- \#vivadoHLS
- \#quartus 
- \#intelHLS

If this line is not available Hog will assume your project runs under Vivado.

*NOTE*: 'vivadoHLS' and 'quartus' options are currently under development. If you are willing to use the corresponding feature branch. Note that no support is guaranteed.

*NOTE*: 'intelHLS' is not supported will simply return an error message.

## TCL Variables

The `./Hog/Tcl/create_project.tcl` uses the following variables to build your project.

### FPGA   
The FPGA variable indicates the target device code.
This variable is *mandatory*.
It must be chosen among the ones provided by the chosen HDL compiler.
As an example for a Xilinx Virtex-7 FPGA it could be set to xc7vx330tffg1157-2.
Note that the exact code will depend on the full charateristics of the device you are using, e.g. number of logic cells, package, speed grade, etc.


### FAMILY 
The FPGA variable indicates the device family. 
This variable applies to *Quartus only*.
The value must be chosen among the ones provided by the chosen HDL compiler.
As an example for a Intel MAX10 FPGA it must be set to "MAX 10".
*NOTE* that the variable value is included in quotation marks.

### SYNTH_STRATEGY    
The SYNTH_STRATEGY variable indicates the synthesis strategy to be used.
It has to be chosen among the ones provided by the chosen HDL compiler
As an example for Vivado you could use: "Vivado Synthesis Defaults".
*NOTE* that the variable value is included in quotation marks.


### SYNTH_FLOW    
The SYNTH_FLOW variable indicates the synthesis flow to be used.
It has to be chosen among the ones provided by the chosen HDL compiler
As an example for Vivado you could use: "Vivado Synthesis 2019".
*NOTE* that the variable value is included in quotation marks.


### IMPL_STRATEGY     
The IMPL_STRATEGY variable indicates the implementation strategy to be used.
It has to be chosen among the ones provided by the chosen HDL compiler
As an example for Vivado you could use: "Vivado Implementation Defaults" or "Performance_Retiming".
*NOTE* that the variable value is included in quotation marks



### IMPL_FLOW
The IMPL_FLOW variable indicates the implementation flow to be used.
It has to be chosen among the ones provided by the chosen HDL compiler.
As an example for Vivado you could use: "Vivado Implementation 2019".
*NOTE* that the variable value is included in quotation marks.

### DESIGN 
The DESIGN variable indicates the name of your project.
This variable is *mandatory*.
It must be automatically set in tthe tcl file, i.e. use "[file rootname [file tail [info script]]]" to get the name of the `<my_project>.tcl` script
*NOTE* that the variable value is included in quotation marks.

### PROPERTIES
The PROPERTIES variable allows you to add optional additional properties to be set while creating your project.
This variable is optional and can be left empty.

*NOTE*: you should use one line per property and that the '\' character must be the last one of each line

To set a property you must define two discrtionaries, one for synthesis and one for implementation. 
The discionaries must have the names of the corresponding Vivado runs.
The default Vivado run names are: synth_1 for synthesis and impl_1 for implementation.

To find out the exact name and value of the property, use Vivado GUI to click on the checkbox you like.
This will make Vivado run the set_property command in the Tcl console.
Then copy and paste the name and the values from the Vivado Tcl console into the lines below.

An example of properties setting is:

```tcl
    set PROPERTIES [dict create \
        synth_1 [dict create \
            STEPS.SYNTH_DESIGN.ARGS.FANOUT_LIMIT 600 \
            STEPS.SYNTH_DESIGN.ARGS.RETIMING true \
            ] \
        impl_1 [dict create \
            STEPS.OPT_DESIGN.ARGS.DIRECTIVE Default \
                ]\
        ]
```



### PATH_REPO
The PATH_REPO variable indicates the path to the root folder of your repository.
This variable is *mandatory*.
The value must be set automatically in the tcl script, i.e. use "[file normalize [file dirname [info script]]]/../../"

### BIN_FILE
The PATH_REPO variable indicates the output extention for the output file.
If this variable is set to '1', the implementation will creates a binary file (.bin) containing only device programming data, without the header information found in the standard bitstream file (.bit).
This variable is optional and its default value is '0'.

## Running additional scripts

The `<my_project>.tcl` script can call other additional script placed in your repository.
If you wish to run some scripts before creating your project then place them before calling `./Hog/Tcl/create_project.tcl`.
The `./Hog/Tcl/create_project.tcl` will finish leaving you project open, you can run additional scripts on your project by placing them after `./Hog/Tcl/create_project.tcl`.

*NOTE*: Do this at your own risk.
