set NAME "Post_Bitstream"
set old_path [file normalize [pwd]]
set path [file normalize [file dirname [info script]]]
cd $path
regexp {(.*)\.tcl} $argv0 old_file old_file
set src_file "./$old_file.bit"
source functions.tcl

Info $NAME 0 "Evaluating firmware date and possibly git commit hash..."

if { [exec git status --untracked-files=no  --porcelain] eq "" } {
    Info $NAME 1 "Git working directory [pwd] clean."
    set commit [GetHash ALL ./]
    set clean "yes"
} else {
    Warning $NAME 1 "Git working directory [pwd] not clean."
    set commit "00000000"    
    set clean "no"
}

# IPBUS submodule
cd "../eFEX-ipbus"
if { [exec git status --untracked-files=no  --porcelain] eq "" } {
    Info $NAME 2 "IPBus Git working directory [pwd] clean."
    set ipb_clean "yes"
} else {
    Warning $NAME 2 "IPBus Git working directory [pwd] not clean"
    set ipb_clean "no"
}

cd $path
if { $clean eq "yes" &&  $ipb_clean eq "yes" } { 
    set new_dir "$commit"
} else {
    Error $NAME 3 "Repository not clean"
}

#Copy file in the revision archive and push the repository to verified branch
# check if timing violations are met

set proj_file [get_property parent.project_path [current_project]]
set proj_dir [file normalize [file dirname $proj_file]]
set proj_name [file rootname [file tail $proj_file]]
set dir "$proj_dir/Runs/$new_dir"
Info $NAME 3 "Creating directory $dir..."
file mkdir $dir

Info $NAME 4 "Copying $old_path to $dir..."
file copy -force $old_path $dir

cd $old_path
Info $NAME 5 "All done."
