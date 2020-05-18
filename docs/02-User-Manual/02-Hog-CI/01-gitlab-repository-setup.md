# Gitlab repository set-up
Hog Continuous Integration makes use of the [Gitlab CI/CD tool](https://docs.gitlab.com/ee/ci/). 

## Remove merge commit

- Go to https://gitlab.cern.ch/YourGroup/YourProject/edit
- Expand __Merge Request settings__ 
- Select Fast-forward merge

## Set-up Runners

Unfortunately we cannot use shared runners because big, slow, and licensed software (Xilinx Vivado, Mentor Graphics Questasim) are required.
So we need to set-up our own physical or virtual machines.
You can use either the Virtual Machine (VM) we provide or a private machine.
Please refer to [Setting up a Virtual Machines](04-Virtual-Machines.md) section for more information.

Now take the following actions:

- Go to `Settings` -> `CI/CD`
- Expand `Runners`
- On the right click `Disable shared runners for this project`
- On the left enable the private runners that you have installed on your machines or the common runner provided by the ATLAS-TDAQ.

## Environment variables

- Go to `Settings` -> `CI/CD`
- Expand `Variables`

The following variables are **needed** for Hog-CI to work, so if any of them is not defined, or defined to a wrong value, Hog-CI will fail.

| Name                            | Value  |
|-----|---|
| __Hog_USER__                    | Your service account (john)                                              |
| __Hog_EMAIL__                   | Your service account's email  address (john@cern.ch)		     |
| __Hog_PASSWORD__                | The password of your service account (should be masked)		     |
| __EOS_MGM_URL__                 | root://eosuser.cern.ch						     |
| __Hog_UNOFFICIAL_BIN_EOS_PATH__ | The EOS path for the binfiles coming out of your CIs		     |
| __Hog_OFFICIAL_BIN_EOS_PATH__   | The EOS path for archiving the official bitfiles of your firmware	     |
| __Hog_PATH__ The PATH           | variable for your VM, should include Vivado bin directory 	     |
| __Hog_PUSH_TOKEN__              | The push token you generated for your service account (should be masked) |
| __Hog_XIL_LICENSE__             | Should contain the Xilinx license servers, separated by a comma          |

With the following **optional** variables you can configure the behaviour of Hog-CI:

| Name                            | Value  |
|-----|---|
| __HOG_USE_DOXYGEN__          | Should be set to 1 if you want the Hog CI to run doxygen (in progress...) |
| __HOG_CHECK_SYNTAX__	       | Should be set to 1 if you want the Hog CI to run check syntax 									   |
| __HOG_CHECK_YAMLREF__	       | If this variable is set to 1, Hog CI will check that "ref" in .gitlab-ci.yml actually matches the gitlab-ci file in the Hog submodule |
| __HOG_IP_EOS_PATH__	         |									   |
| __HOG_NO_BITSTREAM__   |	If this variable is set to 1, Hog-CI will run the implementation but will NOT run the write_bitstream stage								   |
| __HOG_CREATE_OFFICIAL_RELEASE__   |	If this variable is set to 1, Hog-CI will create an official release note using the version and timing summaries taken from the artifact of the projects.								   |
| __HOG_SIMULATION_LIB_PATH__  |									   |
| __HOG_TARGET_BRANCH__          |  Project target branch. Merge request should start from this branch. Default: master |
| __HOG_NJOBS__               |  Number of synthesis and implementation jobs. Default: 4 |
| __HOG_IP_NJOBS__               |  Number of synthesis and implementation jobs. Default: 4 |

