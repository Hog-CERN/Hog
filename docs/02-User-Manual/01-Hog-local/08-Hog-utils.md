# Hog utils

Hog provides a series of Tcl scripts solving different tasks that will be described in this section.
All the following scripts are located in *./Hog/Tcl/utils*. 
Run each script with the *-h* option to see the full list of arguments/options and usage example.

## check-syntax.tcl

This script checks the code syntax in a vivado project.
Arguments:
- Project name

Usage:

```tcl
  source Hog/Tcl/utils/check-syntax.tcl -tclargs <project_name>
```

## compile_modelsimlib.tcl

This script compiles the ModelSim libraries needed to simulate Vivado projects with ModelSim. The libraries are stored into the directory *./SimulationLib*.
Usage:

```tcl
  source Hog/Tcl/utils/compile_modelsimlib.tcl 
```

## compile_questalib.tcl

This script compiles the QuestaSim libraries needed to simulate Vivado projects with QuestaSim. The libraries are stored into the directory *./SimulationLib*.
Usage:

```tcl
  source Hog/Tcl/utils/compile_questalib.tcl 
```

## get_ips.tcl

To speed-up IPs re-generation, Hog allows the user to store compiled IPs into a EOS directory and retrieve them instead of recompile them. 
This is particularly useful for the CI or if the project repository has been freshly cloned. The IPs are stored to EOS together with their SHA, so they are retrieved only if the .xci was not modified. 
The instructions to store the IPs to EOS are detailed in the section [IP synthesis](../07-Usage/#run-ip-synthesis).
get_ips.tcl is used to retrieve IPs from EOS.
Arguments:
- Project name
Options:
- -eos_ip_path <IP PATH>: the EOS path where IPs are stored.

Usage:

```tcl
  source Hog/Tcl/utils/get-ips.tcl -tclargs [-eos_ip_path <IP_PATH>] <project_name>
```

## make_doxygen.tcl

This script is used to create the doxygen documentation. The doxygen configuration file must be stored into *./doxygen/doxygen.conf*. 
If there is no such file, the command will use *./Hog/Templates/doxygen.conf* as doxygen configuration file.

Usage:

```tcl
  source Hog/Tcl/utils/make_doxygen.tcl
```

## check_yaml_ref.tcl

This script checks that the Hog submodule SHA matches the ref in the .gitlab-ci.yml file. 
In fact .gitlab-ci.yml includes the Hog file gitlab-ci.yml:
```yml
include:
    - project: 'hog/Hog'
      file: '/gitlab-ci.yml'
      ref: 'v0.2.64'
```
If the version of the gitlab-ci.yml does not match the local Hog submodule one, unexpected errors may occour. 
The script verifies that gitlab-ci.yml in the Hog submodule matches the one defined in *ref* and, if it doesn't, suggests few solutions to fix the problem.
This script is run by default in the pre-synthesis stage.

Usage:
```tcl
  source Hog/Tcl/utils/check_yaml_ref.tcl
```

## copy_xml.tcl
This script copies IPBus XML files listed in a Hog list file and replace the version and SHA placeholders if they are present in any of the XML files.
Arguments:
- XML list file;
- destination directory;
Options:
- -generate: if set, the VHDL address files will be generated and replaced if already exisiting.
Usage: 
```yml
copy_xml <XML list file> <destination directory> [-generate]
```

## reformat.tcl

This script formats tcl scripts indentation. 
Arguments:
- tcl script

Options:
- -tab_width <pad width> (default = 2)

Usage: 
Usage:
```tcl
  source Hog/Tcl/utils/reformat.tcl -tclargs [-tab_width <pad_width>] <tcl_script> 
```


