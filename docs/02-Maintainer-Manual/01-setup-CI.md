# How to setup Hog-CI:
How to setup Hog Continuous Itegraion on Gitlab

## Openstack Virtual Machine setup
### Service account
Th Hog-I will need to access your repository as a developer (push).
For this reason you need to create a CERN service account [What is it?](https://account.cern.ch/account/Help/?kbid=011010).
- Create a service account (let's call it john)
  - Log in with it to gitlab and give it access to your repository
  - Create a private access token with API rights [here](https://gitlab.cern.ch/profile/personal_access_tokens)
- Prepare a big Volume (~200 GB) call it __vd__, mount it to your machine

- Optional: produce a __keytab file__ for your service account as
    - From lxplus run /usr/kerberos/sbin/ktutil
    - In the ktutil shell enter the following command: "add_entry -password -p john@CERN.CH -k 1 -e arcfour-hmac-md5"
    - Enter password for john@CERN.CH 
    - Enter:  "add_entry -password -p john@CERN.CH -k 1 -e aes256-cts"
    - Enter password for john@CERN.CH
    - Enter "wkt john.keytab"
    - Enter: quit
    - To test the keytab use kinit: "kinit -kt john.keytab john"
    - Type klist to verify that it works

### Gitlab repository setup
#### Remove merge commit
- Go to https://gitlab.cern.ch/YourGroup/YourProject/edit
- Expand __Merge Request settings__ 
- Select Fast-forward merge

#### Setup Runners
Unfortunately we cannot use shared runners because big, slow, and licensed software (Xilinx Vivado, Mentor Graphics Questasim) are required. So we need to setup our own physical or virtual machines.
The official Gitlab intructions can be found [here](https://docs.gitlab.com/runner/install/), however we will see how to create a virtual machine on CERN Openstack in the next paragraph.
So we have our Gitlab runners running on our machines with all the software we need.
Now take the following actions:
- Go to `Settings` -> `CI/CD`
- Expand `Runners`
- On the right click `Disable shared runners for this project`
- On the left enable the private runners that you have installed on your machines
- Now collpase `Runners` and expand `Variables`
- Define the following variables:
  - __HOG_USER__= Your service accounr (john)
  - __HOG_EMAIL__= Your service account's email  address (john@cern.ch)
  - __HOG_PASSWORD__= The password of your service account (should be masked)
  - __EOS_MGM_URL__= root://eosuser.cern.ch
  - __HOG_UNOFFICIAL_BIN_EOS_PATH___= The EOS path for the binfiles coming out of your CIs
  - __HOG_OFFICIAL_BIN_EOS_PATH__= The EOS path for archiving the official bitfiles of your firmware
  - __HOG_PATH__= The PATH variable for your VM, should include Vivado's bin directory, 
  - __HOG_PUSH_TOKEN__= The push token you generated for your service account (should be masked)
  - __HOG_USE_DOXYGEN__= Should be set to 1 if you want the Hog CI to run doxygen (in progress...)
  - __HOG_XIL_LICENSE__= Should contain the Xilinx license servers, separated by a comma

### Create an CERN Openstack Virtual Machine
- Create an instance (I recommend 40GB HD and 16 GB of RAM)
    - You might need to ask for a custom one
- Use an updated CC7 image
- Clone Hog repository somewhere accessible from the VM, e.g. on you AFS home
- ssh into your virtual machine as yourself
- Become root
- Export the following system variables:
  - __HOG_USERNAME__= The name of you service account, e.g. john
  - __HOG_VIVADO_DIR__= Path of your Vivado SDK installation directory containing the xsetup executable (not required if you run the script with the ``-x`` flag)
  - __HOG_TOKEN__= a valid gitlab private token for your service accaount
  - __HOG_USERGROUP__= The name of your user group, e.g. "zp" for ATLAS
- Go to the VM directory and launch the __hog-vm-setup.sh__ script
- Once the script has finished, you can login to the VM as your service account (john)

### Allowing concurrent jobs on a single Openstack VM
- Log into your Openstack machine
- Open with your preferred editor with sudo rights `/etc/gitlab-runner/config.toml`
- In the `global section` add ``concurrent = NUMBER_OF_CONCURRENT_CPU``:  limits how many jobs globally can be run concurrently. That means, it applies to all the runners on the machine independently of the executor [docker, ssh, kubernetes etc]
- In the `runner section` add ``limit = MAX_NUMBER_OF_CONCURRENT_JOB_PER_RUNNER``: Limit how many jobs can be handled concurrently by this token. Suppose that we have 2 runners registered by 2 different tokens, then its limit could be adjusted separately : runner-one limit = 3, runner-two limit =5,…
- In the `runner section` add ``request_concurrency = NUMBER_OF_CONCURRENT_REQUESTS_PER_NEW_JOBS`` : Limit number of concurrent requests for new jobs from GitLab (default 1)
- [Have a look here for more info](https://medium.com/faun/maximize-your-gitlab-runner-power-with-ci-cd-concurrent-pipelines-a5dcc092cee7)
- Example ``config.toml``
``` 
concurrent = 4
check_interval = 0

[session_server]
  session_timeout = 1800

[[runners]]
  limit = 4
  request_concurrency = 4
  name = "HOG vivado runner on mypc"
  url = "https://gitlab.cern.ch"
  token = "ibsaidbasdhubavsuod"
  executor = "shell"
  [runners.custom_build_dir]
  [runners.cache]
    [runners.cache.s3]
    [runners.cache.gcs]
```
If something goes wrong, please report it.

