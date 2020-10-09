#!/usr/bin/env tclsh
#   Copyright 2018-2020 The University of Birmingham
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

# @file
# Check if the content of list files matches the project. It can also be used to update the list files.

#parsing command options
if {[catch {package require cmdline} ERROR]} {
  puts "$ERROR\n If you are running this script on tclsh, you can fix this by installing 'tcllib'" 
  return
}
set parameters {
}

set usage   "USAGE: $::argv0 <project>"


set hog_path [file normalize "[file dirname [info script]]/.."]
set repo_path [pwd]
cd $hog_path
source ./hog.tcl

if {[catch {array set options [cmdline::getoptions ::argv $parameters $usage]}] || $::argc eq 0 } {
  Msg Info [cmdline::usage $parameters $usage]
  cd $repo_path
  exit 1
} else {
  set project [lindex $argv 0]
  set main_folder [file normalize "$repo_path/VivadoProject/$project/$project.runs/"]
}

Msg Info "Opening project $project..."

open_project ../../VivadoProject/$project/$project.xpr


Msg Info "Checkin $project list files..."
lassign [GetProjectFiles] prj_src_files dummy

puts "$prj_src_files"
puts "Dict size: [dict size $prj_src_files]"
dict for {id info} $prj_src_files {
   puts "Dict $id: $info"
    
}


dict for {id info} $dummy {
   puts "Dict $id: $info"
    
}


Msg Info "Checking simulation listfiles..."


lassign [GetHogFiles "$repo_path/Top/$project/list/"] libraries properties
dict for {id value} $libraries {
    puts "Dict $id: $value"
    
}



dict for {id value} $properties {
    puts "Dict $id: $value"
    
}

set prjIPs  [dict get $prj_src_files IP]
set prjXDCs  [dict get $prj_src_files XDC]


foreach key [dict keys $libraries] {
	if {[file extension $key] == ".ip" } {
		#check if project contains IPs specified in listfiles
		foreach IP [dict get $libraries $key] {
			set idx [lsearch -exact $prjIPs $IP]
			set prjIPs [lreplace $prjIPs $idx $idx]
			if {$idx < 0} {
   				 Msg CriticalWarning "$IP not found in Project IPs! Was it removed from the project?"
			}
		} 
	} elseif {[file extension $key] == ".con" } {
		#check if project contains IPs specified in listfiles
		foreach XDC [dict get $libraries $key] {
			set idx [lsearch -exact $prjXDCs $XDC]
			set prjXDCs [lreplace $prjXDCs $idx $idx]
			if {$idx < 0} {
   				 Msg CriticalWarning "$XDC not found in Project constraints! Was it removed from the project?"
			}
		} 
	} else {
		puts "Not found: $key "
	}
	
}


foreach IP $prjIPs {
    Msg CriticalWarning "$IP is used in the project but is not in the listfiles."
}

foreach XDC $prjXDCs {
    Msg CriticalWarning "$XDC is used in the project but is not in the listfiles."
}



