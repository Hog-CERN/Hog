#!/usr/bin/env tclsh
#   Copyright 2018-2026 The University of Birmingham
#   Copyright 2018-2026 Max-Planck-Institute for Physics
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
