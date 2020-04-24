# @Author: Davide Cieri
# @Date:   2020-04-24
# @Last Modified by:   Davide Cieri
# @Last Modified time: 2020-04-24
#!/bin/bash

tcl_dir=$1

if [ -z "${HOG_PUSH_TOKEN}" ] && [ -z "${HOG_USER}" ]; then
  echo "You did not set the environment variable HOG_PUSH_TOKEN.\n\
Please define in the gitlab project settings/CI the secret variables HOG_PUSH_TOKEN and HOG_USER."
  exit 1
fi

if [ ! -z "${tcl_dir}" ];then
    for f in ${tcl_dir}*; do
        if [ -d "$f" ]; then
            for file in $f/*.tcl; do
                echo "[FormatTcl] Formatting $file..."
                tclsh Tcl/utils/reformat.tcl -indent 2 $file
            done
        fi
        if [[ $f == *.tcl ]]; then
            echo "[FormatTcl] Formatting $f..."
            tclsh Tcl/utils/reformat.tcl -indent 2 $f
        fi
    done
fi

git diff
git diff-index --quiet HEAD -- && exit 0

# if we arrive here there are changes -> commit them
git add --all && git commit -m 'code formatted by gitlab-CI'
if [ -z "${GIT_AUTHTOKEN}" ]; then
     echo "Use the login credentials to push the changes"
    url_host=`git remote get-url origin | sed -e "s/https:\/\/gitlab-ci-token:.*@//g"`
    git remote set-url origin ${url_host}
else
    echo "Use the gitlab token to push the changes"
    url_host=`git remote get-url origin | sed -e "s/https:\/\/gitlab-ci-token:.*@//g"`
    git remote set-url origin "https://gitlab-ci-token:${GIT_AUTHTOKEN}@${url_host}"
fi
git push origin ${CI_COMMIT_REF_NAME} > /dev/null
exit 1 # don't follow this CI any further but check the new commit instead
