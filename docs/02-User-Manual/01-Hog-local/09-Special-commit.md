# Hog git hooks

Hog supports a series of special git hooks serving different purposes. The full list of the special keywords is descibed in this section.

## Merge Request description keywords

When a Merge Request is created, the *description* field can be filled with the following keywords:
- MAJOR_VERSION: indicates that a new major version will be released. After the branch is merged, the new tag vill be v<M+1>.<m>.<p> (where M = major, m = minor and p = patch).
- MINOR_VERSION: indicates that a new minor version will be released. After the branch is merged, the new tag vill be v<M>.<m+1>.<p> (where M = major, m = minor and p = patch).  

**Note:** if neither of the two flags is selected, by default the new tag will be v<M>.<m>.<p+1> (where M = major, m = minor and p = patch).

## Commit keywords

- FEATURE: is a commit message contains the FEATURE keywords plus a description message, the message will be auromatically added to the git changelog after the branch has been merged.

