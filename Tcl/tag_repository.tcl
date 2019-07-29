set Name LaunchRuns
if { $::argc eq 0 } {
    puts "USAGE: $::argv0 <merge request> \[version level\]"
    exit 1
} else {
    set merge_request [lindex $argv 0]
    if { $::argc > 1 } {
	set version_level [lindex $argv 1]
    } else {
	set version_level 0
    }
}
set old_path [pwd]
set path [file dirname [info script]]
cd $path
source ./hog.tcl
cd ../../

set tags [TagRepository $merge_request $version_level]
set old_tag [lindex $tags 0]
set new_tag [lindex $tags 1]
exec export HOG_OLD_TAG=$old_tag
exec export HOG_NEW_TAG=$new_tag
Info tag_repository 1 "Environment varibles exported: HOG_OLD_TAG=$old_tag and HOG_NEW_TAG=$new_tag"

cd $old_path
