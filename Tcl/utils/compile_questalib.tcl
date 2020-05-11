# @file
# Compiles Questa libraries

set repo_path [pwd]
cd $repo_path/..
compile_simlib -simulator questa -directory SimulationLib
