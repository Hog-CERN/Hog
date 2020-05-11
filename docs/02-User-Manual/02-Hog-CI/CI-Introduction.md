# Hog Continuous Integration

Hog Continuous Integration (CI) makes use of the [Gitlab CI/CD tool](https://docs.gitlab.com/ee/ci/). The main features of Hog's CI are:

- Controls that merging branches are up-to-date with targets
- Creates and builds Vivado/Quartus projects
- Generates FPGA binary and report files with embedded git commit SHA
- Automatically generates VHDL code documentation using _doxygen_
- If configured, it stores IP generated files and implementation project results in a user-defined EOS folder
- Automatically tags the Gitlab repository and creates _release notes_

Three pipelines are employed triggered by the following actions:

- **Merge Request Pipeline**: triggered by each commit into a _non-WIP_ merge request branch
- **Master Pipeline**: triggered by each commit into the master branch
- **Tag Pipeline**: triggered by the creation of a new tag
