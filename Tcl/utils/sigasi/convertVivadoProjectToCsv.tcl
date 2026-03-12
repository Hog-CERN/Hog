#Vivado script that creates a csv file ("vivado_files.csv") with a list of all VHDL
#and Verilog files in a Vivado project + their library name
#
#How to use
#vivado -mode batch -source convertVivadoProjectToCsv.tcl <VivadoProjectFile.xpr>

#open_project -read_only -quiet project_1.xpr
set source_files [get_files -filter {(FILE_TYPE == VHDL || FILE_TYPE == "VHDL 2008" || FILE_TYPE == VERILOG || FILE_TYPE == SYSTEMVERILOG) && USED_IN_SIMULATION == 1 } ]
set csv_file [open "vivado_files.csv" w]
foreach source_file $source_files {
	puts  $csv_file [ concat  [ get_property LIBRARY $source_file ] "," $source_file ]
}
#close_project

