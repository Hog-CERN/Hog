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
# @brief Collection of Tcl functions used in Vivado/Quartus scripts


## @file hog.tcl
# @brief Collection of Tcl functions used in Vivado/Quartus scripts

### @brief Display a Vivado/Quartus/Tcl-shell info message
#
# @param[in] level  the severity level of the message given as string or integer: status/extra_info 0, info 1, warning 2, critical warning 3, error 4.
# @param[in] msg    the message text.
# @param[in] title  the name of the script displaying the message, if not given, the calling script name will be used by default.
#
#### GLOBAL CONSTANTS
set CI_STAGES {"simulate_project" "generate_project"}
set CI_PROPS {"-synth_only"}

#### FUNCTIONS
proc Msg {level msg {title ""}} {
  set level [string tolower $level]
  if {$level == 0 || $level == "status" || $level == "extra_info"} {
    set vlevel {STATUS}
    set qlevel extra_info
  } elseif {$level == 1 || $level == "info"} {
    set vlevel {INFO}
    set qlevel info
  } elseif {$level == 2 || $level == "warning"} {
    set vlevel {WARNING}
    set qlevel warning
  } elseif {$level == 3 || [string first "critical" $level] !=-1} {
    set vlevel {CRITICAL WARNING}
    set qlevel critical_warning
  } elseif {$level == 4 || $level == "error"} {
    set vlevel {ERROR}
    set qlevel "error"
  } else {
    puts "Hog Error: level $level not defined"
    exit -1
  }

  if {$title == ""} {set title [lindex [info level [expr [info level]-1]] 0]}
  if {[info commands send_msg_id] != ""} {
    # Vivado
    set status [catch {send_msg_id Hog:$title-0 $vlevel $msg}]
    if {$status != 0} {
      exit $status
    }
  } elseif {[info commands post_message] != ""} {
    # Quartus
    post_message -type $qlevel "Hog:$title $msg"
  } else {
    # Tcl Shell
    puts "*** Hog:$title $vlevel $msg"
  }
}

## @brief Write a into file, if the file exists, it will append the string
#
# @param[out] File The log file onto which write the message
# @param[in]  msg  The message text
#
proc WriteToFile {File msg} {
  set f [open $File a+]
  puts $f $msg
  close $f
}

## @brief Sets a property of an object to a given value.
#
# It automatically recognises whether it is in Vivado or Quartus mode
#
# @param[out] property:
# @param[in] value:
# @param[out] object
#
proc  SetProperty {property value object} {
  if {[info commands set_property] != ""} {
        # Vivado
    set_property $property $value $object

  } elseif {[info commands quartus_command] != ""} {
        # Quartus

  } else {
        # Tcl Shell
    puts "***DEBUG Hog:SetProperty $property to $value of $object"
  }


}

## @brief Retrieves the value of a property of an object
#
# It automatically recognises whether it is in Vivado or Quartus mode
#
# @param[in] property the name of the property to be retrieved
# @param[in] object   the object from which to retrieve the property
#
# @returns            the value of object.property
#
proc  GetProperty {property object} {
  if {[info commands get_property] != ""} {
        # Vivado
    return [get_property -quiet $property $object]

  } elseif {[info commands quartus_command] != ""} {
        # Quartus
    return ""
  } else {
        # Tcl Shell
    puts "***DEBUG Hog:GetProperty $property of $object"
    return "DEBUG_propery_value"
  }
}

## @brief Sets the value of a parameter to a given value.
#
# This function is a wrapper for set_param $parameter $value
#
# @param[out] parameter the parameter whose value must be set
# @param[in]  value     the value of the parameter

proc  SetParameter {parameter value } {
  set_param $parameter $value
}

## @brief Adds the file containing the top module to the project
#
# It automatically recognises whether it is in Vivado or Quartus mode
#
# @param[in] top_module name of the top module, expected @c top_<project_name>
# @param[in] top_file   name of the file containing the top module
# @param[in] sources     list of source files
proc AddTopFile {top_module top_file sources} {
  if {[info commands launch_chipscope_analyzer] != ""} {
        #VIVADO_ONLY
    add_files -norecurse -fileset $sources $top_file
  } elseif {[info commands project_new] != ""} {
        #QUARTUS ONLY
    set file_type [FindFileType $top_file]
    set hdl_version [FindVhdlVersion $top_file]
    set_global_assignment -name $file_type $top_file
  } else {
    puts "Adding project top module $top_module"
  }
}

## @brief set the top module as top module.
#
# It automatically recognises whether it is in Vivado or Quartus mode
#
# @param[out] top_module  name of the top module
# @param[in]  sources     list of all source files in the project
#
proc SetTopProperty {top_module sources} {
  Msg Info "Setting TOP property to $top_module module"
  if {[info commands launch_chipscope_analyzer] != ""} {
        #VIVADO_ONLY
    set_property "top" $top_module $sources
  } elseif {[info commands project_new] != ""} {
        #QUARTUS ONLY
    set_global_assignment -name TOP_LEVEL_ENTITY $top_module
  }

}

## @brief Retrieves the project named proj
#
#  It automatically recognises whether it is in Vivado or Quartus mode
#
#  @param[in] proj  the project name
#
#  @return          the project $proj
#
proc GetProject {proj} {
  if {[info commands get_projects] != ""} {
        # Vivado
    return [get_projects $proj]

  } elseif {[info commands quartus_command] != ""} {
        # Quartus
    return ""
  } else {
        # Tcl Shell
    puts "***DEBUG Hog:GetProject $project"
    return "DEBUG_project"
  }

}

## @brief Gets a list of synthesis and implementation runs in the current project that match a run (passed as parameter)
#
# The run name is matched against the input parameter
#
#  @param[in] run  the run identifier
#
#  @return         a list of synthesis and implementation runs matching the parameter
#
proc GetRun {run} {
  if {[info commands get_projects] != ""} {
        # Vivado
    return [get_runs -quiet $run]

  } elseif {[info commands quartus_command] != ""} {
        # Quartus
    return ""
  } else {
        # Tcl Shell
    puts "***DEBUG Hog:GetRun $run"
    return "DEBUG_run"
  }
}

## @brief Gets a list of files contained in the current project that match a file name (passed as parameter)
#
# The file name is matched against the input parameter.
# IF no parameter if passed returns a list of all files in the project
#
#  @param[in] file name (or part of it)
#
#  @return         a list of files matching the parameter
#
proc GetFile {file} {
  if {[info commands get_files] != ""} {
        # Vivado
    return [get_files $file]

  } elseif {[info commands quartus_command] != ""} {
        # Quartus
    return ""
  } else {
        # Tcl Shell
    puts "***DEBUG Hog:GetFile $file"
    return "DEBUG_file"
  }
}

## @brief Creates a new fileset
#
# A file set is a list of files with a specific function within the project.
#
# @param[in] fileset
#
# @returns The create_fileset command returns the name of the newly created fileset
#
proc CreateFileSet {fileset} {
  set a  [create_fileset -srcset $fileset]
  return  $a
}

## @brief Retrieves a fileset
#
# Gets a list of filesets in the current project that match a specified search pattern.
# The default command gets a list of all filesets in the project.
#
# @param[in] fileset the name to be checked
#
# @return a list of filesets in the current project that match the specified search pattern.
#
proc GetFileSet {fileset} {
  set a  [get_filesets $fileset]
  return  $a
}

## @brief Add a new file to a fileset
#
# @param[in] file    name of the files to add. NOTE: directories are not supported.
# @param[in] fileset fileset name
#
proc AddFile {file fileset} {
  add_files -norecurse -fileset $fileset $file
}

## @brief gets the full path to the /../../ folder
#
# @return "[file normalize [file dirname [info script]]]/../../"
#
proc GetRepoPath {} {
  return "[file normalize [file dirname [info script]]]/../../"
}

## @brief Compare two semantic versions
#
# @param[in] ver1 a list of 3 numbers M m p
# @param[in] ver2 a list of 3 numbers M m p
#
# @return Return 1 ver1 is greather than ver2, 0 if they are equal, and -1 if ver2 is greater than ver1
#
proc CompareVersion {ver1 ver2} {
  set ver1 [expr [lindex $ver1 0]*100000 + [lindex $ver1 1]*1000 + [lindex $ver1 2]]
  set ver2 [expr [lindex $ver2 0]*100000 + [lindex $ver2 1]*1000 + [lindex $ver2 2]]
  if {$ver1 > $ver2 } {
    set ret 1
  } elseif {$ver1 == $ver2} {
    set ret 0
  } else {
    set ret -1
  }
  return [expr $ret]
}

## @brief Check git version installed in this machine
#
# @param[in] target_version the version required by the current project
#
# @return Return 1 if the system git version is greater or equal to the target
#
proc GitVersion {target_version} {
  set ver [split $target_version "."]
  set v [Git --version]
  Msg Info "Found Git version: $v"
  set current_ver [split [lindex $v 2] "."]
  set target [expr [lindex $ver 0]*100000 + [lindex $ver 1]*100 + [lindex $ver 2]]
  set current [expr [lindex $current_ver 0]*100000 + [lindex $current_ver 1]*100 + [lindex $current_ver 2]]
  return [expr $target <= $current]
}

## @brief Checks doxygen version installed in this machine
#
# @param[in] target_version the version required by the current project
#
# @return Return 1 if the system Doxygen version is greater or equal to the target
#
proc DoxygenVersion {target_version} {
  set ver [split $target_version "."]
  set v [Execute doxygen --version]
  Msg Info "Found doxygen version: $v"
  set current_ver [split $v ". "]
  set target [expr [lindex $ver 0]*100000 + [lindex $ver 1]*100 + [lindex $ver 2]]
  set current [expr [lindex $current_ver 0]*100000 + [lindex $current_ver 1]*100 + [lindex $current_ver 2]]

  return [expr $target <= $current]
}

## @brief determine file type from extension
#  Used only for Quartus
#
## @return FILE_TYPE the file Type
proc FindFileType {file_name} {
  set extension [file ext $file_name]
  switch $extension {
    .vhd {
      set file_extension "VHDL_FILE"
    }
    .vhdl {
      set file_extension "VHDL_FILE"
    }
    .v {
      set file_extension "VERILOG_FILE"
    }
    .sv {
      set file_extension "SYSTEMVERILOG_FILE"
    }
    .sdc {
      set file_extension "SDC_FILE"
    }
    .qsf {
      set file_extension "SOURCE_FILE"
    }
    .ip {
      set file_extension "IP_FILE"
    }
    .qip {
      set file_extension "QIP_FILE"
    }
    .tcl {
      set file_extension "COMMAND_MACRO_FILE"
    }
    default {
      set file_extension "ERROR"
      Msg Error "Unknown file extension $extension"
    }
  }
  return $file_extension
}

## @brief Set VHDL version to 2008 for *.vhd files
#
# @param[in] file_name the name of the HDL file
#
# @return "-hdl_version VHDL_2008" if the file is a *.vhd files else ""
proc FindVhdlVersion {file_name} {
  set extension [file ext $file_name]
  switch $extension {
    .vhd {
      set vhdl_version "-hdl_version VHDL_2008"
    }
    .vhdl {
      set vhdl_version "-hdl_version VHDL_2008"
    }
    default {
      set vhdl_version ""
    }
  }
  
  return $vhdl_version
}

## @brief Read a list file and adds the files to Vivado/Quartus, adding the additional information as file type.
#
# Additional information is provided with text separated from the file name with one or more spaces
#
# @param[in] list_file file containing vhdl list with optional properties
# @param[in] path      path the vhdl file are referred to in the list file
# @param[in] lib       name of the library files will be added to, if not given will be extracted from the file name
# @param[in] sha_mode  if not set to 0, the list files will be added as well and the IPs will be added to the file rather than to the special ip library. The sha mode should be used when you use the lists to calculate the git SHA, rather than to add the files to the project.
#
# @return              a list of 2 dictionaries: "libraries" has library name as keys and a list of filenames as values, "properties" has as file names as keys and a list of properties as values
#
proc ReadListFile {list_file path {lib ""} {sha_mode 0} } {
  # if no library is given, work it out from the file name
  if {$lib eq ""} {
    set lib [file rootname [file tail $list_file]]
  }
  set ext [file extension $list_file]

  set list_file
  set fp [open $list_file r]
  set file_data [read $fp]
  close $fp
  set list_file_ext [file ext $list_file]
  set libraries [dict create]
  set properties [dict create]
  #  Process data file
  set data [split $file_data "\n"]
  set n [llength $data]
  Msg Info "$n lines read from $list_file."
  set cnt 0

  foreach line $data {
    # Exclude empty lines and comments
    if {![regexp {^ *$} $line] & ![regexp {^ *\#} $line] } {
      set file_and_prop [regexp -all -inline {\S+} $line]
      set srcfile [lindex $file_and_prop 0]
      set srcfile "$path/$srcfile"
      
      set srcfiles [glob -nocomplain $srcfile]
      
      # glob the file list for wildcards
      if {$srcfiles != $srcfile && ! [string equal $srcfiles "" ]} {
	     Msg Info "Wildcard source expanded from $srcfile to $srcfiles"
      } else {
        if {![file exists $srcfile]} {
          Msg CriticalWarning "$srcfile not found in $path"
          continue
        }
      }
      
      foreach vhdlfile $srcfiles {
        if {[file exists $vhdlfile]} {
          set vhdlfile [file normalize $vhdlfile]
          set extension [file ext $vhdlfile]
	  
          if { $extension == $list_file_ext } {
            Msg Info "List file $vhdlfile found in list file, recursively opening it..."
            ### Set list file properties
            set prop [lrange $file_and_prop 1 end]
            set library [lindex [regexp -inline {lib\s*=\s*(.+?)\y.*} $prop] 1]
            if { $library != "" } {
	      Msg Info "Setting $library as library for list file $vhdlfile..."
            } else {
	      Msg Info "Setting $lib as library for list file $vhdlfile..."
	      set library $lib
            }
            lassign [ReadListFile $vhdlfile $path $library $sha_mode] l p
	    
            set libraries [MergeDict $l $libraries]
            set properties [MergeDict $p $properties]
          } elseif {[lsearch {.src .sim .con .ext} $extension] >= 0 } {
            Msg Error "$vhdlfile cannot be included into $list_file, $extension files must be included into $extension files."
          } else {
            ### Set file properties
            set prop [lrange $file_and_prop 1 end]
            regsub -all " *= *" $prop "=" prop
            dict lappend properties $vhdlfile $prop
            ### Set File Set
            #Adding IP library
            if {$sha_mode == 0 && [lsearch {.xci .ip .bd} $extension] >= 0} {
	      dict lappend libraries "$lib.ip" $vhdlfile
	      Msg Info "Appending $vhdlfile to IP list..."
            } else {
	      dict lappend libraries $lib$ext $vhdlfile
            }
          }
          incr cnt
        } else {
          Msg CriticalWarning "File $vhdlfile not found."
        }
      }
    }
  }
  
  if {$sha_mode != 0} {
    dict lappend libraries $lib$ext $list_file
  }
  return [list $libraries $properties]
}

## @brief Merge two tcl dictionaries of lists
#
# If the dictionaries contain same keys, the list at the common key is a merging of the two 
# 
#
# @param[in] dict0 the name of the first dictionary
# @param[in] dict1 the name of the second dictionary
#
# @return        the merged dictionary
#
proc MergeDict {dict0 dict1} {
  set outdict [dict merge $dict1 $dict0]
  foreach key [dict keys $dict1 ] {
    if {[dict exists $dict0 $key]} {
      set temp_list [dict get $dict1 $key]
      foreach vhdfile $temp_list {
      	dict lappend outdict $key $vhdfile
      }
    } 
  }
  return $outdict
}


## @brief Get git SHA of a vivado library
#
# If the special string "ALL" is used, returns the global hash
#
# @param[in] lib the name of the library whose latest commit hash will be returned
#
# @return        the git SHA of the specified library
#
proc GetHashLib {lib} {
  if {$lib eq "ALL"} {
    set ret [Git {log --format=%h -1}]
  } else {
    set ff [get_files -filter LIBRARY==$lib]
    set ret [Git {log --format=%h -1} $ff]
  }

  return $ret
}

## @brief Get a list of all modified the files matching then pattern
#
# @param[in] repo_path the path of the git repository
# @param[in] pattern the pattern with wildcards that files should match
#
# @return    a list of all modified files matchin the pattern
#
proc GetModifiedFiles {{repo_path "."} {pattern "."}} {
  set old_path [pwd]
  cd $repo_path
  set ret [Git "ls-files --modified $pattern"]
  cd $old_path
  return $ret
}

## @brief Restore with checkout -- the files specified in pattern
#
# @param[in] repo_path the path of the git repository
# @param[in] pattern the pattern with wildcards that files should match
#
proc RestoreModifiedFiles {{repo_path "."} {pattern "."}} {
  set old_path [pwd]
  cd $repo_path
  set ret [Git checkout $pattern]
  cd $old_path
  return
}

## @brief Recursively gets file names from list file
#
#  If the list file contains files with extension .src .sim .con, it will recursively open them
#
#  @param[in] FILE  list file to open
#  @param[in] path  the path the files are referred to in the list file
#
#  @returns         a list of the files contained in the list file
#
proc GetFileList {FILE path} {
  set fp [open $FILE r]
  set file_data [read $fp]
  set file_list {}
  close $fp
    #  Process data file
  set data [split $file_data "\n"]
  foreach line $data {
    if {![regexp {^ *$} $line] & ![regexp {^ *\#} $line] } { #Exclude empty lines and comments
      set file_and_prop [regexp -all -inline {\S+} $line]
      set vhdlfile [lindex $file_and_prop 0]
      set vhdlfile "$path/$vhdlfile"
      if {[file exists $vhdlfile]} {
        set extension [file ext $vhdlfile]
        if { [lsearch {.src .sim .con} $extension] >= 0 } {
          lappend file_list {*}[GetFileList $vhdlfile $path]]
        } else {
          lappend file_list $vhdlfile
        }
      } else {
        Msg Warning "File $vhdlfile not found"
      }
    }
  }

  return $file_list
}

## @brief Get git SHA of a subset of list file
#
# @param[in] path the file/path or list of files/path the git SHA should be evaluated from
#
# @return         the value of the desired SHA
#
proc GetSHA {path} {
  set ret [Git {log --format=%h -1} $path ]
  return [string toupper $ret]
}

## @brief Get git version and commit hash of a subset of files
#
# @param[in] path list file or path containing the subset of files whose latest commit hash will be returned
#
# @return  a list: the git SHA, the version in hex format
#
proc GetVer {path} {
  set SHA [GetSHA $path]
  #oldest tag containing SHA
  if {$SHA eq ""} {
    Msg CriticalWarning "Empty SHA found for ${path}. Commit to Git to resolve this warning."
  }
  return [list [GetVerFromSHA $SHA] $SHA]
}

## @brief Get git version and commit hash of a specific commit give the SHA
#
# @param[in] SHA the git SHA of the commit
#
# @return  a list: the git SHA, the version in hex format
#
proc GetVerFromSHA {SHA} {
  if { $SHA eq ""} {
    Msg CriticalWarning "Empty SHA found"
    set ver "v0.0.0"
  } else {
    lassign [GitRet "tag --sort=creatordate --contain $SHA -l v*.*.* -l b*v*.*.*" ] status result
    if {$status == 0} {
      if {[regexp {^ *$} $result]} {
	#newest tag of the repo, parent of the SHA
	lassign [GitRet {describe --tags --abbrev=0 --match=v*.*.* --match=b*v*.*.*}] ret tag
	if {$ret != 0} {
	  Msg CriticalWarning "No Hog version tags found in this repository."
	  set ver v0.0.0
	} else {
	  lassign [ExtractVersionFromTag $tag] M m p mr
	  if {$M == -1} {
	    Msg CriticalWarning "Tag $tag does not contain a Hog compatible version in this repository."
	    #set ver v0.0.0
	  } elseif {$mr == -1} {
	    incr p
	    Msg Info "No tag contains $SHA, will use most recent tag $tag. As this is an official tag, patch will be incremented to $p."
	  } else {
	    lassign [ExtractVersionFromTag $tag] M m p mr
	    if {$M == -1} {
	      Msg CriticalWarning "Tag $tag does not contain a Hog compatible version in this repository."
	      #set ver v0.0.0
	    } elseif {$mr == -1} {
	      incr p
	      Msg Info "No tag contains $SHA, will use most recent tag $tag. As this is an official tag, patch will be incremented to $p."
	    } else {
	      Msg Info "No tag contains $SHA, will use most recent tag $tag. As this is a candidate tag, the patch level will be kept at $p."
	    }
	  }
	  
	  set ver v$M.$m.$p
	}
      } else {
	#The tag in $result contains the current SHA
	set vers [split $result "\n"]
	set ver [lindex $vers 0]
	foreach v $vers {
	  if {[regexp {^v.*$} $v]} {
	    set un_ver $ver
	    set ver $v
	    break
	  }
	}
      }
    } else {
      Msg CriticalWarning "Error while trying to find tag for $SHA"
      set ver "v0.0.0"
    }
  }
  lassign [ExtractVersionFromTag $ver] M m c mr
  
  if {$mr > -1} { # Candidate tab
    set M [format %02X $M]
    set m [format %02X $m]
    set c [format %04X $c]
    
  } elseif { $M > -1 } { # official tag
    set M [format %02X $M]
    set m [format %02X $m]
    set c [format %04X $c]
    
  } else {
    Msg Warning "Tag does not contain a properly formatted version: $ver"
    set M [format %02X 0]
    set m [format %02X 0]
    set c [format %04X 0]
  }
  
  return $M$m$c
}

## Get the project version
#
#  @param[in] tcl_file: The tcl file of the project of which all the version must be calculated
#  @param[in] ext_path: path for external libraries
#  @param[in] sim: if enabled, check the version also for the simulation files
#
#  @return  returns the project version
#
proc GetProjectVersion {tcl_file {ext_path ""} {sim 0}} {
  if { ![file exists $tcl_file] } {
    Msg CriticalWarning "$tcl_file not found"
    return -1
  }
  set old_dir [pwd]
  set proj_dir [file dir $tcl_file]
  cd $proj_dir

  #The latest version the repository
  set v_last [ExtractVersionFromTag [Git {describe --abbrev=0 --match "v*"}]]
  lassign [GetRepoVersions $tcl_file $ext_path $sim] sha ver
  if {$sha == 0} {
    Msg Warning "Repository is not clean"
    cd $old_dir
    return -1
  }

  #The project version
  set v_proj [ExtractVersionFromTag v[HexVersionToString $ver]]
  set comp [CompareVersion $v_proj $v_last]
  if {$comp == 1} {
    Msg Info "The specified project was modified since official version."
    set ret 0
  } else {
    set ret v[HexVersionToString $ver]
  }

  if {$comp == 0} {
    Msg Info "The specified project was modified in the latest official version $ret"
  } elseif {$comp == -1} {
    Msg Info "The specified project was modified in a past official version $ret"
  }

  cd $old_dir
  return $ret
}


## Get git describe of a specific SHA
#
#  @param[in] sha     the git sha of the commit you want to calculate the describe of
#
#  @return            the git describe of the sha or the current one if the sha is 0
#
proc GetGitDescribe {sha} {
  if {$sha == 0 } {
    set describe [Git {describe --always --dirty --tags --long}]
  } else {
    set describe [Git "describe --always --tags --long $sha"]
  }
}



## Get submodule of a specific file. Returns an empty string if the file is not in a submodule
#
#  @param[in] path_file      path of the file that whose paternity must be checked
#
#  @return             The path of the submodule. Returns an empty string if not in a submodule.
#
proc GetSubmodule {path_file} {
  set old_dir [pwd]
  set directory [file normalize [file dir $path_file]]
  cd $directory
  lassign [GitRet {rev-parse --show-superproject-working-tree}] ret base
  if {$ret != 0} {
    Msg CriticalWarning "Git repository error: $sub"
    cd $old_dir
    return ""
  }
  if {$base eq "" } {
    set submodule ""
  } else {
    lassign [GitRet {rev-parse --show-toplevel}] ret sub
    if {$ret != 0} {
      Msg CriticalWarning "Git submodule error: $sub"
      cd $old_dir
      return ""
    }
    set submodule [Relative $base $sub]
  }
  
  cd $old_dir
  return $submodule
}


## Get the versions for all libraries, submodules, etc. for a given project
#
#  @param[in] proj_tcl_file: The tcl file of the project of which all the version must be calculated
#  @param[in] ext_path: path for external libraries
#  @param[in] sim: if enabled, check the version also for the simulation files
#
#  @return  a list conatining all the versions: global, top (project tcl file), constraints, libraries, submodules, exteral, ipbus xml
#
proc GetRepoVersions {proj_tcl_file {ext_path ""} {sim 0}} {
  set old_path [pwd]
  set proj_tcl_file [file normalize $proj_tcl_file]
  set proj_dir [file dir $proj_tcl_file]

  # This will be the list of all the SHAs of this project, the most recent will be picked up as GLOBAL SHA
  set SHAs ""
  set versions ""

  # Hog submodule
  cd $proj_dir
  
  #Append the SHA in which Hog submodule was changed, not the submodule SHA
  lappend SHAs [Git {log --format=%h -1} {../../Hog}]
  cd "../../Hog"
  if {[Git {status --untracked-files=no  --porcelain}] eq ""} {
    Msg Info "Hog submodule [pwd] clean."
    lassign [GetVer ./] hog_ver hog_hash
  } else {
    Msg CriticalWarning "Hog submodule [pwd] not clean, commit hash will be set to 0."
    set hog_hash "0000000"
    set hog_ver "00000000"
  }
  lappend versions $hog_ver

  cd $proj_dir
  
  if {[Git {status --untracked-files=no  --porcelain}] eq ""} {
    Msg Info "Git working directory [pwd] clean."
    set clean 1
  } else {
    Msg CriticalWarning "Git working directory [pwd] not clean, commit hash, and version will be set to 0."
    set clean 0
  }


  # Top project directory
  lassign [GetVer $proj_tcl_file] top_ver top_hash
  lappend SHAs $top_hash
  lappend versions $top_ver

  # Read list files
  set libs ""
  set vers ""
  set hashes ""
  # Specyfiy sha_mode 1 for GetHogFiles to get all the files, includeng the list-files themselves
  lassign [GetHogFiles "./list/" "*.src" 1] src_files dummy
  dict for {f files} $src_files {
    #library names have a .src extension in values returned by GetHogFiles
    set name [file rootname [file tail $f]]
    lassign [GetVer  $files] ver hash
    #Msg Info "Found source list file $f, version: $ver commit SHA: $hash"
    lappend libs $name
    lappend versions $ver
    lappend vers $ver
    lappend hashes $hash
    lappend SHAs $hash
  }

# Read constraint list files

  set cons_hashes ""
  # Specyfiy sha_mode 1 for GetHogFiles to get all the files, includeng the list-files themselves
  lassign [GetHogFiles "./list/" "*.con" 1] cons_files dummy
  dict for {f files} $cons_files {
    #library names have a .con extension in values returned by GetHogFiles
    set name [file rootname [file tail $f]]
    lassign [GetVer  $files] ver hash
    #Msg Info "Found constraint list file $f, version: $ver commit SHA: $hash"
    if {$hash eq ""} {
      Msg CriticalWarning "Constraints file $f not found in Git."
    }
    lappend cons_hashes $hash
    lappend SHAs $hash
    lappend versions $ver
  }

  # Read simulation list files
  if {$sim == 1} {
    set sim_hashes ""
    # Specyfiy sha_mode 1 for GetHogFiles to get all the files, includeng the list-files themselves
    lassign [GetHogFiles "./list/" "*.sim" 1] sim_files dummy
    dict for {f files} $sim_files {
      #library names have a .sim extension in values returned by GetHogFiles
      set name [file rootname [file tail $f]]
      lassign [GetVer  $files] ver hash
      #Msg Info "Found simulation list file $f, version: $ver commit SHA: $hash"
      lappend sim_hashes $hash
      lappend SHAs $hash
      lappend versions $ver
    }
  }
  

  #Of all the constraints we get the most recent
  if {"{}" eq $cons_hashes} {
    Msg CriticalWarning "No hashes found for constraints files (not in git)"
    set cons_hash ""
  } else {
    set cons_hash [string toupper [Git "log --format=%h -1 $cons_hashes"]]
  }
  set cons_ver [GetVerFromSHA $cons_hash]
  #Msg Info "Among all the constraint list files, if more than one, the most recent version was chosen: $cons_ver commit SHA: $cons_hash"

  # Read external library files
  set ext_hashes ""
  set ext_files [glob -nocomplain "./list/*.ext"]
  set ext_names ""

  foreach f $ext_files {
    set name [file rootname [file tail $f]]
    set hash [Git {log --format=%h -1} $f]
    #Msg Info "Found source file $f, commit SHA: $hash"
    lappend ext_names $name
    lappend ext_hashes $hash
    lappend SHAs $hash
    set ext_ver [GetVerFromSHA $hash]
    lappend versions $ext_ver

    set fp [open $f r]
    set file_data [read $fp]
    close $fp
    set data [split $file_data "\n"]
    #Msg Info "Checking checksums of external library files in $f"
    foreach line $data {
      if {![regexp {^ *$} $line] & ![regexp {^ *\#} $line] } { #Exclude empty lines and comments
        set file_and_prop [regexp -all -inline {\S+} $line]
        set hdlfile [lindex $file_and_prop 0]
        set hdlfile $ext_path/$hdlfile
        if { [file exists $hdlfile] } {
          set hash [lindex $file_and_prop 1]
          set current_hash [Md5Sum $hdlfile]
          if {[string first $hash $current_hash] == -1} {
            Msg CriticalWarning "File $hdlfile has a wrong hash. Current checksum: $current_hash, expected: $hash"
          }
        }
      }
    }
  }

  # Ipbus XML
  if [file exists ./list/xml.lst] {
    #Msg Info "Found IPbus XML list file, evaluating version and SHA of listed files..."
    lassign [GetHogFiles "./list/" "xml.lst" 1] xml_files dummy
    lassign [GetVer  [dict get $xml_files "xml.lst"] ] xml_ver xml_hash
    lappend SHAs $xml_hash
    lappend versions $xml_ver
    #Msg Info "Found IPbus XML SHA: $xml_hash and version: $xml_ver."

  } else {
    Msg Info "This project does not use IPbus XMLs"
    set xml_ver  00000000
    set xml_hash 0000000
  }

  #The global SHA and ver is the most recent among everything
  if {$clean == 1} {
    set commit [Git "log --format=%h -1 $SHAs"]
    set version [FindNewestVersion $versions]
  } else {
    set commit  "0000000"
    set version "00000000"
  }
  
  cd $old_path
  
  return [list $commit $version  $hog_hash $hog_ver  $top_hash $top_ver  $libs $hashes $vers  $cons_ver $cons_hash  $ext_names $ext_hashes  $xml_hash $xml_ver] 
}



## Convert hex version to M.m.p string
#
#  @param[in] version the version (in 32-bt hexadecimal format 0xMMmmpppp) to be converted
#
#  @return            a string containing the version in M.m.p format
#
proc HexVersionToString {version} {
  scan [string range $version 0 1] %x M
  scan [string range $version 2 3] %x m
  scan [string range $version 4 7] %x c
  return "$M.$m.$c"
}

## @brief Tags the repository with a new version calculated on the basis of the previous tags
#
# @param[in] tag  a tag in the Hog format: v$M.$m.$p or b$(mr)v$M.$m.$p-$n
#
# @return         a list containing: Major minor patch v.
#
proc ExtractVersionFromTag {tag} {
  if {[regexp {^(?:b(\d+))?v(\d+)\.(\d+).(\d+)(?:-\d+)?$} $tag -> mr M m p]} {
    if {$mr eq ""} {
      set mr -1
    }
  } else {
    Msg Warning "Repository tag $tag is not in a Hog-compatible format."
    set mr -1
    set M -1
    set m -1
    set p -1
  }
  return [list $M $m $p $mr]
}

## @brief Tags the repository with a new version calculated on the basis of the previous tags
#
# @param[in] merge_request_number: Gitlab merge request number to be used in candidate version
# @param[in] version_level:        0 if patch is to be increased (default), 1 if minor level is to be increase, 2 if major level is to be increased, 3 or bigger is used to transform a candidate for a version (starting with b) into an official version
# @param[in] default_level:        If version level is 3 or more, will specify what level to increase when creating the official tag: 0 will increase patch (default), 1 will increase minor and 2 will increase major.
#
proc TagRepository {{merge_request_number 0} {version_level 0} {default_level 0}} {
  lassign [GitRet {describe --tags --abbrev=0 --match=v*.*.* --match=b*v*.*.*}] ret tag
  if {$ret != 0} {
    Msg Error "No Hog version tags found in this repository."
  } else {
    lassign [ExtractVersionFromTag $tag] M m p mr

    if { $M > -1 } { # M=-1 means that the tag could not be parsed following a Hog format
      if {$mr == -1 } { # Tag is official, no b at the beginning (and no merge request number at the end)
        Msg Info "Found official version $M.$m.$p."
        if {$version_level == 2} {
          incr M
          set m 0
          set p 0
          set new_tag b${merge_request_number}v$M.$m.$p
          set tag_opt ""
          if {$merge_request_number <= 0} {
            Msg Error "You should specify a valid merge request number not to risk to fail because of duplicated tags"
            return -1
          }

        } elseif {$version_level == 1} {
          incr m
          set p 0
          set new_tag b${merge_request_number}v$M.$m.$p
          set tag_opt ""
          if {$merge_request_number <= 0} {
            Msg Error "You should specify a valid merge request number not to risk to fail because of duplicated tags"
            return -1
          }

        } elseif {$version_level >= 3} {
        # Version level >= 3 is used to create official tags from beta tags
          if {$default_level == 0} {
            Msg Info "Default_level is set to 0, will increase patch..."
            incr p
          } elseif {$default_level == 1} {
            Msg Info "Default_level is set to 1, will increase minor..."
            set p 0
            incr m
          } elseif {$default_level == 2} {
            Msg Info "Default_level is set to 1, will increase major..."
            set m 0
            set p 0
            incr M
          } else {
            Msg Warning "Wrong default_level $default_level, assuming 0 and increase patch."
            incr p
          }

        #create official tag
          Msg Info "No major/minor version increase, new tag will be v$M.$m.$p..."
          set new_tag v$M.$m.$p
          set tag_opt "-m 'Official_version_$M.$m.$p'"

        }

      } else { # Tag is not official
	#Not official, do nothing unless version level is >=3, in which case convert the unofficial to official
        Msg Info "Found candidate version for $M.$m.$p."
        if {$version_level >= 3} {
          Msg Info "New tag will be an official version v$M.$m.$p..."
          set new_tag v$M.$m.$p
          set tag_opt "-m 'Official_version_$M.$m.$p'"
        }
      }

      # Tagging repositroy
      if [info exists new_tag] {
        Msg Info "Tagging repository with $new_tag..."
	lassign [GitRet "tag $new_tag $tag_opt"] ret msg
	if {$ret != 0} {
          Msg Error "Could not create new tag $new_tag: $msg"
        } else {
          Msg Info "New tag $new_tag created successully."
        }
      } else {
        set new_tag $tag
        Msg Info "Tagging is not needed"
      }
    } else {
      Msg Error "Could not parse tag: $tag"
    }
  }

  return [list $tag $new_tag]
}

## @brief Read a XML list file and copy files to destination
#
# Additional information is provided with text separated from the file name with one or more spaces
#
# @param[in] list_file   file containing list of XML files with optional properties
# @param[in] path        the path the XML files are referred to in the list file
# @param[in] dst         the path the XML files must be copied to
# @param[in] xml_version the M.m.p version to be used to replace the __VERSION__ placeholder in any of the xml files
# @param[in] xml_sha     the Git-SHA to be used to replace the __GIT_SHA__ placeholder in any of the xml files
# @param[in] generate    if set to 1, tells the function to generate the VHDL decode address files rather than check them 
#
proc CopyXMLsFromListFile {list_file path dst {xml_version "0.0.0"} {xml_sha "00000000"}  {generate 0} } {
  lassign  [ExecuteRet python -c "from sys import path;print ':'.join(path\[1:\])"] ret msg
  if {$ret == 0} {
    set ::env(PYTHONPATH) $msg
    set ::env(PYTHONHOME) "/usr"
    lassign [ExecuteRet gen_ipbus_addr_decode -h] ret msg
    if {$ret != 0}  {
      set can_generate 0
    } else {
      set can_generate 1
    }
  } else { 
    Msg Warning "Error while trying to run python: $msg"
    set can_generate 0
  }

  if {$can_generate == 0} {
    if {$generate == 1} {
      Msg Error "Cannot generate IPbus address files, IPbus executable gen_ipbus_addr_decode not found or not working: $msg"
      return -1

    } else {
      Msg Warning "IPbus executable gen_ipbus_addr_decode not found or not working, will not verify IPbus address tables."
    }
  }

  set list_file
  set fp [open $list_file r]
  set file_data [read $fp]
  close $fp
  #  Process data file
  set data [split $file_data "\n"]
  set n [llength $data]
  Msg Info "$n lines read from $list_file"
  set cnt 0
  set xmls {}
  set vhdls {}
  foreach line $data {
    if {![regexp {^ *$} $line] & ![regexp {^ *\#} $line] } { #Exclude empty lines and comments
      set file_and_prop [regexp -all -inline {\S+} $line]
      set xmlfile "$path/[lindex $file_and_prop 0]"
      if {[llength $file_and_prop] > 1} {
        set vhdlfile [lindex $file_and_prop 1]
        set vhdlfile "$path/$vhdlfile"
      } else {
        set vhdlfile 0
      }
      if {[file exists $xmlfile]} {
        set xmlfile [file normalize $xmlfile]
        Msg Info "Copying $xmlfile to $dst..."
        set in  [open $xmlfile r]
        set out [open $dst/[file tail $xmlfile] w]

        while {[gets $in line] != -1} {
          set new_line [regsub {(.*)__VERSION__(.*)} $line "\\1$xml_version\\2"]
          set new_line2 [regsub {(.*)__GIT_SHA__(.*)} $new_line "\\1$xml_sha\\2"]
          puts $out $new_line2
        }
        close $in
        close $out
        lappend xmls [file tail $xmlfile]
        if {$vhdlfile == 0 } {
	  lappend vhdls 0
	} else {
	  lappend vhdls [file normalize $vhdlfile]
	}

      } else {
        Msg Warning "XML file $xmlfile not found"
      }

    }
  }
  set cnt [llength $xmls]
  Msg Info "$cnt file/s copied"

  if {$can_generate == 1} {
    set old_dir [pwd]
    cd $dst
    file mkdir "address_decode"
    cd "address_decode"
    foreach x $xmls v $vhdls {
      if {$v != 0} {
	set x [file normalize ../$x]
	if {[file exists $x]} {
	  lassign [ExecuteRet gen_ipbus_addr_decode -v $x]  status log
	  if {$status == 0} {
	    set generated_vhdl ./ipbus_decode_[file root [file tail $x]].vhd
	    if {$generate == 1} {
	      #copy (replace) file here
	      Msg Info "Copying generated VHDL file $generated_vhdl into $v (replacing if necessary)"
	      file copy -force -- $generated_vhdl $v
	    } else {
	      if {[file exists $v]} {
		#check file here
		set diff [CompareVHDL $generated_vhdl $v]
		if {[llength $diff] > 0} {
		  Msg CriticalWarning "$v does not correspond to its XML $x, [expr $n/3] line/s differ:"
		  Msg Status [join $diff "\n"]
		  set diff_file [open ../diff_[file root [file tail $x]].txt w]
		  puts $diff_file $diff
		  close $diff_file
		} else {
		  Msg Info "$x and $v match."
		}
	      } else {
		Msg Warning "VHDL address decoder file $v not found"
	      }
	    }
	  } else {
	    Msg Warning "Address map generation failed for $x: $log"
	  }
	} else {
	  Msg Warning "Copied XML file $x not found."
	}
      } else {
	Msg Info "Skipped verification of $x as no VHDL file was specified."
      }
    }
    cd ..
    file delete -force address_decode
    cd $old_dir
  }
}

## @brief Compare two VHDL files ignoring spaces and comments
#
# @param[in] file1  the first file
# @param[in] file2  the second file
#
# @ return A string with the diff of the files
#
proc CompareVHDL {file1 file2} {
  set a  [open $file1 r]
  set b  [open $file2 r]

  while {[gets $a line] != -1} {
    set line [regsub {^[\t\s]*(.*)?\s*} $line "\\1"]
    if {![regexp {^$} $line] & ![regexp {^--} $line] } { #Exclude empty lines and comments
      lappend f1 $line
    }
  }

  while {[gets $b line] != -1} {
    set line [regsub {^[\t\s]*(.*)?\s*} $line "\\1"]
    if {![regexp {^$} $line] & ![regexp {^--} $line] } { #Exclude empty lines and comments
      lappend f2 $line
    }
  }

  close $a
  close $b
  set diff {}
  foreach x $f1 y $f2 {
    if {$x != $y} {
      lappend diff "> $x\n< $y\n\n"
    }
  }

  return $diff
}

## @brief Returns the dst path relative to base
#
# @param[in] base   the path with respect to witch the dst path is calculated
# @param[in] dst    the path to be calculated with respect to base
#
proc Relative {base dst} {
  if {![string equal [file pathtype $base] [file pathtype $dst]]} {
    Msg CriticalWarning "Unable to compute relation for paths of different pathtypes: [file pathtype $base] vs. [file pathtype $dst], ($base vs. $dst)"
    return ""
  }

  set base [file normalize [file join [pwd] $base]]
  set dst  [file normalize [file join [pwd] $dst]]

  set save $dst
  set base [file split $base]
  set dst  [file split $dst]

  while {[string equal [lindex $dst 0] [lindex $base 0]]} {
    set dst  [lrange $dst  1 end]
    set base [lrange $base 1 end]
    if {![llength $dst]} {break}
  }

  set dstlen  [llength $dst]
  set baselen [llength $base]

  if {($dstlen == 0) && ($baselen == 0)} {
    set dst .
  } else {
    while {$baselen > 0} {
      set dst [linsert $dst 0 ..]
      incr baselen -1
    }
    set dst [eval [linsert $dst 0 file join]]
  }

  return $dst
}

## @ brief Returns a list of 2 dictionaries: libraries and properties
# - libraries has library name as keys and a list of filenames as values
# - properties has as file names as keys and a list of properties as values
#
# Files, libraries and properties are extracted from the current Vivado project
#
# @return a list of two elements. The first element is a dictionary containing all libraries. The second elements is a discretionary containing all properties
proc GetProjectFiles {} {


  set all_filesets [get_filesets]
  set libraries [dict create]
  set properties [dict create]

  set simulator [get_property target_simulator [current_project]]
  set SIM [dict create]
  set SRC [dict create] 

  foreach fs $all_filesets {

    set all_files [get_files -quiet -of_objects [get_filesets $fs]]
    set fs_type [get_property FILESET_TYPE [get_filesets $fs]]

    if {[string equal $fs_type "SimulationSrcs"] && [llength $all_files] > 0} {
      set topsim [get_property "top"  [get_filesets $fs]]
      set runtime [get_property "$simulator.simulate.runtime"  [get_filesets $fs]]
      #getting file containing top module as explained here: https://forums.xilinx.com/t5/Vivado-TCL-Community/How-can-I-get-the-file-path-of-the-top-module-in-the-current/td-p/455740
      if {[string equal "$topsim" ""]} {
        Msg CriticalWarning "No top simulation file found for fileset $fs."
      } else {
        set simtopfile [lindex [get_files -compile_order sources -used_in simulation -of_objects [get_filesets $fs]] end]
        if {[string equal [get_files -of_objects [get_filesets $fs] $simtopfile] ""] } {
          Msg CriticalWarning "Top simulation file $simtopfile not found in fileset $fs."
        } else {
          dict lappend properties $simtopfile "topsim=$topsim"
          if {![string equal "$runtime" "1000ns"]} { #not writing default value
            dict lappend properties $simtopfile "runtime=$runtime"
          }
        }
      }
      set wavefile [get_property "$simulator.simulate.custom_wave_do" [get_filesets $fs]]
      if {![string equal "$wavefile" ""]} {
        dict lappend properties $wavefile wavefile
      }

      set dofile [get_property "$simulator.simulate.custom_udo" [get_filesets $fs]]
      if {![string equal "$dofile" ""]} {
        dict lappend properties $dofile dofile
      }
    }


    foreach f $all_files {
      if { [lindex [get_property  IS_GENERATED [get_files $f]] 0] == 0 && ![string equal [file extension $f] ".coe"]} {
        set f [file normalize $f]
        lappend files $f
        set type  [get_property FILE_TYPE [get_files $f]]
        set lib [get_property LIBRARY [get_files $f]]
      

        # Type can be complex like VHDL 2008, in that case we want the second part to be a property
        if {[string equal [lindex $type 0] "VHDL"] && [llength $type] == 1} {
          set prop "93"
        } elseif  {[string equal [lindex $type 0] "Block"] && [string equal [lindex $type 1] "Designs"]} { 
          set type "IP"
          set prop ""
        } else {
          set type [lindex $type 0]
          set prop ""
        }

        #check where the file is used and add it to prop
        if {[string equal $fs_type "SimulationSrcs"]} {
          dict lappend SIM $fs $f
          if {![string equal $prop ""]} {
            dict lappend properties $f $prop
          }
        } elseif {[string equal $type "VHDL"]} {
          dict lappend SRC $lib $f
          if {![string equal $prop ""]} {
            dict lappend properties $f $prop
          }
        } elseif {[string equal $type "IP"]} {
          dict lappend libraries "IP" $f
        } elseif {[string equal $type "XDC"]} {
          dict lappend libraries "XDC" $f
          #dict lappend properties $f "XDC"
        } else {
          dict lappend libraries "OTHER" $f
        }
        
        if {[lindex [get_property -quiet used_in_synthesis  [get_files $f]] 0] == 0} {
          dict lappend properties $f "nosynth"
        }
        if {[lindex [get_property -quiet used_in_implementation  [get_files $f]] 0] == 0} {
          dict lappend properties $f "noimpl"
        }
        if {[lindex [get_property -quiet used_in_simulation  [get_files $f]] 0] == 0} {
          dict lappend properties $f "nosim"
        }

      }

    }

    #    dict for {lib f} $libraries {
    #   Msg Status "   Library: $lib: \n *******"
    #   foreach n $f {
    #       Msg Status "$n"
    #   }
    #
    #   Msg Status "*******"
    #    }
  }
  
  dict append libraries "SIM" $SIM 
  dict append libraries "SRC" $SRC 
  dict lappend properties "Simulator" $simulator
  return [list $libraries $properties]
}


## @brief Extract files, libraries and properties from the project's list files
#
# @param[in] list_path path to the list file directory
# @param[in] list_files the file wildcard, if not specified all Hog list files will be looked for
# @param[in] sha_mode forwarded to ReadListFile, see there for info
# @param[in] ext_path path for external libraries forwarded to ReadListFile
#
# @return a list of 2 dictionaries: libraries and properties
# - libraries has library name as keys and a list of filenames as values
# - properties has as file names as keys and a list of properties as values
#
proc GetHogFiles {list_path {list_files ""} {sha_mode 0} {ext_path ""}} {
  set repo_path [file normalize $list_path/../../..]
  if { $list_files == "" } {
    set list_files {.src,.con,.sub,.sim,.ext}  
  }
  set libraries [dict create]
  set properties [dict create]
  set list_files [glob -nocomplain -directory $list_path "*{$list_files}"]

  foreach f $list_files {
    set ext [file extension $f]
    if {$ext == ".ext"} {
      lassign [ReadListFile $f $ext_path "" $sha_mode] l p
    } else {
      lassign [ReadListFile $f $repo_path "" $sha_mode] l p
    }
    set libraries [MergeDict $l $libraries]
    set properties [MergeDict $p $properties]
  }
  return [list $libraries $properties]
}


## @brief Parse possible commands in the first line of Hog files (e.g. #Vivado, #Simulator, etc)
#
# @param[in] list_path path to the list file directory
# @param[in] list_files the list file name 
#
# @return a string with the first-line command
# - libraries has library name as keys and a list of filenames as values
# - properties has as file names as keys and a list of properties as values
#
proc ParseFirstLineHogFiles {list_path list_file} {
  set repo_path [file normalize $list_path/../../..]
  if {![file exists $list_path/$list_file]} {
    Msg Error "list file $list_path/$list_file does not exist!"
    return ""
  } 
  set fp [open $list_path/$list_file r]
  set line [lindex [split [read $fp] "\n"] 0] 
  close $fp

  if {[string match "#*" $line]} {
    return [string trim [string range $line 1 end]]
  } else {
    return ""
  }
}


## @brief  Add libraries and properties to Vivado/Quartus project
#
# @param[in] libraries has library name as keys and a list of filenames as values
# @param[in] properties has as file names as keys and a list of properties as values
#
proc AddHogFiles { libraries properties } {
  Msg Info "Adding source files to project..."
  foreach lib [dict keys $libraries] {
    #Msg Info "lib: $lib \n"
    set lib_files [dict get $libraries $lib]
    #Msg Info "Files in $lib: $lib_files \n"
    set rootlib [file rootname [file tail $lib]]
    set ext [file extension $lib]
    #Msg Info "lib: $lib ext: $ext \n"
    switch $ext {
      .sim {
        set file_set "$rootlib\_sim"
        # if this simulation fileset was not created we do it now
        if {[string equal [get_filesets -quiet $file_set] ""]} {
          create_fileset -simset $file_set
          set simulation  [get_filesets $file_set]
          set_property -name {modelsim.compile.vhdl_syntax} -value {2008} -objects $simulation
          set_property -name {questa.compile.vhdl_syntax} -value {2008} -objects $simulation
          set_property SOURCE_SET sources_1 $simulation
        }
      }
      .con {
        set file_set "constrs_1"
      }
      .prop {
        return
      }
      default {
        set file_set "sources_1"
      }
    }
    # # ADD NOW LISTS TO VIVADO PROJECT
    if {[info commands add_files] != ""} {
      add_files -norecurse -fileset $file_set $lib_files

      if {$ext != ".ip"} {
        # Default sim properties
        if {$ext == ".sim"} {
          set_property "modelsim.simulate.custom_wave_do" "" [get_filesets $file_set]
          set_property "questa.simulate.custom_wave_do" "" [get_filesets $file_set]
          set_property "modelsim.simulate.custom_udo" "" [get_filesets $file_set]
          set_property "questa.simulate.custom_udo" "" [get_filesets $file_set]
        }
        # Add Properties
        foreach f $lib_files {
          set file_obj [get_files -of_objects [get_filesets $file_set] [list "*$f"]]
          #ADDING LIBRARY
          if {[file ext $f] == ".vhd" || [file ext $f] == ".vhdl" } {
            set_property -name "library" -value $rootlib -objects $file_obj
          }

          #ADDING FILE PROPERTIES
          set props [dict get $properties $f]
          if {[file ext $f] == ".vhd" || [file ext $f] == ".vhdl"} {
            if {[lsearch -inline -regex $props "93"] < 0} {
                # ISE does not support vhdl2008
                if { [string first PlanAhead [version]] != 0 } {
                    set_property -name "file_type" -value "VHDL 2008" -objects $file_obj
                }
            } else {
              Msg Info "Filetype is VHDL 93 for $f"
            }
          }

          # XDC
          if {[lsearch -inline -regex $props "XDC"] >= 0 || [file ext $f] == ".xdc"} {
            Msg Info "Setting filetype XDC for $f"
            set_property -name "file_type" -value "XDC" -objects $file_obj
          }

          # Not used in synthesis
          if {[lsearch -inline -regex $props "nosynth"] >= 0} {
            Msg Info "Setting not used in synthesis for $f..."
            set_property -name "used_in_synthesis" -value "false" -objects $file_obj
          }

          # Not used in implementation
          if {[lsearch -inline -regex $props "noimpl"] >= 0} {
            Msg Info "Setting not used in implementation for $f..."
            set_property -name "used_in_implementation" -value "false" -objects $file_obj
          }

          # Not used in simulation
          if {[lsearch -inline -regex $props "nosim"] >= 0} {
            Msg Info "Setting not used in simulation for $f..."
            set_property -name "used_in_simulation" -value "false" -objects $file_obj
          }

          ## Simulation properties
          # Top simulation module
          set top_sim [lindex [regexp -inline {topsim\s*=\s*(.+?)\y.*} $props] 1]
          if { $top_sim != "" } {
            Msg Info "Setting $top_sim as top module for simulation file set $file_set..."
            set_property "top"  $top_sim [get_filesets $file_set]
            current_fileset -simset [get_filesets $file_set]
          }

          # Simulation runtime
          set sim_runtime [lindex [regexp -inline {runtime\s*=\s*(.+?)\y.*} $props] 1]
          if { $sim_runtime != "" } {
            Msg Info "Setting simulation runtime to $sim_runtime for simulation file set $file_set..."
            set_property -name {xsim.simulate.runtime} -value $sim_runtime -objects [get_filesets $file_set]
            set_property -name {modelsim.simulate.runtime} -value $sim_runtime -objects [get_filesets $file_set]
            set_property -name {questa.simulate.runtime} -value $sim_runtime -objects [get_filesets $file_set]
          }

          # Wave do file
          if {[lsearch -inline -regex $props "wavefile"] >= 0} {
            Msg Info "Setting $f as wave do file for simulation file set $file_set..."
            # check if file exists...
            if [file exists $f] {
              set_property "modelsim.simulate.custom_wave_do" $f [get_filesets $file_set]
              set_property "questa.simulate.custom_wave_do" $f [get_filesets $file_set]
            } else {
              Msg Warning "File $f was not found."

            }
          }

          #Do file
          if {[lsearch -inline -regex $props "dofile"] >= 0} {
            Msg Info "Setting $f as udo file for simulation file set $file_set..."
            if [file exists $f] {
              set_property "modelsim.simulate.custom_udo" $f [get_filesets $file_set]
              set_property "questa.simulate.custom_udo" $f [get_filesets $file_set]
            } else {
              Msg Warning "File $f was not found."
            }
          }
        }
      }
      Msg Info "[llength $lib_files] file/s added to $rootlib..."
    }
    if {[info commands project_new] != "" } {
      #QUARTUS ONLY
      foreach vhdlfile $lib_files {
        set file_type [FindFileType $vhdlfile]
        set hdl_version [FindVhdlVersion $vhdlfile]
        if {$rootlib ne "IP"} {
          Msg Warning "set_global_assignment -name $file_type $vhdlfile -library $rootlib "
          set_global_assignment -name $file_type $vhdlfile  -library $rootlib
        } else {
          set_global_assignment  -name $file_type $vhdlfile  $hdl_version
        }
        #missing : ADDING QUARTUS FILE PROPERTIES
      }
    }
  }
}

## @brief Forces all the Vivado runs to look up to date, useful before write bitstream
#
proc ForceUpToDate {} {
  Msg Info "Forcing all the runs to look up to date..."
  set runs [get_runs]
  foreach r $runs {
    Msg Info "Forcing $r..."
    set_property needs_refresh false [get_runs $r]
  }
}


## @brief Copy IP generated files from/to an EOS repository
#
# @param[in] what_to_do: can be "push", if you want to copy the local IP synth result to EOS or "pull" if you want to copy the files from EOS to your local repository
# @param[in] xci_file: the .xci file of the IP you want to handle
# @param[in] runs_dir: the runs directory of the project. Typically called VivadoProject/\<project name\>/\<project name\>.runs
# @param[in] ip_path: the path of directory you want the IP to be saved on eos
# @param[in] force: if not set to 0, will copy the IP to EOS even if it is already present
#
proc HandleIP {what_to_do xci_file ip_path runs_dir {force 0}} {
  if {!($what_to_do eq "push") && !($what_to_do eq "pull")} {
    Msg Error "You must specify push or pull as first argument."
  }

  if { [catch {package require tar} TARPACKAGE]} {
    Msg CriticalWarning "Cannot find package tar. You can fix this by installing package \"tcllib\""
    return -1
  }

  set old_path [pwd]
  set repo_path [file normalize $runs_dir/../../..]

  cd $repo_path

  lassign [eos  "ls $ip_path"] ret result
  if  {$ret != 0} {
    Msg CriticalWarning "Could not find mother directory for ip_path: $ip_path."
    cd $old_path
    return -1
  } else {
    lassign [eos  "ls $ip_path"] ret result
    if  {$ret != 0} {
      Msg Info "IP repostory path on eos does not exist, creating it now..."
      eos "mkdir $ip_path" 5
    } else {
      Msg Info "IP repostory path on eos is set to: $ip_path"
    }
  }

  if !([file exists $xci_file]) {
    Msg CriticalWarning "Could not find $xci_file."
    cd $old_path
    return -1
  }


  set xci_path [file dir $xci_file]
  set xci_name [file tail $xci_file]
  set xci_ip_name [file root [file tail $xci_file]]
  set xci_dir_name [file tail $xci_path]

  set hash [Md5Sum $xci_file]
  set file_name $xci_name\_$hash

  Msg Info "Preparing to $what_to_do IP: $xci_name..."

  if {$what_to_do eq "push"} {
    set will_copy 0
    set will_remove 0
    lassign [eos "ls $ip_path/$file_name.tar"] ret result
    if  {$ret != 0} {
      set will_copy 1
    } else {
      if {$force == 0 } {
        Msg Info "IP already in the repository, will not copy..."
      } else {
        Msg Info "IP already in the repository, will forcefully replace..."
        set will_copy 1
        set will_remove 1
      }
    }
    if {$will_copy == 1} {
      set ip_synth_files [glob -nocomplain $runs_dir/$xci_ip_name*]
      set ip_synth_files_rel ""
      foreach ip_synth_file $ip_synth_files {
        lappend ip_synth_files_rel  [Relative $repo_path $ip_synth_files]
      }

      if {[llength $ip_synth_files] > 0} {
        Msg Info "Found some IP synthesised files matching $runs_dir/$file_name*"
        if {$will_remove == 1} {
          Msg Info "Removing old synthesized directory $ip_path/$file_name.tar..."
          eos "rm -rf $ip_path/$file_name.tar" 5
        }

        Msg Info "Creating local archive with ip generated files..."
        ::tar::create $file_name.tar [glob -nocomplain [Relative $repo_path $xci_path]  $ip_synth_files_rel]
        Msg Info "Copying generated files for $xci_name..."
	lassign [ExecuteRet xrdcp -f -s $file_name.tar  $::env(EOS_MGM_URL)//$ip_path/] ret msg
        if {$ret != 0} {
          Msg CriticalWarning "Something went wrong when copying the IP files to EOS. Error message: $msg"
        }
        Msg Info "Removing local archive"
        file delete $file_name.tar
      } else {
        Msg Warning "Could not find synthesized files matching $runs_dir/$file_name*"
      }
    }
  } elseif {$what_to_do eq "pull"} {
    lassign [eos "ls $ip_path/$file_name.tar"] ret result
    if  {$ret != 0} {
      Msg Info "Nothing for $xci_name was found in the repository, cannot pull."
      cd $old_path
      return -1

    } else {
      set remote_tar "$::env(EOS_MGM_URL)//$ip_path/$file_name.tar"
      Msg Info "IP $xci_name found in the repository $remote_tar, copying it locally to $repo_path..."

      lassign [ExecuteRet xrdcp -f -r -s $remote_tar $repo_path] ret msg
      if {$ret != 0} {
        Msg CriticalWarning "Something went wrong when copying the IP files to EOS. Error message: $msg"
      }
      Msg Info "Extracting IP files from archive to $repo_path..."
      ::tar::untar $file_name.tar -dir $repo_path -noperms
      Msg Info "Removing local archive"
      file delete $file_name.tar
     
    }
  }
  cd $old_path
  return 0
}

## @brief Evaluates the md5 sum of a file
#
#  @param[in] file_name: the name of the file of which you want to vevaluate the md5 checksum
proc Md5Sum {file_name} {
  if !([file exists $file_name]) {
    Msg Warning "Could not find $xci_file."
    set file_hash -1
  }
  if {[catch {package require md5 2.0.7} result]} {
    Msg Warning "Tcl package md5 version 2.0.7 not found ($result), will use command line..."
    set hash [lindex [Execute md5sum $file_name] 0]
  } else {
    set file_hash [string tolower [md5::md5 -hex -file $file_name]]
  }
}


## @brief Checks that "ref" in .gitlab-ci.yml actually matches the hog.yml file in the
#
#  @param[in] repo_path path to the repository root
#  @param[in] allow_failure if true throws CriticalWarnings instead of Errors
#
proc CheckYmlRef {repo_path allow_failure} {

  if {$allow_failure} {
    set MSG_TYPE CriticalWarning
  } else {
    set MSG_TYPE Error
  }

  if { [catch {package require yaml 0.3.3} YAMLPACKAGE]} {
    Msg CriticalWarning "Cannot find package YAML, skipping consistency check of \"ref\" in gilab-ci.yaml file.\n Error message: $YAMLPACKAGE
You can fix this by installing package \"tcllib\""
    return
  }

  set thisPath [pwd]

    # Go to repository path
  cd "$repo_path"
  if [file exists .gitlab-ci.yml] {
    #get .gitlab-ci ref
    set YML_REF ""
    set YML_NAME ""
    if { [file exist .gitlab-ci.yml] } {
      set fp [open ".gitlab-ci.yml" r]
      set file_data [read $fp]
      close $fp
    } else {
      Msg $MSG_TYPE "Cannot open file .gitlab-ci.yml"
      cd $thisPath
      return
    }
    set file_data "\n$file_data\n\n"

    if { [catch {::yaml::yaml2dict -stream $file_data}  yamlDict]} {
      Msg $MSG_TYPE "Parsing $repo_path/.gitlab-ci.yml failed. To fix this, check that yaml syntax is respected, remember not to use tabs."
      cd $thisPath
      return
    } else {
      dict for {dictKey dictValue} $yamlDict {
        #looking for Hog include in .gitlab-ci.yml
        if {"$dictKey" == "include" && [lsearch [split $dictValue " {}"] "hog/Hog" ] != "-1"} {
          set YML_REF [lindex [split $dictValue " {}"]  [expr [lsearch -dictionary [split $dictValue " {}"] "ref"]+1 ] ]
          set YML_NAME [lindex [split $dictValue " {}"]  [expr [lsearch -dictionary [split $dictValue " {}"] "file"]+1 ] ]
        }
      }
    }
    if {$YML_REF == ""} {
      Msg Warning "Hog version not specified in the .gitlab-ci.yml. Assuming that master branch is used"
      cd Hog
      set YML_REF_F [Git {name-rev --tags --name-only origin/master}]
      cd ..
    } else {
      set YML_REF_F [regsub -all "'" $YML_REF ""]
    }

    if {$YML_NAME == ""} {
      Msg $MSG_TYPE "Hog included yml file not specified, assuming hog.yml"
      set YML_NAME_F hog.yml
    } else {
      set YML_NAME_F [regsub -all "^/" $YML_NAME ""]
    }

    lappend YML_FILES $YML_NAME_F

    #getting Hog repository tag and commit
    cd "Hog"

    #check if the yml file includes other files
    if { [catch {::yaml::yaml2dict -file $YML_NAME_F}  yamlDict]} {
      Msg $MSG_TYPE "Parsing $YML_NAME_F failed."
      cd $thisPath
      return
    } else {
      dict for {dictKey dictValue} $yamlDict {
        #looking for included files
        if {"$dictKey" == "include"} {
	  foreach v $dictValue { 
	    lappend YML_FILES [lindex [split $v " "]  [expr [lsearch -dictionary [split $v " "] "local"]+1 ] ]
	  }
	}
      }
    }

    Msg Info "Found the following yml files: $YML_FILES"

    set HOGYML_SHA [GetSHA $YML_FILES]
    lassign [GitRet "log --format=%h -1 $YML_REF_F" $YML_FILES] ret EXPECTEDYML_SHA 
    if {$ret != 0} {
      lassign [GitRet "log --format=%h -1 origin/$YML_REF_F" $YML_FILES] ret EXPECTEDYML_SHA 
      if {$ret != 0} {
        Msg $MSG_TYPE "Error in project .gitlab-ci.yml. ref: $YML_REF not found"
        set EXPECTEDYML_SHA ""
      }
    }
    set EXPECTEDYML_SHA [string toupper $EXPECTEDYML_SHA]
    if  {!($EXPECTEDYML_SHA eq "")} {
      if {$HOGYML_SHA == $EXPECTEDYML_SHA} {
        Msg Info "Hog included file $YML_FILES matches with $YML_REF in .gitlab-ci.yml."

      } else {
        Msg $MSG_TYPE "HOG $YML_FILES SHA mismatch.
        From Hog submodule: $HOGYML_SHA
        From ref in .gitlab-ci.yml: $EXPECTEDYML_SHA
        You can fix this in 2 ways: by changing the ref in your repository or by changing the Hog submodule commit"
      }
    } else {
      Msg $MSG_TYPE "One or more of the following files could not be found $YML_FILES in Hog at $YML_REF"
    }
  } else {
    Msg Info ".gitlab-ci.yml not found in $repo_path. Skipping this step"
  }

  cd "$thisPath"
}

## @brief Parse JSON file
#
# @returns  -1 in case of failure, JSON KEY VALUE in case of success
#
proc ParseJSON {JSON_FILE JSON_KEY} {
  set result [catch {package require Tcl 8.4} TclFound]
  if {"$result" != "0"} {
    Msg CriticalWarning "Cannot find Tcl package version equal or higher than 8.4.\n $TclFound\n Exiting"
    return -1
  }

  set result [catch {package require json} JsonFound]
  if {"$result" != "0"} {
    Msg CriticalWarning "Cannot find JSON package equal or higher than 1.0.\n $JsonFound\n Exiting"
    return -1
  }
  set JsonDict [json::json2dict  $JSON_FILE]
  set result [catch {dict get $JsonDict $JSON_KEY} RETURNVALUE]
  if {"$result" != "0"} {
    Msg CriticalWarning "Cannot find $JSON_KEY in $JSON_FILE\n Exiting"
    return -1
  } else {
    #Msg Info "$JSON_KEY --> $RETURNVALUE"
    return $RETURNVALUE
  }
}

## @brief Handle eos commands
#
# It can be used with lassign like this: lassign [eos \<eos command\> ] ret result
#
#  @param[in] command: the EOS command to be run, e.g. ls, cp, mv, rm
#  @param[in] attempt: (default 0) how many times the command should be attempted in case of failure
#
#  @returns a list of 2 elements: the return value (0 if no error occurred) and the output of the EOS command
proc eos {command {attempt 1}}  {
  global env
  if ![info exists env(EOS_MGM_URL)] {
    Msg Warning "Environment variable EOS_MGM_URL not set, setting it to default value root://eosuser.cern.ch"
    set ::env(EOS_MGM_URL) "root://eosuser.cern.ch"
  }
  if {$attempt < 1} {
    Msg Warning "The value of attempt should be 1 or more, not $attempt, setting it to 1 as default"
    set attempt 1
  }
  for {set i 0} {$i < $attempt} {incr i } {
    set ret [catch {exec -ignorestderr eos {*}$command} result]
    if {$ret == 0} {
      break
    } else {
      if {$attempt > 1} {
        set wait [expr {1+int(rand()*29)}]
        Msg Warning "Command $command failed ($i/$attempt): $result, trying again in $wait seconds..."
        after [expr $wait*1000]
      }
    }
  }
  return [list $ret $result]
}

## @brief Handle git commands
#
#
#  @param[in] command: the git command to be run including refs (branch, tags, sha, etc.), except files.
#  @param[in] files: files given to git as argument. They will always be separated with -- to avoid weird accidents
#
#  @returns the output of the git command
proc Git {command {files ""}}  {
  lassign [GitRet $command $files] ret result
  if {$ret != 0} {
    Msg Error "Code $ret returned by git running: $command -- $files"
  }    

  return $result
}

## @brief Handle git commands without causing an ewrror if ret is not 0
#
# It can be used with lassign like this: lassign [GitRet \<git command\> \<possibly files\> ] ret result
#
#  @param[in] command: the git command to be run including refs (branch, tags, sha, etc.), except files.
#  @param[in] files: files given to git as argument. They will always be separated with -- to avoid weird accidents
#
#  @returns a list of 2 elements: the return value (0 if no error occurred) and the output of the git command
proc GitRet {command {files ""}}  {
  global env
  set ret [catch {exec -ignorestderr git {*}$command -- {*}$files} result]

  return [list $ret $result]
}

## @brief Handle shell commands
#
# It can be used with lassign like this: lassign [ExecuteRet \<command\> ] ret result
#
#  @param[in] args: the shell command
#
#  @returns a list of 2 elements: the return value (0 if no error occurred) and the output of the command
proc ExecuteRet {args}  {
  global env
  if {[llength $args] == 0} {
    Msg CriticalWarning "No argument given" 
    set ret -1
    set result ""
  } else {
    set ret [catch {exec -ignorestderr {*}$args} result]
  }
  
  return [list $ret $result]
}

## @brief Handle shell commands
#
# It can be used with lassign like this: lassign [Execute \<command\> ] ret result
#
#  @param[in] command: the shell command
#
#  @returns the output of the command
proc Execute {args}  {
  global env
  lassign [ExecuteRet {*}$args] ret result
  if {$ret != 0} {
    Msg Error "Command [join $args] returned error code: $ret"
  }

  return $result
}


## @brief Parses .prop files in Top/$proj_name/list directory and creates a dict with the values
#
# @param[in] proj_name:   name of the project that requires the properties in the .prop file
#
proc ParseProcFile {proj_name} {
  set property_files [glob -nocomplain "./Top/$proj_name/list/*.prop"]
  set propDict [dict create ]
  foreach f $property_files {
    set fp [open $f r]
    set file_data [read $fp]
    close $fp
    set data [split $file_data "\n"]
    foreach line $data {
      if {![regexp {^ *$} $line] & ![regexp {^ *\#} $line] } { #Exclude empty lines and comments
        set file_and_prop [regexp -all -inline {\S+} $line]
        dict set propDict [lindex $file_and_prop 0] "[lindex $file_and_prop 1]"
      }
    }
  }
  return $propDict
}


## @brief Gets MAX number of Threads property from .prop file in Top/$proj_name/list directory.
#
# If property is not set returns default = 1
#
# @param[in] proj_name:   name of the project
#
# @return 1 if property is not set else the value of MaxThreads
#
proc GetMaxThreads {proj_name} {
  set maxThreads 1
  set propDict [ParseProcFile $proj_name]
  if {[dict exists $propDict maxThreads]} {
    set maxThreads [dict get $propDict maxThreads]
  }
  return $maxThreads
}

## @brief Returns the gitlab-ci.yml snippet for a CI stage and a defined project
#
#
# @param[in] stage:       name of the Hog-CI stage
# @param[in] proj_name:   name of the project in Hog repository
# @param[in] props:        names of the Hog-CI properties
# @param[in] stage_list:  the list of CI stages, used to evaluate the dependencies. Leave empty for no dependencies.
#
#
proc WriteYAMLStage {stage proj_name {props {}} {stage_list {} }} {
  if { [catch {package require yaml 0.3.3} YAMLPACKAGE]} {
    Msg CriticalWarning "Cannot find package YAML.\n Error message: $YAMLPACKAGE. If you are tunning on tclsh, you can fix this by installing package \"tcllib\""
    return -1
  }
  set dep_list [huddle list ]
  foreach s $stage_list {
    if {$s != $stage} {
      huddle append dep_list [huddle string "$s:$proj_name"]
    } else {
      break
    }
  }

  set synth_only "0"
  if { [lsearch $props "-synth_only"] > -1 } {
    set synth_only 1
  } 

  set inner [huddle create "PROJECT_NAME" $proj_name "HOG_ONLY_SYNTH" $synth_only "extends" ".vars"]

  if {[llength $stage_list] > 0} {
    set middle [huddle create "extends" ".$stage" "variables" $inner "dependencies" $dep_list]
  } else {
    set middle [huddle create "extends" ".$stage" "variables" $inner]
    }
  set outer [huddle create "$stage:$proj_name" $middle ]
  return [ string trimleft [ yaml::huddle2yaml $outer ] "-" ]
}


if {[GitVersion 2.7.2] == 0 } {
  Msg CriticalWarning "Found Git version older than 2.7.2. Hog might not work as expected.\n"
}

proc FindNewestVersion { versions } {
  set new_ver 0
  foreach ver $versions { 
    if { $ver > $new_ver } {
      set new_ver $ver
    }
  }
  return $new_ver
}

