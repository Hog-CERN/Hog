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
  {recreate  "If set, it will create listfiles from the project configuration"}
  {recreate_prjTcl  "If set, it will create the project tcl from the project configuration. To be used together with \"-recreate\""}
  {force  "Force the overwriting of listfiles. To be used together with \"-recreate\""}
  {pedantic  "Script fails in case of mismatch"}
}



proc DictGet {dictName keyName} {
  if {[dict exists $dictName $keyName]} {
    return [dict get $dictName $keyName]
  } else {
    return ""
  }

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
lassign [GetProjectFiles] prjLibraries prjProperties


lassign [GetHogFiles "$repo_path/Top/$project/list/"] listLibraries listProperties



set prjIPs  [DictGet $prjLibraries IP]
set prjXDCs  [DictGet $prjLibraries XDC]
set prjOTHERs [DictGet $prjLibraries OTHER] 
set prjSimDict  [DictGet $prjLibraries SIM]
set prjSrcDict  [DictGet $prjLibraries SRC]


set ErrorCnt 0
set newListfiles [dict create]

foreach key [dict keys $listLibraries] {
	if {[file extension $key] == ".ip" } {
		#check if project contains IPs specified in listfiles
		foreach IP [DictGet $listLibraries $key] {
			set idx [lsearch -exact $prjIPs $IP]
			set prjIPs [lreplace $prjIPs $idx $idx]
			if {$idx < 0} {
   		  Msg CriticalWarning "$IP not found in Project IPs! Was it removed from the project?"
        incr ErrorCnt
			} else {
        dict lappend newListfiles [file rootname $key].src "$IP [DictGet $prjProperties $IP]"
      }
		} 
	} elseif {[file extension $key] == ".con" } {
		#check if project contains XDCs specified in listfiles
		foreach XDC [DictGet $listLibraries $key] {
			set idx [lsearch -exact $prjXDCs $XDC]
			set prjXDCs [lreplace $prjXDCs $idx $idx]
			if {$idx < 0} {
   		  Msg CriticalWarning "$XDC not found in Project constraints! Was it removed from the project?"
        incr ErrorCnt
			} else {
        dict lappend newListfiles $key "$XDC [DictGet $prjProperties $XDC]"
      }
		} 
	} elseif {[file extension $key] == ".sim" } {
    if {[dict exists $prjSimDict "[file rootname $key]_sim"]} {
      set prjSIMs [DictGet $prjSimDict "[file rootname $key]_sim"]
		  #check if project contains sin files specified in listfiles    
		  foreach SIM [DictGet $listLibraries $key] {
			  set idx [lsearch -exact $prjSIMs $SIM]
			  set prjSIMs [lreplace $prjSIMs $idx $idx]
			  if {$idx < 0} {
     		  Msg CriticalWarning "$SIM not found in Project simulation files! Was it removed from the project?"
          incr ErrorCnt
			  } else {
          dict lappend newListfiles $key "$SIM [DictGet $prjProperties $SIM]"
        }
		  } 
      dict set prjSimDict "[file rootname $key]_sim" $prjSIMs
    } else {
      Msg CriticalWarning "[file rootname $key]_sim fileset not found in Project! Was it removed from the project?"
      incr ErrorCnt
    }
	} elseif {[file extension $key] == ".src" || [file extension $key] == ".sub" || [file extension $key] == ".ext" } {
		#check if project contains XDCs specified in listfiles
    set prjSRCs [DictGet $prjSrcDict [file rootname $key]] 
    
		foreach SRC [DictGet $listLibraries $key] {
			set idx [lsearch -exact $prjSRCs $SRC]
			set prjSRCs [lreplace $prjSRCs $idx $idx]
			if {$idx < 0} {
   				set idx [lsearch -exact $prjOTHERs $SRC]
			    set prjOTHERs [lreplace $prjOTHERs $idx $idx]
			    if {$idx < 0} {
       			Msg CriticalWarning "$SRC not found in Project source files! Was it removed from the project?"
            incr ErrorCnt
			    } else {
            dict lappend newListfiles $key "$SRC [DictGet $prjProperties $SRC]"
          }
			} else {
         dict lappend newListfiles $key "$SRC [DictGet $prjProperties $SRC]"
      }
		} 
    dict set prjSrcDict [file rootname $key] $prjSRCs
	} else {
		Msg CriticalWarning "$key listfiles format unrecognized by Hog."
    incr ErrorCnt
	}
	
}


foreach IP $prjIPs {
  Msg CriticalWarning "$IP is used in the project but is not in the listfiles."
  incr ErrorCnt
  dict lappend newListfiles Default.src "$IP [DictGet $prjProperties $IP]"
}

foreach XDC $prjXDCs {
  Msg CriticalWarning "$XDC is used in the project but is not in the listfiles."
  incr ErrorCnt
  dict lappend newListfiles Default.con "$XDC [DictGet $prjProperties $XDC]"
}

foreach key [dict key $prjSimDict] {
  if {[string equal $key ""] } {
    continue
  }
  foreach SIM [dict get $prjSimDict $key] {
    if {[string equal $SIM ""] } {
      continue
    }
    incr ErrorCnt
    Msg CriticalWarning "$SIM is used in the project simulation fileset $key but is not in the listfiles."
    dict lappend newListfiles ${key}.sim "$SIM [DictGet $prjProperties $SIM]"
  }
}

foreach key [dict key $prjSrcDict] {
  if {[string equal $key ""] } {
    continue
  }
  foreach SRC [dict get $prjSrcDict $key] {
    if {[string equal $SRC ""] } {
      continue
    }
    Msg CriticalWarning "$SRC is used in the project (library $key) but is not in the listfiles."
    incr ErrorCnt
    dict lappend newListfiles ${key}.sim "$SRC [DictGet $prjProperties $SRC]"
  }
}

foreach SRC $prjOTHERs {
  Msg CriticalWarning "$SRC is used in the project but is not in the listfiles."
  incr ErrorCnt
  dict lappend newListfiles Default.src "$SRC [DictGet $prjProperties $SRC]"
}


#checking file properties
foreach key [dict keys $listProperties] {
  foreach prop [lindex [DictGet $listProperties $key] 0] {
    if {[lsearch -nocase [lindex [DictGet $prjProperties $key] 0] $prop] < 0 && ![string equal $prop ""]} {
 			Msg CriticalWarning "$key property $prop is set in listfiles but not in Project!"
      incr ErrorCnt
    } 
  }
}


foreach key [dict keys $prjProperties] {
  foreach prop [lindex [DictGet $prjProperties $key] 0] {
    #puts "FILE $key: PROPERTY $prop"
    if {[lsearch -nocase [lindex [DictGet $listProperties $key] 0] $prop] < 0 && ![string equal $prop ""] && ![string equal $key "Simulator"] } {
 			Msg CriticalWarning "$key property $prop is set in Project but not in listfiles!"
      incr ErrorCnt
    } 
  }
}

#summary of errors found
if {$options(pedantic) == 1} {
  Msg Error "Number of errors: $ErrorCnt"
} else {
  Msg CriticalWarning "Number of errors: $ErrorCnt"
}

#recreating list files
if {$options(recreate) == 1} {
  if {[file exists $repo_path/Top] && [file isdirectory $repo_path/Top] && $options(force) == 0} {
    set DirName Top_new/$project/
  } else {
    set DirName Top/$project/
  }
  file mkdir  $repo_path/$DirName/list
  foreach listFile [dict keys $newListfiles] {
    set lFd [open $repo_path/$DirName/list/$listFile w]
    if {[string equal [file extension $listFile] ".sim"]} {
      puts $lFd "#Simulator [DictGet $prjProperties Simulator]"
    }
    foreach ln [DictGet $newListfiles $listFile] {
      puts $lFd "$ln"
    }
  }

  if {$options(recreate_prjTcl) == 1} {
    set lFd [open $repo_path/$DirName/$project.tcl w]
    puts $lFd "#vivado"

    puts $lFd "#### FPGA and Vivado strategies and flows

set FPGA [get_property PART [current_project]]\"
set SYNTH_STRATEGY \"[get_property STRATEGY [get_runs synth_1]]\"
set SYNTH_FLOW \"[get_property FLOW [get_runs synth_1]]\"
set IMPL_STRATEGY \"[get_property STRATEGY [get_runs impl_1]]\"
set IMPL_FLOW \"[get_property FLOW [get_runs impl_1]]\"
set DESIGN \"\[file rootname \[file tail \[info script\]\]\]\"
set PATH_REPO \"\[file normalize \[file dirname \[info script\]\]\]/../../\"
set SIMULATOR \"[DictGet $prjProperties Simulator]\""



    #properties
    puts $lFd "set PROPERTIES \[dict create \\"
    foreach proj_run [get_runs] {
      puts $lFd " $proj_run \[dict create \\"
      foreach prop [list_property [get_runs $proj_run]] {
        set Dval [list_property_value -default $prop [get_runs $proj_run]]
        set val [get_property $prop [get_runs $proj_run]]
        if {$Dval!=$val} {
          puts $lFd "   $prop  $val \\"
        }
      
      }
      puts $lFd " \] \\"
    }

    #shall we also add custom project properties?
     puts $lFd "\]"

    puts $lFd "source \$PATH_REPO/Hog/Tcl/create_project.tcl"
  }
}

