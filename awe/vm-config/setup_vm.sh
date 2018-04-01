#!/bin/bash
if [ -v AWE_NAME ]; then
    echo "[awe-VM Setup] Project name set to $AWE_NAME"
else
    echo "[awe-VM Setup] ERROR: Variable AWE_NAME should be set to the name of the project"
    exit 1
fi
if [ -v AWE_PATH ]; then
    echo "[awe-VM Setup] awe-compatible HDL repository path set to $AWE_PATH"
else
    echo "[awe-VM Setup] ERROR: Variable AWE_PATH should be set to the root of the repository containing Hog/awe"
    exit 1
fi

if [ -v AWE_REPO ]; then
    echo "[awe-VM Setup] awe-compatible HDL repository set to $AWE_REPO"
else
    echo "[awe-VM Setup] ERROR: Variable AWE_REPO should be set to the name of the HDL repository containing Hog/awe"
    exit 1
fi

if [ -v AWE_VIVADO_DIR ]; then
    echo "[awe-VM Setup] Vivado installation direcotry is set to $AWE_VIVADO_DIR"
else
    VIVADO_DIR=/afs/cern.ch/work/f/fgonnell/Xilinx_Vivado_SDK_2017.3_1005_1/
    echo "[awe-VM Setup] ERROR: variable AWE_VIVADO_DIR should be set and point to a valid Xilinx Vivado SDK installation directory."
    exit 1
fi

if [ -v AWE_USERNAME ]; then
    echo "[awe-VM Setup] The user awe will use is: $AWE_USERNAME"
else
    echo "[awe-VM Setup] ERROR: variable AWE_USERNAME should be set with a valid CERN user name"
    exit 2
fi

if [ -v AWE_USEREMAIL ]; then
    echo "[awe-VM Setup] The user email awe will use is: $AWE_USEREMAIL"
else
    echo "[awe-VM Setup] ERROR: variable AWE_USEREMAIL should be set with a valid CERN user email"
    exit 2
fi

if [ -v AWE_USERGROUP ]; then
    echo "[awe-VM Setup] The user group awe will use is: $AWE_USERGROUP"
else
    echo "[awe-VM Setup] ERROR: variable AWE_USERGROUP should be set with a valid CERN user group"
    exit 3
fi

if [ -v AWE_PRIVATETOKEN ]; then
    echo "[awe-VM Setup] The private token for gitlab acces is set to : $AWE_PRIVATETOKEN"
else
    echo "[awe-VM Setup] ERROR: variable AWE_PRIVATETOKEN should be set with a valid gitlab private token"
    exit 3
fi

if [ -z "$AWE_WEB_PATH" ] || [ -z "$AWE_REVISION_PATH" ] || [ -z "$AWE_KEYTAB" ]; then
  echo "[awe-VM Setup] ERROR: variable AWE_WEB_PATH, AWE_REVISION_PATH, AWE_KEYTAB should be set with a valid value"
  exit 1
fi

if [ "$(whoami)" != "root" ]; then
    echo "Script must be run as root"
    exit -1
fi

echo [awe-VM Setup] Adding $AWE_USERNAME user...
addusercern $AWE_USERNAME
echo [awe-VM Setup] Making $AWE_USERNAME home...
mkdir /home/$AWE_USERNAME
chmod a+rxw /home/$AWE_USERNAME
chown $AWE_USERNAME:$AWE_USERGROUP /home/$AWE_USERNAME

echo "[awe-VM Setup] Installing useful packages..."
yum -y install htop emacs git eos-fuse doxygen python-webpy screen

echo "[awe-VM Setup] Installing wandisco repository..."
yum -y install http://opensource.wandisco.com/centos/6/git/x86_64/wandisco-git-release-6-1.noarch.rpm
echo "[awe-VM Setup] Updating to recent version of git from wandisco..."
yum -y --disablerepo=base,updates  update git

echo "[awe-VM Setup] Installing uhal from ipbus..."
curl http://ipbus.web.cern.ch/ipbus/doc/user/html/_downloads/ipbus-sw.centos7.x86_64.repo > ipbus-sw.repo
cp ipbus-sw.repo /etc/yum.repos.d/
yum -y groupinstall uhal

echo "[awe-VM Setup] Config files into $AWE_USERNAME's home"
envsubst < gitconfig > /home/$AWE_USERNAME/.gitconfig
chown $AWE_USERNAME:$AWE_USERGROUP /home/$AWE_USERNAME/.gitconfig
cp -r ssh/ /home/$AWE_USERNAME/.ssh
chown -R $AWE_USERNAME:$AWE_USERGROUP /home/$AWE_USERNAME/.ssh
chmod 600 /home/$AWE_USERNAME/.ssh/*
cp bash_profile /home/$AWE_USERNAME/.bash_profile
chown $AWE_USERNAME:$AWE_USERGROUP /home/$AWE_USERNAME/.bash_profile
cp -r bashrc /home/$AWE_USERNAME/.bashrc
chown $AWE_USERNAME:$AWE_USERGROUP /home/$AWE_USERNAME/.bashrc

echo "[awe-VM Setup] Changing home directory of $AWE_USERNAME user to /home/$AWE_USERNAME..."
usermod -m -d /home/$AWE_USERNAME $AWE_USERNAME

echo "[awe-VM Setup] Copying keytab file to $AWE_USERNAME home and renaming it..."
cp $AWE_KEYTAB /home/$AWE_USERNAME/$AWE_USERNAME.keytab
chown $AWE_USERNAME:$AWE_USERGROUP /home/$AWE_USERNAME/$AWE_USERNAME.keytab

echo "[awe-VM Setup] Copying eos config files..."
cp ./eos_config/* /etc/sysconfig/

echo "[awe-VM Setup] Copying Kerberos config file..."
cp ./krb5.conf /etc

echo "[awe-VM Setup] Activating EOS service..."
systemctl enable eosd.service
systemctl start eosd.service
eosfusebind krb5

echo "[awe-VM Setup] Configuring firewall..."
firewall-cmd --zone=public --add-port=8000/tcp --permanent
firewall-cmd --reload

echo "[awe-VM Setup] Installing awe service..."
envsubst < awe@.service > /etc/systemd/system/awe@.service
envsubst < awe.conf > /etc/awe-$AWE_NAME.conf
systemctl enable awe@$AWE_NAME

echo "[awe-VM Setup] Creating swap file, this might take a while..."
dd if=/dev/zero of=/swapfile bs=1024 count=16777216
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile

if [ -e /dev/vdb ]; then
    echo "[awe-VM Setup] Formatting and mounting /dev/vdb..."
    mkfs.ext4 /dev/vdb
    mkdir /mnt/vd
    chmod a+xrw /mnt/vd
    mount /dev/vdb /mnt/vd
else
    echo "[awe-VM Setup] WARINING /dev/vdb not found"
fi

cd /home/$AWE_USERNAME
su $AWE_USERNAME -c "git clone ssh://git@gitlab.cern.ch:7999/$AWE_REPO"
cd -

if [[ -x "$AWE_VIVADO_DIR/xsetup" ]]; then
    echo "[awe-VM Setup] Installing Vivado, this might take more than a while..."
    $AWE_VIVADO_DIR/xsetup --agree XilinxEULA,3rdPartyEULA,WebTalkTerms --batch Install --config ./install_config.txt
else
    echo "[awe-VM Setup] Vivado setup not found in $VIVADO_DIR..."
fi
