# @file
# Compiles modelsim libraries

set repo_path [pwd]
cd $repo_path
compile_simlib -simulator modelsim -directory SimulationLib
