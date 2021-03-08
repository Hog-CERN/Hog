#!/usr/bin/env tclsh
#   Copyright 2018-2021 The University of Birmingham
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
if { [string first PlanAhead [version]] == 0 } {
    set tcl_path         [file normalize "[file dirname [info script]]"]
    source $tcl_path/cmdline.tcl
}
set parameters {
  {project.arg "" "Project name. If not set gets current project"}
  {recreate  "If set, it will create List Files from the project configuration"}
  {recreate_conf  "If set, it will create the project hog.conf file."}
  {force  "Force the overwriting of List Files. To be used together with \"-recreate\""}
  {pedantic  "Script fails in case of mismatch"}
  {ext_path.arg "" "Sets the absolute path for the external libraries."}
}



proc DictGet {dictName keyName} {
  if {[dict exists $dictName $keyName]} {
    return [dict get $dictName $keyName]
  } else {
    return ""
  }
}

proc RelativeLocal {pathName fileName} {
  if {[string first [file normalize $pathName] [file normalize $fileName]] != -1} {
    return [Relative $pathName $fileName]
  } else {
    return ""
  }
}


set usage   "Checks if the list files matches the project ones. It can also be used to update the list files. \nUSAGE: $::argv0 \[Options\]"


set hog_path [file normalize "[file dirname [info script]]/.."]
set repo_path [file normalize "$hog_path/../.."]
#cd $hog_path
source $hog_path/hog.tcl

if {[catch {array set options [cmdline::getoptions ::argv $parameters $usage]}]} {
  Msg Info [cmdline::usage $parameters $usage]
  #cd $repo_path
  exit 1
}


set ext_path $options(ext_path)

if {![string equal $options(project) ""]} {
  set project $options(project)
  Msg Info "Opening project $project..."
  if { [string first PlanAhead [version]] != 0 } {
    open_project "$repo_path/Projects/$project/$project.xpr"
  }
} else {
  set project [get_projects [current_project]]
}





Msg Info "Checking $project list files..."
lassign [GetProjectFiles] prjLibraries prjProperties


lassign [GetHogFiles -ext_path "$ext_path" "$repo_path/Top/$project/list/"] listLibraries listProperties

set prjIPs  [DictGet $prjLibraries IP]
set prjXDCs  [DictGet $prjLibraries XDC]
set prjOTHERs [DictGet $prjLibraries OTHER]
set prjSimDict  [DictGet $prjLibraries SIM]
set prjSrcDict  [DictGet $prjLibraries SRC]


#clening doubles from listlibraries and listProperties
foreach library [dict keys $listLibraries] {
  set fileNames [DictGet $listLibraries $library]
  foreach fileName $fileNames {
    set idxs [lreplace [lsearch -exact -all $fileNames $fileName] 0 0]
    foreach idx $idxs {
		  set fileNames [lreplace $fileNames $idx $idx]
    }
  }
  dict set listLibraries $library $fileNames
}
foreach property [dict keys $listProperties] {
  set props [lindex [dict get $listProperties $property] 0]
  foreach prop $props {
    set idxs [lreplace [lsearch -exact -all $props $prop] 0 0]
    foreach idx $idxs {
		  set props [lreplace $props $idx $idx]
    }
  }
  dict set listProperties $property [list $props]
}

#checking list files
set ErrorCnt 0
set newListfiles [dict create]

foreach key [dict keys $listLibraries] {
	if {[file extension $key] == ".ip" } {
		#check if project contains IPs specified in listfiles
		foreach IP [DictGet $listLibraries $key] {
			set idx [lsearch -exact $prjIPs $IP]
			set prjIPs [lreplace $prjIPs $idx $idx]
			if {$idx < 0} {
   		  Msg CriticalWarning "$IP not found in project IPs! Was it removed from the project?"
        incr ErrorCnt
			} else {
        dict lappend newListfiles [file rootname $key].src [string trim "[RelativeLocal $repo_path $IP] [DictGet $prjProperties $IP]"]
      }
		}
	} elseif {[file extension $key] == ".con" } {
		#check if project contains XDCs specified in listfiles
		foreach XDC [DictGet $listLibraries $key] {
			set idx [lsearch -exact $prjXDCs $XDC]
			set prjXDCs [lreplace $prjXDCs $idx $idx]
			if {$idx < 0} {
   		  Msg CriticalWarning "$XDC not found in project constraints! Was it removed from the project?"
        incr ErrorCnt
			} else {
        dict lappend newListfiles $key [string trim "[RelativeLocal $repo_path $XDC] [DictGet $prjProperties $XDC]"]
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
     		  Msg CriticalWarning "$SIM not found in project simulation files! Was it removed from the project?"
          incr ErrorCnt
			  } else {
          dict lappend newListfiles $key [string trim "[RelativeLocal $repo_path $SIM] [DictGet $prjProperties $SIM]"]
        }
		  }
      dict set prjSimDict "[file rootname $key]_sim" $prjSIMs
    } else {
      Msg CriticalWarning "[file rootname $key]_sim fileset not found in project! Was it removed from the project?"
      incr ErrorCnt
    }
	} elseif {[file extension $key] == ".src" || [file extension $key] == ".sub"} {
	  #check if project contains sources specified in listfiles
	  set prjSRCs [DictGet $prjSrcDict [file rootname $key]]
	  
	  foreach SRC [DictGet $listLibraries $key] {
	    set idx [lsearch -exact $prjSRCs $SRC]
	    set prjSRCs [lreplace $prjSRCs $idx $idx]
	    if {$idx < 0} {
	      set idx [lsearch -exact $prjOTHERs $SRC]
	      set prjOTHERs [lreplace $prjOTHERs $idx $idx]
	      if {$idx < 0} {
		Msg CriticalWarning "$SRC not found in project source files! Was it removed from the project?"
		incr ErrorCnt
	      } else {
		dict lappend newListfiles $key [string trim "[RelativeLocal $repo_path $SRC] [DictGet $prjProperties $SRC]"]
	      }
	    } else {
	      dict lappend newListfiles $key [string trim "[RelativeLocal $repo_path $SRC] [DictGet $prjProperties $SRC]"]
	    }
	  }
	  dict set prjSrcDict [file rootname $key] $prjSRCs
	} elseif {[file extension $key] == ".ext" } {
	  #check if project contains external files specified in listfiles
	  set prjSRCs [DictGet $prjSrcDict [file rootname $key]]
	  
	  foreach SRC [DictGet $listLibraries $key] {
	    set idx [lsearch -exact $prjSRCs $SRC]
	    set prjSRCs [lreplace $prjSRCs $idx $idx]
	    if {$idx < 0} {
	      set idx [lsearch -exact $prjOTHERs $SRC]
	      set prjOTHERs [lreplace $prjOTHERs $idx $idx]
	      if {$idx < 0} {
		Msg CriticalWarning "$SRC not found in project source files! Was it removed from the project?"
		incr ErrorCnt
	      } else {
		dict lappend newListfiles $key [string trim "[RelativeLocal $ext_path $SRC] [Md5Sum $SRC] [DictGet $prjProperties $SRC]"]
		dict lappend prjProperties $SRC [Md5Sum $SRC]
	      }
	    } else {
	      dict lappend newListfiles $key [string trim "[RelativeLocal $ext_path $SRC] [Md5Sum $SRC] [DictGet $prjProperties $SRC]"]
	      dict lappend prjProperties $SRC [Md5Sum $SRC]
	    }
	  }
	  dict set prjSrcDict [file rootname $key] $prjSRCs
	} else {
	  Msg CriticalWarning "$key list file format unrecognized by Hog."
	  incr ErrorCnt
	}
  
}


foreach IP $prjIPs {
  incr ErrorCnt
  if {[string equal [RelativeLocal $repo_path $IP] ""]} {
    if {[string equal [RelativeLocal $ext_path $IP] ""]} {
      Msg CriticalWarning "Source $IP is used in the project but is not in the repository or in a known external path."
    } else {
      Msg CriticalWarning "External IP $IP is used in the project but is not in the list files."
      dict lappend newListfiles Default.ext [string trim "[RelativeLocal $ext_path $IP] [Md5Sum $IP] [DictGet $prjProperties $IP]"]
    }
  } else {
    Msg CriticalWarning "$IP is used in the project but is not in the list files."
    dict lappend newListfiles Default.src [string trim "[RelativeLocal $repo_path $IP] [DictGet $prjProperties $IP]"]
  }
}

foreach XDC $prjXDCs {
  incr ErrorCnt
  if {[string equal [RelativeLocal $repo_path $XDC] ""]} {
    if {[string equal [RelativeLocal $ext_path $XDC] ""]} {
      Msg CriticalWarning "Source $XDC is used in the project but is not in the repository or in a known external path."
    } else {
      Msg CriticalWarning "External source $XDC is used in the project but is not in the list files."
      dict lappend newListfiles Default.ext [string trim "[RelativeLocal $ext_path $XDC] [Md5Sum $XDC] [DictGet $prjProperties $XDC]"]
    }
  } else {
    Msg CriticalWarning "$XDC is used in the project but is not in the list files."
    dict lappend newListfiles Default.con [string trim "[RelativeLocal $repo_path $XDC] [DictGet $prjProperties $XDC]"]
  }
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
    Msg CriticalWarning "$SIM is used in the project simulation fileset $key but is not in the list files."
    dict lappend newListfiles [string range $key 0 end-4].sim [string trim "[RelativeLocal $repo_path $SIM] [DictGet $prjProperties $SIM]"]
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
    incr ErrorCnt
    if {[string equal [RelativeLocal $repo_path $SRC] ""]} {
      if {[string equal [RelativeLocal $ext_path $SRC] ""]} {
        Msg CriticalWarning "Source $SRC is used in the project but is not in the repository or in a known external path."
      } else {
        Msg CriticalWarning "External source $SRC is used in the project (library $key) but is not in the list files."
        dict lappend newListfiles ${key}.ext [string trim "[RelativeLocal $ext_path $SRC] [Md5Sum $SRC] [DictGet $prjProperties $SRC]"]
      }
    } else {
      Msg CriticalWarning "$SRC is used in the project (library $key) but is not in the list files."
      dict lappend newListfiles ${key}.src [string trim "[RelativeLocal $repo_path $SRC] [DictGet $prjProperties $SRC]"]
   }
  }
}

foreach SRC $prjOTHERs {
  incr ErrorCnt
  if {[string equal [RelativeLocal $repo_path $SRC] ""]} {
    if {[string equal [RelativeLocal $ext_path $SRC] ""]} {
      Msg CriticalWarning "Source $SRC is used in the project but is not in the repository or in a known external path."
    } else {
      Msg CriticalWarning "External source $SRC is used in the project but is not in the list files."
      dict lappend newListfiles Default.ext [string trim "[RelativeLocal $ext_path $SRC] [Md5Sum $SRC] [DictGet $prjProperties $SRC]"]
    }
  } else {
    Msg CriticalWarning "$SRC is used in the project but is not in the list files."
    dict lappend newListfiles Default.src [string trim "[RelativeLocal $repo_path $SRC] [DictGet $prjProperties $SRC]"]
  }
}


#checking file properties
foreach key [dict keys $listProperties] {
  foreach prop [lindex [DictGet $listProperties $key] 0] {
    if {[lsearch -nocase [DictGet $prjProperties $key] $prop] < 0 && ![string equal $prop ""] && ![string equal $prop "XDC"]} {
      Msg CriticalWarning "$key property $prop is set in list files but not in project!"
      incr ErrorCnt
    }
  }
}


foreach key [dict keys $prjProperties] {
  foreach prop [DictGet $prjProperties $key] {
    #puts "FILE $key: PROPERTY $prop"
    if {[lsearch -nocase [lindex [DictGet $listProperties $key] 0] $prop] < 0 && ![string equal $prop ""] && ![string equal $key "Simulator"] && ![string equal $prop "top=top_[file root $project]"]} {
      Msg CriticalWarning "$key property $prop is set in project but not in list files!"
      incr ErrorCnt
    }
  }
}

#summary of errors found
if {$options(pedantic) == 1 && $ErrorCnt > 0} {
  Msg Error "Number of errors: $ErrorCnt"
} elseif {$ErrorCnt > 0} {
  Msg CriticalWarning "Number of errors: $ErrorCnt"
} else {
  Msg Info "List Files matches project. All ok!"
}

if {[file exists $repo_path/Top/$project] && [file isdirectory $repo_path/Top/$project] && $options(force) == 0} {
  set DirName Top_new/$project
} else {
  set DirName Top/$project
}

#recreating list files
if {$options(recreate) == 1} {
  Msg Info "Updating list files in $repo_path/$DirName/list"


  file mkdir  $repo_path/$DirName/list
  foreach listFile [dict keys $newListfiles] {
    if {[string equal [file extension $listFile] ".sim"]} {
      set listSim [ParseFirstLineHogFiles "$repo_path/Top/$project/list/" $listFile]
      set lFd [open $repo_path/$DirName/list/$listFile w]
      if {[string equal -nocase [lindex [split $listSim " "] 0] "Simulator"] && [string equal -nocase [lindex [split $listSim " "] 1] "skip_simulation"]} {
         puts $lFd "#$listSim"
      } else {
        puts $lFd "#Simulator [DictGet $prjProperties Simulator]"
      }
    } else {
      set lFd [open $repo_path/$DirName/list/$listFile w]
    }
    foreach ln [DictGet $newListfiles $listFile] {
      puts $lFd "$ln"
    }
    close $lFd
  }
}



#recreating hog.conf
if {$options(recreate_conf) == 1} {

  #reading old hog.conf if exist and copy the parameters
  set confFile $repo_path/$DirName/hog.conf
  set paramDict [dict create]
  if {[file exists $confFile]} {
    set oldConfDict [ReadConf $confFile]
    if {[dict exists $oldConfDict parameters]} {
      set paramDict [dict get $oldConfDict parameters]
    }
  }

  #list of properties that don't have to be written
  set PROP_BAN_LIST  [list DEFAULT_LIB \
                           PART \
                           STEPS.SYNTH_DESIGN.TCL.PRE \
                           STEPS.SYNTH_DESIGN.TCL.POST \
                           STEPS.WRITE_BITSTREAM.TCL.PRE \
                           STEPS.WRITE_BITSTREAM.TCL.POST \
                           STEPS.ROUTE_DESIGN.TCL.POST \
                     ]



  Msg Info "Updating configuration file $repo_path/$DirName/hog.conf"
  file mkdir  $repo_path/$DirName/list

  set confDict  [dict create]

  #writing not default properties for current_project, synth_1 and impl_1
  set runs [list [current_project]]
  lappend runs [list [get_runs synth*]]
  lappend runs [list [get_runs impl*]]
  foreach proj_run $runs {
    #creting dictionary for each $run
    set projRunDict [dict create]
    #selecting only READ/WRITE properties 
    set run_props [list]
    foreach propReport [split "[report_property  -return_string -all $proj_run]" "\n"] {

      if {[string equal "[lindex $propReport 2]" "false"]} { 
        lappend run_props [lindex $propReport 0]
      }
    }

    foreach prop $run_props {
      #current values
      set val [get_property $prop $proj_run]  
      #ignoring properties in $PROP_BAN_LIST and properties containing repo_path
      if {$prop in $PROP_BAN_LIST || [string first $repo_path $val] != -1} { 
        Msg Info "Skipping property $prop"
      } else { 
        # default values
        set Dval [list_property_value -default $prop $proj_run] 
        if {$Dval!=$val} {
          dict set projRunDict $prop  $val
        }
      }
    }
    if {"$proj_run" == "[current_project]"} {
      dict set projRunDict "PART" [get_property PART $proj_run]  
      dict set confDict main  $projRunDict
    } else {
      dict set confDict $proj_run  $projRunDict
    }
  }

  #adding volatile properties
  dict set confDict parameters $paramDict 


  #writing configuration file  
  WriteConf $confFile $confDict "vivado"
}

#closing project if a new one was opened
if {![string equal $options(project) ""]} {
    if { [string first PlanAhead [version]] != 0 } {
        close_project
    }
}
