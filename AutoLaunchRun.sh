#!/bin/bash
if [ "$#" -lt 2 ]; then  
    echo "Usage $0 <repository path> <source branch> <target branch> <tag number> [revision dir] [web dir]"
    echo
    exit -1
fi

DIR=$1
FROM_BRANCH=$2
TO_BRANCH=$3
TAG_NUMBER=$4
REVISION_DIR=/mnt/vd/eFEX-revision/
WEB_DIR=/eos/user/e/efex/www/
if [ "$#" -gt 4 ]; then  
    REVISION_DIR=$5
fi
if [ "$#" -gt 5 ]; then  
    WEB_DIR=$6
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
touch $LOCK

ARCHIVE_DIR=$WEB_DIR/firmware
OLD_DIR=`pwd`
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $DIR
echo "repo: $DIR, from: $FROM_BRANCH to: $TO_BRANCH Tag: $TAG_NUMBER, rev $REVISION_DIR, web $WEB_DIR"
git submodule init
git submodule update
git clean -xdf
git reset --hard HEAD
echo [AutoLaunchRun] Checking out destination branch $TO_BRANCH ...
git checkout $TO_BRANCH
git fetch
ALL_GOOD=1
AT_LEAST_ONE=0

declare -A PROJ_COMM
for PR in `ls ./Top`
do
    cd ./Top/$PR
    PROJ_COMM[$PR]=$(git log --format=%h -1 -- $(cat ./list/*) .)
    cd -
done

echo [AutoLaunchRun] Checking out source branch $FROM_BRANCH ...
git checkout $FROM_BRANCH
echo [AutoLaunchRun] Pulling ...
git pull
echo [AutoLaunchRun] Merginging $TO_BRANCH into $FROM_BRANCH before automatic workflow...
git merge -m "Merging $TO_BRANCH into $FROM_BRANCH before automatic workflow" $TO_BRANCH
if [ $? -eq 0 ]; then
    echo [AutoLaunchRun] Merge was successful
    COMMIT=`git describe --always --match v*`
    echo [AutoLaunchRun] Project is now at $COMMIT on $FROM_BRANCH
    TIME_DIR=$REVISION_DIR/$COMMIT/timing
    UTIL_DIR=$REVISION_DIR/$COMMIT/utilization
    mkdir -p $TIME_DIR
    mkdir -p $UTIL_DIR
    NJOBS=`/usr/bin/nproc`
    
    echo [AutoLaunchRun] Looping over projects...
    for PROJECT in `ls ./Top`
    do
	cd ./Top/$PROJECT
	if [ "$(git log --format=%h -1 -- $(cat ./list/* ) .)" == ${PROJ_COMM[$PROJECT]} ]; then
	    cd - > /dev/null
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
	echo "Project: $PROJECT ($COMMIT) from branch $FROM_BRANCH is preparing to run with $NJOBS jobs..." > $WEB_DIR/status-$COMMIT-$PROJECT
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
	    echo [AutoLaunchRun] Found bitfile $BITFILE
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
		echo [AutoLaunchRun] Found binfile $BINFILE
		NEW_BINFILE=$OUT_DIR/../$PROJECT-$COMMIT.bin	    
	    	mv $BINFILE $NEW_BINFILE
		cp $NEW_BINFILE $ARCHIVE_DIR/$COMMIT
	    fi
	    
	    echo [AutoLaunchRun] Copyin xml...
	    cp -r $OUT_DIR/xml $ARCHIVE_DIR/$COMMIT/$PROJECT/
	    
	    echo [AutoLaunchRun] Copyin reports...
	    cp $OUT_DIR/*/*.rpt $ARCHIVE_DIR/$COMMIT/$PROJECT/reports

	else
	    echo "[AutoLaunchRun] Error in design flow for $PROJECT ($COMMIT)"
	    MESSAGE=`cat $JOURNAL_FILE $WEB_DIR/status-$COMMIT-$PROJECT`
	    printf $MESSAGE  | mail -s "Error in design flow for $PROJECT ($COMMIT)" -a $LOG_FILE atlas-l1calo-efex@cern.ch
	    ALL_GOOD=0
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
	echo [AutoLaunchRun] Resetting and cleaning...
	git reset --hard HEAD
	git clean -xdf
	echo [AutoLaunchRun] Pushing $FROM_BRANCH 
	git push origin $FROM_BRANCH

	if [ $AT_LEAST_ONE -eq 1 ]; then
	    echo [AutoLaunchRun] Tagging aws$TAG_NUMBER and pushing...
	    git tag aws$TAG_NUMBER -m "Automatic tag ($TAG_NUMBER) after successful automatic test" -m "$GIT_MESSAGE"
	    git push origin aws$TAG_NUMBER
	    cd $DIR
	    echo "" >> doxygen/doxygen.conf
	    echo -e "\nPROJECT_NUMBER = $COMMIT" >> doxygen/doxygen.conf
	    rm -rf ../Doc
	    mkdir -p ../Doc/html
	    
	    echo [AutoLaunchRun] Launching doxygen...
	    aws$TAG_NUMBER
	    /usr/bin/doxygen doxygen/doxygen.conf 2>&1 > ../Doc/html/doxygen-$COMMIT.log
	    rm -r $WEB_DIR/../doc/*
	    cp -r ../Doc/html/* $WEB_DIR/../doc/
	    echo [AutoLaunchRun] Automatic workflow successful
	    RET_VAL=0
	else
	    echo [AutoLaunchRun] No errors encountered but all projects were skipped, will not tag nor generate Doxygen. 
	    RET_VAL=1
	fi
    else
	echo [AutoLaunchRun] Errors were encountered, will not tag nor generate Doxygen. 
	RET_VAL=2
    fi
else
    echo [AutoLaunchRun] Impossible to merge $TO_BRANCH into $FROM_BRANCH aborting...
    RET_VAL=3
fi
rm -f $LOCK
cd $OLD_DIR
exit $RET_VAL
