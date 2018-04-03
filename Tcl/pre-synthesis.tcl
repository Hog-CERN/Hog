set NAME "Pre_Synthesis"
if [file exists ../buypass_commit] {
    set buypass_commit 1
} else  {
    set buypass_commit 0
}
if [file exists ../no_time] {
    set no_time 1
} else  {
    set no_time 0
}
set old_path [pwd]
set tcl_path [file dirname [info script]]
source $tcl_path/hog.tcl

# Go to repository path
cd ../../../../ 

set proj_file [get_property parent.project_path [current_project]]
set proj_dir [file normalize [file dirname $proj_file]]
set proj_name [file rootname [file tail $proj_file]]

Info $NAME 0 "Evaluating firmware date and, possibly, git commit hash..."

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

lassign [GetVer ./Top/$proj_name/ ./Top/$proj_name/] top_ver top_hash dummy

# Read list files
set libs ""
set vers ""
set hashes ""
set list_files [glob  "./Top/$proj_name/list/*.src"]
foreach f $list_files {
    set name [file rootname [file tail $f]]
    lassign [GetVer  $f ./Top/$proj_name/] ver hash dummy
    Info $NAME 1 "Found source file $f, version: $ver commit SHA: $hash"
    lappend libs $name
    lappend vers $ver
    lappend hashes $hash
}

# Submodules
set subs ""
set subs_hashes ""
set sub_files [glob  "./Top/$proj_name/list/*.sub"]
foreach f $sub_files {
    set sub_dir [file rootname [file tail $f]]
    if [file exists ./$sub_dir] {
	cd "./$sub_dir"
	lappend subs $sub_dir
	if { [exec git status --untracked-files=no  --porcelain] eq "" } {
	    Info $NAME 2 "$sub_dir submodule clean."
	    lappend subs_hashes [GetHash ALL ./]
	} else {
	    Warning $NAME 2 "$sub_dir submodule not clean, commit hash will be set to 0."
	    lappend subs_hashes "0000000"    
	}
	cd ..
    } else {
	Warning $NAME 2 "$sub_dir submodule not found"
    }
}

# Hog submodule
cd "./Hog"
if { [exec git status --untracked-files=no  --porcelain] eq "" } {
    Info $NAME 2 "Hog submodule [pwd] clean."
    set hog_hash [GetHash ALL ./]
    set hog_clean "yes"
} else {
    Warning $NAME 2 "Hog submodule [pwd] not clean, commit hash will be set to 0."
    # Maybe an error would be better here...
    set hog_hash "0000000"    
    set hog_clean "no"
}

set clock_seconds [clock seconds]
set date [clock format $clock_seconds  -format {%d%m%Y}]
set timee [clock format $clock_seconds -format {00%H%M%S}]
set tt [clock format $clock_seconds -format {%d/%m/%Y at %H:%M:%S}]
if {$no_time == 1} {
    set date  "21041926"
    set timee "00024000"
}


# set global generic varibles
set generic_string "GLOBAL_FWDATE=32'h$date GLOBAL_FWTIME=32'h$timee OFFICIAL=32'h$official GLOBAL_FWHASH=32'h$commit TOP_FWHASH=32'h$top_hash GLOBAL_FWVERSION=32'h$version TOP_FWVERSION=32'h$top_ver HOG_FWHASH=32'h$hog_hash"

#set project specific lists
foreach l $libs v $vers h $hashes {
    set ver "[string toupper $l]_FWVERSION=32'h$v "
    set hash "[string toupper $l]_FWHASH=32'h$h"
    set generic_string "$generic_string $ver $hash"
}

#set project specific sub modules
foreach s $subs h $subs_hashes {
    set hash "[string toupper $s]_FWHASH=32'h$h"
    set generic_string "$generic_string $hash"
}

Info $NAME 4 "Generic String: $generic_string"

set_property generic $generic_string [current_fileset]

Status $NAME 3 " ------------------------- PRE SYNTHESIS -------------------------"
Status $NAME 3 " $tt"
Status $NAME 3 " Firmware date and time: $date, $timee"
Status $NAME 3 " Global SHA: $commit, VER: $version"
Status $NAME 3 " Top SHA: $top_hash, VER: $top_ver"
Status $NAME 3 " Hog SHA: $hog_hash"
Status $NAME 3 " Official reg: $official"
Status $NAME 3 " --- Libraries ---"
foreach l $libs v $vers h $hashes {
    Status $NAME 3 " $l SHA: $h, VER: $v"    
}
Status $NAME 3 " --- Submodules ---"
foreach s $subs sh $subs_hashes {
    Status $NAME 3 " $s SHA: $sh"    
}
Status $NAME 3 " -----------------------------------------------------------------"

cd $old_path
#if {$clean eq "yes" && $ipb_clean eq "yes"} {
#    Info $NAME 5 "Creating certificate file..."
#    set cfile [open ../commit-hash w] 
#    puts $cfile $commit
#    close $cfile
#} else {
#    Info $NAME 5 "Deleting certificate file..."
#    file delete -force ../commit-hash
#}

Info $NAME 6 "All done."
