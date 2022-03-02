#   Copyright 2018-2022 The University of Birmingham
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

# @file
# Create sigasi csv file

set path [file normalize "[file dirname [info script]]/.."]
set old_path [pwd]
source $path/hog.tcl

if { $::argc != 1} {
  Msg Info "Usage: make_sigasi_csv <project name>"
  exit 1
}
set project_name [lindex $argv 0]
set project_file [file normalize $path/../../Projects/$project_name/$project_name.xpr]

if {[file exists $project_file]} {
  Msg Info "Opening existing project file $project_file..."
  open_project -quiet $project_file
} else {
  Msg Info "Creating project: $project_name..."
  source $path/../../Top/$project_name/$project_name.tcl
}

#Simulation
set csv_name "${project_name}_sigasi_sim.csv"
#Create IPs here
Msg Info "Generating IP targets for simulations..."
foreach ip [get_ips] {
  set targets [list_targets [get_files [file tail [get_property IP_FILE $ip]]]]
  if { [ lsearch -exact $targets simulation] >= 0 }  {
    generate_target simulation $ip
  } else {
    Msg Warning "IP $ip is not a simulation target, skipping..."
  }
}





Msg Info "Creating sigasi csv file for simulation $csv_name..."
set source_files [get_files -filter {(FILE_TYPE == VHDL || FILE_TYPE == "VHDL 2008" || FILE_TYPE == VERILOG || FILE_TYPE == SYSTEMVERILOG) && USED_IN_SIMULATION == 1 } ]
set csv_file [open $old_path/$csv_name w]
foreach source_file $source_files {
  puts  $csv_file [ concat  [ get_property LIBRARY $source_file ] "," $source_file ]
}
close $csv_file

#Synthesis
set csv_name "${project_name}_sigasi_synth.csv"
Msg Info "Generating IP targets for synthesis..."
foreach ip [get_ips] {
  generate_target synthesis $ip
}

Msg Info "Creating sigasi csv file for synthesis $csv_name..."
set source_files [get_files -filter {(FILE_TYPE == VHDL || FILE_TYPE == "VHDL 2008" || FILE_TYPE == VERILOG || FILE_TYPE == SYSTEMVERILOG) && USED_IN_SYNTHESIS == 1 } ]
set csv_file [open $old_path/$csv_name w]
foreach source_file $source_files {
  puts  $csv_file [ concat  [ get_property LIBRARY $source_file ] "," $source_file ]
}
close $csv_file
