set NAME "Post_Implementation"
set old_path [pwd]
set tcl_path [file normalize "[file dirname [info script]]/.."]
source $tcl_path/hog.tcl

set run_path [file normalize "$old_path/.."]
if [file exists ../buypass_commit] {
    set buypass_commit 1
} else  {
    set buypass_commit 0
}
Msg Info "Evaluating firmware date and, possibly, git commit hash..."
set commit "0000000"
if { [exec git status --untracked-files=no  --porcelain] eq "" } {
    Msg Info "Git working directory [pwd] clean."
    lassign [GetVer ALL ./] version commit official
    set clean "yes"
} else {
    if {$buypass_commit == 1} {
    Msg Info "Buypassing commit check."
    lassign [GetVer ALL ./] version commit official
    set clean "yes"
    } else {
	   Msg CriticalWarning "Git working directory [pwd] not clean, commit hash, official, and version will be set to 0."
  	   set official "00000000"
       set commit   "0000000"
       set version  "00000000"
       set clean    "no"
   }
}

puts $commit

# Set bitstream embedded variables
set_property BITSTREAM.CONFIG.USERID $commit [current_design]
set_property BITSTREAM.CONFIG.USR_ACCESS $commit [current_design]
Msg Info "All done."
