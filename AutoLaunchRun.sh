#!/bin/bash
if [ "$#" -lt 2 ]; then  
    echo "Usage $0 <repository path> <source branch> <destination branch> [revision dir] [web dir]"
    echo
    exit -1
fi

REVISION_DIR=/mnt/vd/eFEX-revision/
WEB_DIR=/eos/user/e/efex/www/
if [ "$#" -gt 3 ]; then  
    REVISION_DIR=$4
fi
if [ "$#" -gt 4 ]; then  
    WEB_DIR=$5
fi


LOCK=$REVISION_DIR/lock
#if [ -f $LOCK ]; then
#    echo "lock file found"
#    exit
#fi
while [ -f $LOCK ]; do
    echo "[AutoLaunchRun] waiting for lock file to disappear..."
    sleep 10
done

ARCHIVE_DIR=$WEB_DIR/firmware
OLD_DIR=`pwd`
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
DIR=$1
cd $DIR
git submodule init #--quiet
git submodule update #--quiet
git clean -xdf #--quiet
FROM_BRANCH=$2
TO_BRANCH=$3
echo "repo: $DIR, from: $FROM_BRANCH to $TO_BRANCH, rev $REVISION_DIR, web $WEB_DIR"
git reset --hard HEAD #--quiet
git checkout $FROM_BRANCH #--quiet
git fetch  #--quiet
ALL_GOOD=1
AT_LEAST_ONE=0

if ! git diff --quiet remotes/origin/$FROM_BRANCH; then #is this check still necessary?
#if [ 1 ]; then
    touch $LOCK
    declare -A PROJ_COMM
    for PR in `ls ./Top`
    do
	cd ./Top/$PR
	PROJ_COMM[$PR]=$(git log --format=%h -1 -- $(cat ./list/*) .)
	cd -
    done

    git pull  #--quiet
    COMMIT=`git log --format=%h -1`
    TIME_DIR=$REVISION_DIR/$COMMIT/timing
    UTIL_DIR=$REVISION_DIR/$COMMIT/utilization
    mkdir -p $TIME_DIR
    mkdir -p $UTIL_DIR
    NJOBS=`/usr/bin/nproc`
    
    # Loop over projects here
    for PROJECT in `ls ./Top`
    do
	cd ./Top/$PROJECT
	if [ "$(git log --format=%h -1 -- $(cat ./list/* ) .)" == ${PROJ_COMM[$PROJECT]} ]; then
	    cd -
	    echo [AutoLaunchRun] Project $PROJECT has not changed since last synthesis, skipping design-flow
	    continue
	fi
	cd -
	RUNS_DIR=./VivadoProject/$PROJECT/$PROJECT.runs
	echo [AutoLaunchRun] Creating project $PROJECT...
	OUT_DIR=$REVISION_DIR/$COMMIT/$PROJECT
	mkdir -p $OUT_DIR
	LOG_FILE=$OUT_DIR/viv.log
	JOURNAL_FILE=$OUT_DIR/viv.jou
	echo "Project: $PROJECT ($COMMIT) from branch $FROM_BRANCH to $TO_BRANCH is preparing to run with $NJOBS jobs..." > $WEB_DIR/status-$COMMIT-$PROJECT
	vivado -mode batch -notrace -journal $JOURNAL_FILE -log $LOG_FILE -source ./Tcl/launch_runs.tcl -tclargs $PROJECT $RUNS_DIR $NJOBS # > /dev/null
	if [ $? -ne 0 ]; then
	    cat $JOURNAL_FILE  | mail -s "Error during design flow for $PROJECT ($COMMIT)" -a $LOG_FILE l1calo-efex@cern.ch    
	fi
	sleep 10
	/usr/bin/perl $SCRIPT_DIR/RunStatus.pl $RUNS_DIR $WEB_DIR/status-$COMMIT-$PROJECT
	sleep 10
	/usr/bin/perl $SCRIPT_DIR/RunStatus.pl $RUNS_DIR $WEB_DIR/status-$COMMIT-$PROJECT
	sleep 10
	cp -pr $RUNS_DIR/* $OUT_DIR
	cp $OUT_DIR/*/*$PROJECT\_timing_summary_routed.rpt* $TIME_DIR 2>/dev/null
	cp $OUT_DIR/*/*$PROJECT\_utilization_synth.rpt* $UTIL_DIR 2>/dev/null
	TIMING_REP=`ls $OUT_DIR/*/*$PROJECT\_timing_summary_routed.rpt* 2>/dev/null | head -1`
	BITFILE=`ls $OUT_DIR/*/*$PROJECT.bit 2>/dev/null | head -1`
	BINFILE=`ls $OUT_DIR/*/*$PROJECT.bin 2>/dev/null | head -1`
	if [ ! -z $BITFILE ] && [ -f $BITFILE ]; then
	    AT_LEAST_ONE=1
	    GOOD_MESSAGE=$GOOD_MESSAGE"\n$PROJECT\n"`cat $TIMING_REP | grep "Design Timing Summary" -B1 -A12 | grep -v "\-\-\-"`
	    GIT_MESSAGE=$GIT_MESSAGE"
$PROJECT
"`cat $TIMING_REP | grep "Design Timing Summary" -B1 -A12 | grep -v "\-\-\-"`

	    # rename and move bitfile
	    NEW_BITFILE=$OUT_DIR/../$PROJECT-$COMMIT.bit
	    mv $BITFILE $NEW_BITFILE

	    # archive bitfile
	    mkdir -p $ARCHIVE_DIR/$COMMIT/$PROJECT/reports
	    cp $NEW_BITFILE $ARCHIVE_DIR/$COMMIT 

	    if [ ! -z $BINFILE ] && [ -f $BINFILE ]; then
		NEW_BINFILE=$OUT_DIR/../$PROJECT-$COMMIT.bin	    
	    	mv $BINFILE $NEW_BINFILE
		cp $NEW_BINFILE $ARCHIVE_DIR/$COMMIT
	    fi
	    
	    #copy xml
	    cp -r $OUT_DIR/xml $ARCHIVE_DIR/$COMMIT/$PROJECT/
	    
	    #copy reports
	    cp $OUT_DIR/*/*.rpt $ARCHIVE_DIR/$COMMIT/$PROJECT/reports

	else
	    MESSAGE=`cat $JOURNAL_FILE $WEB_DIR/status-$COMMIT-$PROJECT`
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
	if [ "$(ls -A . 2>/dev/null)" ]; then 
	    tar czf $ZIP_TIMING *
	    ZIP_TIMING="-a $ZIP_TIMING"
	else
	    ZIP_TIMING=
	fi    
	cd $DIR
	cd $UTIL_DIR
	if [ "$(ls -A . 2>/dev/null)" ]; then 
	    tar czf $ZIP_UTIL *
	    ZIP_UTIL="-a $ZIP_UTIL"
	else
	    ZIP_UTIL=
	fi    
	cd $DIR
	printf "$MSG" | mail -s "Completed design flow for $COMMIT" $ZIP_TIMING $ZIP_UTIL atlas-l1calo-efex@cern.ch
    fi

    if [ $ALL_GOOD -eq 1 ]; then
	if [ $AT_LEAST_ONE -eq 1 ]; then
	    # Clean and push on git branch
	    git reset --hard HEAD #--quiet
	    git clean -xdf #--quiet
	    git checkout $TO_BRANCH #--quiet
	    git merge --no-ff -m "Merge $FROM_BRANCH ($COMMIT) into $TO_BRANCH after successful automatic test" -m "$GIT_MESSAGE" $FROM_BRANCH #--quiet
	    git push origin $TO_BRANCH #--quiet 2>&1 > /dev/null
	    cd $DIR
	    echo "" >> doxygen/doxygen.conf
	    echo -e "\nPROJECT_NUMBER = $COMMIT" >> doxygen/doxygen.conf
	    rm -rf ../Doc
	    mkdir -p ../Doc/html
	    
	    # Doxygen
	    /usr/bin/doxygen doxygen/doxygen.conf 2>&1 > ../Doc/html/doxygen-$COMMIT.log
	    rm -r $WEB_DIR/../doc/*
	    cp -r ../Doc/html/* $WEB_DIR/../doc/
	else
	    echo [AutoLaunchRun] All project were skipped, will not commit to $TO_BRANCH or generate Doxygen. 
	fi
    else
	echo [AutoLaunchRun] Errors were encountered, will not commit to $TO_BRANCH or generate Doxygen. 
    fi
else
    echo [AutoLaunchRun] Repository up to date on $FROM_BRANCH branch at `git log --format=%h -1` 
fi
rm -f $LOCK
cd $OLD_DIR

