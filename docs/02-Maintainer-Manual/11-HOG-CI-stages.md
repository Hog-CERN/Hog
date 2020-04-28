# HOG CI stages

The Hog continuous integration is divided in multiple chains. 
All the cahins depend on a single initial stage namely `merge`.

## Merge stage

The `merge` stage performs the following operations

Reads the environmental variables needed by the continuous integration scripts and checks they are defined.
It also checks that all the tools 
It then checks if the commit message starts with 'ResolveWIP*' if so it removes the 'WIP' status from the merge request.

The stage then proceeeds in generating a new version for the current firmware, merges it to master and tags the result.
Errors are raised if th marge or tagging fails.

## Main  chain
- creation: creates project
- simulation: runs simulation
- ip
- synthesis
- implementation
- collect
- copy
- clean

## Documentation chain

This chain is composed by a single stage named `doxygen`.

The merge stage verifies the merge request can be merged correctly.
The doxygen stage builds the doxygen documentation for your code and copies it to:
- *HOG_UNOFFICIAL_BIN_EOS_PATH*/*CI_COMMIT_SHORT_SHA*/Doc-*FIRMWARE_VERSION*

*HOG_UNOFFICIAL_BIN_EOS_PATH* is the varoible you defined wile setting up the CI. 
It points to the EOS path for the unofficial binfiles coming out of your CIs.
*CI_COMMIT_SHORT_SHA* is the git sha of the lastest commit in 32-bit hexadecimal format.
*FIRMWARE_VERSION* is the firmware version taken from the `git describe` command.

Note that if you have no *HOG_UNOFFICIAL_BIN_EOS_PATH* is not set then the copy of the files will fail.
