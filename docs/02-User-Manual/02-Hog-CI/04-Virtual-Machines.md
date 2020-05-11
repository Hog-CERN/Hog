# Setting up a Virtual Machines for firmware implementation

In order to allow git to implement your firmware automatically at each new push on the mater you will need to set-up a Virtual Machine.

The ATLAS TDAQ group provides a dedicated Virtual Machine accessible by all groups having a cern service account.
More information on this machine can be found in the [ATLAS common firmware Virtual Machine](#ATLAS_common?firmware_virtual_machine) section.

If you want to use your private Virtual Machine you can find more information in the [Setting up a dedicated Virtual Machine](#setting_up_a_dedicated_Virtual_Machine) section.

## Setting up a dedicated Virtual Machine

In this section you can find more information on how to set up your private gitlab runner.
Instructions are provided assuming you have access to the CERN computing resources. 
If this is not the case you can still use Hog provided that you have a machine running CentOS 7 set up as a gitlab runner.
In the latter case you can ignore the next section and jump directly to [Install gitlab runner](#install_gitlab runner)

### Create an CERN Openstack Virtual Machine

OpenStack is a cloud operating system that controls large pools of compute, storage, and networking resources throughout a data-centre, all managed and provisioned through APIs with common authentication mechanisms.
Openstack provides you with a [dashboard](https://openstack.cern.ch/project/) from which you can manage VM instances
More information on Openstack can be found in the [Openstack Dashboard Documentation](https://docs.openstack.org/horizon/train/user/).

In order to create a new VM you have to connect to the [CERN Openstack dashboard](https://openstack.cern.ch/project/) and create a new instance.

Openstack instances come with different flavours, meaning you can allocate only a fixed amount of each resource to each VM.
The flavours available are usually not enough for the requirements of modern firmware implementation.
Please check the requirement for the tools and devices in your project and ask for a custom flavour.

Before creating an new instance you can add a new disk that you can use to install the needed tools.
To do this go under ``` Volumes > Volumes ``` on the left navbar.
Once the Volumes summary appears you can click on ``` + Create Volume ``` and follow the instructions therein.
We recommend having at least a 40GB HD

Once you obtained a custon flavour and a dedicated disck you can create a new instance. 
Navigate to ``` Compute > Instances ```, once you get to the instances summary click  on ``` Launch Instance ```.
Fill in the required information on the modal that will appear.
Under the ``` Source ``` tab * select an updated CC7 image *, this will generate a VM running under Centos 7.
Select the custom Flavor in the ``` Flavor ``` tab.
Generate a new key pair and save the private key, this will be needed later to access your VM.

Once a new instance is running (note it might take few minutes to be generated) attach the Volume you created to the VM.
This can be done through the dropdown menu on the right side of the instance summary by clicking on ``` attach volume ```.

You can now connect to your machine through ssh.
*NOTE* your machine is not fully public yet (reference the Openstack manual for this).
This means your VM will be accessible only from the cern domain.
If you are not on the cern domain connect to a CERN public machine (``` lxplus ```) and then to you machine.

```bash
  ssh -i private-key.pem <machine_ip_or_name>
 ```

 Once you are logged on your machine change the root password:

 ```bash
  sudo password root
 ```
Please follow the IT reccomendations when chosing a new password.
Mount the volume you created, make sure you own it, format it, etc...

```bash
 sudo su                             # become root
 mkfs.ext3 /dev/<diskname>           # format the disk
 mkdir /mnt/vd                       # create mounting point for the disk
 mount /dev/<diskname> /mnt/vd       # mount the disk
 chown -hR <username> /mnt/vd        # own the disk
```

*NOTE* there is no need to add this disk to /etc/fstab for automati mounting since Hog will later do this automatically.

You are now ready to install your favourite tools!

### Installing  HDL tools

Install al the needed tools on your brand new VM.
The machine will need an installation of all licensed software (Xilinx Vivado, Mentor Graphics Questasim, ...) you use in your project.
*NOTE* you are the one responsible for correctly licensing the software!

### Install gitlab runner

Information on How to install a new gitlab runnare on your VM can be found [here](https://docs.gitlab.com/runner/install/)

#### Allowing concurrent jobs on a single Openstack Virtual Machine

- Log into your VM
- Open with your preferred editor with sudo rights `/etc/gitlab-runner/config.toml`
- In the `global section` add ``concurrent = NUMBER_OF_CONCURRENT_CPU``:  limits how many jobs globally can be run concurrently. That means, it applies to all the runners on the machine independently of the executor [docker, ssh, kubernetes etc]
- In the `runner section` add ``limit = MAX_NUMBER_OF_CONCURRENT_JOB_PER_RUNNER``: Limit how many jobs can be handled concurrently by this token. Suppose that we have 2 runners registered by 2 different tokens, then its limit could be adjusted separately : runner-one limit = 3, runner-two limit =5,
- In the `runner section` add ``request_concurrency = NUMBER_OF_CONCURRENT_REQUESTS_PER_NEW_JOBS`` : Limit number of concurrent requests for new jobs from gitLab (default 1)
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
    name = "Hog vivado runner on mypc"
    url = "https://gitlab.cern.ch"
    token = "ibsaidbasdhubavsuod"
    executor = "shell"
    [runners.custom_build_dir]
    [runners.cache]
      [runners.cache.s3]
      [runners.cache.gcs]
```
If something goes wrong, please report it.

### Hog set-up on the gitlab runner

Hog will need the Virtual Machine you use as gitlab runner to be properly set-up.
- Clone Hog repository somewhere accessible from the VM, e.g. on you AFS home
- ssh into your virtual machine as yourself
- Become root
- Export the following system variables:
  - __Hog_USERNAME__= The name of you service account, e.g. john
  - __Hog_VIVADO_DIR__= Path of your Vivado SDK installation directory containing the xsetup executable (not required if you run the script with the ``-x`` flag)
  - __Hog_TOKEN__= a valid gitlab private runner token: Go to `Settings` -> `CI/CD` and expand the `Runners` tab. The registration token in `Specific Runners ` column.
  - __Hog_USERGROUP__= The name of your user group, e.g. "zp" for ATLAS
- Go to the VM directory and launch the __hog-vm-setup.sh__ script
- Once the script has finished, you can login to the VM as your service account (john)

## ATLAS common firmware Virtual Machine

We provide a Virtual Machine satisfying basic requirements./
*NOTE*: currenctly we provide one instance to be shared among all the projects.
Do not use this machine for firmware development!

CREM reserved for us an instance with _ c3.2xlarge flavor_

- 120 GB RAM
- CPU: Intel(R) Xeon(R) CPU E5-2683 v4 @ 2.10GHz
- 640 GB SSD
- 10 TB Storage

In order to access this machine plese create a [CERN service account](https://account.cern.ch/account/Help/?kbid=011010)
After the service account has been created, send an email to [atlas-tdaq-firmware-support](mailto:atlas-tdaq-firmware-support@cern.ch), so that the account is added to the VM (no sudo rights), with its home.
once your account has been activated, you can log into the ``` atlas-tdaq-firmware-dev ``` machine.
the following tools are available for set-up:

- devtoolset-7: ``` /opt/rh/devtoolset-7 ```
- git 2.18: ``` /opt/rh/rh-git218 ```
- Vivado 2017.4, 2018.1, 2019.2:  ``` /opt/Xilinx/Vivado/$VERSION/ ```
- Quartus 19.2: ``` opt/intel/FPGA_pro/19.2/ ```
- QuestaSim 10.7a (from CERN DFS repository): ```/opt/questa/10.7a/linux_x86_64/modeltech/bin/ ```

Newer version of these tools mightbe available.
If your project needs specific tools please get in touch with [atlas-tdaq-firmware-support](mailto:atlas-tdaq-firmware-support@cern.ch)

To set up this machine to run CI/CD for your project go on the gitlab page for your project. 
Go to `Settings` -> `CI/CD` and expand the `Runners` tab.
Copy the registration token in `Specific Runners ` column.

Run `sudo gitlab/runner register` on the VM.

- Enter https://gitlab.cern.ch as coordination URL.
- Enter the token you just obtained as token.
- Enter `shell` when asked to enter the Executor.
