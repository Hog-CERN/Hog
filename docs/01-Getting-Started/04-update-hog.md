# Update Hog to a new release

First of all, you might want to go to Hog [repository][gitlab.cern.ch/hog/Hog] and choose what version you want to update to.
Otherwise you might just want to update to the most recent version.

On your project's Gitlab website, create a new merge request and a new branch starting from master.
(You can also create a new branch locally and open the merge request on the website later.)
Checkout the branch and go into the Hog directory


Now if you want to update Hog to the latest version:

```bash
  Repo>cd Hog
  Repo/Hog> git checkout master
  Repo/Hog> git pull
```

Now do git describe to find out what version you got:

```bash
Repo/Hog>git describe
```

You should obtain something like vX.Y.Z

if you want to update to a specific version:

```bash
  Repo>cd Hog
  Repo/Hog> git checkout vX.Y.Z
```

Now you have to update your `.gitlab-ci.yml` file. This is the file used to configure Gitlab continuous integration (CI), if you are not using  Gitlab CI you can skip this part
Go back to your repo and edit the `.gitlab-ci.yml` with your favourite editor, say emacs:

```bash
  Repo/Hog> cd ..
  Repo> emacs .gitlab-ci.yml
```

At the beginning, in the include section you have a ref, similar to this:

```yaml
  include:
    - project: 'hog/Hog'
      file: '/gitlab-ci.yml'
      ref: 'va.b.c'
```

Change the ref to the new version you've just pulled:

```yaml
  include:
    - project: 'hog/Hog'
      file: '/gitlab-ci.yml'
      ref: 'vX.Y.Z'
```

Save the file close the editor.
Add the modified files (`Hog` submodule and `.gitlab-ci.yml`), commit, and push:

```bash
  Repo> git add .gitlab-ci.yml Hog
  Repo> git commit -m "Update Hog to vX.Y.Z"
  Repo> git push
```

Finally go to your project's Gitlab website, open a merge request for your branch (if you have not done that already) and merge it.
You can do all of this within a branch (and merge request) that you had already open to work at some modification.
