# Setting up Hog Continuous Integration
Hog Continuous Integration makes use of the [Gitlab CI/CD tool](https://docs.gitlab.com/ee/ci/). Both the Gitlab repository and your local area must be set-up to work properly with Hog CI. In this paragraph, we assume that we are working with a Gitlab Project called `MyProject` under the Gitlab group `MyGroup`. Please, replace these with the actual names of your project and group.

# Preliminary requirements
To run the Hog-CI, you need a CERN service account. If you don't have one, you can easily request it [here](https://account.cern.ch/account/Management/NewAccount.aspx). The service account will run the Hog CI. For that, it needs to have access to your local repository.

- Go to https://gitlab.cern.ch/MyGroup/MyProject/-/project_members and give *Mantainer* rights to your service account
- Log in to Gitlab with your service account and create a private access token with API rights [here](https://gitlab.cern.ch/profile/personal_access_tokens)

Once you have your service account, you should also get 1 TB of space on EOS, that can be used to store the results of Hog CI. If, for some reasons, your service account doesn't have space on EOS, you could request it [here](https://resources.web.cern.ch/resources/Manage/EOS/Default.aspx).

# Set up your personal Gitlab CI YAML
Gitlab CI uses a [YAML configuration file](https://docs.gitlab.com/ee/ci/yaml/) to define which commands it must run. By default this file is called `.gitlab-ci.yml` and must be stored in the root folder of your repository. Hog cannot provide a full YAML file for your project, but a template file can be found under [`Hog` -> `Templates` -> `gitlab-ci.yml` ](https://gitlab.cern.ch/hog/Hog/-/blob/master/Templates/gitlab-ci.yml) as a reference.
For example, suppose we want to write the `.gitlab-ci.yml` configuration file to run the Hog project `my_project` on the CI. This file will actually include the Hog `hog.yml` configuration file, where the CI stages are defined. To include the reference to the Hog parent file, add at the beginning of your `.gitlab-ci.yml`

```yaml
  include:
    - project: 'hog/Hog'
      file: '/hog.yml'
      ref: 'vX.Y.Z'
```
Here you must substitute 'vX.Y.Z' with the version of Hog you want to use. The version of Hog **MUST** be specified. If you fail to do so , the CI will pick up the parent configuration file from the latest Hog master branch. This is discouraged, since Hog development could lead to not back-compatible changes that could break your CI. Moreover the pre synthesis script will check that the reference in your `.gitlab-ci.yml` file is consistent with your local Hog submodule, giving a Critical Warning if the two don't match.

Now, you need to define the stages you want to run in the CI for our project. Hog CI runs always the stages that are not project-specific (e.g. *Merge*), therefore there is no need to declare them in your file. To add a stage `stage_1` for your `my_project`, use the following syntax:

```yaml
  stage_1:my_project:
    extends: .stage_1
    variables:
      extends: .vars
      VARIABLE: <variable_value>
```

In this snippet the first line is the stage name, i.e. you are defining a stage named 'stage_1:my_project'.
The second line tells the script that the stage is an extension of '.stage_1' defined in the parent `hog.yml` file.
The third line starts the variable declaration section of the script.
Since your script extends `.stage_1`, then it must define the variable used by this script.
The line `extends: .vars` informs the variables section that it is an extension of the `.vars` object defined in `hog.yml`.
The last line shows how to set the value for one named `VARIABLE` defined in the `.vars` object.

So, for example, if you want to add a *Creation* stage for your `my_project`, you should add to the `.gitlab-ci.yml`, the following lines:

```yaml
  create_project:my_project:
    extends: .create_project
    variables:
      extends: .vars
      PROJECT_NAME: my_project
```

A more detailed description of the CI stages and their YAML configuration can be found [here](04-HOG-CI-stages.md)

# Remove merge commit

- Go to https://gitlab.cern.ch/MyGroup/MyProject/edit
- Expand __Merge Request settings__
- Select *Fast-forward merge*

<img style="float: middle;" width="700" src="../figures/fast-forward.png">

# Pipeline configuration

- Go to https://gitlab.cern.ch/MyGroup/MyProject/-/settings/ci_cd
- Expand _General pipelines_
- Select *git clone*
- Set *Git shallow clone* to 0
- Set *Timeout* to a long threshold, for example 1d

<img style="float: middle;" width="700" src="../figures/pipeline.png">


# Set-up Runners

Unfortunately, we cannot use shared runners as the necessary software (Xilinx Vivado, Mentor Graphics Questasim, etc.) are not available. The download, installation and licensing processes would have to be done at each time that the CI is started, slowing down the entire process.. As a consequence, you need to set-up your own physical or virtual machines. Please refer to [Setting up a Virtual Machines](04-Virtual-Machines.md) section for more information.

Now take the following actions:

- Go to `Settings` -> `CI/CD`
- Expand `Runners`
- On the right click `Disable shared runners for this project`
- On the left enable the private runners that you have installed on your machines.

<img style="float: middle;" width="700" src="../figures/shared_runners.png">


# Environment variables

- Go to `Settings` -> `CI/CD`
- Expand `Variables`

The following variables are **needed** for Hog-CI to work, so if any of them is not defined, or defined to a wrong value, Hog-CI will fail.

| Name                            | Value  |
|-----|---|
| __HOG_USER__                    | Your service account name (e.g. my_service_account)                                              |
| __HOG_EMAIL__                   | Your service account's email  address (e.g. service_account_mail@cern.ch)        |
| __HOG_PASSWORD__                | The password of your service account (should be masked)        |
| __HOG_PATH__                    | The PATH variable for your VM, should include Vivado bin directory       |
| __HOG_PUSH_TOKEN__              | The push token you generated for your service account (should be masked) |
| __HOG_XIL_LICENSE__             | Should contain the Xilinx license servers, separated by a comma          |

With the following **optional** variables you can configure the behaviour of Hog-CI:

| Name                            | Value  |
|-----|---|
| __EOS_MGM_URL__                 | Set the EOS instance. If your EOS storage is a user storage use `root://eosuser.cern.ch`. For EOS projects, have a look [here](http://cernbox-manual.web.cern.ch/cernbox-manual/en/project_space/access-to-project-space.html)              |
| __HOG_UNOFFICIAL_BIN_EOS_PATH__ | The EOS path for the binary files produdced by the CI        |
| __HOG_OFFICIAL_BIN_EOS_PATH__   | The EOS path for archiving the official binary files of your project     |
| __HOG_USE_DOXYGEN__          | Should be set to 1, if you want the Hog CI to create the doxygen documentation of your project |
| __HOG_CHECK_SYNTAX__         | Should be set to 1, if you want the Hog CI to run check syntax                      |
| __HOG_CHECK_YAMLREF__        | If this variable is set to 1, Hog CI will check that "ref" in `.gitlab-ci.yml` actually matches the gitlab-ci file in the Hog submodule |
| __HOG_IP_EOS_PATH__          |  The EOS path where to store the IP generated results. If not set, the CI will synthesise the IPs each time                  |
| __HOG_NO_BITSTREAM__   |  If this variable is set to 1, Hog-CI runs the implementation but does NOT run the write_bitstream stage                  |
| __HOG_CREATE_OFFICIAL_RELEASE__   | If this variable is set to 1, Hog-CI creates an official release note using the version and timing summaries taken from the artifact of the projects.                  |
| __HOG_SIMULATION_LIB_PATH__  |  The PATH in your VM, where the Simulation Lib files are stored (Vivado only)                   |
| __HOG_TARGET_BRANCH__          |  Project target branch. Merge request should start from this branch. Default: master |
| __HOG_NJOBS__               |  Number of CPU jobs for the synthesis and implementation. Default: 4 |
| __HOG_IP_NJOBS__               |  Number of CPU jobs for the synthesis and implementation. Default: 4 |

# EOS space (Optional)

The Gitlab CI will produce some artefacts. These include the resulting binary files of your firmware projects and, optionally, the Doxygen documentation html files. Hog has also the ability to copy these files into a desired EOS repository. To enable this feature, we have to specify the following environmental variables: __EOS_MGM_URL__, __HOG_UNOFFICIAL_BIN_EOS_PATH__, __HOG_OFFICIAL_BIN_EOS_PATH__.

If you wish to have your files to be accessible in a web browser, you should create a web page in EOS, following [these instructions](http://cernbox-manual.web.cern.ch/cernbox-manual/en/web/). For a personal project, by default, the website will be stored in `/eos/user/<initial>/<userID>/www`. The Hog EOS paths must be then sub-folders of the website root path. To expose the files in the website, follow these [instructions](http://cernbox-manual.web.cern.ch/cernbox-manual/en/web/expose_files_in_website.html).