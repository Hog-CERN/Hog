# Standard simulation pre-hook. Called once for each simulation set.
foreach hook [list \
  "$repo_path/Top/$project_name/pre-simulation.tcl" \
  "$repo_path/Top/$project_name/pre-simulation_$simset.tcl" \
  "$repo_path/Top/$project_name/pre-$simset-simulation.tcl"] {
  if {[file exists $hook]} {
    Msg Info "Sourcing user pre-simulation file $hook"
    source $hook
  }
}
