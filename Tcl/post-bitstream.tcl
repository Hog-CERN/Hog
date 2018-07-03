set NAME "Post_Bitstream"
set old_path [pwd]
set tcl_path [file dirname [info script]]
source $tcl_path/hog.tcl

# Go to repository path
cd ../../../../ 

set proj_file [get_property parent.project_path [current_project]]
set proj_dir [file normalize [file dirname $proj_file]]
set proj_name [file rootname [file tail $proj_file]]

Info $NAME 0 "Evaluating git describe..."
# look for bit and bin file
# rename them with git describe and copy them close to $old_path/..
# some commands if [file exists ./Top/$proj_name/xml/xml.lst] {
if { [exec git status --untracked-files=no  --porcelain] eq "" } {
    Info $NAME 1 "Git working directory [pwd] clean."
    lassign [GetVer ALL ./] version commit official
    set clean "yes"
} else {
    if {$buypass_commit == 1} {
	Info $NAME 1 "Buypassing commit check."
	lassign [GetVer ALL ./] version commit official
	set clean "yes"
    } else {
	Warning $NAME 1 "Git working directory [pwd] not clean, commit hash, official, and version will be set to 0."
	set official "00000000"
	set commit   "0000000"
	set version  "00000000"    
	set clean    "no"
    }
}

