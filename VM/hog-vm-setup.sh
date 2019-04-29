HOG_USERNAME=efex
HOG_USERGROUP=zp
HOG_VIVADO_DIR=/afs/cern.ch/work/f/fgonnell/Xilinx_Vivado_SDK_2017.3_1005_1/
HOG_TOKEN=LDRqe3_ExsUByTmEduxs

if [ "$(whoami)" != "root" ]; then
    echo "Script must be run as root"
    exit -1
fi

echo [Hog VM Setup] Adding $HOG_USERNAME user...
addusercern $HOG_USERNAME
echo [Hog VM Setup] Adding $HOG_USERNAME to systemd_journal group...
usermod -a -G systemd-journal $HOG_USERNAME
echo [Hog VM Setup] Making $HOG_USERNAME home...
mkdir /home/$HOG_USERNAME
chmod a+rxw /home/$HOG_USERNAME
chown $HOG_USERNAME:$HOG_USERGROUP /home/$HOG_USERNAME

echo "[Hog VM Setup] Installing useful packages..."
curl -L https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.rpm.sh | bash
yum -y install gitlab-runner jq emacs


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
    gitlab-runner install --user=efex --working-directory=/mnt/vd/runner
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
    echo "[Hog VM Setup] WARINING /dev/vdb not found"
fi

echo "[Hog VM Setup] Adding lines into fstab..."
echo " " >> /etc/fstab
echo "# Lines added by awe #" >> /etc/fstab
echo "/swapfile   swap    swap    sw  0   0" >> /etc/fstab
echo "/dev/vdb  /mnt/vd  ext4    rw,relatime,seclabel,data=ordered 0 0" >> /etc/fstab

if [[ -x "$HOG_VIVADO_DIR/xsetup" ]]; then
    echo "[Hog VM Setup] Installing Vivado, this might take more than a while..."
    $HOG_VIVADO_DIR/xsetup --agree XilinxEULA,3rdPartyEULA,WebTalkTerms --batch Install --config ./install_config.txt
else
    echo "[Hog VM Setup] Vivado setup not found in $VIVADO_DIR..."
fi

