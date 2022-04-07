#!/usr/bin/env tclsh
#   Copyright 2018-2022 The University of Birmingham
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
if {[IsISE]} {
  set tcl_path         [file normalize "[file dirname [info script]]"]
  source $tcl_path/cmdline.tcl
}
set parameters {
  {project.arg "" "Project name. If not set gets current project"}
  {outFile.arg "" "Name of output log file."}
  {log_list.arg "1" "Logs list files errors to outFile."}
  {log_conf.arg "1" "Logs hog.conf errors to outFile."}
  {recreate  "If set, it will create List Files from the project configuration"}
  {recreate_conf  "If set, it will create the project hog.conf file."}
  {force  "Force the overwriting of List Files. To be used together with \"-recreate\""}
  {pedantic  "Script fails in case of mismatch"}
  {ext_path.arg "" "Sets the absolute path for the external libraries."}
}

proc RelativeLocal {pathName fileName} {
  if {[string first [file normalize $pathName] [file normalize $fileName]] != -1} {
    return [Relative $pathName $fileName]
  } else {
    return ""
  }
}

proc CriticalAndLog {msg {outFile ""}} {
  Msg CriticalWarning $msg
  if {$outFile != ""} {
    set oF [open "$outFile" a+]
    puts $oF $msg
    close $oF
  }
}


set usage   "Checks if the list files matches the project ones. It can also be used to update the list files. \nUSAGE: $::argv0 \[Options\]"


set hog_path [file normalize "[file dirname [info script]]/.."]
set repo_path [file normalize "$hog_path/../.."]
source $hog_path/hog.tcl

if {[catch {array set options [cmdline::getoptions ::argv $parameters $usage]}]} {
  Msg Info [cmdline::usage $parameters $usage]
  exit 1
}


set ext_path $options(ext_path)


set ListErrorCnt 0
set ListSimErrorCnt 0
set ConfErrorCnt 0
set TotErrorCnt 0
set SIM_PROPS  [list "dofile" \
  "wavefile" \
  "topsim" \
  "runtime" \
]

if {![string equal $options(project) ""]} {
  set project $options(project)
  set group_name [file dirname $project]
  set project_name [file tail $project]
  Msg Info "Opening project $project_name..."

  if {[IsVivado]} {
    file mkdir "$repo_path/Projects/$project/$project_name.gen/sources_1"
    open_project "$repo_path/Projects/$project/$project_name.xpr"
    set proj_file [get_property DIRECTORY [current_project]]
    set proj_dir [file normalize $proj_file]
    set group_name [GetGroupName $proj_dir]
  }
} else {
  set project_name [get_projects [current_project]]
  set proj_file [get_property DIRECTORY [current_project]]
  set proj_dir [file normalize $proj_file]
  set group_name [GetGroupName $proj_dir]
}


if {$options(outFile)!= ""} {
  set outFile $options(outFile)
  if {[file exists $outFile]} {
    file delete $outFile
  }

  if {!$options(log_list)} {
    set outFile ""
  }

} else {
  set outFile ""
}


if {[file exists $repo_path/Top/$group_name/$project_name] && [file isdirectory $repo_path/Top/$group_name/$project_name] && $options(force) == 0} {
  set DirName Top_new/$group_name/$project_name
} else {
  set DirName Top/$group_name/$project_name
}




if { $options(recreate_conf) == 0 || $options(recreate) == 1 } {
  Msg Info "Checking $project_name list files..."
  # Get project libraries and propertiers from Vivado
  lassign [GetProjectFiles] prjLibraries prjProperties
  Msg Info "Retrieved Vivado project files..."
  # Get project libraries and properties from list files
  lassign [GetHogFiles -ext_path "$ext_path" -repo_path $repo_path "$repo_path/Top/$group_name/$project_name/list/"] listLibraries listProperties listMain
  # Get files generated at creation time
  set extraFiles [ReadExtraFileList "$repo_path/Projects/$group_name/$project_name/.hog/extra.files"]

  set prjIPs      [DictGet $prjLibraries IP]
  set prjXDCs     [DictGet $prjLibraries XDC]
  set prjOTHERs   [DictGet $prjLibraries OTHER]
  set prjSimDict  [DictGet $prjLibraries SIM]
  set prjSrcDict  [DictGet $prjLibraries SRC]


  # Removing duplicates from listlibraries and listProperties
  foreach library [dict keys $listLibraries] {
    set fileNames [DictGet $listLibraries $library]
    foreach fileName $fileNames {
      set idxs [lreverse [lreplace [lsearch -exact -all $fileNames $fileName] 0 0]]
      foreach idx $idxs {
        set fileNames [lreplace $fileNames $idx $idx]
      }
    }
    dict set listLibraries $library $fileNames
  }
  foreach property [dict keys $listProperties] {
    set props [lindex [dict get $listProperties $property] 0]
    foreach prop $props {
      set idxs [lreverse [lreplace [lsearch -exact -all $props $prop] 0 0]]
      foreach idx $idxs {
        set props [lreplace $props $idx $idx]
      }
    }
    dict set listProperties $property [list $props]
  }

  # Compare List files against project files
  set newListfiles [dict create]
  foreach key [dict keys $listLibraries] {
    if {[file extension $key] == ".ip" } {
      #check if project contains IPs specified in listfiles
      foreach IP [DictGet $listLibraries $key] {
        set idx [lsearch -exact $prjIPs $IP]
        set prjIPs [lreplace $prjIPs $idx $idx]
        if {$idx < 0} {
          if {$options(recreate) == 1} {
            Msg Info "$IP was found in list files but not in project."
          } else {
            CriticalAndLog "$IP found in list files but not in project IPs." $outFile
          }
          incr ListErrorCnt
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
          if {$options(recreate) == 1} {
            Msg Info "$XDC was removed from the project."
          } else {
            CriticalAndLog "$XDC not found in project constraints." $outFile
          }
          incr ListErrorCnt
        } else {
          dict lappend newListfiles $key [string trim "[RelativeLocal $repo_path $XDC] [DictGet $prjProperties $XDC]"]
        }
      }
    } elseif {[file extension $key] == ".sim"} {
      if {[dict exists $prjSimDict "[file rootname $key]_sim"]} {
        set prjSIMs [DictGet $prjSimDict "[file rootname $key]_sim"]
        # loop over list files associated with this simset
        foreach simlist [dict keys $listMain] {
          #check if project contains sim files specified in list files
          if {[DictGet $listMain $simlist] == $key } {
            foreach SIM [DictGet $listLibraries $simlist] {
              if {[file extension $SIM] == ".udo" || [file extension $SIM] == ".do" || [file extension $SIM] == ".tcl"} {
                set prop_sim_file [RelativeLocal $repo_path $SIM]
              } else {
                set prop_sim_file $SIM
              }
              set idx [lsearch -exact $prjSIMs $SIM]
              set prjSIMs [lreplace $prjSIMs $idx $idx]
              if {$idx < 0} {
                if {$options(recreate) == 1} {
                  Msg Info "$SIM was removed from the project."
                } else {
                  Msg Info "$SIM not found in project simulation libraries"
                }
                incr ListSimErrorCnt
              } else {
                dict lappend newListfiles $simlist [string trim "[RelativeLocal $repo_path $SIM] [DictGet $prjProperties $prop_sim_file]"]
              }
            }
            dict set prjSimDict "[file rootname $key]_sim" $prjSIMs
          }
        }
      } else {
        set main_lib [dict get $listMain $key]
        if { $main_lib == $key } {
          if {$options(recreate) == 1} {
            Msg Info "[file rootname $key]_sim fileset was removed from the project."
          }
        }
      }
    } elseif {[file extension $key] == ".src" } {
      #check if project contains sources specified in listfiles
      set prjSRCs [DictGet $prjSrcDict [file rootname $key]]

      foreach SRC [DictGet $listLibraries $key] {
        set idx [lsearch -exact $prjSRCs $SRC]
        set prjSRCs [lreplace $prjSRCs $idx $idx]
        if {$idx < 0} {
          set idx [lsearch -exact $prjOTHERs $SRC]
          set prjOTHERs [lreplace $prjOTHERs $idx $idx]
          if {$idx < 0} {
            if {$options(recreate) == 1} {
              Msg Info "$SRC was removed from the project."
            } else {
              CriticalAndLog "$SRC was found in Hog list files but not in project." $outFile
            }
            incr ListErrorCnt
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
            if {$options(recreate) == 1} {
              Msg Info "$SRC was removed from the project."
            } else {
              CriticalAndLog "$SRC not found in project source files." $outFile
            }
            incr ListErrorCnt
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
      incr ListErrorCnt
    }
  }

  # Check Extra Files
  foreach f [dict keys $extraFiles] {
    set idxIP [lsearch -exact $prjIPs $f]
    set prjIPs [lreplace $prjIPs $idxIP $idxIP]

    set idxSRC -1
    foreach lib [dict keys $prjSrcDict] {
      set prjSRCs [dict get $prjSrcDict $lib]
      set idxSRC [lsearch -exact $prjSRCs $f]
      set prjSRCs [lreplace $prjSRCs $idxSRC $idxSRC]
      dict set prjSrcDict $lib $prjSRCs
      if {$idxSRC > -1} {
        break
      }
    }

    set idxOTH [lsearch -exact $prjOTHERs $f]
    set prjOTHERs [lreplace $prjOTHERs $idxOTH $idxOTH]

    set idxXDC [lsearch -exact $prjXDCs $f]
    set prjXDCs [lreplace $prjXDCs $idxXDC $idxXDC]

    if {$idxIP < 0 && $idxSRC < 0 && $idxOTH < 0 && $idxXDC < 0 } {
      if {$options(recreate) == 1} {
        Msg Info "$f was found in list files but not in project."
      } else {
        CriticalAndLog "$f found in list files but not in project." $outFile
      }
      incr ListErrorCnt
    } else {
      # Check that the file hasn't changed
      set new_md5sum [Md5Sum $f]
      set old_md5sum [DictGet $extraFiles $f]
      if {$new_md5sum != $old_md5sum} {
        CriticalAndLog "$f in project has been modified from creation time. Please update the script you used to create the file and regenerate the project, or save the file outside the Projects/ directory and add it to a project list file" $outFile
      }
    }
  }


  foreach IP $prjIPs {
    incr ListErrorCnt
    if {[string equal [RelativeLocal $repo_path $IP] ""]} {
      if {[string equal [RelativeLocal $ext_path $IP] ""]} {
        Msg CriticalWarning "Source $IP is used in the project but is not in the repository or in a known external path."
      } else {
        if {$options(recreate) == 1} {
          Msg Info "External IP $IP was added to the project."
        } else {
          CriticalAndLog "External IP $IP is used in the project but is not in the list files." $outFile
        }
        dict lappend newListfiles Default.ext [string trim "[RelativeLocal $ext_path $IP] [Md5Sum $IP] [DictGet $prjProperties $IP]"]
      }
    } else {
      if {$options(recreate) == 1} {
        Msg Info "$IP was added to the project."
      } else {
        CriticalAndLog "$IP is used in the project but is not in the list files." $outFile
      }
      dict lappend newListfiles Default.src [string trim "[RelativeLocal $repo_path $IP] [DictGet $prjProperties $IP]"]
    }
  }

  foreach XDC $prjXDCs {
    incr ListErrorCnt
    if {[string equal [RelativeLocal $repo_path $XDC] ""]} {
      if {[string equal [RelativeLocal $ext_path $XDC] ""]} {
        CriticalAndLog "Source $XDC is used in the project but is not in the repository or in a known external path." $outFile
      } else {
        if {$options(recreate) == 1} {
          Msg Info "External source $XDC was added to the project."
        } else {
          CriticalAndLog "External source $XDC is used in the project but is not in the list files." $outFile
        }
        dict lappend newListfiles Default.ext [string trim "[RelativeLocal $ext_path $XDC] [Md5Sum $XDC] [DictGet $prjProperties $XDC]"]
      }
    } else {
      if {$options(recreate) == 1} {
        Msg Info "$XDC was added to the project."
      } else {
        CriticalAndLog "$XDC is used in the project but is not in the list files." $outFile
      }
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
      if {[file extension $SIM] == ".udo" || [file extension $SIM] == ".do" || [file extension $SIM] == ".tcl"} {
        set prop_sim_file [RelativeLocal $repo_path $SIM]
      } else {
        set prop_sim_file $SIM
      }
      if {[string range $key end-3 end]=="_sim"} {
        dict lappend newListfiles [string range $key 0 end-4].sim [string trim "[RelativeLocal $repo_path $SIM] [DictGet $prjProperties $prop_sim_file]"]
        if {$options(recreate) == 1} {
          Msg Info "$SIM was added to the project."
        }
      } else {
        dict lappend newListfiles $key.sim [string trim "[RelativeLocal $repo_path $SIM] [DictGet $prjProperties $prop_sim_file]"]
        if {$options(recreate) == 1} {
          Msg Info "$key simulation fileset does not respect Hog format. It will be renamed to ${key}_sim"
        }
      }
    }
  }

  foreach key [dict keys $prjSrcDict] {
    if {[string equal $key ""] } {
      continue
    }
    foreach SRC [dict get $prjSrcDict $key] {
      if {[string equal $SRC ""] } {
        continue
      }
      incr ListErrorCnt
      if {[string equal [RelativeLocal $repo_path $SRC] ""]} {
        if {[string equal [RelativeLocal $ext_path $SRC] ""]} {
          CriticalAndLog "Source $SRC is used in the project but is not in the repository or in a known external path." $outFile
        } else {
          if {$options(recreate) == 1} {
            Msg Info "External source $SRC was added to the project (library $key)."
          } else {
            CriticalAndLog "External source $SRC is used in the project (library $key) but is not in the list files." $outFile
          }
          dict lappend newListfiles ${key}.ext [string trim "[RelativeLocal $ext_path $SRC] [Md5Sum $SRC] [DictGet $prjProperties $SRC]"]
        }
      } else {
        if {$options(recreate) == 1} {
          Msg Info "$SRC was added to the project (library $key)."
        } else {
          CriticalAndLog "$SRC is used in the project (library $key) but is not in the list files." $outFile
        }
        dict lappend newListfiles ${key}.src [string trim "[RelativeLocal $repo_path $SRC] [DictGet $prjProperties $SRC]"]
      }
    }
  }

  foreach SRC $prjOTHERs {
    incr ListErrorCnt
    if {[string equal [RelativeLocal $repo_path $SRC] ""]} {
      if {[string equal [RelativeLocal $ext_path $SRC] ""]} {
        CriticalAndLog "Source $SRC is used in the project but is not in the repository or in a known external path." $outFile
      } else {
        if {$options(recreate) == 1} {
          Msg Info "External source $SRC was added to the project."
        } else {
          CriticalAndLog "External source $SRC is used in the project but is not in the list files." $outFile
        }
        dict lappend newListfiles Default.ext [string trim "[RelativeLocal $ext_path $SRC] [Md5Sum $SRC] [DictGet $prjProperties $SRC]"]
      }
    } else {
      if {$options(recreate) == 1} {
        Msg Info "$SRC was added to the project."
      } else {
        CriticalAndLog "$SRC is used in the project but is not in the list files." $outFile
      }
      dict lappend newListfiles Default.src [string trim "[RelativeLocal $repo_path $SRC] [DictGet $prjProperties $SRC]"]
    }
  }


  # Checking properties in list file
  foreach key [dict keys $listProperties] {
    foreach prop [lindex [DictGet $listProperties $key] 0] {
      set is_sim_prop 0
      foreach simprop $SIM_PROPS {
        if {[string first $simprop $prop] != -1} {
          set is_sim_prop 1

          break
        }
      }
      if {([file extension $key] == ".udo" || [file extension $key] == ".do" || [file extension $key] == ".tcl") && $is_sim_prop == 1} {
        set prop_file [RelativeLocal $repo_path $key]
      } else {
        set prop_file $key
      }

      if {[lsearch -nocase [DictGet $prjProperties $prop_file] $prop] < 0 && ![string equal $prop ""] && ![string equal $prop "XDC"]} {

        if {$options(recreate) == 1} {
          Msg Info "$prop_file property $prop was removed from the project."
        } else {
          if {$is_sim_prop == 1} {
            Msg Info "$prop_file property $prop is set in list files but not in project." $outFile
          } else {
            CriticalAndLog "$prop_file property $prop is set in list files but not in project." $outFile
          }
        }
        if {$is_sim_prop == 0} {
          incr ListErrorCnt
        } else {
          incr ListSimErrorCnt
        }
      }
    }
  }




  foreach key [dict keys $prjProperties] {
    if {[dict exists $extraFiles $key]} {
      # Skip property check for file generated at creation time.
      continue
    }
    foreach prop [DictGet $prjProperties $key] {
      set is_sim_prop 0
      foreach simprop $SIM_PROPS {
        if {[string first $simprop $prop] != -1} {
          set is_sim_prop 1
          break
        }
      }

      if {([file extension $key] == ".udo" || [file extension $key] == ".do" || [file extension $key] == ".tcl") && $is_sim_prop == 1} {
        set prop_file $repo_path/$key
      } else {
        set prop_file $key
      }

      if {[lsearch -nocase [lindex [DictGet $listProperties $prop_file] 0] $prop] < 0 && ![string equal $prop ""] && ![string equal $prop_file "Simulator"] && ![string equal $prop "top=top_[file root $project_name]"] } {
        if {$options(recreate) == 1} {
          Msg Info "$prop_file property $prop was added to the project."
        } else {
          if { $is_sim_prop == 1 } {
            Msg Info "$prop_file simulation property $prop is set in project but not in list files."
          } else {
            CriticalAndLog "$prop_file property $prop is set in project but not in list files!" $outFile
          }
        }
        if { $is_sim_prop == 0 } {
          incr ListErrorCnt
        } else {
          incr ListSimErrorCnt
        } 
      }
    }
  }

  #summary of errors found
  if  {$ListErrorCnt == 0} {
    Msg Info "Design List Files matches project. Nothing to do."
  }

  if  {$ListSimErrorCnt == 0} {
    Msg Info "Simulation List Files matches project. Nothing to do."
  }


  #recreating list files
  if {$options(recreate) == 1 && ($ListErrorCnt > 0 || $ListSimErrorCnt > 0) } {
    Msg Info "Updating list files in $repo_path/$DirName/list"

    #delete existing listFiles
    if {$options(force) == 1} {
      set listpath "$repo_path/Top/$group_name/$project_name/list/"
      foreach F [glob -nocomplain "$listpath/*.src" "$listpath/*.sub" "$listpath/*.ext"  "$listpath/*.con"] {
        if {[dict exists $newListfiles [file tail $F]] == 0} {
          file delete $F
        }
      }
    }

    file mkdir  $repo_path/$DirName/list
    foreach listFile [dict keys $newListfiles] {
      if {[string equal [file extension $listFile] ".sim"]} {
        if {[file exists "$repo_path/Top/$group_name/$project_name/list/$listFile"]} {
          set listSim [ParseFirstLineHogFiles "$repo_path/Top/$group_name/$project_name/list/" $listFile]
        } else {
          set listSim ""
        }
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
}


set conf_file "$repo_path/Top/$group_name/$project_name/hog.conf"
#checking project settings
if { $options(recreate) == 0 || $options(recreate_conf) == 1 } {

  if {!$options(log_conf)} {
    set outFile ""
  } else {
    set outFile $options(outFile)
  }


  #creating 4 dicts:
  #   - hogConfDict:     hog.conf properties (if exists)
  #   - defaultConfDict: default properties
  #   - projConfDict:    current project properties
  #   - newConfDict:     "new" hog.conf

  set hogConfDict [dict create]
  set defaultConfDict [dict create]
  set projConfDict [dict create]
  set newConfDict  [dict create]

  #filling hogConfDict
  if {[file exists $conf_file]} {
    set hogConfDict [ReadConf $conf_file]

    #convert hog.conf dict keys to uppercase
    foreach key [list main synth_1 impl_1] {
      set runDict [DictGet $hogConfDict $key]
      foreach runDictKey [dict keys $runDict ] {
        #do not convert paths
        if {[string first $repo_path [DictGet $runDict $runDictKey]]!= -1} {
          continue
        }
        dict set runDict [string toupper $runDictKey] [DictGet $runDict $runDictKey]
        dict unset runDict [string tolower $runDictKey]
      }
      dict set hogConfDict $key $runDict
    }
  } elseif {$options(recreate_conf)==0} {
    Msg Warning "$repo_path/Top/$group_name/$project_name/hog.conf not found. Skipping properties check"
  }


  #filling newConfDict with exististing hog.conf properties apart from main synth_1 and impl_1
  foreach key [dict keys $hogConfDict] {
    if {$key != "main" && $key != "synth_1" && $key != "impl_1"} {
      dict set newConfDict $key [DictGet $hogConfDict $key]
    }
  }

  #list of properties that must not be checked/written
  set PROP_BAN_LIST  [list DEFAULT_LIB \
    PART \
    IP_CACHE_PERMISSIONS \
    SIM.IP.AUTO_EXPORT_SCRIPTS \
    XPM_LIBRARIES \
    REPORT_STRATEGY \
    STEPS.WRITE_BITSTREAM.ARGS.READBACK_FILE \
    STEPS.WRITE_BITSTREAM.ARGS.VERBOSE \
    STEPS.SYNTH_DESIGN.TCL.PRE \
    STEPS.SYNTH_DESIGN.TCL.POST \
    STEPS.WRITE_BITSTREAM.TCL.PRE \
    STEPS.WRITE_BITSTREAM.TCL.POST \
    STEPS.INIT_DESIGN.TCL.POST \
    STEPS.ROUTE_DESIGN.TCL.POST \
    COMPXLIB.MODELSIM_COMPILED_LIBRARY_DIR \
    COMPXLIB.QUESTA_COMPILED_LIBRARY_DIR \
    COMPXLIB.RIVIERA_COMPILED_LIBRARY_DIR \
    COMPXLIB.ACTIVEHDL_COMPILED_LIBRARY_DIR \
    COMPXLIB.IES_COMPILED_LIBRARY_DIR \
    COMPXLIB.VCS_COMPILED_LIBRARY_DIR \
    NEEDS_REFRESH \
    AUTO_INCREMENTAL_CHECKPOINT.DIRECTORY \
  ]

#filling defaultConfDict and projConfDict
foreach proj_run [list [current_project] [get_runs synth_1] [get_runs impl_1]] {
  #creting dictionary for each $run
  set projRunDict [dict create]
  set defaultRunDict [dict create]
  #selecting only READ/WRITE properties
  set run_props [list]
  foreach propReport [split "[report_property  -return_string -all $proj_run]" "\n"] {

    if {[string equal "[lindex $propReport 2]" "false"]} {
      lappend run_props [lindex $propReport 0]
    }
  }

  foreach prop $run_props {
    #ignoring properties in $PROP_BAN_LIST
    if {$prop in $PROP_BAN_LIST} {
      set tmp  0
      #Msg Info "Skipping property $prop"
    } else {
      #Project values
      #   setting only relative paths
      if {[string first  $repo_path [get_property $prop $proj_run]] != -1} {
        dict set projRunDict [string toupper $prop] [Relative $repo_path [get_property $prop $proj_run]]
      } elseif {[string first  $ext_path [get_property $prop $proj_run]] != -1} {
        dict set projRunDict [string toupper $prop]  [Relative $ext_path [get_property $prop $proj_run]]
      } else {
        dict set projRunDict [string toupper $prop] [get_property $prop $proj_run]
      }

      # default values
      dict set defaultRunDict [string toupper $prop]  [list_property_value -default $prop $proj_run]
    }
  }
  if {"$proj_run" == "[current_project]"} {
    dict set projRunDict "PART" [get_property PART $proj_run]
    dict set projConfDict main  $projRunDict
    dict set defaultConfDict main $defaultRunDict
  } else {
    dict set projConfDict $proj_run  $projRunDict
    dict set defaultConfDict $proj_run $defaultRunDict
  }
}

#adding default properties set by default by Hog or after project creation
set defMainDict [dict create TARGET_LANGUAGE VHDL SIMULATOR_LANGUAGE MIXED]
dict set defMainDict IP_OUTPUT_REPO "[Relative $repo_path $proj_dir]/${project_name}.cache/ip"
dict set defaultConfDict main [dict merge [DictGet $defaultConfDict main] $defMainDict]

#comparing projConfDict, defaultConfDict and hogConfDict
set hasStrategy 0

foreach proj_run [list main synth_1 impl_1] {
  set projRunDict [DictGet $projConfDict $proj_run]
  set hogConfRunDict [DictGet $hogConfDict $proj_run]
  set defaultRunDict [DictGet $defaultConfDict $proj_run]
  set newRunDict [dict create]

  set strategy_str "STRATEGY strategy Strategy"
  foreach s $strategy_str {
    if {[dict exists $hogConfRunDict $s]} {
      set hasStrategy 1
    }
  }

  if {$hasStrategy == 1 && $options(recreate_conf) == 0} {
    Msg Warning "A strategy for run $proj_run has been defined inside hog.conf. This prevents Hog to compare the project properties. Please regenerate your hog.conf file using the dedicated Hog button."
  }

  foreach settings [dict keys $projRunDict] {
    set currset [DictGet  $projRunDict $settings]
    set hogset [DictGet  $hogConfRunDict $settings]
    set defset [DictGet  $defaultRunDict $settings]

    if {[string toupper $currset] != [string toupper $hogset] && [string toupper $currset] != [string toupper $defset]} {
      if {[string first "DEFAULT" [string toupper $currset]] != -1 && $hogset == ""} {
        continue
      }
      if {[string tolower $hogset] == "true" && $currset == 1} {
        continue
      }
      if {[string tolower $hogset] == "false" && $currset == 0} {
        continue
      }
      if {[string toupper $settings] != "STRATEGY"} {
        dict set newRunDict $settings $currset
        if {$options(recreate_conf) == 1} {
          incr ConfErrorCnt
          Msg Info "$proj_run setting $settings has been changed from \"$hogset\" in hog.conf to \"$currset\" in project."
        } elseif {[file exists $repo_path/Top/$group_name/$project_name/hog.conf] && $hasStrategy == 0} {
          CriticalAndLog "Project $proj_run setting $settings value \"$currset\" does not match hog.conf \"$hogset\"." $outFile
          incr ConfErrorCnt
        }
      }
    } elseif {[string toupper $currset] == [string toupper $hogset] && [string toupper $hogset] != "" && [string toupper $settings] != "STRATEGY"} {
      dict set newRunDict $settings $currset
    }
  }
  dict set newConfDict $proj_run $newRunDict

  #if anything remains into hogConfDict it means that something is wrong
  foreach settings [dict keys $hogConfRunDict] {
    if {[dict exists $projRunDict $settings]==0} {
      if {$settings in $PROP_BAN_LIST} {
        Msg CriticalWarning "In hog.conf file the property $proj_run is set to \"$settings\". This property is usually ignored and will not be automatically rewritten when automatically recreating hog.conf."
        continue
      }
      incr ConfErrorCnt
      if {$options(recreate_conf) == 0} {
        CriticalAndLog "hog.conf property $settings is not a valid Vivado property." $outFile
      } else {
        Msg Info "found property $settings in old hog.conf. This is not a valid Vivado property and will be deleted."
      }
    }
  }
}

#check if the version in the she-bang is the same as the IDE version, otherwise incr ConfErrorCnt
set actual_version [GetIDEVersion]
lassign [GetIDEFromConf $conf_file] ide conf_version
if {$actual_version != $conf_version} {
  CriticalAndLog "The version specified in the first line of hog.conf is wrong or no version was specified. If you want to run this project with $ide $actual_version, the first line of hog.conf should be: \#$ide $actual_version"
  incr ConfErrorCnt
}


if {$ConfErrorCnt == 0 && [file exists $conf_file ] == 1} {
  Msg Info "$conf_file matches project. Nothing to do"
}

#recreating hog.conf
if {$options(recreate_conf) == 1 && ($ConfErrorCnt > 0 || [file exists $conf_file] == 0 || $hasStrategy == 1)} {
  Msg Info "Updating configuration file $repo_path/$DirName/hog.conf."
  file mkdir  $repo_path/$DirName/list
  #writing configuration file
  set confFile $repo_path/$DirName/hog.conf
  set version [GetIDEVersion]
  WriteConf $confFile $newConfDict "vivado $version"
}

}


#closing project if a new one was opened
if {![string equal $options(project) ""]} {
  if {[IsVivado]} {
    close_project
  }
}


set TotErrorCnt [expr $ConfErrorCnt + $ListErrorCnt]

if {$options(recreate_conf) == 0 && $options(recreate) == 0} {
  if {$options(pedantic) == 1 && $TotErrorCnt > 0} {
    Msg Error "Number of errors: $TotErrorCnt. (Design List files = $ListErrorCnt, hog.conf = $ConfErrorCnt)."
  } elseif {$TotErrorCnt > 0} {
    Msg CriticalWarning "Number of errors: $TotErrorCnt (Design List files = $ListErrorCnt, hog.conf = $ConfErrorCnt)."
  } else {
    Msg Info "Design List files and hog.conf match project. All ok!"
  }

  if { $ListSimErrorCnt > 0 } {
    Msg Info "Number of mismatch in simulation list files = $ListSimErrorCnt"
  } else {
    Msg Info "Simulation list files match project. All ok!"
  }

}
Msg Info "All done."

return $TotErrorCnt
