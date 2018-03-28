if {[get_param synth.vivado.isSynthRun]} {
    set NAME "Post_Synthesis"
} else {
    set NAME "Post_Implementation"
}
set old_path [file normalize [pwd]]
set path [file normalize [file dirname [info script]]]
cd $path
source functions.tcl
if [file exists "$old_path/../commit-hash" ] {
    Info $NAME 0 "Getting git commit hash from file..."
    set infile [open "$old_path/../commit-hash" r]
    set commit [gets $infile line]
    set clean "yes"
} else {
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
    set clock_seconds [clock seconds]
    set date [clock format $clock_seconds  -format {%d-%m-%Y}]
    set timee [clock format $clock_seconds -format {%H-%M-%S}]
    set new_dir "$date\_$timee"
}

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
