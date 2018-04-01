# Hog: HDL on Git
List files, IP location, git ignore 
Always recreate project when adding new file

## IPBus functionality
XML file location
address map location

## HDL repository methodology
Include this repository (Hog) as a submodule into your HDL repository (do not change the directory name).


# AWE: the Automatic Work-flow Engine
## Gitlab repository setup
### Remove merge commit
Go to https://gitlab.cern.ch/YourGroup/YourProject/edit
Expand __Merge Request settings__ 
Select Fast-forward merge

### Service account as approver
From this page, add your service account as approver
Also check __Remove all approvals in a merge request when...__

### Setup web hook for awe
Go to settings -> Integration
Set as URL you machine name like this: http://myvirtualmchine.cern.ch:8000/
To setup the webhook, check only __Merge request event__
Port 8000 will be opened on your VM's firewall by the setup script

## Openstack Virtual Machine setup
- Create a service account
  - Log in with it to gitlab and give it access to your repository
  - Create a private access token with API rights here: https://gitlab.cern.ch/profile/personal_access_tokens
- Prepare a big Volume (~500 GB) call it __vd__, mount it to your machine
- Use image: CENTOS7
- Produce a __keytab file__ for your service account
- Export the following system variables:

__AWE\_NAME__= Name of your project

__AWE\_REPO__=atlas-l1calo-efex/eFEXFirmware

__AWE\_VIVADO\_DIR__=/afs/cern.ch/work/f/fgonnell/Xilinx_Vivado_SDK_2017.3_1005_1/

__AWE_USERNAME__= The name of you service account, e.g. john

__AWE\_PATH__= Path of your local repository, e.g. /home/john/repo

__AWE\_USEREMAIL__= You service account's email, e.g. john@cern.ch

__AWE\_USERGROUP__= Your service account's group, e.g. zp

__AWE\_PRIVATETOKEN__= Your gitlab private token

__AWE\_WEB\_PATH__= A path accessible via web, possibly on eos, e.g. /eos/user/j/john/www

__AWE_REVISION_PATH__= A path with a lot of disk space, use your Volume vd, e.g. /mnt/vd/project-revision/

__AWE_KEYTAB__= The keytab file you created, will be copied in your user's home and renamed john.keytab

__AWE_GITLAB_URL__= URL of the gitlab API you plan tu use, e.g. https://gitlab.cern.ch/api/v4/projects/

- Clone Hog repository somewhere accessible from the VM, e.g. on you AFS home
- ssh into your virtual machine as yourself
- Become root
- Export the following system variables:

  - __AWE\_NAME__= Name of your project

  - __AWE\_REPO__= The name of your firmware repository, including groups

  - __AWE\_VIVADO\_DIR__= Directory with the Vivado installer, where xsetup executable is located (accessible from you VM, AFS work area is a good idea)

  - __AWE_USERNAME__= The name of you service account, e.g. john

  - __AWE\_PATH__= Path of your local repository, e.g. /home/john/repo

  - __AWE\_USEREMAIL__= You service account's email, e.g. john@cern.ch

  - __AWE\_USERGROUP__= Your service account's group, e.g. zp

  - __AWE\_PRIVATETOKEN__= Your gitlab private token

  - __AWE\_WEB\_PATH__= A path accessible via web, possibly on eos, e.g. /eos/user/j/john/www

  - __AWE_REVISION_PATH__= A path with a lot of disk space, use your Volume vd, e.g. /mnt/vd/project-revision/

  - __AWE_KEYTAB__= The keytab file you created, will be copied in your user's home and renamed john.keytab

  - __AWE_GITLAB_URL__= URL of the gitlab API you plan tu use, e.g. https://gitlab.cern.ch/api/v4/projects/

- Go to the awe/vm-setup directory and launch the __setup\_vm.sh__ script