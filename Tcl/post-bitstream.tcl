set NAME "Post_Bitstream"
set old_path [pwd]
set tcl_path [file dirname [info script]]
source $tcl_path/hog.tcl

set proj_file [get_property parent.project_path [current_project]]
set proj_name [file rootname [file tail $proj_file]]
if {$proj_name == ""} {
    set proj_name [current_project]
}

set bit_file [file normalize "$old_path/top_$proj_name.bit"]
set bin_file [file normalize "$old_path/top_$proj_name.bin"]
set xml_dir [file normalize "$old_path/../xml"]

# Go to repository path
cd $tcl_path/../../ 

Info $NAME 0 "Evaluating git describe..."
set describe [exec git describe --always --dirty]
set ts [clock format [clock seconds] -format {%Y-%m-%d-%H-%M}]
set prefix $ts-$describe

set dst_dir [file normalize "$old_path/../$prefix"]
set dst_bit [file normalize "$dst_dir/$proj_name\-$describe.bit"]
set dst_bin [file normalize "$dst_dir/$proj_name\-$describe.bin"]
set dst_xml [file normalize "$dst_dir/xml"]

if [file exists $bit_file] {
    Info $NAME 1 "Creating $dst_dir..."
    file mkdir $dst_dir
    Info $NAME 2 "Copying bit file $bit_file into $dst_bit..."
    file copy -force $bit_file $dst_bit
    if [file exists $xml_dir] {
	Info $NAME 2 "XML directory found, copying xml files from $xml_dir to $dst_xml..." 
	file copy -force $xml_dir $dst_xml
    }
    if [file exists $bin_file] {
	Info $NAME 4 "Copying bin file $bin_file into $dst_bin..."
	file copy -force $bin_file $dst_bin
    }
} else {
   Warning $NAME 5 "Bit file $bit_file not found."
}

cd $old_path
Info $NAME 6 "All done."
