# set simulator xsim
set path [file normalize "[file dirname [info script]]/.."]
if { $::argc eq 0 } {
    puts "USAGE: $::argv0 <project> [questa library path]"
    exit 1
} else {
    set project [lindex $argv 0]
    set main_folder [file normalize "$path/../../VivadoProject/$project/$project.sim/"]

    if {[llength $argv] > 1} {
    set lib_path [lindex $argv 1]
    } else {
    set lib_path [file normalize "$main_folder/../../../SimulationLib"]
    }
}


set old_path [pwd]
cd $path
source ./hog.tcl
Msg Info "Simulation library path is set to $lib_path."
if !([file exists $lib_path]) {
    Msg Error "Could not find simulation library path: $lib_path."
    exit -1
}

Msg Info "Opening project $project..."
open_project ../../VivadoProject/$project/$project.xpr
set_property "compxlib.modelsim_compiled_library_dir" $lib_path [current_project]
Msg Info "Retrieving list of simulation sets..."

foreach s [get_filesets] {
    set type [get_property FILESET_TYPE $s]
    if {$type eq "SimulationSrcs"} {
        if {!($s eq "sim_1")} { 
            set filename [string range $s 0 [expr {[string first "_sim" $s] -1 }]]
            set fp [open "../../Top/$project/list/$filename.sim" r]
            set file_data [read $fp]
            close $fp
            set data [split $file_data "\n"]
            set n [llength $data]
            Msg Info "$n lines read from $filename"
            
            set firstline [lindex $data 0]
            if { [regexp {^ *\#Simulator} $firstline] } {
                set simulator_prop [regexp -all -inline {\S+} $firstline]
                set simulator [lindex $simulator_prop 1]
                set_property "target_simulator" $simulator [current_project]
                Msg Info "Creating simulation scripts for $s..."
                current_fileset -simset $s
                set sim_dir $main_folder/$s/behav
                if { ($simulator eq "xsim") } {
                    launch_simulation -simset [get_filesets $s]
                } else {
                    launch_simulation -scripts_only -simset [get_filesets $s]
                    set top_name [get_property TOP $s]
                    #set sim_script  [file normalize $sim_dir/$simulator/$top_name.sh] 
                    set sim_script  [file normalize $sim_dir/$simulator/] 
                    Msg Info "Adding simulation script location $sim_script for $s..."
                    lappend sim_scripts $sim_script
                } 
            } else { #Default is modelsim
            	set_property "target_simulator" "modelsim" [current_project]
            	Msg Info "Creating simulation scripts for $s..."
                current_fileset -simset $s
                set sim_dir $main_folder/$s/behav
                launch_simulation -scripts_only -simset [get_filesets $s]
                set top_name [get_property TOP $s]
                #set sim_script  [file normalize $sim_dir/$simulator/$top_name.sh] 
                set sim_script  [file normalize $sim_dir/modelsim/] 
                Msg Info "Adding simulation script location $sim_script for $s..."
                lappend sim_scripts $sim_script
            } 

            
        }
    }
}

Msg Info "Generating IP simulation targets, if any..."

foreach ip [get_ips] {
    generate_target simulation $ip
}

set errors 0
if [info exists sim_scripts] {
    foreach s $sim_scripts {
    #cd [file dir $s]
    #set cmd ./[file tail $s]
    cd $s
    set cmd ./compile.sh
    Msg Info "Compiling: $cmd..."

    if { [catch { exec $cmd } log] } {
        Msg CriticalWarning "Compilation failed for $s, error info: $::errorInfo"
        incr errors
    }
    Msg Info "Compilation log starts:"
    Msg Status "\n\n$log\n\n"
    Msg Info "Compilation log ends"

    set cmd ./simulate.sh
    Msg Info "Simulating: $cmd..."

    if { [catch { exec $cmd } log] } {
        Msg CriticalWarning "Simulation failed for $s, error info: $::errorInfo"
        incr errors
    }
    Msg Info "Simulation log starts:"
    Msg Status "\n\n$log\n\n"
    Msg Info "Simulation log ends"
    }
    
    if {$errors > 0} {
    Msg Error "Simualtion failed, there were $errors failures. Look above for details."
    exit -1
    } else {
    Msg Info "All simulations were successful."
    }

} else {
    Msg Info "No simulation set was found in this project."
}

Msg Info "All done."
