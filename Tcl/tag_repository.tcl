#!/usr/bin/env tclsh

set Name tag_repository
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
Msg Info "Old tag was: $old_tag and new tag is: $new_tag"


if {$version_level >= 3} {
    set official $env(HOG_OFFICIAL_BIN_EOS_PATH)
    set unofficial $env(HOG_UNOFFICIAL_BIN_EOS_PATH)
    set wild_card $unofficial/*$old_tag*
    puts $env(HOG_USE_DOXYGEN) 
    if {[info exists env(HOG_USE_DOXYGEN)]} {
        set use_doxygen $env(HOG_USE_DOXYGEN)
    
        # Run doxygen
        set doxygen_conf "./doxygen/doxygen.conf"
        puts $doxygen_conf
        if {$use_doxygen == 1} {
            if {[file exists $doxygen_conf] & [DoxygenVersion 1.8.13]} {
                Msg Info "Running doxygen with $doxygen_conf..."
                set outfile [open $doxygen_conf a]
                puts $outfile \nPROJECT_NUMBER=$new_tag
                close $outfile
                exec -ignorestderr doxygen $doxygen_conf
            } else {
                Msg Info "Running doxygen with ./Hog/doxygen.conf..."
                set outfile [open "./Hog/doxygen.conf" a]
                puts $outfile \nPROJECT_NUMBER=$new_tag
                close $outfile
                exec -ignorestderr doxygen "./Hog/doxygen.conf"
            }
        }
        set status [catch {exec eos ls $wild_card} folders]
        if {$status == 0} {
        Msg Info "Found these files using $wild_card: $folders"
        Msg Info "Copying files to official directory..."
        set new_dir $official/$new_tag

        Msg Info "Creating $new_dir"
        exec eos mkdir -p $new_dir


        # Copying doxygen documentation if files were created
        pwd
        if {[file exists ./Doc/html]} {
            set dox_dir $official/$new_tag/doc
            Msg Info "Creating doxygen dir $dox_dir..."
            exec eos mkdir -p $dox_dir
            Msg Info "Copying doxygen files..."
            exec -ignorestderr eos cp -r ./Doc/html/* $dox_dir
        }
        foreach f $folders {
            set dst $new_dir/[regsub "(.*)_$old_tag\(.*\)" $f "\\1\\2"]
            Msg Info "Copying $f into $dst..."
            exec eos mkdir -p $dst
            exec -ignorestderr eos cp -r $unofficial/$f/* $dst/
            
            Msg Info "Ranaming bit and bin files..."
            catch {exec eos ls $dst/*$old_tag.*} new_files
            foreach ff $new_files {
            set old_name $dst/$ff
            set new_name [regsub "(.*)$old_tag\(.*\)" $old_name "\\1$new_tag\\2"]
            Msg Info "Moving $old_name into $new_name..."
            exec eos mv $old_name $new_name
            }                                                               
        }
    }
    # Delete unofficial tags
    Msg Info "Looking for unofficial tags to delete for official version $new_tag..."
    set res [ catch {exec git tag {*}"-l b*$new_tag*"} tags_to_delete]
    set number_of_tags [llength $tags_to_delete]
    Msg Info "Found $number_of_tags tags to delete: $tags_to_delete"
    if {$number_of_tags > 0} {
    set res [catch {exec git push origin {*}"-d $tags_to_delete"} deleted_tags]
    set res [catch {exec git tag {*}"-d $tags_to_delete"} loc_deleted_tags] 
    Msg Info "Tags deleted. Remote response:\n $deleted_tags"
    Msg Info "Local response: \n response\n $loc_deleted_tags"  
    }

    
    } else {
    Msg Warning "Could not find anything useful using $wild_card."
    }
    Msg Info "New official version $new_tag created successfully."
}

cd $old_path
