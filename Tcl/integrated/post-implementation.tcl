set old_path [pwd]
set tcl_path [file normalize "[file dirname [info script]]/.."]
source $tcl_path/hog.tcl
set run_path [file normalize "$old_path/.."]

Msg Info "Evaluating repository git SHA..."
set commit "0000000"
if { [exec git status --untracked-files=no  --porcelain] eq "" } {
    Msg Info "Git working directory [pwd] clean."
    lassign [GetVer ALL ./] version commit
} else {
    Msg CriticalWarning "Git working directory [pwd] not clean, git commit hash be set to 0."
    set commit   "0000000"
}

set commit_usr [exec git rev-parse --short=8 HEAD]

Msg Info "The git SHA value $commit will be set as bitstream USERID."

# Set bitstream embedded variables
set_property BITSTREAM.CONFIG.USERID $commit [current_design]
set_property BITSTREAM.CONFIG.USR_ACCESS $commit_usr [current_design]

Msg Info "All done."
