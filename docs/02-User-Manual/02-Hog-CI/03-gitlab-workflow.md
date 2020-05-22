# gitlab Work-Flow

Hog foresees that you are fully exploiting Gitlab features. In details, the expected work-flow starts with the creation of a new issue and a correlated merge request and branch. To do this, go to the Gitlab website and navigate to your repository.
Click on issues and open a new issue describing the fix you are to implement or the new feature you want to introduce.
Once you have an issue, you can open a merge request marked as *WIP* (work in progress) and a new branch simply by clicking `Create merge request` inside the issue overview.

When creating the merge request, you can write the *MINOR_VERSION* or *MAJOR_VERSION* keywords in the merge request description, to tell Hog how to tag the repository once the source branch is merged into your official branch.

You have now a new branch connected to the issue. Go to your shell, navigate to your local project folder and checkout the new branch.
You can now develop your new feature or commit the code you have.

Once you are done with your changes, you are ready to start the Hog CI. This requires to solve the `WIP` status. This can be done either by going to the Merge Request page in the Gitlab web-site and click on the Resolve-WIP

<img style="float: middle;" width="700" src="../figures/resolve-wip.png">


simply [resolve the `WIP`status](https://docs.gitlab.com/ee/user/project/merge_requests/work_in_progress_merge_requests.html).
Remember to merge the master in your branch before resolving the `WIP`status.
You are now able to merge the merge request by simply clicking on the merge button in the merge request!

## I do not want to use issues

Anyway you can avoid using issues by creating a new branch and a merge request connected to your branch.
You can still use the nice `WIP` feature by adding `[WIP]` or `WIP:` at the beginning of the title of the merge request: the merge request will be [marked as work in progress](https://docs.gitlab.com/ee/user/project/merge_requests/work_in_progress_merge_requests.html).
You can also solve the `WIP` status from command line by adding `resolveWIP` at the beginning of your last commit.

## OMG I already have my code somewhere on my pc but I never committed it! OMG I Accidentally committed everything to a wrong branch!

If you have already some uncommitted/committed new feature, **DON'T PANIC!**

You can always create a new branch, commit your code there and simply create a new merge request when ready.
By adding `[WIP]` or `WIP:` at the beginning of the title of the merge request then the merge request will be [marked as work in progress](https://docs.gitlab.com/ee/user/project/merge_requests/work_in_progress_merge_requests.html).

If you have already committed your changes to a wrong branch (let's say the master) simply reset that branch to the latest correct commit.
Create a new branch, check it out and commit your code there.

## Increasing version number
Hog uses a 32 bit integer to assign a version to your firmware.
The final version will have the form *vMAJOR_VERSION.MINOR_VERSION.patch*.
You will be able to change these numbers by editing the merge request description.

The bit 31 down to 24 are indicate a major revision number; this number can be increased by placing `MAJOR_VERSION` in the merge request description.
While merging the merge request Hog will read the description, find the `MAJOR_VERSION` keyword and increase the major revision counter.
This will also reset the minor and patch counters.

The bit 23 down to 16 are indicate a minor revision number; this number can be increased by placing `MINOR_VERSION` in the merge request description.
While merging the merge request Hog will read the description, find the `MINOR_VERSION` keyword and increase the minor revision counter.
This will also reset the patch counters.

The bit 15 down to 0 are indicate a major revision number; this number will be increased automatically at each accepted merge request.
While merging the merge request Hog will read the description, find no keyword and increase the patch counter.

### Examples

Let's suppose the last tag of your firmware is v1.a.ba3f, thus the corresponding version is 01 0a ba3f
The possible scenarios are:

| Merge request description        | Original version | Final version |
|:---------------------------------|:----------------:|:-------------:|
|  without any keyword             | 01 0a ba3f       | 01 0a ba40    |
| conatins `MINOR_VERSION` keyword | 01 0a ba3f       | 01 0b 0000    |
| conatins `MAJOR_VERSION` keyword | 01 0a ba3f       | 02 00 0000    |

