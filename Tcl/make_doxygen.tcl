#!/usr/bin/env tclsh
set Name make_doxygen

set old_path [pwd]
set path [file dirname [info script]]
cd $path
source ./hog.tcl
cd ../../

set tags [TagRepository 0 0]
set version [lindex $tags 0]
Msg Info "Creating doxygen documentation for tag $version"


# Run doxygen
set doxygen_conf "./doxygen/doxygen.conf"
if {[file exists $doxygen_conf] == 0 } {
    # Using Default hog template
    set doxygen_conf "./Hog/Templates/doxygen.conf"
    Msg Info "Running doxygen with ./Hog/Templates/doxygen.conf..."
} else {
    Msg Info "Running doxygen with $doxygen_conf..."
}

if {[DoxygenVersion 1.8.13]} {
    set outfile [open $doxygen_conf a]
    puts $outfile \nPROJECT_NUMBER=$version
    close $outfile
    exec -ignorestderr doxygen $doxygen_conf
}


# Copy documentation to eos
if {[info exists env(HOG_UNOFFICIAL_BIN_EOS_PATH)]} {
    set output_dir $env(HOG_UNOFFICIAL_BIN_EOS_PATH)/$env(CI_COMMIT_SHORT_SHA)/Doc
    Msg Info "Creating $output_dir"
    exec eos mkdir -p $output_dir
    
    if {[file exists ./Doc/html]} {
        Msg Info "Copying doxygen files..."
        exec -ignorestderr eos cp -r ./Doc/html/* $output_dir
    } else {
        Msg Warning "Doxygen documentation not found in Doc/html/"
    }
} else {
    Msg Error "Environmental variable HOG_UNOFFICIAL_BIN_EOS_PATH not set. Doxygen documentation cannot be copied to eos."
}

cd $old_path
