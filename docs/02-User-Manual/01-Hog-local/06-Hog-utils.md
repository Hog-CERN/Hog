# Additional Tcl Scripts

Hog provides a series of Tcl scripts, which executes different common tasks. These scripts are located in *./Hog/Tcl/utils*.
To execute the scripts, you need to open first the Vivado Tcl Shell.

```bash
vivado -mode tcl
```

Run each script with the *-h* option to see the full list of arguments/options and usage example.

## check-syntax.tcl

This script checks the code syntax of a vivado project.

Arguments:

- `<project_name>`: the project name

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

To speed-up IPs re-generation, Hog allows the user to store compiled IPs into an EOS directory and retrieve them instead of recompile them.
This is particularly useful for the CI or if the project repository has been freshly cloned. The IPs are stored to EOS together with their SHA, so they are retrieved only if the `.xci` was not modified.
The instructions to store the IPs to EOS are detailed in the section [IP synthesis](../07-Usage/#run-ip-synthesis).
get_ips.tcl is used to retrieve IPs from EOS.
To execute this command you need to have [EOS software](https://eos.web.cern.ch/) installed on your machine.

Arguments:

- `<project_name>`: the project name

Options:

* `-eos_ip_path <IP PATH>`: the EOS path where IPs are stored

Usage:

```tcl
  source Hog/Tcl/utils/get-ips.tcl -tclargs [-eos_ip_path <IP_PATH>] <project_name>
```

## make_doxygen.tcl

This script is used to create the doxygen documentation. The doxygen configuration file must be stored into *./doxygen/doxygen.conf*.
If there is no such file, the command will use *./Hog/Templates/doxygen.conf* as doxygen configuration file.
You require a version of Doxygen newer than 1.8.13 installed on your machine, to execute this script

Usage:

```tcl
  source Hog/Tcl/utils/make_doxygen.tcl
```

## check_yaml_ref.tcl

This script checks that the Hog submodule SHA matches the ref in your `.gitlab-ci.yml` file. The `.gitlab-ci.yml` file defines what stages of the Hog Continuous Integration will be run. For more information, please consult the [Hog-CI chapter](../../02-Hog-CI/01-CI-Introduction.md).

If the two SHAs do not match, the script returns an Error, suggests few solutions to fix the problem.

This script is run by default in the pre-synthesis stage.

Usage:
```tcl
  source Hog/Tcl/utils/check_yaml_ref.tcl
```

## copy_xml.tcl
This script copies IPBus XML files (see [IPbus section](../07-IPbus.md)) listed in a Hog list file and replaces the version and SHA place holders, if they are present in any of the XML files.

Arguments:

* `<xml_list_file>`: the IPbus XML list file
* `<dest_dir>`: the destination directory

Options:

* `-generate`: if set, the VHDL address files will be generated and replaced if already existing

Usage:
```yml
copy_xml <xml_list_file> <dest_dir> [-generate]
```

## reformat.tcl

This script formats tcl scripts indentation.

Arguments:

* `<tcl_script>`: the tcl script to format

Options:

* `-tab_width <pad width>`: the tab width to be used to indent the code (default = 2)

Usage:
```tcl
  source Hog/Tcl/utils/reformat.tcl -tclargs [-tab_width <pad_width>] <tcl_script>
```


