set NAME "Post_Bitstream"
set old_path [pwd]
set tcl_path [file dirname [info script]]
source $tcl_path/hog.tcl

set proj_file [get_property parent.project_path [current_project]]
set proj_dir [file normalize [file dirname $proj_file]]
set proj_name [file rootname [file tail $proj_file]]
set bit_file [file normalize "$old_path/top_$proj_name.bit"]
set bin_file [file normalize "$old_path/top_$proj_name.bin"]

# Go to repository path
cd $tcl_path/../../ 

Info $NAME 0 "Evaluating git describe..."
set describe [exec git describe --always]

set dst_bit [file normalize "$old_path/../$proj_name\-$describe.bit"]
set dst_bin [file normalize "$old_path/../$proj_name\-$describe.bin"]

if [file exists $bit_file] {
    Info $NAME 1 "Copying bit file $bit_file into $dst_bit"
    file copy $bit_file $dst_bit
    if [file exists $bin_file] {
	Info $NAME 2 "Copying bin file $bin_file into $dst_bin"
	file copy $bin_file $dst_bin
    }
} else {
   Warn $NAME 3 "Bit file $bit_file not found"
}
