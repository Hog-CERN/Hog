#!/usr/bin/env tclsh
set Name tag_repository
if { $::argc eq 0 } {
    puts "USAGE: $::argv0 <merge request> \[version level\] \[Hog?\]"
    exit 1
} else {
    set merge_request [lindex $argv 0]
    if { $::argc > 1 } {
    set version_level [lindex $argv 1]
    } else {
    set version_level 0
    }
	if { $::argc > 2 } {
	set TaggingPath ../
	} else {
	set TaggingPath ../..
	}
}
set old_path [pwd]
set path [file dirname [info script]]
cd $path
source ./hog.tcl
cd $TaggingPath

Msg Info "Evaluating git describe..."
set describe [exec git describe --always --tags --long]
Msg Info "Git describe: $describe"

set tags [TagRepository $merge_request $version_level]
set old_tag [lindex $tags 0]
set new_tag [lindex $tags 1]
Msg Info "Old tag was: $old_tag and new tag is: $new_tag"

if {$version_level >= 3 && $::argc < 2} {
    set official $env(HOG_OFFICIAL_BIN_EOS_PATH)
    set unofficial $env(HOG_UNOFFICIAL_BIN_EOS_PATH)

    set wild_card $unofficial/*$describe*
    
    set status [catch {exec eos ls $wild_card} folders]
    if {$status == 0} {
        Msg Info "Found these files using $wild_card: $folders"
        Msg Info "Copying files to official directory..."
        set new_dir $official/$new_tag

        Msg Info "Creating $new_dir"
        exec eos mkdir -p $new_dir

	# f Loop over projects in repository
        foreach f $folders {
            set dst $new_dir/[regsub "(.*)\_$describe\(.*\)" $f "\\1"]
            Msg Info "Copying $f into $dst..."
            exec eos mkdir -p $dst
            exec -ignorestderr eos cp -r $unofficial/$f/* $dst/
            
            Msg Info "Renaming bit and bin files..."
            catch {exec eos ls $dst/*$describe.*} new_files
	    Msg Info "Found these binary files: $new_files"
            foreach ff $new_files {
                set old_name $dst/$ff
		set ext [file extension $ff]
                set new_name [regsub "(.*)\-$describe\(.*\)" $old_name "\\1-$new_tag$ext"]
                Msg Info "Moving $old_name into $new_name..."
                exec eos mv $old_name $new_name
            }                                                               
        }    
} else {
    Msg Warning "Could not find anything useful using $wild_card."
}
    Msg Info "New official version $new_tag created successfully."
}

cd $old_path
