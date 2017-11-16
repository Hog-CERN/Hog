#!/bin/bash
if [ "$#" -lt 2 ]; then  
    echo "Usage $0 <source branch> <destination branch> [revision dir] [web dir]"
    echo
    exit -1
fi

REVISION_DIR=/mnt/big/eFEX-revision
WEB_DIR=/eos/user/e/efex/www/revision
if [ "$#" -gt 2 ]; then  
    REVISION_DIR=$3
fi
if [ "$#" -gt 3 ]; then  
    WEB_DIR=$4
fi


LOCK=$REVISION_DIR/lock
OLD_DIR=`pwd`
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $DIR
if [ -f $LOCK ]; then
    exit
fi
cd ..
git submodule init --quiet
git submodule update --quiet
git clean -xdf --quiet
cd $DIR
FROM_BRANCH=$1
TO_BRANCH=$2
git reset --hard HEAD --quiet
git checkout $FROM_BRANCH --quiet
git fetch  --quiet
ALL_GOOD=1
AT_LEAST_ONE=0
if ! git diff --quiet remotes/origin/$FROM_BRANCH; then
    touch $LOCK
    git pull  --quiet
    COMMIT=`git log --format=%h -1`

    TIME_DIR=$REVISION_DIR/$COMMIT/timing
    UTIL_DIR=$REVISION_DIR/$COMMIT/utilization
    mkdir -p $TIME_DIR
    mkdir -p $UTIL_DIR
    NJOBS=`/usr/bin/nproc`
    
    # Loop over projects here
    for PROJECT in `ls ../Top`
    do
	RUNS_DIR=../VivadoProject/$PROJECT/$PROJECT.runs
	echo "Creating project $PROJECT..."
	OUT_DIR=$REVISION_DIR/$COMMIT/$PROJECT
	mkdir -p $OUT_DIR
	LOG_FILE=$OUT_DIR/viv.log
	JOURNAL_FILE=$OUT_DIR/viv.jou
	echo "Project: $PROJECT ($COMMIT) from branch $FROM_BRANCH to $TO_BRANCH is preparing to run with $NJOBS jobs..." > $WEB_DIR/status
	vivado -mode batch -notrace -journal $JOURNAL_FILE -log $LOG_FILE -source ../Tcl/launch_runs.tcl -tclargs $PROJECT $RUNS_DIR $NJOBS > /dev/null
	if [ $? -ne 0 ]; then
	    cat $JOURNAL_FILE  | mail -s "Error during design flow for $PROJECT ($COMMIT)" -a $LOG_FILE l1calo-efex@cern.ch    
	fi
	sleep 10
	/usr/bin/perl ./RunStatus.pl $RUNS_DIR $WEB_DIR/status
	sleep 10
	/usr/bin/perl ./RunStatus.pl $RUNS_DIR $WEB_DIR/status
	sleep 10
	cp -pr $RUNS_DIR/* $OUT_DIR
	cp $OUT_DIR/*/*$PROJECT\_timing_summary_routed.rpt* $TIME_DIR 2>/dev/null
	cp $OUT_DIR/*/*$PROJECT\_utilization_synth.rpt* $UTIL_DIR 2>/dev/null
	TIMING_REP=`ls $OUT_DIR/*/*$PROJECT\_timing_summary_routed.rpt* 2>/dev/null | head -1`
	BITFILE=`ls $OUT_DIR/*/*$PROJECT.bit 2>/dev/null | head -1`
	if [ ! -z $BITFILE ] && [ -f $BITFILE ]; then
	    AT_LEAST_ONE=1
	    GOOD_MESSAGE=$GOOD_MESSAGE"\n$PROJECT\n"`cat $TIMING_REP | grep "Design Timing Summary" -B1 -A12 | grep -v "\-\-\-"`
	    GIT_MESSAGE=$GIT_MESSAGE"
$PROJECT
"`cat $TIMING_REP | grep "Design Timing Summary" -B1 -A12 | grep -v "\-\-\-"`
	    mv $BITFILE $OUT_DIR/$(basename $BITFILE .bit)-$COMMIT.bit	    
	else
	    MESSAGE=`cat $JOURNAL_FILE $WEB_DIR/status`
	    printf $MESSAGE  | mail -s "Error in design flow for $PROJECT ($COMMIT)" -a $LOG_FILE atlas-l1calo-efex@cern.ch
	    ALL_GOOD=0
	    #break
	fi
    done

    if [ $AT_LEAST_ONE -eq 1 ]; then
	if [ $ALL_GOOD -eq 1 ]; then
	    MSG="All projects flows were successful\n"$GOOD_MESSAGE
	else
	    MSG=$GOOD_MESSAGE
	fi

	ZIP_TIMING=$REVISION_DIR/$COMMIT/timing.tar.gz 
	ZIP_UTIL=$REVISION_DIR/$COMMIT/utilization.tar.gz
	cd $TIME_DIR
	if [ `ls * 2>/dev/null` ]; then 
	    tar czf $ZIP_TIMING *
	    ZIP_TIMING="-a $ZIP_TIMING"
	else
	    ZIP_TIMING=
	fi    
	cd -
	cd $UTIL_DIR
	if [ `ls * 2>/dev/null` ]; then 
	    tar czf $ZIP_UTIL *
	    ZIP_UTIL="-a $ZIP_UTIL"
	else
	    ZIP_UTIL=
	fi    
	cd -
	printf "$MSG" | mail -s "Completed design flow for $PROJECT ($COMMIT)" $ZIP_TIMING $ZIP_UTIL atlas-l1calo-efex@cern.ch
    fi

    if [ $ALL_GOOD -eq 1 ]; then
	git reset --hard HEAD --quiet
	git clean -xdf --quiet
	git checkout $TO_BRANCH --quiet
	git merge --no-ff -m "Merge $FROM_BRANCH into $TO_BRANCH after successful automatic test" -m "$GIT_MESSAGE" $FROM_BRANCH --quiet
	git push origin $TO_BRANCH --quiet 2>&1 > /dev/null
	cd .. #go to git repository main directory
	echo "" >> doxygen/doxygen.conf
	echo -e "\nPROJECT_NUMBER = $COMMIT" >> doxygen/doxygen.conf
	/usr/bin/doxygen doxygen/doxygen.conf 2>&1 > $WEB_DIR/../doc/doxygen-$COMMIT.log
	rm -r $WEB_DIR/../doc/*
	cp -r ../Doc/html/* $WEB_DIR/../doc/
    else
	echo Errors were encountered, will not commit to $TO_BRANCH. 
    fi
else
    echo Repository up to date on $FROM_BRANCH branch at $COMMIT 
fi
rm -f $LOCK
cd $OLD_DIR

