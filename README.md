# HDL On Git (Hog)

Coordinating firmware development among many international collaborators is becoming a very widespread problem.

Guaranteeing firmware synthesis with P&R reproducibility and assuring traceability of binary files is paramount.
Hog tackles these issues by exploiting advanced Git features and being deeply integrated with HDL IDE, with particular attention to Intellectual Properties (IP) handling.

Hog is a set of Tcl/Shell scripts plus a suitable methodology to allow a fruitful use of Git as a HDL repository and guarantee synthesis reproducibility and binary file traceability.

More information on the how to use Hog can be found in the [user documentation website](http://hog-user-docs.web.cern.ch/)

## Hog Releases
Stable Hog releases are stored in the `master branch` and  are tagged as `Hog<YEAR>.<n>`, for example `Hog2020.1`.
Pulling the `master` branch always gives you the most updated Hog stable release.

Hog developers use the `develop` branch, tagging functional but not
thoroughly tested releases with the format `vM.m.p`, for example `v1.2.3`.
So pulling the develop branch will give you the most updated Hog version but not necessarily a stable on.

## Report issues or bugs
You can report problems with Hog in using the issues in this repository. Please use the:

- Report Problem label, if you are experiencing an unwanted behaviour
- Feature Proposal label, if you want to propose a new Hog feature
- Question label, if you want to ask a question about Hog


## License

Hog is distributed under the Apache License, Version 2.0. 
