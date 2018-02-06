#!/bin/bash
echo Adding efex user...
addusercern efex
echo Making efex home...
mkdir /home/efex
chmod a+rxw /home/efex

echo Installing git...
yum install git

echo Cloning repository...
cd /home/efex
git clone https://:@gitlab.cern.ch:8443/atlas-l1calo-efex/AutomationScripts.git

echo Running setup script...
cd /home/efex/AutomationScripts/vm-config
bash setup_vm.sh
