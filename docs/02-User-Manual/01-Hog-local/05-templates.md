# Templates

Hog provides templates for the most important file needed in your HDL repository.
The templates are located in the [Hog/Templates](https://gitlab.cern.ch/hog/Hog/-/tree/master/Templates) directory.
Here is a list of the available tamplates:

## top.tcl
`top.tcl` is a Tcl script to generate the HDL project, the so colled "Tcl project-file".
Contains an example of all the variables used by Hog to generate a project

To use this file, copy it to the `Top/<project>/` directory, rename it to `<project>.tcl`  and modify it to accommodate your needs as exlained [here](../01-Project-Tcl).

## top.vhd
`top.vhd` is an example of top level file in VHDL. It contains the definition of the generics set by Hog to keep track of the firmware versions, as exalained [here](../03-parameters-genercis).

To use this file, copy it anywhere in your project, rename it and modify it to accommodate your project. Remember that the contained entity must be called `top_<project_name>` and that this file name and path must be included in a .src list file in `Top/project/list/` directory.

## top.v
`top.v`  is an	example of top level file in Verilog. See top.vhd for details.

## gitlab-ci.yml
`gitlab-ci.yml` is an example of YAML configuration file for the gitlab CI;\. it contains definitions of the jobs to be run for a project in your repository. To use this file, copy it to the root folder of your repository and rename it to `.gitlab-ci.yml`. Modify the file replacing the place holde with the name of your project. If you have several projects in your repository, you should copy and paste the file content several times and change the place holder with the names of all your projects. 

## gitignore
`gitignore` is an example of gitignore file. This file tells git which files should be ignored. Files covered by a rule in this file will not be uploaded to your repository.
The template contains rules for all the files used by the supported HDL compilers that should not be tracked by git. To use this file copy it to the root folder of your repository and rename it `.gitignore`.
This file has special rules for the `IP` and `BD` folders. In the `IP` folder only the .xci files contained in a subfolder should be considered, while in the `BD` folder only the .bd files. This is done beacuse the Gitlab CI needs to export the so-called artifacts so Hog has to know a priori where all the additional files will be created by the HDL synthesiser.

The provided template only works for a simple directory structure, but more complex strcutures can be used in Hog, as long as **all the .xci files** are contained in the `IP` foilder and **all the .bd** files are contained in the `BD` folder, you can use as many subdirectories as you need. In this case you will have to write your own `.gitignore` file, rememebr that it is possible to use multiple gitingore files palced in sub directory in your rep[ository.

## doxygen.conf
`doxygen.conf` is an example of Doxygen configuration file optimised for VHDL. To use this file, copy it to a folder named `doxygen` in the root folder of your repository, modify to accommodate you project.

