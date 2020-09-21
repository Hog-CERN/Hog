#planahead
############# modify these to match project ################
set BIN_FILE 0
set SIMULATOR  xsim

set FPGA xc6vlx130tff1156-1

## FPGA and PlanAhead strategies and flows
set SYNTH_FLOW "XST 14"
set SYNTH_STRATEGY "PlanAhead Defaults"
set IMPL_FLOW "ISE 14"
set IMPL_STRATEGY "ISE Defaults"

### Set Run Properties ###
#
# ATTENTION: The \ character must be the last one of each line
#
# The default run names are: synth_1 for synthesis and impl_1 for implementation.
#
# To find out the exact name and value of the property, use planAhead GUI to click on the checkbox you like.
# This will make planAhead run the set_property command in the Tcl console.
# Then copy and paste the name and the values from the planAhead Tcl console into the lines below.

set PROPERTIES [dict create \
    synth_1 [dict create \
        steps.xst.args.equivalent_register_removal no \
    ] \
    impl_1 [dict create \
        steps.map.args.pr b \
        steps.map.args.logic_opt on \
        steps.par.args.mt 4  \
        steps.map.args.register_duplication true \
        steps.bitgen.args.More\ Options {{-g CRC:enable -g ConfigRate:33 -g StartUpClk:CCLK -g DonePipe:yes}} \
    ]\
]
# please see https://www.xilinx.com/support/documentation/sw_manuals/xilinx14_7/devref.pdf for
# documentation on the "More Options"

### Project name and repository path
set DESIGN    "[file rootname [file tail [info script]]]"
set PATH_REPO "[file normalize [file dirname [info script]]]/../../"
source $PATH_REPO/Hog/Tcl/create_project.tcl
