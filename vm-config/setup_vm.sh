#!/bin/bash

yum install htop emacs git eos-fuse doxygen python-webpy

mkfs.ex4 /dev/vdb
mkdir /mnt/vd
chmod a+xrw /mnt/vd
mount /dev/vdb /mnt/v

addusercern efex
# making efex home
mkdir /home/efex
chmod a+rxw /home/efex

# copying git config file
cp gitconfig /home/efex/.gitconfig

cp -r ssh/ /home/efex/.ssh
cp bash_profile /home/efex/.bash_profile
cp -r bashrc /home/efex/.bashrc
# change home directory in /etc/passwd

# go to vivado installation dir
./xsetup --agree XilinxEULA,3rdPartyEULA,WebTalkTerms --batch Install --config ../install_config.txt

# copy eos config files from lxplus
cp ./eos_config/* /etc/sysconfig/

# copy krb5 config file
cp ./krb5.conf /etc

systemctl enable eosd.service
systemctl start eosd.service
eosfusebind krb5

dd if=/dev/zero of=/swapfile bs=1024 count=16777216
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile

#firewall
firewall-cmd --zone=public --add-port=8000/tcp --permanent
firewall-cmd --reload

