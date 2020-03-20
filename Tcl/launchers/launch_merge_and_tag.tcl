#!/usr/bin/env tclsh

#parsing command options

set old_path [pwd]
set TclPath [file dirname [info script]]/..
source $TclPath/hog.tcl

if {[catch {package require cmdline} ERROR]} {
	Msg Error "$ERROR\n If you are running this script on tclsh, you can fix this by installing 'tcllib'" 
	return
}

set parameters {
    {Hog    "Runs merge and tag of Hog repository. Default = off. To be only used by HOG developers!!!"}
    {merged "Set this flag to tag the new version after marging the merge_request. Default = off"}
	{mr_par.arg "" "Merge request parameters in JSON format. Ignored if -merged is set"}
	{mr_id.arg 0 "Merge request ID. Ignored if -merged is set"}
	{push.arg "" "Optional: git branch for push"}
}

set usage "- CI script that merges your branch with master and creates a new tag\n USAGE: $::argv0 \[OPTIONS\] <git branch> \n. Options:"

if {[catch {array set options [cmdline::getoptions ::argv $parameters $usage]}] } {
    Msg Info [cmdline::usage $parameters $usage]
	cd $old_path
	return
}




if { $options(Hog) == 0 } {
	set onHOG ""
 } else {
	Msg Info "You are merging and tagging Hog (only for HOG developers!!!)"
	set onHOG "-Hog"
 }

set VERSION 0
set merge_request_number 0
if {$options(merged) == 0} {
	if {$options(mr_par) ==""} {
		Msg Error "Merge request parameters not provided! You must provide them using \"-mr_par \$MR_PARAMETERS\" flag"
		cd $old_path
		exit 1
	}
	if {$options(mr_id) ==""} {
		Msg Error "Merge request id not provided! You must provide them using \"-mr_id \$MR_ID\" flag"
		cd $old_path
		exit 1
	}
	set WIP [ParseJSON  $options(mr_par) "work_in_progress"]
	set MERGE_STATUS [ParseJSON  $options(mr_par) "merge_status"]
	set DESCRIPTION [ParseJSON  $options(mr_par) "description"]
	Msg Info "WIP: ${WIP},  Merge Request Status: ${MERGE_STATUS}   Description: ${DESCRIPTION}"
	if {[lsearch $DESCRIPTION "*MINOR_VERSION*" ] >= 0} {
		set VERSION 1
	}
	if {[lsearch $DESCRIPTION "*MAJOR_VERSION*" ] >= 0} {
		set VERSION 2
	} 
	
	set merge_request_number $options(mr_id) 
} else {
	set VERSION 3
}

Msg Info "Version Level $VERSION"
if {[catch {exec git merge --no-commit origin/master} MRG]} {
	Msg Error "Branch is outdated, please merge the latest changes from master with:\n git fetch && git merge origin/master\n"
	exit 1	
}

Msg Info [exec $TclPath/tag_repository.tcl -level $VERSION $onHOG $merge_request_number]
if {$options(push)!= ""} {
	if {[catch {exec git push origin $options(push)} TMP]} {
		Msg Warning $TMP
	} else {
		Msg Info $TMP
	}
	if {[catch {exec git push --tags origin $options(push)} TMP]} {
		Msg Warning $TMP
	} else {
		Msg Info $TMP
	}
}
