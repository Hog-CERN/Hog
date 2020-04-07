set old_path [pwd]
set tcl_path [file normalize "[file dirname [info script]]/.."]
source $tcl_path/hog.tcl
set run_path [file normalize "$old_path/.."]
set bin_dir [file normalize "$old_path/../../../../bin"]    
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

set proj_name [file rootname [file tail $proj_file]]

puts [pwd]
Msg Info "Evaluating git describe..."
set describe [exec git describe --always --dirty --tags --long]
Msg Info "Git describe: $describe"

set dst_dir [file normalize "$bin_dir/$proj_name\-$describe"]
file mkdir $dst_dir
#Version table
if [file exists $run_path/versions.txt] {
    file copy -force $run_path/versions.txt $dst_dir
} else {
    Msg Warning "No versions file found"
}
#Timing file
# puts $run_path
exec ls $run_path/
set timing_files [ glob -nocomplain "$run_path/timing_*.txt" ]
puts $timing_files
set timing_file [file normalize [lindex $timing_files 0]]
puts $timing_file
if [file exists $timing_file ] {
    file copy -force $timing_file $dst_dir/
} else {
    Msg Warning "No timing file found, not a problem if running locally"
}


cd $old_path

Msg Info "All done."
