# How to setup Hog-CI
This chapter describes how to setup Hog Continuous Itegration on Gitlab.
 In order to access your repository and compile your HDL, the gfitlab CI will need a dedicated account. 
 Before staring please get a [service account](#service_account).

 Once you  have your service account you to get an [eos space](#eos_space) where to store your *.bit files and your documentation.

 You can now start instructing the gitlab CI on what actions must be taken in order to compile your firmware usinga [YAML file](Gitlab_CI_YAML). 

  - Create a service account (let's call it john)
  - Log in with it to gitlab and give it access to your repository
  - Create a private access token with API rights [here](https://gitlab.cern.ch/profile/personal_access_tokens)


# EOS space

The gitlab CI will produce some artifacts.
These include the *.bit files for your firmware and eventually additional files or the documentation for your project.
You must foresee an eos space where to copy these files.
For this you can use the eos space of your service account: `/eos/user/<first_letter>/<service_account>`
In case you do not like to store your files there or you have no access to eos, we provide free eos space under `/eos/project/h/hog/`
in order to be able to use such a space get in touch with [HOG support](mailto:hog@cern.ch).


# Gitlab CI YAML

The gitlab continuosu integration uses [YAML files](https://docs.gitlab.com/ee/ci/yaml/) to devine wich commands it must run.
Because of this you will need to add a .gitlab-ci.yml file to your the root folder of your repository.
HOG can not provide a full YAML file for your project but a template file can be found under `Hog` > `Templates` > `gitlab-ci.yml`
You can copy this file and modify it according to your needs.

In addittion you will need to act on the repository website to define few variables needed by the HOG CI.
A full description of the used variables can be found in [Gitlab repository setup](#gitlab-repository-setup) section.

# Gitlab workflow

HOG foresees that you are fully exploting the gitlab features.

In detail the expected workflow starts with the creation of a new issue and a correlated merge request and branch.
To do this go to the gitlab website and navigate to your repository.
Click on issues and open a new issue describing the fix you are to implement or the new feature you want to introduce.
Once you have an issue you can open a merge request marked as WIP (work in progress) and a new branch simply by clicking `Create merge request` inside the issue overview.

When creating the merge request please use the MINOR_VERSION and MAJOR_VERSION keywords in the merge request description to tell HOG the expected version.
Just remenber the final version (and tag) will be vMAJOR_VERSION.MINOR_VERSION.patch where patch is an incremental number.
You will always be able to change these numbers by editing the merge request.

You will now have a new branch connected to the merge request.
Go to your shell, navigate to your local project folder and checkout the new branch.
You can now develop your new feature or commit the code you have.

Once you are done with your changes simply [resolve the `WIP`status](https://docs.gitlab.com/ee/user/project/merge_requests/work_in_progress_merge_requests.html).
Remember to merge the master in your branch before resolving the `WIP`status.
You are now able to merge the merge request by simply clicking on the merge button in the merge request!

## OMG I already have my code somewhere on my pc but I never committed it! OMG I Accidentally committed everything to a wrong branch!

If you have already some uncommitted/committed new feature, `DON'T PANIC!`.
You can always create a new branch, commit your code there and simply create a new merge request when ready.
By adding `[WIP]` or `WIP:` at the beginning of the title of the merge request then the merge request will be [marked as work in progress](https://docs.gitlab.com/ee/user/project/merge_requests/work_in_progress_merge_requests.html).
If you have already committed your changes to a worng branch (let's say the master) simply reset the current branch to the latest correct commit. 
Create a new branch, check it out and commit your code there.

## I do not want to use issues

Anyway you can avoid using issues by creating a new branch and a merge request connected to your branch.
You can still use the nice `WIP` feature by adding `[WIP]` or `WIP:` at the beginning of the title of the merge request: the merge request will be [marked as work in progress](https://docs.gitlab.com/ee/user/project/merge_requests/work_in_progress_merge_requests.html).
You can also solve the `WIP` status from command line by adding `resolveWIP` at the beginning of your last commit.
 
