set Name LaunchCheckSyntax
set path [file normalize "[file dirname [info script]]/.."]
if { $::argc eq 0 } {
    puts "USAGE: $::argv0 <project>"
    exit 1
} else {
    set project [lindex $argv 0]
        set main_folder [file normalize "$path/../../VivadoProject/$project/$project.runs/"]
}

set old_path [pwd]
cd $path
source ./hog.tcl
Info $Name 1 "Opening project $project..."
open_project ../../VivadoProject/$project/$project.xpr

set syntax [check_syntax -return_string]

if {[string first "CRITICAL" $syntax ] != -1} {
    check_syntax
    exit 1
}

