# Templates

Templates for some of the file needed to set-up your git repository are distributed with Hog.
You can find the templates in the [Hog/Templates](https://gitlab.cern.ch/hog/Hog/-/tree/master/Templates) directory.
The following file templates are distributed with Hog:

- `top.tcl`

	- example of tcl script to generate the HDL project;
	- contains the definition of the variables used by Hog to generate your project;
	- to use this file copy it to the `Top/project/` directory, rename it and modify it to accommodate your project;

- `top.vhd`:

	- example of top level file in VHDL;
	- contains the definition of the generics set by Hog to keep track of the firmware versions;
	- to use this file copy it anywhere in your project, rename it and modify it to accommodate your project, remember to rename the contained entity `top_<project_name>` and to include the file in a list file in `Top/project/list/` directory;

- `top.v`:

	- example of top level file in Verilog;
	- contains the definition of the parameters set by Hog to keep track of the firmware versions;
	- to use this file copy it anywhere in your project, rename it and modify it to accommodate your project, remember to rename the contained module `top_<project_name>` and to include the file in a list file in `Top/project/list/` directory;

- `gitlab-ci.yml`:

	- example of YAML configuration file for the gitlab CI;
	- contains definitions fo the main passages of firmware testing and implementation;
	- to use this file copy it to the root folder of your repository, modify it to accommodate your usage, rename it `.gitlab-ci.yml`;

- `gitignore`:

	- example of gitignore file. This file tells git which files should be ignored. Files covered By a rule in this file will not be uploaded to your repository;
	- contains rules for all the files used by the supported HDL compilers that should not be tracked by git;
	- to use this file copy it to the root folder of your repository and rename it `.gitignore`;

- `doxygen.conf`:

	- example of Doxygen configuration file;
	- contains [... the default Doxygen configuration ...];
	- to use this file copy it to a folder named `doxygen` in the root folder of your repository, modify to accommodate you project.

