#!/usr/bin/env tclsh
#parsing command options
if {[catch {package require cmdline} ERROR]} {
	puts "$ERROR\n If you are running this script on tclsh, you can fix this by installing 'tcllib'" 
	return
}
set parameters {
}

set usage   "Script to copy project files and documentation from \$HOG_UNOFFICIAL_BIN_EOS_PATH to \$HOG_OFFICIAL_BIN_EOS_PATH \nUsage: $argv0 <hog official eos path> <hog unofficial eos path> <tag> <commit short SHA>\n"


set old_path [pwd]
set path [file dirname [info script]]
cd $path
source ./hog.tcl
if {[catch {array set options [cmdline::getoptions ::argv $parameters $usage]}] || $argc != 4} {
    Msg Info [cmdline::usage $parameters $usage]
	cd $old_path
    exit 1
}
lassign $argv official unofficial tag current_sha

cd ../../
Msg Info "Evaluating git describe..."
set describe [exec git describe --always --tags --long]
Msg Info "Git describe: $describe"


lassign [ExtractVersionFromTag $tag] M m p mr

if {$mr == -1} {
    set wild_card $unofficial/$current_sha/
    lassign [eos "ls $wild_card"] status folders

    if {$status == 0} {
        Msg Info "Found these files using $wild_card: $folders"
        set new_dir $official/$tag
        Msg Info "Copying $wild_card into $official/$new_dir"
        eos "cp $wild_card $official" 5
        eos "mv $official/$current_sha $official/$new_dir" 5
        # eos "mkdir -p $new_dir" 5
        # puts "eos mkdir -p $new_dir"
        puts "eos cp $wild_card $official"
        puts "eos mv $official/$current_sha $official/$new_dir"

        # f Loop over projects in repository
        foreach f $folders {
            set new_folder [string range $f 0 [expr {[string last "-git" $f]}]]
            if { $new_folder != ""} {
                Msg Info "Renaming $f into $new_folder" 
                eos "mv $official/$new_dir/$f $official/$new_dir/$new_folder" 5
                lassign [eos "ls $official/$new_dir/$new_folder"] sub_status sub_folders
                foreach fp $sub_folders {
                    set new_file [string range $fp 0 [expr {[string last "-git" $fp]}]]
                    set extension [string range $fp [expr {[string last "." $fp]} + 1] end]
                    if {$new_file != ""} {
                        Msg Info "Renaming file $fp into $new_file.$extension"
                        eos "mv $official/$new_dir/$new_folder/$fp $official/$new_dir/$new_folder/$new_file.$extension" 5
                    }
                }
            } 
            # Msg Info "Copying $f into $official/$tag/$new_folder\_$tag..."
            # # eos "mkdir -p $official/$tag/$new_folder$tag"
            # puts "eos mkdir -p $official/$tag/$new_folder$tag"
            # foreach fp $f {
            #     puts $fp
            #     set new_fp [string range $fp 0 [expr {[string last "-git" $fp]} - 1]]
            #     set extension [string range $fp [expr {[string last "." $fp]} + 1] end]
            #     if {[string last "-git" $fp] != -1} {
            #         Msg Info "eos cp -r $unofficial/$current_sha/$fp $official/$tag/$new_folder$tag/$new_fp.$extension"
            #         # eos "cp -r $unofficial/$current_sha/$fp $official/$tag/$new_folder\_$tag/$new_fp.$extension" 5 
            #     } else {
            #         Msg Info "eos cp -r $unofficial/$current_sha/$fp/* $official/$tag/$new_folder$tag/$fp"
            #         # eos "cp -r $unofficial/$current_sha/$fp/* $official/$tag/$" 5 
            #     }

            }
        }

        set wild_card $unofficial/$current_sha/Doc*
        lassign [eos "ls $wild_card"] status doc_folder

        if {$status == 0} {
            Msg Info "Updating official doxygen documentation in $official/Doc"
            eos "mkdir -p $official/Doc" 5
            eos "cp -r $unofficial/$current_sha/Doc*/* $official/Doc/" 5
        }
    } else {
        Msg Error "Could not find anything useful using $wild_card."
    }
}

cd $old_path
