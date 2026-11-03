# Standard simulation post-hook. Called once for each simulation set.
foreach hook [list \
  "$repo_path/Top/$project_name/post-simulation.tcl" \
  "$repo_path/Top/$project_name/post-simulation_$simset.tcl" \
  "$repo_path/Top/$project_name/post-$simset-simulation.tcl"] {
  if {[file exists $hook]} {
    Msg Info "Sourcing user post-simulation file $hook"
    source $hook
  }
}
