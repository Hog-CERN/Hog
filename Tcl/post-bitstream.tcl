set NAME "Post_Bitstream"
set old_path [pwd]
set tcl_path [file dirname [info script]]
source $tcl_path/hog.tcl

set bit_file [file normalize [lindex [glob -nocomplain "$old_path/*.bit"] 0]]
if [file exists $bit_file] {

    set proj_name [string map {"top_" ""} [file rootname [file tail $bit_file]]]
    set name [file rootname [file tail [file normalize [pwd]/..]]]
    set bit_file [file normalize "$old_path/top_$proj_name.bit"]
    set bin_file [file normalize "$old_path/top_$proj_name.bin"]
    set xml_dir [file normalize "$old_path/../xml"]
    set run_dir [file normalize "$old_path/.."]    
    set bin_dir [file normalize "$old_path/../../../../bin"]    
    
    # Go to repository path
    cd $tcl_path/../../ 
    
    set git_status [exec git status]
    Status $NAME 1 " *********************** GIT STATUS ************************************** "
    Status $NAME 1 "$git_status"
    Status $NAME 1 " *********************** END OF GIT STATUS ******************************* "    
    
    Info $NAME 0 "Evaluating git describe..."
    set describe [exec git describe --always --dirty]
    Info $NAME 1 "Git describe: $describe"

    set ts [clock format [clock seconds] -format {%Y-%m-%d-%H-%M}]
    #set prefix $ts-$describe
    set prefix $name\_$describe

    
    set dst_dir [file normalize "$bin_dir/$prefix"]
    set dst_bit [file normalize "$dst_dir/$name\-$describe.bit"]
    set dst_bin [file normalize "$dst_dir/$name\-$describe.bin"]
    set dst_xml [file normalize "$dst_dir/xml"]
    
    Info $NAME 2 "Creating $dst_dir..."
    file mkdir $dst_dir
    Info $NAME 3 "Copying bit file $bit_file into $dst_bit..."
    file copy -force $bit_file $dst_bit
    # Reports
    file mkdir $dst_dir/reports
    set reps [glob -nocomplain "$run_dir/*/*.rpt"]
    if [file exists [lindex $reps 0]] {
	file copy -force {*}$reps $dst_dir/reports
    } else {
	Warning $NAME 4 "No reports found in $run_dir subfolders"
    }
	    
    # XML
    if [file exists $xml_dir] {
	Info $NAME 4 "XML directory found, copying xml files from $xml_dir to $dst_xml..." 
	if [file exists $dst_xml] {
	    Info $NAME 5 "Directory $dst_xml exists, deleting it..." 
	    file delete -force $dst_xml
	}
	file copy -force $xml_dir $dst_xml
    }
    # bin File
    if [file exists $bin_file] {
	Info $NAME 6 "Copying bin file $bin_file into $dst_bin..."
	file copy -force $bin_file $dst_bin
    }

    #Version table
    if [file exists $run_dir/versions] {
	file copy -force $run_dir/versions $dst_dir
    } else {
	Warning $NAME 7 "No versions file found"
    }
    #Timing file
    puts $run_dir
    puts [glob -nocomplain "$run_dir/timing_*"]
    set timing_file [file normalize [lindex [glob -nocomplain "$run_dir/timing_*"] 0]]
    if [file exists $timing_file] {
	file copy -force $timing_file $dst_dir
    } else {
	Warning $NAME 7 "No timing file found"
    }
    

} else {
    CriticalWarning $NAME 8 "Bit file not found."
}

cd $old_path
Info $NAME 9 "All done."
