#!/bin/bash
OLD_DIR=`pwd`
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $DIR

FROM_BRANCH=$1
TO_BRANCH=$2
LOG_FILE=/mnt/big/eFEX-revision/viv.log
JOURNAL_FILE=/mnt/big/eFEX-revision/viv.jou
git reset --hard HEAD --quiet
git clean -xdf --quiet
git checkout $FROM_BRANCH --quiet
git submodule init --quiet
git submodule update --quiet
COMMIT=`git log --format=%h -1`
git fetch  --quiet
if ! git diff --quiet remotes/origin/$FROM_BRANCH; then
    git pull  --quiet
    vivado -mode batch -notrace -journal $JOURNAL_FILE -log $LOG_FILE -source ../Tcl/design_flow.tcl -tclargs process_fpga /mnt/big/eFEX-revision/ > /dev/null
    if [ $? -ne 0 ]; then
	cat $JOURNAL_FILE  | mail -s "Error during design flow for $project ($COMMIT)" -a $LOG_FILE l1calo-efex@cern.ch    
    fi
else
    echo Repository up to date on $FROM_BRANCH branch at $COMMIT 
fi

cd $OLD_DIR
