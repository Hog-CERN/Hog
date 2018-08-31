set NAME "Pre_Synthesis"
if [file exists ../buypass_commit] {
    set buypass_commit 1
} else  {
    set buypass_commit 0
}
if [file exists ../no_time] {
    set real_time 1
} else  {
    set real_time 0
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

# Top project directory
lassign [GetVer ./Top/$proj_name/ ./Top/$proj_name/] top_ver top_hash dummy

# Read list files
set libs ""
set vers ""
set hashes ""
set list_files [glob  -nocomplain "./Top/$proj_name/list/*.src"]
foreach f $list_files {
    set name [file rootname [file tail $f]]
    lassign [GetVer  $f ./Top/$proj_name/] ver hash dummy
    Info $NAME 1 "Found source file $f, version: $ver commit SHA: $hash"
    lappend libs $name
    lappend vers $ver
    lappend hashes $hash
}

# XML
set xml_dst $old_path/../xml
if [file exists ./Top/$proj_name/xml/xml.lst] {
    Info $NAME 2 "XML list file found, using version of listed XMLs"
    # version of xml in list files is used if list file exists
    set xml_target  ./Top/$proj_name/xml/xml.lst
    Info $NAME 3 "Creating XML directory $xml_dst..."
    file mkdir $xml_dst
    lassign [GetVer $xml_target ./Top/$proj_name/] xml_ver xml_hash dummy
    scan [string range $xml_ver 0 1] %x M
    scan [string range $xml_ver 2 3] %x m
    scan [string range $xml_ver 4 7] %x c
    set xml_ver_formatted "$M.$m.$c"
    Info $NAME 4 "Copying xml files to $xml_dst and adding xml version $xml_ver_formatted..."
    CopyXMLsFromListFile $xml_target ./Top/$proj_name $xml_ver_formatted $xml_hash $xml_dst

} elseif [file exists ./Top/$proj_name/xml] {
    Info $NAME 2 "XML list file not found, using version of XML directory"
    # version of the directory if no list file exists
    set xml_target  ./Top/$proj_name/xml
    lassign [GetVer $xml_target ./Top/$proj_name/] xml_ver xml_hash dummy
    file copy -force $xml_target $old_path/..
} else {
    Info $NAME 2 "This project does not have XMLs"
}

# Submodules
set subs ""
set subs_hashes ""
set sub_files [glob -nocomplain "./Top/$proj_name/list/*.sub"]
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
set date [exec git log -1 --format=%cd --date=format:'%d%m%Y']
set timee [exec git log -1 --format=%cd --date=format:'00%H%M%S']
set tt [clock format $clock_seconds -format {%d/%m/%Y at %H:%M:%S}]

if {$real_time == 1} {
    set date [clock format $clock_seconds  -format {%d%m%Y}]
    set timee [clock format $clock_seconds -format {00%H%M%S}]
}


# set global generic varibles
set generic_string "GLOBAL_FWDATE=32'h$date GLOBAL_FWTIME=32'h$timee OFFICIAL=32'h$official GLOBAL_FWHASH=32'h$commit TOP_FWHASH=32'h$top_hash XML_HASH=32'h$xml_hash GLOBAL_FWVERSION=32'h$version TOP_FWVERSION=32'h$top_ver XML_VERSION=32'h$xml_ver HOG_FWHASH=32'h$hog_hash"

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

# writing info into status file
set status_file [open "$old_path/../versions" "w"]

Status $NAME 3 " ------------------------- PRE SYNTHESIS -------------------------"
Status $NAME 3 " $tt"
Status $NAME 3 " Firmware date and time: $date, $timee"
puts $status_file "Date, $date, $timee"
Status $NAME 3 " Global SHA: $commit, VER: $version"
puts $status_file "Global, $commit, $version"
Status $NAME 3 " XML SHA: $top_hash, VER: $top_ver"
puts $status_file "XML, $xml_hash, $xml_ver"
Status $NAME 3 " Top SHA: $top_hash, VER: $top_ver"
puts $status_file "Top, $top_hash, $top_ver"
Status $NAME 3 " Hog SHA: $hog_hash"
puts $status_file "Hog, $hog_hash, 00000000"
Status $NAME 3 " Official reg: $official"
puts $status_file "Official, $official, 00000000"
Status $NAME 3 " --- Libraries ---"
foreach l $libs v $vers h $hashes {
    Status $NAME 3 " $l SHA: $h, VER: $v"    
    puts $status_file "$l, $h, $v"
}
Status $NAME 3 " --- Submodules ---"
foreach s $subs sh $subs_hashes {
    Status $NAME 3 " $s SHA: $sh"
    puts $status_file "$s, $sh, 00000000"    
}
Status $NAME 3 " -----------------------------------------------------------------"
close $status_file


cd $old_path

Info $NAME 6 "All done."
