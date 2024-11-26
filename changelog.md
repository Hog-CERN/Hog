## Repository info
- Merge request number: 487
- Branch name: 346-move-to-gitlab-cli

## MR Description
Closes #346


## Changelog

- Disable exit for MERGE_STATUS and fix concurrency in github
- Separating main and tag pipeline in Github
- Separating the release creator job from the binary archiving to run the former with shared runners
- Moving GetArtifactsAndRename to glab
- Using the ubuntu docker everywhere in the CI
- Use glab cli to remove draft status
- Checking all the properties that could be set in a list file
- Use glab cli in launch_testfirmware CI job

