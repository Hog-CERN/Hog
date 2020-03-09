# Available templates

The following file tamplates are distributed with HOG:
- `top.vhd`:
	- example of top level file in vhdl;
	- contains the definition of the variables set by HOG to keep track of the frimware versions;
	- to use this file copy it to the `Top/project/` direcotory, rename it and modify it to accommodate your project;
- `gitlab-ci.yml`:
	- example of YAML configuration file for the gitlab CI;
	- contains definitions fo the main passages of firmware testing and implementation;
	- to use this file copy it to the root folder of your repository, modify it to accomodate your usage, rename it `.gitlab-ci.yml`;
- `gitignore`:
	- example of gitignore file. This file tells git which files should be ignored. Files covered By a rule in this file will not be uploaded to yopur repository;
	- contains rules for all the files used by the supported HDL compilers that shoul dnot be tracked by git;
	- to use this file copy it to the root folder of your repository and rename it `.gitignore`;
- `doxygen.conf`:
	- example of doxygen configuration file;
	- contains [... the default doxygen configuration ...];
	- to use this file copy it to a folder named doxygen in the root folder of your repository, modify to accommodate you project.

You can find the templates in the `Hog/Template` directory
