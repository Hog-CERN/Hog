# @file
# Compiles modelsim libraries

set old_path [pwd]
set path [file dirname [info script]]
cd $path
compile_simlib -simulator modelsim -directory ../../SimulationLib
