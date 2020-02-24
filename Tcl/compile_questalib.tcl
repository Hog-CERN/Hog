set old_path [pwd]
set path [file dirname [info script]]
cd $path
compile_simlib -simulator questa -directory ../../SimulationLib
