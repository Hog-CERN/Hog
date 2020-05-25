# Configure your YAML file
In this paragraph, we describe the stages of the Hog CI pipelines that need to be configured in your local `.gitlab-ci.yml` file. Only the stages that are *project-specific* must be defined in this file. General stages are directly included from the `hog.yml` reference file and are not configurable.

The configurable stages are:

- Creation
- Simulation
- IP
- Synthesis
- Implementation

## Creation Stage

The Creation stage calls the `create_project` function and creates the Quartus/Vivado project, using the `Hog/CreateProject.sh` bash script.

It can be configured with the following variables:

- `PROJECT_NAME` : (**Mandatory**) name of the Hog project you want to create
- `HOG_CHECK_SYNTAX` : (**Optional**) if 1, it checks the syntax of the created project. Better if defined globally as an environmental variable in your [Gitlab repository](02-setup-CI.md#environment-variables)
- `HOG_CHECK_YAMLREF` : (**Optional**) if 1, it checks that the `hog.yml` file referenced in your `.gitlab-ci.yml` is the same as the one included in your `Hog`submodule. Better if defined globally as an environmental variable in your [Gitlab repository](02-setup-CI.md#environment-variables)

The resulting stage in your `.gitlab-ci.yml` file, for the project `my_project` is,

```YAML
create_project:my_project:
    extends: .create_project
    variables:
      extends: .vars
      PROJECT_NAME: my_project
```

## Simulation Stage
The Simulation stage calls the `simulate_project` function and launches a behavioural simulation for each `.sim` list file in your Hog project. By default, simulation is executed using *modelsim*. If you wish to use another simulation software, add the following line to the top of your `.sim` list file:
```
Simulator xsim # For Vivado Simulator
Simulator questa # For QuestaSim
Simulator modelsim # For Modelsim
```
`simulate_project` requires two variables:

- `PROJECT_NAME` : (**Mandatory**) name of the Hog project you want to simulate
- `HOG_SIMULATION_LIB_PATH`: (**Mandatory for Questa/Modelsim**) Path to the compiled simulation lib in your VM. It shall be defined in your [Gitlab CI/CD variables](02-setup-CI.md#environment-variables).

The resulting stage in your `.gitlab-ci.yml` file, for the project `my_project` is,

```YAML
simulate_project:my_project:
    extends: .simulate_project
    variables:
      extends: .vars
      PROJECT_NAME: my_project
```

## IP Stage
The IP stage calls the `synthesise_ips` function and generates the synthesis and implementation products for the IPs included in your project. It is configured with the following variables.

- `PROJECT_NAME` : (**Mandatory**) name of the Hog project to open
- `HOG_IP_NJOBS` : (**Optional**) number of jobs to generate the IP products. It shall be defined in your [Gitlab CI/CD variables](02-setup-CI.md#environment-variables). Default: 4
- `HOG_IP_EOS_PATH`: (**Optional**) path to the EOS folder where the IP generated results are stored. If defined, the stage will copy the IP products from EOS without relaunching the IP synthesis/implementation to speed up the pipeline. If the IP products on EOS are outdated, the script will regenerate the products and upload them to EOS. It shall be defined in your [Gitlab CI/CD variables](02-setup-CI.md#environment-variables).

The resulting stage in your `.gitlab-ci.yml` file, for the project `my_project` is,

```YAML
synthesise_ips:my_project:
    extends: .synthesise_ips
    variables:
      extends: .vars
      PROJECT_NAME: my_project
    dependencies:
        - create_project:my_project
```

## Synthesis Stage
The Synthesis stage calls the `synthesise_project` function and synthesise your project. It is configured with the following variables.

- `PROJECT_NAME`: (**Mandatory**) name of the Hog project to open
- `HOG_NJOBS`: (**Optional**) number of jobs to run the synthesis. It shall be defined in your [Gitlab CI/CD variables](02-setup-CI.md#environment-variables). Default: 4

The resulting stage in your `.gitlab-ci.yml` file, for the project `my_project` is,

```YAML
synthesise_project:my_project:
    extends: .synthesise_project
    variables:
      extends: .vars
      PROJECT_NAME: my_project
    dependencies:
        - synthesise_ips:my_project
```

## Implementation Stage
The Implementation stage calls the `implement_project` function and runs the implementation of your project. It is configured with the following variables.

- `PROJECT_NAME`: (**Mandatory**) name of the Hog project to open
- `HOG_NJOBS`: (**Optional**) number of jobs to run the synthesis. It shall be defined in your [Gitlab CI/CD variables](02-setup-CI.md#environment-variables). Default: 4
- `HOG_NO_BITSTREAM`: (**Optional**) If set to 1, the script will not write a bitstream for your project. Default: 0

The resulting stage in your `.gitlab-ci.yml` file, for the project `my_project` is,

```YAML
implement_project:my_project:
    extends: .implement_project
    variables:
      extends: .vars
      PROJECT_NAME: my_project
      HOG_NO_BITSTREAM : 1 # No bitstream will be produced
    dependencies:
      - synthesise_project:my_project
```

# clean stage

Script cleaning  uses the following variables:

 - Hog\_UNOFFICIAL\_BIN\_EOS\_PATH, taken from repository settings, see (gitlab repository set-up)[#gitlab-repository-set-up]

Deletes artifacts from Hog\_UNOFFICIAL\_BIN\_EOS\_PATH.

## Documentation chain

This chain is composed by a single stage named `doxygen`.

The merge stage verifies the merge request can be merged correctly.
The doxygen stage builds the Doxygen documentation for your code and copies it to:
- *Hog_UNOFFICIAL_BIN_EOS_PATH*/*CI_COMMIT_SHORT_SHA*/Doc-*FIRMWARE_VERSION*

*Hog_UNOFFICIAL_BIN_EOS_PATH* is the variable you defined wile setting up the CI.
It points to the EOS path for the unofficial coming out of your CI.
*CI_COMMIT_SHORT_SHA* is the git SHA of the latest commit in 32-bit hexadecimal format.
*FIRMWARE_VERSION* is the firmware version taken from the `git describe` command.

Note that if you have no *Hog_UNOFFICIAL_BIN_EOS_PATH* is not set then the copy of the files will fail.

