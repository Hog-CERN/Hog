set NAME "Post_Implementation"
set old_path [pwd]
set tcl_path [file dirname [info script]]
source $tcl_path/hog.tcl

set run_path [file normalize "$old_path/.."]

Info $NAME 8 "All done."
