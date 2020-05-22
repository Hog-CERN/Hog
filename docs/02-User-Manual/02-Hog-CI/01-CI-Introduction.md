# Hog Continuous Integration

Hog Continuous Integration (CI) makes use of the [Gitlab CI/CD tool](https://docs.gitlab.com/ee/ci/). The main features of Hog's CI are:

- Controls that merging branches are up-to-date with targets
- Creates and builds Vivado/Quartus projects
- Generates FPGA binary and report files with embedded git commit SHA
- Automatically generates VHDL code documentation using _doxygen_
- If configured, it stores IP generated files and implementation project results in a user-defined EOS folder
- Automatically tags the Gitlab repository and creates _release notes_

Three pipelines are employed, triggered by the following actions:

- **Merge Request Pipeline**: triggered by each commit into a _non-WIP_ merge request branch
- **Master Pipeline**: triggered by each commit into the master branch
- **Tag Pipeline**: triggered by the creation of a new official tag (starting with "v\*")

# Merge Request Pipeline
The *Merge Request* pipeline simulates, synthetises and implements the chosen HDL projects. If specified, it stores the resulting outputs to an EOS repository and creates the doxygen documentation.

The stages of the Merge Request pipeline are the following:

1. *Merge*: checks that all the required Hog environmental variables are set up and that the source branch is not outdated with respect to the target branch. If it is, pipeline fails and asks user to update source branch.
2. *Creation*: creates a Vivado/Quartus project for each project specified in the .gitlab-ci.yml file. It checks also that the Hog submodule in the repository is the same as the one specified in the CI configuration file. Finally, for Vivado projects, it checks the syntax of the HDL codes, before moving to the next stage.
3. *IP*: generates the synthesis and implementation files for the IP in each project. An option to use the EOS repository to store the IP results and retrieve them to speed up the pipeline, can be enabled.
4. *Synthesis*: synthesises the projects.
5. *Implementation*: Implements the projects and creates the bitstreams. An option to disable the bitstream writing can be enabled. It also writes in the merge request page the implementation timing results and project version.
6. *Collect*: Collects all the artefacts from the previous stages. If EOS is used, it copies the implementation outputs to the EOS repository.
7. *Doxygen*. Creates the doxygen documentation and stores it to EOS if enabled.

# Master Pipeline
The *Master* pipeline consists only of one stage (*Merge*), which tags the repository according to the Merge Request description. Assuming the latest tag was *vA.B.C*, the pipeline will

*  increase A, if the MR description contains the keyword
"MAJOR_VERSION"
*  increase B, if the MR description contains the keyword
"MINOR_VERSION"
*  increase C, in the other cases

# Tag Pipeline
The *Tag* pipeline consists of two stages:

1.  *Copy*: If EOS is enabled, copies the *Merge Request* output files from the EOS unofficial to the EOS official storage, creating a new subfolder with the name of the new tag. It writes also the release note for the new tag, with the timing results and the project versions.
2.  *Clean*: If EOS is enabled, cleans the unofficial storage of all the files of the merge request already merged.

