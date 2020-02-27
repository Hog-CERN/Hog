set old_path [pwd]
set tcl_path [file normalize "[file dirname [info script]]/.."]
source $tcl_path/hog.tcl

# Go to repository path
cd "$tcl_path/../.."

if {[info commands get_property] != ""} {
    # Vivado
    set proj_file [get_property parent.project_path [current_project]]
} elseif {[info commands project_new] != ""} {
    # Quartus
    set proj_file "/q/a/r/Quartus_project.qpf"
} else {
    #Tclssh
    set proj_file $old_path/[file tail $old_path].xpr
    Msg CriticalWarning "You seem to be running locally on tclsh, so this is a debug, the project file will be set to $proj_file and was derived from the path you launched this script from: $old_path. If you want this script to work properly in debug mode, please launch it from the top folder of one project, for example Repo/VivadoProject/fpga1/ or Repo/Top/fpga1/"
}
	
set proj_dir [file normalize [file dirname $proj_file]]
set proj_name [file rootname [file tail $proj_file]]



# Calculating flavour if any
set flavour [string map {. ""} [file ext $proj_name]]
if {$flavour != ""} {
    if [string is integer $flavour] {
	Msg Info "Project $proj_name has flavour = $flavour, the generic variable FLAVUOR will be set to $flavour"
    } else {
	Msg Warning "Project name has a non numeric extension, flavour will be set to -1"
	set flavour -1
    }

} else {
    set flavour -1
}


Msg Info "Evaluating firmware date and, possibly, git commit hash..."

if { [exec git status --untracked-files=no  --porcelain] eq "" } {
    Msg Info "Git working directory [pwd] clean."
    lassign [GetVer ALL ./] version commit
} else {
	Msg CriticalWarning "Git working directory [pwd] not clean, commit hash, and version will be set to 0."
    set commit   "0000000"
    set version  "00000000"    
}

# Top project directory
lassign [GetVer ./Top/$proj_name/ ./Top/$proj_name/] top_ver top_hash

# Read list files
set libs ""
set vers ""
set hashes ""
set list_files [glob  -nocomplain "./Top/$proj_name/list/*.src"]
foreach f $list_files {
    set name [file rootname [file tail $f]]
    lassign [GetVer  $f ./Top/$proj_name/] ver hash
    Msg Info "Found source file $f, version: $ver commit SHA: $hash"
    lappend libs $name
    lappend vers $ver
    lappend hashes $hash
}

# Read external library files
set ext_hashes ""
set ext_files [glob -nocomplain "./Top/$proj_name/list/*.ext"]
set ext_names ""
foreach f $ext_files {
    
    set name [file rootname [file tail $f]]
    set hash [exec git log --format=%h -1 $f ]
    Msg Info "Found source file $f, commit SHA: $hash"
    lappend ext_names $name
    lappend ext_hashes $hash

    set fp [open $f r]
    set file_data [read $fp]
    close $fp
    set data [split $file_data "\n"]
    Msg Info "Checking checksums of external library files in $f"
    foreach line $data {
        if {![regexp {^ *$} $line] & ![regexp {^ *\#} $line] } { #Exclude empty lines and comments
            set file_and_prop [regexp -all -inline {\S+} $line]
            set hdlfile [lindex $file_and_prop 0]
            set hdlfile "$env(HOG_EXTERNAL_PATH)/$hdlfile"
            if { [file exists $hdlfile] } {
                set hash [lindex $file_and_prop 1]
                set current_hash [exec md5sum $hdlfile]
                set current_hash [lindex $current_hash 0]
                if {[string first $hash $current_hash] == -1} {
                    Msg CriticalWarning "File $hdlfile has a wrong hash. Current checksum: $current_hash, expected: $hash"
                }
            }
        }
    }

}

# XML
set xml_dst $old_path/../xml
set use_ipbus 1
if [file exists ./Top/$proj_name/xml/xml.lst] {
    Msg Info "XML list file found, using version of listed XMLs"
    # version of xml in list files is used if list file exists
    set xml_target  ./Top/$proj_name/xml/xml.lst
    Msg Info "Creating XML directory $xml_dst..."
    file mkdir $xml_dst
    lassign [GetVer $xml_target ./Top/$proj_name/] xml_ver_hex xml_hash

    Msg Info "Copying xml files to $xml_dst and adding xml version $xml_ver..."
    CopyXMLsFromListFile $xml_target ./Top/$proj_name $xml_dst $xml_ver $xml_hash 

} elseif [file exists ./Top/$proj_name/xml] {
    Msg Info "XML list file not found, using version of XML directory"
    # version of the directory if no list file exists
    set xml_target  ./Top/$proj_name/xml
    lassign [GetVer $xml_target ./Top/$proj_name/] xml_ver_hex xml_hash
    file delete -force $old_path/../xml
    file copy -force $xml_target $old_path/..

} else {
    Msg Info "This project does not use IPbus XMLs"
    set xml_ver_hex 0000000
    set xml_hash 0000000
    set use_ipbus 0
}
set xml_ver [HexVersionToString $xml_ver_hex]


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
	    Msg Info "$sub_dir submodule clean."
	    lappend subs_hashes [GetHash ALL ./]
	} else {
	    Msg CriticalWarning "$sub_dir submodule not clean, commit hash will be set to 0."
	    lappend subs_hashes "0000000"    
	}
	cd ..
    } else {
	Msg CriticalWarning "$sub_dir submodule not found"
    }
}

# Hog submodule
cd "./Hog"
if { [exec git status --untracked-files=no  --porcelain] eq "" } {
    Msg Info "Hog submodule [pwd] clean."
    lassign [GetVer ALL ./] hog_ver hog_hash
} else {
    Msg CriticalWarning "Hog submodule [pwd] not clean, commit hash will be set to 0."
    set hog_hash "0000000"
    set hog_ver "0000000"
}
cd ..

set clock_seconds [clock seconds]
set tt [clock format $clock_seconds -format {%d/%m/%Y at %H:%M:%S}]

if [GitVersion 2.9.3] {
    set date [exec git log -1 --format=%cd --date=format:'%d%m%Y']
    set timee [exec git log -1 --format=%cd --date=format:'00%H%M%S']
} else {
    Msg Warning "Found Git version older than 2.9.3. Using current date and time instead of commit time."
    set date [clock format $clock_seconds  -format {%d%m%Y}]
    set timee [clock format $clock_seconds -format {00%H%M%S}]
}

#####  Passing Hog genric to top file
if {[info commands set_property] != ""} {
    ### VIVADO
    # set global generic varibles
    set generic_string "GLOBAL_FWDATE=32'h$date GLOBAL_FWTIME=32'h$timee GLOBAL_FWHASH=32'h$commit TOP_FWHASH=32'h$top_hash XML_HASH=32'h$xml_hash GLOBAL_FWVERSION=32'h$version TOP_FWVERSION=32'h$top_ver XML_VERSION=32'h$xml_ver_hex HOG_FWHASH=32'h$hog_hash HOG_FWVERSION=32'h$hog_ver"
    
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
    
    foreach e $ext_names h $ext_hashes {
	set hash "[string toupper $e]_FWHASH=32'h$h"
	set generic_string "$generic_string $hash"
    }
    
    if {$flavour != -1} {
	set generic_string "$generic_string FLAVOUR=$flavour"
    }
    
    set_property generic $generic_string [current_fileset]
    set status_file "$old_path/../versions.txt"

} elseif {[info commands quartus_command] != ""} {
    ### QUARTUS
    set  status_file "$old_path/../versions.txt"

} else {
    ### Tcl Shell
    puts "Hog:DEBUG GLOBAL_FWDATE=$date GLOBAL_FWTIME=$timee"
    puts "Hog:DEBUG GLOBAL_FWHASH=$commit TOP_FWHASH=$top_hash"
    puts "Hog:DEBUG XML_HASH=$xml_hash GLOBAL_FWVERSION=$version TOP_FWVERSION=$top_ver"
    puts "Hog:DEBUG XML_VERSION=$xml_ver_hex HOG_FWHASH=$hog_hash HOG_FWVERSION=$hog_ver"
    puts "Hog:DEBUG LIBS: $libs $vers $hashes"
    puts "Hog:DEBUG SUBS: $subs $subs_hashes"
    puts "Hog:DEBUG EXT: $ext_names $ext_hashes"
    puts "Hog:DEBUG FLAVOUR: $flavour"
    set  status_file "$old_path/versions.txt"
    
} 
Msg Info "Opening version file $status_file..."
set status_file [open $status_file "w"]
# writing info into status file

Msg Status " ------------------------- PRE SYNTHESIS -------------------------"
Msg Status " $tt"
Msg Status " Firmware date and time: $date, $timee"
puts $status_file "Date, $date, $timee"
if {$flavour != -1} {
    Msg Status " Project flavour: $flavour"
}

set version [HexVersionToString $version]
Msg Status " Global SHA: $commit, VER: $version"
puts $status_file "Global, $commit, $version"

if {$use_ipbus == 1} {
    Msg Status " XML SHA: $xml_hash, VER: $xml_ver"
    puts $status_file "XML, $xml_hash, $xml_ver"
}
set top_ver [HexVersionToString $top_ver]
Msg Status " Top SHA: $top_hash, VER: $top_ver"
puts $status_file "Top, $top_hash, $top_ver"

set hog_ver [HexVersionToString $hog_ver]
Msg Status " Hog SHA: $hog_hash, VER: $hog_ver"
puts $status_file "Hog, $hog_hash, $hog_ver"

Msg Status " --- Libraries ---"
foreach l $libs v $vers h $hashes {
    set v [HexVersionToString $v]
    Msg Status " $l SHA: $h, VER: $v"    
    puts $status_file "$l, $h, $v"
}
Msg Status " --- Submodules ---"
foreach s $subs sh $subs_hashes {
    Msg Status " $s SHA: $sh"
    puts $status_file "$s, $sh, 00000000"    
}
Msg Status " --- External Libraries ---"
foreach e $ext_names eh $ext_hashes {
    Msg Status " $e SHA: $eh"
    puts $status_file "$e, $eh, 00000000"    
}
Msg Status " -----------------------------------------------------------------"
close $status_file


CheckYmlRef $tcl_path/../..
cd $old_path

Msg Info "All done."
