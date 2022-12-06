# @file
#   Copyright 2018-2023 The University of Birmingham
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


# Launch Libero implementation and possibly write bitstream in text mode

# Import tcllib
if {[info exists env(HOG_TCLLIB_PATH)]} {
  lappend auto_path $env(HOG_TCLLIB_PATH) 
} else {
  puts "ERROR: To run Hog with Microsemi Libero SoC, you need to define the HOG_TCLLIB_PATH variable."
  return
}

#parsing command options
if {[catch {package require cmdline} ERROR] || [catch {package require struct::matrix} ERROR]} {
  puts "$ERROR\n Tcllib not found. If you are running this script on tclsh, you can fix this by installing 'tcllib'"
  return
}

set parameters {
  {ip_path.arg "" "If set, the synthesised IPs will be copied to the specified IP repository path."}
  {no_bitstream    "If set, the bitstream file will not be produced."}
  {synth_only      "If set, only the synthesis will be performed."}
  {impl_only       "If set, only the implementation will be performed. This assumes synthesis should was already done."}
  {recreate        "If set, the project will be re-created if it already exists."}
  {no_reset        "If set, runs (synthesis and implementation) won't be reset before launching them."}
  {check_syntax    "If set, the HDL syntax will be checked at the beginning of the workflow."}
  {njobs.arg 4 "Number of jobs. Default: 4"}
  {ext_path.arg "" "Sets the absolute path for the external libraries."}
  {simlib_path.arg  "" "Path of simulation libs"}
}

set usage "- USAGE: $::argv0 \[OPTIONS\] <project> \n. Options:"
set path [file normalize "[file dirname [info script]]/.."]
set repo_path [file normalize "$path/../.."]
set old_path [pwd]
set bin_dir [file normalize "$path/../../bin"]
source $path/hog.tcl

if {[catch {array set options [cmdline::getoptions ::argv $parameters $usage]}] ||  [llength $argv] < 1 } {
  Msg Info [cmdline::usage $parameters $usage]
  exit 1
} else {
  set project [lindex $argv 0]
  set group_name [file dirname $project]
  set project [file tail $project]
  if { $group_name != "." } {
    set project_name "$group_name/$project"
  } else {
    set project_name "$project"
  }
  set main_folder [file normalize "$repo_path/Projects/$project_name/"]
  set do_implementation 1
  set do_synthesis 1
  set do_bitstream 1
  set recreate 0
  set reset 1
  set check_syntax 0
  set ip_path ""
  set ext_path ""
  set simlib_path ""
}


#Go to Hog/Tcl
cd $path

if { $options(no_bitstream) == 1 } {
  set do_bitstream 0
}

if { $options(recreate) == 1 } {
  set recreate 1
}

if { $options(synth_only) == 1 } {
  set do_implementation 0
}

if { $options(impl_only) == 1 } {
  set do_synthesis 0
}

if { $options(no_reset) == 1 } {
  set reset 0
}

if { $options(check_syntax) == 1 } {
  set check_syntax 1
}

if { $options(ext_path) != ""} {
  set ext_path $options(ext_path)
}

if { $options(simlib_path) != ""} {
  set workflow_simlib_path $options(simlib_path)
}

#Copy IP from IP repository
# if { $options(ip_path) != "" } {
#   set ip_path $options(ip_path)

#   Msg Info "Getting IPs for $project_name..."
#   set ips {}
#   lassign [GetHogFiles -list_files "*.src" -repo_path $repo_path "$repo_path/Top/$project_name/list/" ] src_files dummy
#   dict for {f files} $src_files {
#     #library names have a .src extension in values returned by GetHogFiles
#     if { [file ext $f] == ".ip" } {
#       lappend ips {*}$files
#     }
#   }

#   Msg Info "Copying IPs from $ip_path..."
#   set copied_ips 0
#   set repo_ips {}
#   foreach ip $ips {
#     set ip_folder [file dirname $ip]
#     set files_in_folder [glob -directory $ip_folder -- *]
#     if { [llength $files_in_folder] == 1 } {
#       set ret [HandleIP pull $ip $ip_path $main_folder]
#       if {$ret == 0} {
#         incr copied_ips
#       }
#     } else {
#       Msg Info "Synthesised files for IP $ip are already in the repository. Do not copy from IP repository..."
#       lappend repo_ips $ip
#     }
#   }
#   Msg Info "$copied_ips IPs were copied from the IP repository."
# }


if {$do_synthesis == 0} {
  Msg Info "Will launch implementation only..."

} else {
  if {$do_implementation == 1} {
    if {$do_bitstream == 1} {
      Msg Info "Will launch implementation and write bitstream..."
    } else {
      Msg Info "Will launch implementation only..."
    }
  } else {
    Msg Info "Will launch synthesis only..."
  }
}

if { $ip_path != "" } {
  Msg Info "Will copy synthesised IPs from/to $ip_path"
}

Msg Info "Number of jobs set to $options(njobs)."

############# CREATE or OPEN project ############
set project_file [file normalize $repo_path/Projects/$project_name/$project.prjx]

if {[file exists $project_file]} {
  Msg Info "Found project file $project_file for $project_name."
  set proj_found 1
} else {
  Msg Info "Project file not found for $project_name."
  set proj_found 0
}

if {($proj_found == 0 || $recreate == 1) && $do_synthesis == 1} {
  Msg Info "Creating (possibly replacing) the project $project_name..."
  lassign [GetConfFiles $repo_path/Top/$project_name] conf sim pre post

  if {[file exists $conf]} {
    source ./create_project.tcl
  } else {
    Msg Error "Project $project_name is incomplete: no hog.conf file found, please create one..."
  }
} else {
  Msg Info "Opening existing project file $project_file..."
  file mkdir "$repo_path/Projects/$project_name/$project.gen/sources_1"
  open_project -file $project_file -do_backup_on_convert 1 -backup_file {./Projects/$project_file.zip}
}

########## CHECK SYNTAX ###########
if { $check_syntax == 1 } {
  Msg Info "Checking syntax option is not supported for Microchip Libero Soc yet. Skipping.."  
}

defvar_set -name RWNETLIST_32_64_MIXED_FLOW -value 0

############# SYNTH ###############

if {$do_synthesis == 1} {
  Msg Info "Run SYNTHESIS..."
  if {[catch {run_tool -name {SYNTHESIZE}  }] } {
    Msg Error "SYNTHESIZE FAILED!"
  } else {
    Msg Info "SYNTHESIZE PASSED!"
  }  
} else {
  Msg Info "Skipping synthesis (and IP handling)..."
}

############### IMPL ###################

if {$do_implementation == 1 } {

  Msg Info "Starting implementation flow..."
  if {[catch {run_tool -name {PLACEROUTE}  }] } {
    Msg Error "PLACEROUTE FAILED!"
  } else {
    Msg Info "PLACEROUTE PASSED."
  }

  # source $path/../../Hog/Tcl/integrated/post-implementation.tcl

  # Check timing
  Msg Info "Run VERIFYTIMING ..."
  if {[catch {run_tool -name {VERIFYTIMING} -script {integrated/libero_timing.tcl} }] } {
    Msg CriticalWarning "VERIFYTIMING FAILED!"
  } else {
    Msg Info "VERIFYTIMING PASSED \n"
  }


  if {$do_bitstream == 1} {
    Msg Info "Starting write bitstream flow..."
    Msg Info "Run GENERATEPROGRAMMINGDATA ..."
    if {[catch {run_tool -name {GENERATEPROGRAMMINGDATA}  }] } {
      Msg Error "GENERATEPROGRAMMINGDATA FAILED!"
    } else {
      Msg Info "GENERATEPROGRAMMINGDATA PASSED."
    }
    Msg Info "Sourcing Hog/Tcl/integrated/post-bitstream.tcl"       
    source $path/../../Hog/Tcl/integrated/post-bitstream.tcl
  }

  #Go to repository path
  cd $repo_path

  lassign [GetRepoVersions [file normalize ./Top/$project_name] $repo_path] sha
  set describe [GetHogDescribe $sha]
  Msg Info "Git describe set to $describe"

  set dst_dir [file normalize "$bin_dir/$project_name\-$describe"]

  file mkdir $dst_dir

  #Version table
  if [file exists $main_folder/versions.txt] {
    file copy -force $main_folder/versions.txt $dst_dir
  } else {
    Msg Warning "No versions file found in $main_folder/versions.txt"
  }
  #Timing file
  set timing_file [file normalize "$repo_path/Projects/timing.txt" ]

  if [file exists $timing_file ] {
    file copy -force $timing_file $dst_dir/
  } else {
    Msg Warning "No timing file found, not a problem if running locally"
  }

}

Msg Info "All done."
cd $old_path
