#Quartus script that creates a csv file ("quartus_files.csv") with a list of all VHDL
#and (System)Verilog files in a Quartus project (+ their library name)
#
#How to use
#quartus_sh -t convertQuartusProjectToCsv.tcl <path to qpf or qsf file>

set project_path [lindex $argv 0]

#open Quartus project
project_open -current_revision $project_path
#display project info
puts "Sigasi: Converting project \"[get_current_project]\" to a CSV file"
puts "Sigasi: Current revision \"[get_current_revision]\""

#open result file for writing
set csv_file_name "quartus_files.csv"
set csv_file [open $csv_file_name w]
puts "Sigasi: Writing result to [ file dirname [ file normalize $csv_file ] ]/$csv_file_name"

#procedure for write all files in Quartus collection to a csv line
proc process_files {csv_file collection} {
    foreach_in_collection hdl_file $collection {
        set filename [get_assignment_info $hdl_file -value]
        set path [resolve_file_path $filename]
        # set get_tcl_command [get_assignment_info $hdl_file -get_tcl_command]
        set library [get_assignment_info $hdl_file -library]
        set library [expr {[string length $library]>0 ? $library : "work"}]

        puts $csv_file [join [ list $library $path] "," ]
    }
}

process_files $csv_file [get_all_assignments -name VHDL_FILE -type global]
process_files $csv_file [get_all_assignments -name VERILOG_FILE -type global]
process_files $csv_file [get_all_assignments -name SYSTEMVERILOG_FILE -type global]