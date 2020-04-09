#!/usr/bin/env tclsh

#parsing command options
if {[catch {package require cmdline} ERROR]} {
    puts "$ERROR\n If you are running this script on tclsh, you can fix this by installing 'tcllib'" 
    return
}

set parameters {
    {lib_path.arg ""   "Compiled simulation library path"}
}

set usage "- USAGE: $::argv0 \[OPTIONS\] <project> \n. Options:"

set path [file normalize "[file dirname [info script]]/.."]
if { [catch {array set options [cmdline::getoptions ::argv $parameters $usage]}] ||  [llength $argv] < 1 } {
    puts [cmdline::usage $parameters $usage]
    exit 1
} else {
    set project [lindex $argv 0]
    set main_folder [file normalize "$path/../../VivadoProject/$project/$project.sim/"]

    if {$options(lib_path)!= ""} {
        set lib_path $options(lib_path)
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
Msg Info "Retrieving list of simulation sets..."

set errors 0

foreach s [get_filesets] {
    
    set type [get_property FILESET_TYPE $s]
    if {$type eq "SimulationSrcs"} {
        if {!($s eq "sim_1")} { 
            set filename [string range $s 0 [expr {[string last "_sim" $s] -1 }]]
            set fp [open "../../Top/$project/list/$filename.sim" r]
            set file_data [read $fp]
            close $fp
            set data [split $file_data "\n"]
            set n [llength $data]
            Msg Info "$n lines read from $filename"

            set firstline [lindex $data 0]
            #find simulator
            if { [regexp {^ *\#Simulator} $firstline] } {
                set simulator_prop [regexp -all -inline {\S+} $firstline]
                set simulator [lindex $simulator_prop 1]
            } else {
                set simulator "modelsim"
            }
            if {$simulator eq "skip_simulation"} {
                Msg Info "Skipping simulation for $s"
                continue
            }
            set_property "target_simulator" $simulator [current_project]
            Msg Info "Creating simulation scripts for $s..."
            current_fileset -simset $s
            set sim_dir $main_folder/$s/behav           
            if { ($simulator eq "xsim") } {
                set_property -name {xsim.elaborate.load_glbl} -value {true}
                if { [catch { launch_simulation -simset [get_filesets $s] } log] } {
                    Msg CriticalWarning "Simulation failed for $s, error info: $::errorInfo"
                    incr errors
                }
            } else {
                set_property "compxlib.${simulator}_compiled_library_dir" $lib_path [current_project]
                launch_simulation -scripts_only -simset [get_filesets $s]
                set top_name [get_property TOP $s]
                #set sim_script  [file normalize $sim_dir/$simulator/$top_name.sh] 
                set sim_script  [file normalize $sim_dir/$simulator/] 
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

        if { "$simulator" != "modelsim"} {
            set cmd ./elaborate.sh
            Msg Info "Elaborating: $cmd..."
            if { [catch { exec $cmd } log] } {
                Msg CriticalWarning "Elaboration failed for $s, error info: $::errorInfo"
                incr errors
            }
        }
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
