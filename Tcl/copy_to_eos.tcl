#!/usr/bin/env tclsh
set old_path [pwd]
set path [file dirname [info script]]
cd $path
source ./hog.tcl
cd ../../

Msg Info "Evaluating git describe..."
set describe [exec git describe --always --tags --long]
Msg Info "Git describe: $describe"

set tag $env(CI_COMMIT_TAG)
lassign [ExtractVersionFromTag $tag] M m p n mr

if {$mr == -1} {
    set official $env(HOG_OFFICIAL_BIN_EOS_PATH)
    set unofficial $env(HOG_UNOFFICIAL_BIN_EOS_PATH)
    set current_sha $env(CI_COMMIT_SHORT_SHA)
    set wild_card $unofficial/$current_sha/
    
    set status [catch {exec eos ls $wild_card} folders]
    if {$status == 0} {
        Msg Info "Found these files using $wild_card: $folders"
        Msg Info "Copying files to official directory..."
        set new_dir $official/$tag

        Msg Info "Creating $new_dir"
        exec eos mkdir -p $new_dir
        
        # f Loop over projects in repository
        foreach f $folders {
            set dst $new_dir/[regsub "(.*)\_$describe\(.*\)" $f "\\1"]
            Msg Info "Copying $f into $dst..."
            exec eos mkdir -p $dst
            exec -ignorestderr eos cp -r $unofficial/$current_sha/$f/* $dst/
            
            Msg Info "Renaming bit and bin files..."
            catch {exec eos ls $dst/*$describe.*} new_files
            Msg Info "Found these binary files: $new_files"
            foreach ff $new_files {
                set old_name $dst/$ff
                set ext [file extension $ff]
                set new_name [regsub "(.*)\-$describe\(.*\)" $old_name "\\1-$tag$ext"]
                Msg Info "Moving $old_name into $new_name..."
                exec eos mv $old_name $new_name
            }

            if {[file exists $unofficial/$current_sha/Doc]} {
                Msg Info "Updating official doxygen documentation in $official/Doc"
                exec eos mkdir -p $official/Doc
                exec -ignorestderr eos cp -r $unofficial/$current_sha/Doc/* $official/Doc
            }            
        }    
    } else {
        Msg Error "Could not find anything useful using $wild_card."
    }
}

cd $old_path
