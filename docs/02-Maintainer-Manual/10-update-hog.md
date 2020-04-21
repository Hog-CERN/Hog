# Update HOG

Create a new merge request and a new branch starting from master.
Checkout the branch and there go into the Hog directory and update it to the last release:

```bash
  Repo>     cd Hog
  Repo/Hog> git checkout master
  Repo/Hog> git pull
```

Now check what version you got:

```bash
Repo/Hog> git describe
v1.2.3
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
      ref: 'v1.2.3'
```

Close the editor and save
Now add the modified files and commit:

```bash
Repo>git add .gitlab-ci.yml Hog
Repo>git commit -m "Update Hog to v.1.2.3"
Repo>git push
```

Now go online open the merge request and merge it.
