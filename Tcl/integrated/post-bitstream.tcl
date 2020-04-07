set old_path [pwd]
set tcl_path [file normalize "[file dirname [info script]]/.."]
source $tcl_path/hog.tcl

if {[info commands get_property] != ""} {
    #Vivado
    set fw_file [file normalize [lindex [glob -nocomplain "$old_path/*.bit"] 0]]
    set proj_name [string map {"top_" ""} [file rootname [file tail $fw_file]]]
    set name [file rootname [file tail [file normalize [pwd]/..]]]
    set bit_file [file normalize "$old_path/top_$proj_name.bit"]
    set bin_file [file normalize "$old_path/top_$proj_name.bin"]
    set ltx_file [file normalize "$old_path/top_$proj_name.ltx"]    
    
} elseif {[info commands quartus_command] != ""} {
    # Quartus
    set fw_file [file normalize [lindex [glob -nocomplain "$old_path/*.bit"] 0]]
    set proj_name [string map {"top_" ""} [file rootname [file tail $fw_file]]]
    set name [file rootname [file tail [file normalize [pwd]/..]]]
    set bit_file [file normalize "$old_path/top_$proj_name.bit"]
    set bin_file [file normalize "$old_path/top_$proj_name.bin"]
    set ltx_file [file normalize "$old_path/top_$proj_name.ltx"]    

    
} else {
    #tcl shell
    set fw_file [file normalize [lindex [glob -nocomplain "$old_path/*.bit"] 0]]

    set proj_name [string map {"top_" ""} [file rootname [file tail $fw_file]]]
    set name [file rootname [file tail [file normalize [pwd]/..]]]
    set bit_file [file normalize "$old_path/top_$proj_name.bit"]
    set bin_file [file normalize "$old_path/top_$proj_name.bin"]
    set ltx_file [file normalize "$old_path/top_$proj_name.ltx"]        
}
if [file exists $fw_file] {


    set xml_dir [file normalize "$old_path/../xml"]
    set run_dir [file normalize "$old_path/.."]    
    set bin_dir [file normalize "$old_path/../../../../bin"]    
    
    # Go to repository path
    cd $tcl_path/../../ 
    
    Msg Info "Evaluating git describe..."
    set describe [exec git describe --always --dirty --tags --long]
    Msg Info "Git describe: $describe"

    set ts [clock format [clock seconds] -format {%Y-%m-%d-%H-%M}]

    set dst_dir [file normalize "$bin_dir/$name\-$describe"]
    set dst_bit [file normalize "$dst_dir/$name\-$describe.bit"]
    set dst_bin [file normalize "$dst_dir/$name\-$describe.bin"]
    set dst_ltx [file normalize "$dst_dir/$name\-$describe.ltx"]    
    set dst_xml [file normalize "$dst_dir/xml"]
    
    Msg Info "Creating $dst_dir..."
    file mkdir $dst_dir
    Msg Info "Evaluating differences with last commit..."
    set diff [exec git diff]
    if {$diff != ""} {
        Msg Warning "Found differences with last commit..."
        Msg Info "$diff"
        set fp [open "$dst_dir/diff_postbistream.txt" w+]
        puts $fp "$diff"
        close $fp
    } else {
        Msg Info "No differences with last commit."
    }

    Msg Info "Copying bit file $bit_file into $dst_bit..."
    file copy -force $bit_file $dst_bit
    # Reports
    file mkdir $dst_dir/reports
    set reps [glob -nocomplain "$run_dir/*/*.rpt"]
    if [file exists [lindex $reps 0]] {
	file copy -force {*}$reps $dst_dir/reports
    } else {
	Msg Warning "No reports found in $run_dir subfolders"
    }
	    
    # IPbus XML
    if [file exists $xml_dir] {
	Msg Info "XML directory found, copying xml files from $xml_dir to $dst_xml..." 
	if [file exists $dst_xml] {
	    Msg Info "Directory $dst_xml exists, deleting it..." 
	    file delete -force $dst_xml
	}
	file copy -force $xml_dir $dst_xml
    }
    # bin File
    if [file exists $bin_file] {
	Msg Info "Copying bin file $bin_file into $dst_bin..."
	file copy -force $bin_file $dst_bin
    } else {
	Msg Info "No bin file found: $bin_file, that is not a problem"
    }

    write_debug_probes -quiet $ltx_file
    
    # ltx File
    if [file exists $ltx_file] {
	Msg Info "Copying ltx file $ltx_file into $dst_ltx..."
	file copy -force $ltx_file $dst_ltx
    } else {
	Msg Info "No ltx file found: $ltx_file, that is not a problem"
    }    

} else {
    Msg CriticalWarning "Firmware binary file not found."
}

cd $old_path
Msg Info "All done."
