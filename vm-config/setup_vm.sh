#!/bin/bash
if [ -v VIVADO_DIR]; then
    echo "[VM Setup] Vivado installation direcotry is set to $VIVADO_DIR"
else
    VIVADO_DIR=/afs/cern.ch/work/f/fgonnell/Xilinx_Vivado_SDK_2017.3_1005_1/
    echo "[VM Setup] Automatically setting Vivado installation direcotry to $VIVADO_DIR"
fi

echo "[VM Setup] Installing useful packages..."
yum install htop emacs git eos-fuse doxygen python-webpy screen

echo "[VM Setup] Installing wandisco repository..."
yum install http://opensource.wandisco.com/centos/6/git/x86_64/wandisco-git-release-6-1.noarch.rpm
echo "[VM Setup] Updating to recent version of git from wandisco..."
yum --disablerepo=base,updates  update git

echo "[VM Setup] Installing uhal from ipbus..."
curl http://ipbus.web.cern.ch/ipbus/doc/user/html/_downloads/ipbus-sw.centos7.x86_64.repo > ipbus-sw.repo
cp ipbus-sw.repo /etc/yum.repos.d/
yum groupinstall uhal

echo "[VM Setup] Config files into efex's home"
cp gitconfig /home/efex/.gitconfig
chown efex:zp /home/efex/.gitconfig
cp -r ssh/ /home/efex/.ssh
chown efex:zp /home/efex/.ssh
cp bash_profile /home/efex/.bash_profile
chown efex:zp /home/efex/.bash_profile
cp -r bashrc /home/efex/.bashrc
chown efex:zp /home/efex/.bashrc

echo "[VM Setup] ***************************** "
echo "[VM Setup] ACTION NEEDED: Please change home directory of efex user to /home/efex in /etc/passwd"
echo "[VM Setup] ***************************** "

echo "[VM Setup] Copying eos config files..."
cp ./eos_config/* /etc/sysconfig/

echo "[VM Setup] Copying Kerberos config file..."
cp ./krb5.conf /etc

echo "[VM Setup] Activating EOS service..."
systemctl enable eosd.service
systemctl start eosd.service
eosfusebind krb5

echo "[VM Setup] Configuring firewall..."
firewall-cmd --zone=public --add-port=8000/tcp --permanent
firewall-cmd --reload

echo "[VM Setup] Installing efex AWS service..."
cp efex-aws.service /etc/systemd/system
systemctl enable efex-aws.service

echo "[VM Setup] Creating swap file, this might take a while..."
dd if=/dev/zero of=/swapfile bs=1024 count=16777216
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile

if [ -e /dev/vdb ]; then
    echo "[VM Setup] Formatting and mounting /dev/vdb..."
    mkfs.ex4 /dev/vdb
    mkdir /mnt/vd
    chmod a+xrw /mnt/vd
    mount /dev/vdb /mnt/vd
else
    echo "[VM Setup] WARINING /dev/vdb not found"
fi

if [[ -x "$VIVADO_DIR/xsetup" ]]; then
    echo "[VM Setup] Installing Vivado, this might take more than a while..."
    $VIVADO_DIR/xsetup --agree XilinxEULA,3rdPartyEULA,WebTalkTerms --batch Install --config ./install_config.txt
else
    echo "[VM Setup] Vivado setup not found in $VIVADO_DIR..."
fi
