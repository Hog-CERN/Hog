#!/usr/bin/env tclsh


set old_path [pwd]
set TclPath [file dirname [info script]]/..
source $TclPath/hog.tcl


 if { $::argc < 1 } {
	Msg Info "You are merging and tagging your project.
If you want to merge and tag Hog, please run \"$::argv0 1\"" 
	set onHOG ""
 } else {
	Msg Info "You are merging and tagging Hog.
If you want to merge and tag your project, please run \"$::argv0\"" 
	set onHOG 1
 }

set WIP [ParseJSON  $::env(MR_PARAMETERS) "work_in_progress"]
set MERGE_STATUS [ParseJSON  $::env(MR_PARAMETERS) "merge_status"]
set DESCRIPTION [ParseJSON  $::env(MR_PARAMETERS) "description"]
Msg Info "WIP: ${WIP},  Merge Request Status: ${MERGE_STATUS}   Description: ${DESCRIPTION}"
set VERSION 0

if {[lsearch $DESCRIPTION "*MINOR_VERSION*" ] >= 0} {
	set VERSION 1
}
if {[lsearch $DESCRIPTION "*MAJOR_VERSION*" ] >= 0} {
	set VERSION 2
}

Msg Info "Version Level $VERSION"
exec git merge --no-commit origin/master
puts [exec $TclPath/tag_repository.tcl  $::env(CI_MERGE_REQUEST_IID) $VERSION $onHOG]
catch {exec git push origin $::env(CI_COMMIT_REF_NAME)} TMP
puts $TMP
catch {exec git push --tags origin $::env(CI_COMMIT_REF_NAME)} TMP
puts $TMP
