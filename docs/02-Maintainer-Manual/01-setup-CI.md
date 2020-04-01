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
