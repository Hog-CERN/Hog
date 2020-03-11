#!/usr/bin/env tclsh
if {$argc != 0} {
    puts "Script to copy project files and documentation from \$HOG_UNOFFICIAL_BIN_EOS_PATH to \$HOG_OFFICIAL_BIN_EOS_PATH \n"
    puts "Usage: vivado -mode batch -notrace -source ./Hog/Tcl/copy_to_eos.tcl\n"
    exit 1
}

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
            Msg Info "Copying $f into $official/$tag/$f\_$tag..."
            exec -ignorestderr eos cp -r $unofficial/$current_sha/$f $official/$tag/$f\_$tag           
        }

        set wild_card $unofficial/$current_sha/Doc
        set status [catch {exec eos ls $wild_card} doc_folder]

        if {$status == 0} {
            Msg Info "Updating official doxygen documentation in $official/Doc"
            exec eos mkdir -p $official/Doc
            exec -ignorestderr eos cp -r $unofficial/$current_sha/Doc/* $official/Doc
        }
    } else {
        Msg Error "Could not find anything useful using $wild_card."
    }
}

cd $old_path
