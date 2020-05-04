# Set-up a gitlab YAML file 

The gitlab Continuous Integration (CI) uses [YAML files](https://docs.gitlab.com/ee/ci/yaml/) to define which commands it must run.
Because of this you will need to add a .gitlab-ci.yml file to your the root folder of your repository.

HOG foresees that the continuous integration of your firmware uses the same tcl script runner locally (directly or by usage of the Vivado/Quartus GUI).
Sadly we can not provide a unique working configuration for all projects you therefore have to configure the gitlab CI by creating a custom YAML file.
The good news is you do not have to write it from scratch, instead your YAML will simply extend a common set of scripts by defining few variables specific to your project.
This can be achieved by requiring your YAML file to depend on a common base: ./Hog/gitlab-ci.yml
Below you can find few features that might be useful when extending this file. 
At the end of this section we provide a simple (HOW TO extend HOG Continuous Integration scripts)[#HOW-TO-extend-HOG-Continuous-Integration-scripts] 

The Hog continuous integration is divided in multiple chains. 
All the chains depend on a single initial stage namely `merge`.

## Merge stage

The `merge` stage performs the following operations

Reads the environmental variables needed by the continuous integration scripts and checks they are defined.
It also checks that all the tools 
It then checks if the commit message starts with 'ResolveWIP' if so it removes the 'WIP' status from the merge request.

The stage then proceeds in generating a new version for the current firmware, merges it to master and tags the result.
Errors are raised if the merge or tagging fails.

## Main  chain
The main chain is composed by the following stages:

- creation: creates project
- simulation: runs simulation
- ip: regenerate IPs
- synthesis: synthesize the project
- implementation: implement the project and generate binary file
- collect: collect artifacts 
- copy copy artifacts to EOS folder
- clean: clean environment

For each of these stages Hogs provides some default scripts that can be extended to accommodate the need of your project.

### creation stage

Script .create\_project uses the following variables:

  - PROJECT\_NAME : the project name 
  - HOG\_CHECK\_SYNTAX : if 1  run check syntax on the created project, taken from repository settings, see (Gitlab repository set-up)[#Gitlab-repository-set-up]
  - HOG\_CHECK\_YAMLREF : if 1 checks Yaml consistency checker is disabled, taken from repository settings, see (Gitlab repository set-up)[#Gitlab-repository-set-up]

This step will generate a new project in the following folder:
  - 'VivadoProject/$PROJECT\_NAME' for Vivado

### simulation stage 

Script simulate\_project  uses the following variables:

  - PROJECT\_NAME : the project name 
  - HOG\_SIMULATION\_LIB\_PATH: taken from repository settings, see (Gitlab repository set-up)[#Gitlab-repository-set-up]

This step will run all the simulation for your project.

### ip stage

Script .synthesise\_ips uses the following variables:
  
  - PROJECT\_NAME : the project name 
  - HOG\_IP\_EOS\_PATH: taken from repository settings, see (Gitlab repository set-up)[#Gitlab-repository-set-up]

Gets the generated IP and synthesises them.

### synthesis stage 

Script .synthesise\_project uses the following variables:  

  - PROJECT\_NAME : the project name 
  - HOG\_NJOBS: number of jobs used by Vivado, default 4, taken from repository settings, see (Gitlab repository set-up)[#Gitlab-repository-set-up]

Synthesises the project.

### implementation stage

Script .implement\_project uses the following variables:
  
  - PROJECT\_NAME : the project name 
  - HOG\_NJOBS: number of jobs used by Vivado, default 4, taken from repository settings, see (Gitlab repository set-up)[#Gitlab-repository-set-up]
  - HOG\_NO\_BITSTREAM: if present do not generate binary file, taken from repository settings, see (Gitlab repository set-up)[#Gitlab-repository-set-up]
  - HOG\_UNOFFICIAL\_BIN\_EOS\_PATH, taken from repository settings, see (Gitlab repository set-up)[#Gitlab-repository-set-up]

Runs implementation and copies the resulting files in HOG\_UNOFFICIAL\_BIN\_EOS\_PATH/COMMIT\_SHA

### collect stage

Script collect\_artifacts generates a changelog files and pushes it to th repo.

### copy stage

Script create\_official\_release uses the following variables:

 - HOG\_CREATE\_OFFICIAL\_RELEASE, taken from repository settings, see (Gitlab repository set-up)[#Gitlab-repository-set-up]

creates a new tag for the current repository


Script copy\_to\_eos uses the following variables:

 - HOG\_OFFICIAL\_BIN\_EOS\_PATH, taken from repository settings, see (Gitlab repository set-up)[#Gitlab-repository-set-up] 
 - HOG\_UNOFFICIAL\_BIN\_EOS\_PATH, taken from repository settings, see (Gitlab repository set-up)[#Gitlab-repository-set-up]

Copies all artifacts to  HOG\_OFFICIAL\_BIN\_EOS\_PATH/CI\_COMMIT\_TAG


# clean stage 

Script cleaning  uses the following variables: 

 - HOG\_UNOFFICIAL\_BIN\_EOS\_PATH, taken from repository settings, see (Gitlab repository set-up)[#Gitlab-repository-set-up]

Deletes artifacts from HOG\_UNOFFICIAL\_BIN\_EOS\_PATH.

## Documentation chain

This chain is composed by a single stage named `doxygen`.

The merge stage verifies the merge request can be merged correctly.
The doxygen stage builds the Doxygen documentation for your code and copies it to:
- *HOG_UNOFFICIAL_BIN_EOS_PATH*/*CI_COMMIT_SHORT_SHA*/Doc-*FIRMWARE_VERSION*

*HOG_UNOFFICIAL_BIN_EOS_PATH* is the variable you defined wile setting up the CI. 
It points to the EOS path for the unofficial coming out of your CI.
*CI_COMMIT_SHORT_SHA* is the git SHA of the latest commit in 32-bit hexadecimal format.
*FIRMWARE_VERSION* is the firmware version taken from the `git describe` command.

Note that if you have no *HOG_UNOFFICIAL_BIN_EOS_PATH* is not set then the copy of the files will fail.

## HOW TO extend HOG Continuous Integration scripts

HOG can not provide a full YAML file for your project but a template file can be found under `Hog` > `Templates` > `gitlab-ci.yml`

Suppose your project is called project\_1 and is contained in a repository named Repo. 
If you want to extend the script .script\_1 defined in Repo/Hog/gitlab-ci.yml
First of all you must let gitlab know you want to extend the latter file.
To do this you must include the parent file at the beginning of Repo/.gitlab-ci.yml:

```yaml
  include:
    - project: 'hog/Hog'
      file: '/gitlab-ci.yml'
      ref: 'vX.Y.Z'
```
Here you must substitute 'vX.Y.Z' with the correct version of HOG you are using.
You can check the HOG version by running:

```bash
  Repo>     cd Hog
  Repo/Hog> git describe
  vX.Y.Z
  Repo/Hog> cd ..
  
```

You can now start extending the provided scripts.
To extend the scripts use the following syntax:

```yaml
  script\_1:project\_1:
    extends: .script\_1
    variables:
      extends: .vars
      VARIABLE: <variable_value>
```

In this snippet the first line is the script name, i.e. you are defining a script named 'script\_1:project\_1'
The second line tells This scripts extends the script '.script\_1' defined in 'Repo/Hog/gitlab-ci.yml'
The third line starts the variable declaration section of the script.
Since your script extends '.script\_1' then it must define the variable use by this script.
The line 'extends: .vars' informs the variables section extends the .vars object defined in 'Repo/Hog/gitlab-ci.yml'.
The last line shows how to set the value for one named VARIABLE defined in the .vars object.


If now you want another script named 'script\_2' to extend '.script\_2' and you want 'script\_2' to run after 'script\_1' you can tell this to the gitlab CI using this syntax:

```yaml
  script\_1:project\_1:
    [...]

  script\_2:project\_1:
    [...]
    dependencies:
        - script\_1:project\_1
```

*NOTE* it is quite important you specify the dependencies in your YAML file since if you do not do this the scripts will be run in parallel.
Typically you want all your scripts to depend at least on the create\_project script. 

