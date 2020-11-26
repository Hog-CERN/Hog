#open_project -read_only -quiet project_1.xpr
set source_files [get_files -filter {(FILE_TYPE == VHDL || FILE_TYPE == "VHDL 2008" || FILE_TYPE == VERILOG || FILE_TYPE == SYSTEMVERILOG) && USED_IN_SIMULATION == 1 } ]
set csv_file [open "vivado_files.csv" w]
foreach source_file $source_files {
	puts  $csv_file [ concat  [ get_property LIBRARY $source_file ] "," $source_file ]
}
#close_project
