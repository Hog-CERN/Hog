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

TagRepository $merge_request $version_level

cd $old_path
