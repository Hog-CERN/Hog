# Hog utils

Hog provides a series of Tcl scripts solving different tasks that will be described in this section. All the following scripts can be found in *./Hog/Tcl/utils*. 

## check-syntax.tcl

This script checks the code syntax in a vivado project.
Arguments:
- Project name

Usage:

```tcl
  source Hog/Tcl/utils/check-syntax.tcl -tclargs <project_name>
```

## compile_modelsimlib.tcl

This script compiles the Modelsim libraries needed to simulate Vivado projects with Modelsim. The libraries are stored into the directory *./SimulationLib*.
Usage:

```tcl
  source Hog/Tcl/utils/compile_modelsimlib.tcl 
```

## compile_questalib.tcl

This script compiles the Questasim libraries needed to simulate Vivado projects with Questasim. The libraries are stored into the directory *./SimulationLib*.
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
- -eos_ip_path <IP PATH>

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
