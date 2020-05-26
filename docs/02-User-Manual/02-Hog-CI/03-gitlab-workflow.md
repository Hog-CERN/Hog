# Gitlab Work-Flow

Hog foresees that you are fully exploiting Gitlab features. In details, the expected work-flow starts with the creation of a new issue and a correlated merge request and branch. To do this, go to the Gitlab website and navigate to your repository.
Click on issues and open a new issue describing the fix you are to implement or the new feature you want to introduce.
Once you have an issue, you can open a merge request marked as *WIP* (work in progress) and a new branch simply by clicking `Create merge request` inside the issue overview.

When creating the merge request, you can write the *MINOR_VERSION* or *MAJOR_VERSION* keywords in the merge request description, to tell Hog how to tag the repository once the source branch is merged into your official branch.

You have now a new branch connected to the issue. Go to your shell, navigate to your local project folder and checkout the new branch.
You can now develop your new feature or commit the code you have.

Once you are done with your changes, you are ready to start the Hog CI. This requires to solve the `WIP` status. This can be done either by going to the Merge Request page in the Gitlab web-site and click on the `Resolve WIP status`,

<img style="float: middle;" width="700" src="../figures/resolve-wip.png">

or you can start your commit message with `ResolveWIP:` from the command line.

```bash
  MyProject> git add new_files
  MyProject> git commit -m "ResolveWIP: <my message>"
  MyProject> git push
```

If you opt for the website method, remember that you need to push another commit afterwards to start the CI. Once the pipeline passes and your changes are approved, if required, you can merge your source branch simply by clicking on the merge button in the merge request.

<img style="float: middle;" width="700" src="../figures/merge.png">

## Create a Merge Request without an issue

You can avoid using issues by creating a new branch and a merge request connected to your branch.
You can still use the nice `WIP` feature by adding `[WIP]` or `WIP:` at the beginning of the title of the merge request: the merge request will be [marked as work in progress](https://docs.gitlab.com/ee/user/project/merge_requests/work_in_progress_merge_requests.html).

## Commit your code and accidental commits

If you have already some uncommitted/committed new features, you should create a new branch, commit your code there and create a new merge request when ready.

If you have already committed your changes to a wrong branch (e.g. the `master`) simply reset that branch to the latest correct commit, e.g.
```bash
  MyProject> git reset --hard <latest_correct_commit_hash>
  MyProject> git push origin master
```

Create a new branch, check it out and commit your code there. To avoid direct commit to the master (or official) branch, you can configure the repository to forbid pushing directly in a protected branch here: https://gitlab.cern.ch/MyGroup/MyProject/-/settings/repository

## Increasing version number
Hog uses a 32-bit integer to assign a version to your firmware.
The final version will have the form *vMAJOR_VERSION.MINOR_VERSION.patch*.
You will be able to change these numbers by editing the merge request description.

The bits 31 down to 24 indicate a major revision number; this number can be increased by placing `MAJOR_VERSION` in the merge request description.
While merging the merge request Hog will read the description, find the `MAJOR_VERSION` keyword and increase the major revision counter.
This will also reset the minor and patch counters.

The bits 23 down to 16 indicate a minor revision number. This number can be increased by placing `MINOR_VERSION` in the merge request description.
While merging the merge request Hog will read the description, find the `MINOR_VERSION` keyword and increase the minor revision counter.
This will also reset the patch counters.

The bits 15 down to 0 indicate a major revision number. This number will be increased automatically at each accepted merge request.
While merging the merge request Hog will read the description, find no keyword and increase the patch counter.

### Examples

Let's suppose the last tag of your firmware is v1.2.4, the possible scenarios are:

| Merge request description        | Original version | Final version |
|:---------------------------------|:----------------:|:-------------:|
|  without any keyword             | v1.2.4     | v1.2.5    |
| contains `MINOR_VERSION` keyword | v1.2.4       | v1.3.0    |
| contains `MAJOR_VERSION` keyword | v1.2.4       | v2.0.0    |

## Gitlab Release Notes
When creating a new tag, Hog CI will also create a new release. Hog has the ability to write automatically the release note, by looking at the merge request commit messages. If you want a commit message to be included in the release note, you should start your commit message with the `FEATURE:` keyword. For example:

```bash
git commit -m "FEATURE: Some awesome update"
```

