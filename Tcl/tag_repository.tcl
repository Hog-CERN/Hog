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
Info $Name 1 "Old tag was: $old_tag and new tag is: $new_tag"

set official $env(HOG_OFFICIAL_BIN_EOS_PATH)
set unofficial $env(HOG_UNOFFICIAL_BIN_EOS_PATH)
set use_doxygen $env(HOG_USE_DOXYGEN)

if {$version_level >= 3} {
    # Run doxygen
    set doxygen_conf "./doxygen/doxygen.conf"

    if {$use_doxygen == 1} {
	if {[file exists $doxygen_conf] & [DoxygenVersion 1.8.13]} {
	    Info $Name 2 "Running doxygen with $doxygen_conf..."
	    set outfile [open $doxygen_conf a]
	    puts $outfile \nPROJECT_NUMBER=$new_tag
	    close $outfile
	    exec -ignorestderr doxygen $doxygen_conf
	} else {
	    Info $Name 2 "Could not find $doxygen_conf or Doxygen version is older than 1.8.13. Will not run doxygen."
	}
    }
    set wild_card $unofficial/*$old_tag*
    set status [catch {exec eos ls $wild_card} folders]
    if {$status == 0} {
	Info $Name 3 "Found these files using $wild_card: $folders"
	Info $Name 4 "Copying files to official directory..."
	set new_dir $official/$new_tag
	Info $Name 4 "Creating $new_dir"
	exec eos mkdir $new_dir

	# Copying doxygen documentation if files were created
	if {[file exists ../Doc/html]} {
	    set dox_dir $official/$new_tag/doc
	    Info $Name 4 "Creating doxygen dir $dox_dir..."
	    exec eos mkdir $dox_dir
	    Info $Name 4 "Copying doxygen files..."
	    exec -ignorestderr eos cp -r ../Doc/html/* $dox_dir
	}
	foreach f $folders {
	    set dst $new_dir/[regsub "(.*)_$old_tag\(.*\)" $f "\\1\\2"]
	    Info $Name 4 "Copying $f into $dst..."
	    exec eos mkdir $dst
	    exec -ignorestderr eos cp -r $unofficial/$f/* $dst/
	    
	    Info $Name 5 "Ranaming bit and bin files..."
	    catch {exec eos ls $dst/*$old_tag.*} new_files
	    foreach ff $new_files {
		set old_name $dst/$ff
		set new_name [regsub "(.*)$old_tag\(.*\)" $old_name "\\1$new_tag\\2"]
		Info $Name 6 "Moving $old_name into $new_name..."
		exec eos mv $old_name $new_name
	    }
	}

    # Delete unofficial tags
    Info $Name 2 "Looking for unofficial tags to delete for official version $new_tag..."
    set res [ catch {exec git tag {*}"-l b*$new_tag*"} tags_to_delete]
    set number_of_tags [llength $tags_to_delete]
    Info $Name 2 "Found $number_of_tags tags to delete: $tags_to_delete"
    if {$number_of_tags > 0} {
	set res [catch {exec git push origin {*}"-d $tags_to_delete"} deleted_tags]
	set res [catch {exec git tag {*}"-d $tags_to_delete"} loc_deleted_tags]	
	Info $Name 2 "Tags deleted. Remote response:\n $deleted_tags"
	Info $Name 2 "Local response: \n response\n $loc_deleted_tags"	
    }

	
    } else {
	Warning $Name 5 "Could not find anything useful using $wild_card."
    }
    Info $Name 6 "New official version $new_tag created successfully."
}

cd $old_path
