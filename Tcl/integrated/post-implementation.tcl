set old_path [pwd]
set tcl_path [file normalize "[file dirname [info script]]/.."]
source $tcl_path/hog.tcl
# Go to repository pathcd $old_pathcd $old_path
cd $tcl_path/../../ 
Msg Info "Evaluating repository git SHA..."
set commit "0000000"
if { [exec git status --untracked-files=no  --porcelain] eq "" } {
    Msg Info "Git working directory [pwd] clean."
    lassign [GetVer ALL ./] version commit
} else {
    Msg CriticalWarning "Git working directory [pwd] not clean, git commit hash be set to 0."
    set commit   "0000000"
}



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


#number of threads
set maxThreads 1
set property_files [glob -nocomplain "./Top/$proj_name/list/*.prop"]
foreach f $property_files {
	set fp [open $f r]
	set file_data [read $fp]
	close $fp
	set data [split $file_data "\n"]
	foreach line $data {    
		if {![regexp {^ *$} $line] & ![regexp {^ *\#} $line] } { #Exclude empty lines and comments
			set file_and_prop [regexp -all -inline {\S+} $line]
			if {[string equal [lindex $file_and_prop 0] "maxThreads"]} {
				set maxThreads [lindex $file_and_prop 1]
			}
		}
	}
}
if {$maxThreads != 1} {
	Msg CriticalWarning "Multithreading enabled. Bitfile is not deterministic. Number of threads: $maxThreads"
	set commit   "0000000"
}


set commit_usr [exec git rev-parse --short=8 HEAD]

Msg Info "The git SHA value $commit will be set as bitstream USERID."

# Set bitstream embedded variables
set_property BITSTREAM.CONFIG.USERID $commit [current_design]
set_property BITSTREAM.CONFIG.USR_ACCESS $commit_usr [current_design]

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



cd $old_path

Msg Info "All done."
