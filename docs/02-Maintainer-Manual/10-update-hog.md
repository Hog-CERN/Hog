# Update HOG

Create a new merge request and a new branch starting from master.
Checkout the branch and there go into the Hog directory

Before updating HOG go to the hog repository and checkout the release notes for the latest version of HOG.
*NOTE* that any peculiarity of a specific release is reported in the release notes and may require more changes with respect to the ones reported here.
To get the latest release simply run:
q
```bash
git describe --tags $(git rev-list --tags --max-count=1)
```

You can now update HOG to the last release:

```bash
  Repo>     cd Hog
  Repo/Hog> git checkout vX.Y.ZvX.Y.ZvX.Y.Z
  Repo/Hog> git pull
```
Here vX.Y.Z is the output of the git describe command above.

*NOTE* if you want specisfic new features you can also use the master of the HOG reposistory. 
Please be careful and check what you are getting.
To use the master simply run:

```bash
  Repo>     cd Hog
  Repo/Hog> git checkout master
  Repo/Hog> git pull
```

Now check what version you got:

```bash
Repo/Hog> git describe
vX.Y.Z
```

Go back to your repo and edit the .gitlab-ci.yml with your favourite editor (say emacs)

```bash
Repo/Hog> cd ..
Repo> emacs .gitlab-ci.yml
```

At the beginning, in the include section you have a ref, similar to this:

```yaml
include:
    - project: 'hog/Hog'
      file: '/gitlab-ci.yml'
      ref: 'v1.1.0'
```

Change the ref to the new version you've just pulled:

```yaml
include:
    - project: 'hog/Hog'
      file: '/gitlab-ci.yml'
      ref: 'vX.Y.Z'
```

Close the editor and save
Now add the modified files and commit:

```bash
Repo>git add .gitlab-ci.yml Hog
Repo>git commit -m "Update Hog to vX.Y.Z"
Repo>git push
```
Now go online open the merge request and merge it.
