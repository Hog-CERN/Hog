#!/usr/bin/env tclsh
if {$argc != 4} {
    puts "Script to copy project files and documentation from \$HOG_UNOFFICIAL_BIN_EOS_PATH to \$HOG_OFFICIAL_BIN_EOS_PATH \n"
    puts "Usage: $argv0 <hog official eos path> <hog unofficial eos path> <tag> <commit short SHA>\n"
    exit 1
}

set old_path [pwd]
set path [file dirname [info script]]
cd $path
source ./hog.tcl

lassign $argv official unofficial tag current_sha

cd ../../
Msg Info "Evaluating git describe..."
set describe [exec git describe --always --tags --long]
Msg Info "Git describe: $describe"


lassign [ExtractVersionFromTag $tag] M m p n mr

if {$mr == -1} {
    set wild_card $unofficial/$current_sha/
    
    lassign [eos "ls $wild_card"] status folders
    
    if {$status == 0} {
        Msg Info "Found these files using $wild_card: $folders"
        Msg Info "Copying files to official directory..."
        set new_dir $official/$tag

        Msg Info "Creating $new_dir"
        eos "mkdir -p $new_dir" 5
        
        # f Loop over projects in repository
        foreach f $folders {
            Msg Info "Copying $f into $official/$tag/$f\_$tag..."
            eos "cp -r $unofficial/$current_sha/$f $official/$tag/$f\_$tag" 5
        }

        set wild_card $unofficial/$current_sha/Doc
        lassign "ls $wild_card"] status doc_folder

        if {$status == 0} {
            Msg Info "Updating official doxygen documentation in $official/Doc"
            eos "mkdir -p $official/Doc" 5
            eos "cp -r $unofficial/$current_sha/Doc/* $official/Doc" 5
        }
    } else {
        Msg Error "Could not find anything useful using $wild_card."
    }
}

cd $old_path
