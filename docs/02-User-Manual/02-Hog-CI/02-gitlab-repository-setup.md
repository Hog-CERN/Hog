# Gitlab repository set-up
Hog Continuous Integration makes use of the [Gitlab CI/CD tool](https://docs.gitlab.com/ee/ci/). The repository must be set-up in order to work properly with Hog CI.

## Remove merge commit

- Go to https://gitlab.cern.ch/YourGroup/YourProject/edit
- Expand __Merge Request settings__
- Select *Fast-forward merge*

<img style="float: middle;" width="700" src="../figures/fast-forward.png">

## Pipeline configuration

- Go to https://gitlab.cern.ch/YourGroup/YourProject/-/settings/ci_cd
- Expand _General pipelines_
- Select *git clone*
- Set *Git shallow clone* to 0
- Set *Timeout* to a long threshold, for example 1d

<img style="float: middle;" width="700" src="../figures/pipeline.png">


## Set-up Runners

Unfortunately, we cannot use shared runners because big, slow, and licensed software (Xilinx Vivado, Mentor Graphics Questasim) are required.
So we need to set-up our own physical or virtual machines.
You can use either the Virtual Machine (VM) we provide or a private machine.
Please refer to [Setting up a Virtual Machines](04-Virtual-Machines.md) section for more information.

Now take the following actions:

- Go to `Settings` -> `CI/CD`
- Expand `Runners`
- On the right click `Disable shared runners for this project`
- On the left enable the private runners that you have installed on your machines or the common runner provided by the ATLAS-TDAQ.

<img style="float: middle;" width="700" src="../figures/shared_runners.png">


## Environment variables

- Go to `Settings` -> `CI/CD`
- Expand `Variables`

The following variables are **needed** for Hog-CI to work, so if any of them is not defined, or defined to a wrong value, Hog-CI will fail.

| Name                            | Value  |
|-----|---|
| __HOG_USER__                    | Your service account (john)                                              |
| __HOG_EMAIL__                   | Your service account's email  address (john@cern.ch)		     |
| __HOG_PASSWORD__                | The password of your service account (should be masked)		     |
| __EOS_MGM_URL__                 | Set the EOS instance. If your EOS storage is a user storage use `root://eosuser.cern.ch`. For EOS projects, have a look [here](http://cernbox-manual.web.cern.ch/cernbox-manual/en/project_space/access-to-project-space.html)				     |
| __HOG_UNOFFICIAL_BIN_EOS_PATH__ | The EOS path for the binfiles coming out of your CIs		     |
| __HOG_OFFICIAL_BIN_EOS_PATH__   | The EOS path for archiving the official bitfiles of your firmware	     |
| __HOG_PATH__                    | The PATH variable for your VM, should include Vivado bin directory 	     |
| __HOG_PUSH_TOKEN__              | The push token you generated for your service account (should be masked) |
| __HOG_XIL_LICENSE__             | Should contain the Xilinx license servers, separated by a comma          |

With the following **optional** variables you can configure the behaviour of Hog-CI:

| Name                            | Value  |
|-----|---|
| __HOG_USE_DOXYGEN__          | Should be set to 1, if you want the Hog CI to create the doxygen documentation of your project |
| __HOG_CHECK_SYNTAX__	       | Should be set to 1, if you want the Hog CI to run check syntax 									   |
| __HOG_CHECK_YAMLREF__	       | If this variable is set to 1, Hog CI will check that "ref" in .gitlab-ci.yml actually matches the gitlab-ci file in the Hog submodule |
| __HOG_IP_EOS_PATH__	         |	The EOS path where to store the IP generated results. If not set, the CI will syntesise the IPs each time								   |
| __HOG_NO_BITSTREAM__   |	If this variable is set to 1, Hog-CI will run the implementation but will NOT run the write_bitstream stage								   |
| __HOG_CREATE_OFFICIAL_RELEASE__   |	If this variable is set to 1, Hog-CI will create an official release note using the version and timing summaries taken from the artifact of the projects.								   |
| __HOG_SIMULATION_LIB_PATH__  |	The PATH in your VM, where the Simulation Lib files are stored (Vivado only)								   |
| __HOG_TARGET_BRANCH__          |  Project target branch. Merge request should start from this branch. Default: master |
| __HOG_NJOBS__               |  Number of CPU jobs for the synthesis and implementation. Default: 4 |
| __HOG_IP_NJOBS__               |  Number of CPU jobs for the synthesis and implementation. Default: 4 |

