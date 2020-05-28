# Hog CI Products
In this paragraph, we describe the output products of the Hog CI pipelines.

## Merge Request Pipeline Products
The Merge Request pipeline generates a `bin` folder, where it stores the output products for each Hog project that has been run over the CI. It can be browsed, by opening the `collect_artifacts` stage of your pipeline and then clicking on `Download` or `Browse` on the right sidebar.

<img style="float: middle;" width="700" src="../figures/collect.png">
<img style="float: middle;" width="300" src="../figures/collect-artifacts.png">


For each project, it creates a sub-folder with the following format:
```
  <project_name>-<latest-tag>-<number_mr_commit>-<git-SHA>
```
For example, in our TestFirmware, we have four Hog projects: `bd_design`, `example`, `proj.1` and `proj.2`, and the `bin` folder content, looks like:

<img style="float: middle;" width="700" src="../figures/bin_folder.png">

Inside each project sub-folder, you will find the bitstream files, a txt file with the timing report (`timing_*.txt`), a txt file with the version summary (`version.txt`), a `report` folder containing the Vivado/Quartus reports and an `xml` folder for possible address tables.

<img style="float: middle;" width="700" src="../figures/project-bin.png">.

The Merge Request pipelines writes also notes with the resulting timing and version status in the Gitlab MR page, for faster control.

<img style="float: middle;" width="700" src="../figures/mr-message.png">.

### Doxygen documentation
If configured (`HOG_USE_DOXYGEN` set to 1), Hog CI creates also the Doxygen documentation for the entire repository. This documentation can be browsed by opening `doxygen` stage artefacts in the Gitlab web page.

### EOS Unofficial

If configured (`HOG_UNOFFICIAL_BIN_EOS_PATH` defined), the Hog CI will also create a folder, named as the git SHA, in `HOG_UNOFFICIAL_BIN_EOS_PATH`, where it copies the content of the `bin` folder. If the CI produced the Doxygen documentation, the html version is also copied in the same folder, inside a `Doc-*` sub-folder.


## Tag Pipeline Products

The Tag pipeline creates the Gitlab Release note, as described [here](03-gitlab-workflow.md#Gitlab Release Notes) and, if `HOG_UNOFFICIAL_BIN_EOS_PATH` and `HOG_OFFICIAL_BIN_EOS_PATH` are defined, it copies the content of the latest git SHA folder in `HOG_UNOFFICIAL_BIN_EOS_PATH` to a new folder in `HOG_OFFICIAL_BIN_EOS_PATH`, named as the new tag. If doxygen has been also run, the newly generated documentation is copied also in the `Doc` folder inside `HOG_OFFICIAL_BIN_EOS_PATH`.

Finally, if the copy is successful, the CI deletes all the sub-folders in `HOG_UNOFFICIAL_BIN_EOS_PATH` related to the Merge Request just merged.

