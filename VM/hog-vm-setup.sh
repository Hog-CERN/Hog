#!/usr/bin/env bash
OLD_DIR=`pwd`
THIS_DIR="$(dirname "$0")"

if [ "$(whoami)" != "root" ]; then
    echo "[Hog VM Setup] FATAL: Script must be run as root."
    exit -1
fi

if [ -v HOG_USERNAME ]; then
    echo "[Hog VM Setup] The user Hog will use is: $HOG_USERNAME"
else
    echo "[Hog VM Setup] ERROR: variable HOG_USERNAME should be set with a valid CERN user name"
    exit -1
fi

if [ -v HOG_USERGROUP ]; then
    echo "[Hog VM Setup] The user group Hog will use is: $HOG_USERGROUP"
else
    echo "[Hog VM Setup] ERROR: variable HOG_USERGROUP should be set with a valid CERN user group"
    exit -1
fi

if [ -v HOG_TOKEN ]; then
    echo "[Hog VM Setup] The private token for gitlab acces is set to : $HOG_TOKEN"
else
    echo "[Hog VM Setup] ERROR: variable HOG_TOKEN should be set with a valid gitlab private token"
    exit -1
fi

if [ -v HOG_VIVADO_DIR ]; then
    echo "[Hog VM Setup] Vivado installation direcotry is set to $HOG_VIVADO_DIR"
else
    echo "[Hog VM Setup] ERROR: variable HOG_VIVADO_DIR should be set and point to a valid Xilinx Vivado SDK installation directory (containing the xsetup file)."
    exit -1
fi

cd "${THIS_DIR}"

echo
echo [Hog VM Setup] Adding $HOG_USERNAME user...
addusercern $HOG_USERNAME
echo
echo [Hog VM Setup] Adding $HOG_USERNAME to systemd_journal group...
usermod -a -G systemd-journal $HOG_USERNAME
echo
echo [Hog VM Setup] Making $HOG_USERNAME home...
mkdir /home/$HOG_USERNAME
chmod a+rxw /home/$HOG_USERNAME
chown $HOG_USERNAME:$HOG_USERGROUP /home/$HOG_USERNAME
/sbin/usermod -m -d /home/$HOG_USERNAME $HOG_USERNAME

echo [Hog VM Setup] Copying files to $HOG_USERNAME home...
cp -f ./hog_bash_profile /home/$HOG_USERNAME/.bash_profile
cp -f ./hog_bashrc /home/$HOG_USERNAME/.bashrc

echo
echo "[Hog VM Setup] Installing useful packages..."
curl -L https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.rpm.sh | bash
yum -y install gitlab-runner jq emacs doxygen eos-client

echo
echo "[Hog VM Setup] Installing wandisco repository..."
yum -y install http://opensource.wandisco.com/centos/6/git/x86_64/wandisco-git-release-6-1.noarch.rpm
echo "[Hog VM Setup] Updating to recent version of git from wandisco..."
yum -y --disablerepo=base,updates  update git

echo
echo "[Hog VM Setup] Installing uhal from ipbus..."
curl http://ipbus.web.cern.ch/ipbus/doc/user/html/_downloads/ipbus-sw.centos7.x86_64.repo > ipbus-sw.repo
cp ipbus-sw.repo /etc/yum.repos.d/
yum -y groupinstall uhal

echo
echo "[Hog VM Setup] Creating swap file, this might take a while..."
dd if=/dev/zero of=/swapfile bs=1024 count=16777216
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile

if [ -e /dev/vdb ]; then
    echo "[Hog VM Setup] Formatting and mounting /dev/vdb..."
    mkfs.ext4 /dev/vdb
    mkdir /mnt/vd
    chmod a+xrw /mnt/vd
    mount /dev/vdb /mnt/vd
    mkdir /mnt/vd/runner
    
    echo "[Hog VM Setup] Setting up Gitlab runner..."
    gitlab-runner uninstall
    gitlab-runner install --user=$HOG_USERNAME --working-directory=/mnt/vd/runner
    gitlab-runner register \
        --non-interactive \
        --url "https://gitlab.cern.ch" \
        --registration-token "$HOG_TOKEN" \
        --executor "shell" \
        --description "HOG vivado runner on $HOSTNAME" \
        --tag-list "hog,vivado" \
        --run-untagged="true" \
        --locked="false"
    gitlab-runner start
else
    echo
    echo "[Hog VM Setup] WARINING /dev/vdb not found"
fi

echo
echo "[Hog VM Setup] Adding lines into fstab..."
echo " " >> /etc/fstab
echo "# Lines added by Hog #" >> /etc/fstab
echo "/swapfile   swap    swap    sw  0   0" >> /etc/fstab
echo "/dev/vdb  /mnt/vd  ext4    rw,relatime,seclabel,data=ordered 0 0" >> /etc/fstab

if [[ -x "$HOG_VIVADO_DIR/xsetup" ]]; then
    echo
    echo "[Hog VM Setup] Installing Vivado, this might take more than a while..."
    $HOG_VIVADO_DIR/xsetup --agree XilinxEULA,3rdPartyEULA,WebTalkTerms --batch Install --config ./install_config.txt
else
    echo
    echo "[Hog VM Setup] Vivado setup not found in $VIVADO_DIR..."
fi

cd "${OLD_DIR}"

