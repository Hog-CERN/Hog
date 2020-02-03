
# Contributing 

##Contributing to the Manual

This site uses MkDocs to render the Markdown files.
The source is hosted on GitLab: [HOG](https://gitlab.cern.ch/hog/Hog)

To contribute to the user manual plase read this section carefully.
You should first clone the repository:
```console
git clone https://gitlab.cern.ch/hog/Hog.git
```
As an alternative you can use the Web IDE directly from the gitlab website. This allows you to preview the resulting page.

If you want to do this locally and haven't set up your permissions for local gitlab yet, follow the instructions [here](https://docs.gitlab.com/ce/ssh/README.html).

Everything you'll need to edit is inside the `docs/` directory. Sections are represented by subdirectories within `docs/`, and the section "home" pages  come from `index.md` files in each directory. You can create further markdown files to add topics to the section.

Any changes you make to this repo will be automatically propagated to this website when you push your commits.

### Markdown

This manual is made in markdown, a simple language for formatting text. If you're not familiar, there is a handy cheatsheet [here](https://github.com/adam-p/markdown-here/wiki/Markdown-Cheatsheet). There are a few special cases for the specific flavor of markdown that GitLab uses (most notably for newline syntax) that are documented [here](https://docs.gitlab.com/ee/user/markdown.html).

### Continuous integration set-up

CI for this project was set up using the information in the [mkdocs](https://gitlab.cern.ch/authoring/documentation/mkdocs) repository. The generated website is automagically deployed [here](http://cern.ch/hog-user-manual)

