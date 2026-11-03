# Project-owned XSim custom-Do example for WCFG-selected VCD capture.
# Keep project-specific forces, runs, and checks between start and stop.
source [file join [file dirname [info script]] wcfg_vcd.tcl]

# Vivado can invoke CUSTOM_DO after its generated script has stopped.
restart
WcfgVcd::start selected_signals.vcd

run 50 us

WcfgVcd::stop
quit
