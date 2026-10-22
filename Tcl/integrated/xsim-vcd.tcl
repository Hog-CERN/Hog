# XSim custom-Do script installed by Hog when HOG_XSIM_VCD is enabled.
set runtime 120ns
if {[info exists ::env(HOG_XSIM_VCD_RUNTIME)]} {
  set runtime $::env(HOG_XSIM_VCD_RUNTIME)
}

set vcd_file waveform.vcd
if {[info exists ::env(HOG_XSIM_VCD_FILE)]} {
  set vcd_file $::env(HOG_XSIM_VCD_FILE)
}

open_vcd $vcd_file
log_vcd [get_objects -r /*]
run $runtime
close_vcd
quit
