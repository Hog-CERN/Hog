#!/bin/bash
echo [init] Adding efex user...
sudo addusercern efex
echo [init] Making efex home...
sudo mkdir /home/efex
sudo chmod a+rxw /home/efex
sudo chown efex:zp /home/efex

echo [init] Installing git...
sudo yum install git

echo [init] Cloning repository...
cd /home/efex
git clone https://:@gitlab.cern.ch:8443/atlas-l1calo-efex/AutomationScripts.git
sudo chown efex:zp -R ./AutomationScripts/

echo [init] Running setup script...
cd /home/efex/AutomationScripts/vm-config
sudo bash setup_vm.sh
