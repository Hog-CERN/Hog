#!/usr/bin/env tclsh
set Name make_doxygen

set old_path [pwd]
set path [file dirname [info script]]
cd $path
source ./hog.tcl
cd ../../

if [catch {exec git tag --sort=-creatordate} last_tag] {
    Msg Error "No Hog version tags found in this repository."
    } else {
    set tags [split $last_tag "\n"]
    set tag [lindex $tags 0]
    lassign [ExtractVersionFromTag $tag] M m p n mr
    set version v$M.$m.$p
    Msg Info "Creating doxygen documentation for tag $version"

}

# Run doxygen
set doxygen_conf "./doxygen/doxygen.conf"
if {[file exists $doxygen_conf] & [DoxygenVersion 1.8.13]} {
    set outfile [open $doxygen_conf a]
    puts $outfile \nPROJECT_NUMBER=$version
    close $outfile
    Msg Info "Running doxygen with $doxygen_conf..."
    exec -ignorestderr doxygen $doxygen_conf
} elseif {[DoxygenVersion 1.8.13]} {
    set outfile [open "./Hog/doxygen.conf" a]
    puts $outfile \nPROJECT_NUMBER=$version
    close $outfile
    Msg Info "Running doxygen with ./Hog/doxygen.conf..."
    exec -ignorestderr doxygen "./Hog/doxygen.conf"
}


# Copy documentation to eos
if {[info exists env(HOG_OFFICIAL_BIN_EOS_PATH)]} {
    set official $env(HOG_OFFICIAL_BIN_EOS_PATH)
    set new_dir $official/$version
    Msg Info "Creating $new_dir"
    exec eos mkdir -p $new_dir
    if {[file exists ./Doc/html]} {
        set dox_dir $official/$version/doc
        Msg Info "Creating doxygen dir $dox_dir..."
        exec eos mkdir -p $dox_dir
        Msg Info "Copying doxygen files..."
        exec -ignorestderr eos cp -r ./Doc/html/* $dox_dir
    }
}
cd $old_path