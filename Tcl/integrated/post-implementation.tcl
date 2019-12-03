set NAME "Post_Implementation"
set old_path [pwd]
set tcl_path [file normalize "[file dirname [info script]]/.."]
source $tcl_path/hog.tcl

set run_path [file normalize "$old_path/.."]

Msg Info "All done."
