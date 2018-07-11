# Hog: HDL on Git
List files, IP location, git ignore
Always recreate project when adding new file

## IPBus functionality
XML file location
address map location

## HDL repository methodology
Include this repository (Hog) as a submodule into your HDL repository.
Hog relies on the following assumptions:
- Hog must be in the root path of your repository
- The directory name must be "Hog"

HDL source files, together with contraint files, simulation files can be located anyware in the repository, even if a directory structure that reflects the __libraries__ in the project is advised.
A Hog-based repository can contain many projects. You should use many projects in the same repository when they share a significant amount of code: e.g. many FPGAs on the same board. If this is not the case you may think of having differente repositories. In this case, you may include the little amount of shared code as a git submodule, that is also handled by Hog.
Hog is a simple project, ment to be useful to speed up work. It is not extremely configuralbe: the scripts rely on special direcotry structure to be respected as explained in the following paragraphs.

### Top directory
The __Top__ direcotry is locaed in the root folder of the repository. Say the the repository is called Repo:
'''
Repo/Top
'''
It contains one subdrectory for every project (say proj_1, proj_2, proj_3) in the repository:
'''
Repo/Top/proj_1
Repo/Top/proj_2
Repo/Top/proj_3
'''

