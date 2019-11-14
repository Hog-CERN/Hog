# HOG-ci: setup
Working for an HDL Git repository setup with Hog

### Service account as approver
- From this page, add your service account as approver
- Also check __Remove all approvals in a merge request when...__

## Openstack Virtual Machine setup
### Service account
In order to handle tasks on the VM, you will need a CERN service account.
- Create a service account (let's call it john)
  - Log in with it to gitlab and give it access to your repository
  - Create a private access token with API rights here: https://gitlab.cern.ch/profile/personal_access_tokens
- Prepare a big Volume (~500 GB) call it __vd__, mount it to your machine

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

### Create an CERN Openstack Virtual Machine
- Create an Instance with 40GB HD and 16 GB of RAM
    - You might need to ask for a custom one 
- Use an updated CC7 image
- Clone awe repository somewhere accessible from the VM, e.g. on you AFS home
- ssh into your virtual machine as yourself
- Become root
- Export the following system variables:
  - __HOG_USERNAME__= The name of you service account, e.g. john
  - __HOG_VIVADO_DIR__= Path of your Vivado SDK installation directory containing the xsetup executable
  - __HOG_TOKEN__= a valid gitlab private token for your service accaount

- Go to the VM directory and launch the __hog-vm-setup.sh__ script
- After the script is finished, you can login to the VM as your service account (john)

If something goes wrong, please report it

## Gitlab repository setup
### Remove merge commit
- Go to https://gitlab.cern.ch/YourGroup/YourProject/edit
- Expand __Merge Request settings__ 
- Select Fast-forward merge

## Setup Runners
### Define the following variables:
- __HOG_USER__= Your service accounr (john)
- __HOG_EMAIL__= Your service account's email  address (john@cern.ch)
- __HOG_PASSWORD__= The password of your service account (should be masked)
- __EOS_MGM_URL__= root://eosuser.cern.ch
- __HOG_UNOFFICIAL_BIN_EOS_PATH___= The EOS path for the binfiles coming out of your CIs
- __HOG_OFFICIAL_BIN_EOS_PATH__= The EOS path for archiving the official bitfiles of your firmware
- __HOG_PATH__= The PATH variable for your VM, should include Vivado's bin directory, 
- __HOG_PUSH_TOKEN__= The push token you generated for your service account (should be masked)
- __HOG_USE_DOXYGEN__= Should be set to 1 if you want the Hog CI to run doxygen
- __HOG_XIL_LICENSE__= Should contain the Xilinx license servers, separated by a comma


