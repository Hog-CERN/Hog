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
set CI_STAGES {"generate_project" "simulate_project"}
set CI_PROPS {"-synth_only"}


#### FUNCTIONS

proc GetSimulators {} {
  set SIMULATORS [list "modelsim" "questa" "riviera" "activehdl" "ies" "vcs"]
  return $SIMULATORS
}

## Get whether the IDE is Xilinx (Vivado or ISE)
proc IsXilinx {} {
  return [expr {[info commands get_property] != ""}]
}

## Get whether the IDE is vivado
proc IsVivado {} {
  if {[IsXilinx]} {
    return [expr {[string first Vivado [version]] == 0}]
  } else {
    return 0
  }
}

## Get whether the IDE is ISE (planAhead)
proc IsISE {} {
  if {[IsXilinx]} {
    return [expr {[string first PlanAhead [version]] == 0}]
  } else {
    return 0
  }
}

## Get whether the IDE is Quartus
proc IsQuartus {} {
  return [expr {[info commands project_new] != ""}]
}

## Get whether we are in tclsh
proc IsTclsh {} {
  return [expr ![IsQuartus] && ![IsXilinx]]
}

proc Msg {level msg {title ""}} {
  set level [string tolower $level]
  if {$level == 0 || $level == "status" || $level == "extra_info"} {
    set vlevel {STATUS}
    set qlevel info
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
  if {[IsXilinx]} {
    # Vivado
    set status [catch {send_msg_id Hog:$title-0 $vlevel $msg}]
    if {$status != 0} {
      exit $status
    }
  } elseif {[IsQuartus]} {
    # Quartus
    post_message -type $qlevel "Hog:$title $msg"
    if { $qlevel == "error"} {
      exit 1
    }
  } else {
    # Tcl Shell
    puts "*** Hog:$title $vlevel $msg"
    if {$qlevel == "error"} {
      exit 1
    }
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
  if {[IsXilinx]} {
    # Vivado
    set_property $property $value $object

  } elseif {[IsQuartus]} {
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
  if {[IsXilinx]} {
    # Vivado
    return [get_property -quiet $property $object]

  } elseif {[IsQuartus]} {
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
  if {[IsXilinx]} {
    #VIVADO_ONLY
    add_files -norecurse -fileset $sources $top_file
  } elseif {[IsQuartus]} {
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
  if {[IsXilinx]} {
    #VIVADO_ONLY
    set_property "top" $top_module $sources
  } elseif {[IsQuartus]} {
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
  if {[IsXilinx]} {
    # Vivado
    return [get_projects $proj]

  } elseif {[IsQuartus]} {
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
  if {[IsXilinx]} {
    # Vivado
    return [get_runs -quiet $run]

  } elseif {[IsQuartus]} {
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
  if {[IsXilinx]} {
    # Vivado
    set Files [get_files $file]
    set f [lindex $Files 0]
   
    return $f
    
  } elseif {[IsQuartus]} {
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
  #Msg Info "Found Git version: $v"
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
    .stp {
      set file_extension "USE_SIGNALTAP_FILE"
    }
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
    .qsys {
      set file_extension "QSYS_FILE"
    }
    .qip {
      set file_extension "QIP_FILE"
    }
    .sip {
      set file_extension "SIP_FILE"
    }
    .bsf {
      set file_extension "BSF_FILE"
    }
    .bdf {
      set file_extension "BDF_FILE"
    }
    .tcl {
      set file_extension "COMMAND_MACRO_FILE"
    }
    .vdm {
      set file_extension "VQM_FILE"
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
# @param[in] args The arguments are \<list_file\> \<path\> [options]
# * list_file file containing vhdl list with optional properties
# * path      path the vhdl file are referred to in the list file
# Options:
# * -lib \<library\> name of the library files will be added to, if not given will be extracted from the file name
# * -sha_mode  if not set to 0, the list files will be added as well and the IPs will be added to the file rather than to the special ip library. The sha mode should be used when you use the lists to calculate the git SHA, rather than to add the files to the project.
# * -verbose enable verbose messages
#
# @return              a list of 3 dictionaries: "libraries" has library name as keys and a list of filenames as values, "properties" has as file names as keys and a list of properties as values, main_libs has library name as keys and the correspondent top list file name as value
#
proc ReadListFile args {

  if {[IsQuartus]} {
    load_package report
    if { [catch {package require cmdline} ERROR] } {
      puts "$ERROR\n If you are running this script on tclsh, you can fix this by installing 'tcllib'"
      return 1
    }
  }

  set parameters {
    {lib.arg ""  "The name of the library files will be added to, if not given will be extracted from the file name."}
    {main_lib.arg "" The name of the library, from the main list file}
    {sha_mode "If set, the list files will be added as well and the IPs will be added to the file rather than to the special ip library. The sha mode should be used when you use the lists to calculate the git SHA, rather than to add the files to the project."}
    {verbose "Verbose messages"}
  }
  set usage "USAGE: ReadListFile \[options\] <list file> <path>"
  if {[catch {array set options [cmdline::getoptions args $parameters $usage]}] ||  [llength $args] != 2 } {
    Msg Error "[cmdline::usage $parameters $usage]"
    return
  }
  set list_file [lindex $args 0]
  set path [lindex $args 1]
  set sha_mode $options(sha_mode)
  set lib $options(lib)
  set main_lib $options(main_lib)
  set verbose $options(verbose)

  if { $sha_mode == 1} {
    set sha_mode_opt "-sha_mode"
  } else {
    set sha_mode_opt  ""
  }

  if { $verbose == 1} {
    set verbose_opt "-verbose"
  } else {
    set verbose_opt  ""
  }

  # if no library is given, work it out from the file name
  if {$lib eq ""} {
    set lib [file rootname [file tail $list_file]]
  }

  if {$main_lib eq ""} {
    set main_lib $lib
  }

  set ext [file extension $list_file]

  set list_file
  set fp [open $list_file r]
  set file_data [read $fp]
  close $fp
  set list_file_ext [file ext $list_file]
  set libraries [dict create]
  set main_libs [dict create]
  set properties [dict create]
  #  Process data file
  set data [split $file_data "\n"]
  set n [llength $data]
  if {$verbose == 1} {
    Msg Info "$n lines read from $list_file."
  }
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
        if {$verbose == 1} {
          Msg Info "Wildcard source expanded from $srcfile to $srcfiles"
        }
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
            if {$verbose == 1} {
              Msg Info "List file $vhdlfile found in list file, recursively opening it..."
            }
            ### Set list file properties
            set prop [lrange $file_and_prop 1 end]
            set library [lindex [regexp -inline {lib\s*=\s*(.+?)\y.*} $prop] 1]
            if { $library != "" } {
              if {$verbose == 1} {
                Msg Info "Setting $library as library for list file $vhdlfile..."
              }
            } else {
              if {$verbose == 1} {
                Msg Info "Setting $lib as library for list file $vhdlfile..."
              }
              set library $lib
            }
            lassign [ReadListFile {*}"-lib $library -main_lib $main_lib $sha_mode_opt $verbose_opt $vhdlfile $path"] l p m
            set libraries [MergeDict $l $libraries]
            set properties [MergeDict $p $properties]
            set main_libs [dict merge $m $main_libs]
          } elseif {[lsearch {.src .sim .con .ext} $extension] >= 0 } {
            Msg Error "$vhdlfile cannot be included into $list_file, $extension files must be included into $extension files."
          } else {
            ### Set file properties
            set prop [lrange $file_and_prop 1 end]
            regsub -all " *= *" $prop "=" prop
            dict lappend properties $vhdlfile $prop
            if {$verbose == 1} {
              Msg Info "Adding property $prop to $vhdlfile..."
            }
            ### Set File Set
            #Adding IP library
            if {$sha_mode == 0 && [lsearch {.xci .ip .bd} $extension] >= 0} {
              dict lappend libraries "$lib.ip" $vhdlfile
              dict set main_libs "$lib.ip" "$main_lib.ip"

              if {$verbose == 1} {
                Msg Info "Appending $vhdlfile to IP list..."
              }
            } else {
              set m [dict create]
              dict set m $lib$ext $main_lib$ext
              dict lappend libraries $lib$ext $vhdlfile
              if {[dict exists $main_libs $lib$ext] == 0} {
                set main_libs [dict merge $m $main_libs]
              }
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
  return [list $libraries $properties $main_libs]
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



## @brief Gets key from dict and returns default if key not found
#
# @param[in] dictName the name of the dictionary
# @param[in] keyName the name of the key
# @param[in] default the default value to be retruned if the key is not found
#
# @return        the dictionary key value

proc DictGet {dictName keyName {default ""}} {
  if {[dict exists $dictName $keyName]} {
    return [dict get $dictName $keyName]
  } else {
    return $default
  }
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
    set ret [GetSHA]
  } else {
    set ff [get_files -filter LIBRARY==$lib]
    set ret [GetSHA $ff]
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
    if {![regexp {^ *$} $line] & ![regexp {^ *\#} $line] } {
      #Exclude empty lines and comments
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
# @param[in] path the file/path or list of files/path the git SHA should be evaluated from. If is not set, use the current path
#
# @return         the value of the desired SHA
#
proc GetSHA {{path ""}} {
  if {$path == ""} {
    set ret [Git {log --format=%h --abbrev=7 -1} ]
    return [string toupper $ret]
  }

  # Get repository top level
  set repo_path [lindex [Git {rev-parse --show-toplevel} $path] 0]
  set paths {}
  # Retrieve the list of submodules in the repository
  foreach f $path {
    set file_in_module 0
    if {[file exists $repo_path/.gitmodules]} {
      lassign [GitRet "config --file $repo_path/.gitmodules --get-regexp path" " "] status result
      if {$status == 0} {
        set submodules [split $result "\n"]
      } else {
        set submodules ""
        Msg Warning "Something went wrong while trying to find submodules: result"
      }

      foreach mod $submodules {
        set module [lindex $mod 1]
        if {[string first "$repo_path/$module" $f] == 0} {
          # File is in a submodule. Append
          set file_in_module 1
          lappend paths "$repo_path/$module"
          break
        }
      }

    }
    if {$file_in_module == 0} {
      #File is not in a submodule
      lappend paths $f
    }
  }

  set ret [Git {log --format=%h --abbrev=7 -1} $paths ]
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

  if {$mr > -1} {
    # Candidate tab
    set M [format %02X $M]
    set m [format %02X $m]
    set c [format %04X $c]

  } elseif { $M > -1 } {
    # official tag
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
#  @param[in] proj_dir: The top folder of the project of which all the version must be calculated
#  @param[in] repo_path: The top folder of the repository
#  @param[in] ext_path: path for external libraries
#  @param[in] sim: if enabled, check the version also for the simulation files
#
#  @return  returns the project version
#
proc GetProjectVersion {proj_dir repo_path {ext_path ""} {sim 0}} {
  if { ![file exists $proj_dir] } {
    Msg CriticalWarning "$proj_dir not found"
    return -1
  }
  set old_dir [pwd]
  cd $proj_dir

  #The latest version the repository
  set v_last [ExtractVersionFromTag [Git {describe --abbrev=0 --match "v*"}]]
  lassign [GetRepoVersions $proj_dir $repo_path $ext_path $sim] sha ver
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


## Get custom Hog describe of a specific SHA
#
#  @param[in] sha     the git sha of the commit you want to calculate the describe of
#
#  @return            the Hog describe of the sha or the current one if the sha is 0
#
proc GetHogDescribe {sha} {
  if {$sha == 0 } {
    # in case the repo is dirty, we use the last commited sha and add a -dirty suffix
    set new_sha "[GetSHA]"
    set suffix "-dirty"
  } else {
    set new_sha $sha
    set suffix ""
  }
  set describe "v[HexVersionToString [GetVerFromSHA $new_sha]]-hog$new_sha$suffix"
  return $describe
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


## Get the configuration files to create a vivado/quartus project
#
#  @param[in] proj_dir: The project directory containing the conf file or the the tcl file
#
#  @return[in] a list containing the full path of the hog.conf, sim.conf, pre-creation.tcl, post-creation.tcl and proj.tcl files

proc GetConfFiles {proj_dir} {
  if ![file isdirectory $proj_dir] {
    Msg Error "$proj_dir is supposed to be the top project directory"
    return -1
  }
  set conf_file [file normalize $proj_dir/hog.conf]
  set sim_file [file normalize $proj_dir/sim.conf]
  set pre_tcl [file normalize $proj_dir/pre-creation.tcl]
  set post_tcl [file normalize $proj_dir/post-creation.tcl]

  return [list $conf_file $sim_file $pre_tcl $post_tcl]
}

## Get the versions for all libraries, submodules, etc. for a given project
#
#  @param[in] proj_dir: The project directory containing the conf file or the the tcl file
#  @param[in] repo_path: top path of the repository
#  @param[in] ext_path: path for external libraries
#  @param[in] sim: if enabled, check the version also for the simulation files
#
#  @return  a list containing all the versions: global, top (project tcl file), constraints, libraries, submodules, external, ipbus xml, user ip repos
#
proc GetRepoVersions {proj_dir repo_path {ext_path ""} {sim 0}} {
  if { [catch {package require cmdline} ERROR] } {
    puts "$ERROR\n If you are running this script on tclsh, you can fix this by installing 'tcllib'"
    return 1
  }

  set old_path [pwd]
  set conf_files [GetConfFiles $proj_dir]

  # This will be the list of all the SHAs of this project, the most recent will be picked up as GLOBAL SHA
  set SHAs ""
  set versions ""

  # Hog submodule
  cd $repo_path

  #Append the SHA in which Hog submodule was changed, not the submodule SHA
  lappend SHAs [GetSHA {Hog}]
  lappend versions [GetVerFromSHA $SHAs]

  cd "$repo_path/Hog"
  if {[Git {status --untracked-files=no  --porcelain}] eq ""} {
    Msg Info "Hog submodule [pwd] clean."
    lassign [GetVer ./] hog_ver hog_hash
  } else {
    Msg CriticalWarning "Hog submodule [pwd] not clean, commit hash will be set to 0."
    set hog_hash "0000000"
    set hog_ver "00000000"
  }

  cd $proj_dir

  if {[Git {status --untracked-files=no  --porcelain}] eq ""} {
    Msg Info "Git working directory [pwd] clean."
    set clean 1
  } else {
    Msg CriticalWarning "Git working directory [pwd] not clean, commit hash, and version will be set to 0."
    set clean 0
  }

  # Top project directory
  lassign [GetVer [join $conf_files]] top_ver top_hash
  lappend SHAs $top_hash
  lappend versions $top_ver

  # Read list files
  set libs ""
  set vers ""
  set hashes ""
  # Specify sha_mode 1 for GetHogFiles to get all the files, including the list-files themselves
  lassign [GetHogFiles -list_files "*.src" -sha_mode -repo_path $repo_path "./list/"] src_files dummy
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
  # Specify sha_mode 1 for GetHogFiles to get all the files, including the list-files themselves
  lassign [GetHogFiles  -list_files "*.con" -sha_mode -repo_path $repo_path  "./list/" ] cons_files dummy
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
    # Specify sha_mode 1 for GetHogFiles to get all the files, including the list-files themselves
    lassign [GetHogFiles  -list_files "*.sim" -sha_mode -repo_path $repo_path  "./list/"] sim_files dummy
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
    #" Fake comment for Visual Code Studio
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
    set hash [GetSHA $f]
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
      if {![regexp {^ *$} $line] & ![regexp {^ *\#} $line] } {
        #Exclude empty lines and comments
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
    lassign [GetHogFiles  -list_files "xml.lst" -repo_path $repo_path  -sha_mode "./list/"] xml_files dummy
    lassign [GetVer  [dict get $xml_files "xml.lst"] ] xml_ver xml_hash
    lappend SHAs $xml_hash
    lappend versions $xml_ver

    #Msg Info "Found IPbus XML SHA: $xml_hash and version: $xml_ver."

  } else {
    Msg Info "This project does not use IPbus XMLs"
    set xml_ver  00000000
    set xml_hash 0000000
  }

  set user_ip_repos ""
  set user_ip_repo_hashes ""
  set user_ip_repo_vers ""
  # User IP Repository (Vivado only, hog.conf only)
  if [file exists [lindex $conf_files 0]] {

    set PROPERTIES [ReadConf [lindex $conf_files 0]]
    set has_user_ip 0

    if {[dict exists $PROPERTIES main]} {
      set main [dict get $PROPERTIES main]
      dict for {p v} $main {
        if { [ string tolower $p ] == "ip_repo_paths" } {
          set has_user_ip 1
          foreach repo $v {
            lappend user_ip_repos "$repo_path/$repo"
          }
        }
      }
    }

    foreach repo $user_ip_repos {
      lassign [GetVer $repo] ver sha
      lappend user_ip_repo_hashes $sha
      lappend user_ip_repo_vers $ver
      lappend versions $ver
    }
  }


  #The global SHA and ver is the most recent among everything
  if {$clean == 1} {
    set commit [Git "log --format=%h -1 --abbrev=7 $SHAs"]
    set version [FindNewestVersion $versions]
  } else {
    set commit  "0000000"
    set version "00000000"
  }

  cd $old_path

  set top_hash [format %+07s $top_hash]
  set cons_hash [format %+07s $cons_hash]
  return [list $commit $version  $hog_hash $hog_ver  $top_hash $top_ver  $libs $hashes $vers  $cons_ver $cons_hash  $ext_names $ext_hashes  $xml_hash $xml_ver $user_ip_repos $user_ip_repo_hashes $user_ip_repo_vers ]
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
  lassign [ExecuteRet git tag -l "v*" --sort=-v:refname --merged ] vret vtags
  lassign [ExecuteRet git tag -l "b*" --sort=-v:refname --merged ] bret btags

  if {[llength $vtags] == 0 } {
    set vret 9
  }

  if {[llength $btags] == 0 } {
    set bret 9
  }

  if {$vret != 0 && $bret != 0} {
    Msg Error "No Hog version tags found in this repository."
  } else {
    set vers ""
    if { $vret == 0 } {
      set vtag [lindex $vtags 0]
      set vtag [ regsub {(v.*)-.*} $vtag "\\1" ]
      lassign [ExtractVersionFromTag $vtag] M m p mr
      set M [format %02X $M]
      set m [format %02X $m]
      set p [format %04X $p]
      lappend vers $M$m$p
    }

    if { $bret == 0 } {
      set btag [lindex $btags 0]
      lassign [ExtractVersionFromTag $btag] M m p mr
      set M [format %02X $M]
      set m [format %02X $m]
      set p [format %04X $p]
      lappend vers $M$m$p
    }
    set ver [FindNewestVersion $vers]
    set tag v[HexVersionToString $ver]

    # If btag is the newest get mr number
    if {$tag != $vtag} {
      lassign [ExtractVersionFromTag $btag] M m p mr
    } else {
      lassign [ExtractVersionFromTag $tag] M m p mr
    }

    if { $M > -1 } {
      # M=-1 means that the tag could not be parsed following a Hog format
      if {$mr == -1 } {
        # Tag is official, no b at the beginning (and no merge request number at the end)
        Msg Info "Found official version $M.$m.$p."
	set old_tag $vtag
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

      } else {
        # Tag is not official
        #Not official, do nothing unless version level is >=3, in which case convert the unofficial to official
        Msg Info "Found candidate version for $M.$m.$p."
	set old_tag $btag
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
        set new_tag $old_tag
        Msg Info "Tagging is not needed"
      }
    } else {
      Msg Error "Could not parse tag: $tag"
    }
  }

  return [list $old_tag $new_tag]
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
  set ::env(PYTHONHOME) "/usr"
  lassign  [ExecuteRet python -c "from __future__ import print_function; from sys import path;print(':'.join(path\[1:\]))"] ret msg
  if {$ret == 0} {
    set ::env(PYTHONPATH) $msg
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
  set dst [file normalize $dst]
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
  # Process data file
  set data [split $file_data "\n"]
  set n [llength $data]
  Msg Info "$n lines read from $list_file"
  set cnt 0
  set xmls {}
  set vhdls {}
  foreach line $data {
    if {![regexp {^ *$} $line] & ![regexp {^ *\#} $line] } {
      # Exclude empty lines and comments
      set file_and_prop [regexp -all -inline {\S+} $line]
      set xmlfiles [glob "$path/[lindex $file_and_prop 0]"]

      # for single non-globbed xmlfiles, we can have an associated vhdl file
      # multiple globbed xml does not make sense with a vhdl property
      if {[llength $xmlfiles]==1 && [llength $file_and_prop] > 1} {
        set vhdlfile [lindex $file_and_prop 1]
        set vhdlfile "$path/$vhdlfile"
      } else {
        set vhdlfile 0
      }

      set xml_list_error 0
      foreach xmlfile $xmlfiles {

        if {[file isdirectory $xmlfile]} {
          Msg CriticalWarning "Directory $xmlfile listed in xml.lst. Directories are not supported!"
          set xml_list_error 1
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
      if {${xml_list_error}} {
        Msg Error "Invalid files added to xml.lst!"
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
          lassign [ExecuteRet gen_ipbus_addr_decode $x 2>&1]  status log
          if {$status == 0} {
            set generated_vhdl ./ipbus_decode_[file root [file tail $x]].vhd
            if {$generate == 1} {
              Msg Info "Copying generated VHDL file $generated_vhdl into $v (replacing if necessary)"
              file copy -force -- $generated_vhdl $v
            } else {
              if {[file exists $v]} {
                set diff [CompareVHDL $generated_vhdl $v]
                if {[llength $diff] > 0} {
                  Msg CriticalWarning "$v does not correspond to its XML $x, [expr $n/3] line/s differ:"
                  Msg Status [join $diff "\n"]
                  set diff_file [open ../diff_[file root [file tail $x]].txt w]
                  puts $diff_file $diff
                  close $diff_file
                } else {
                  Msg Info "[file tail $x] and $v match."
                }
              } else {
                Msg Warning "VHDL address map file $v not found."
              }
            }
          } else {
            Msg Warning "Address map generation failed for [file tail $x]: $log"
          }
        } else {
          Msg Warning "Copied XML file $x not found."
        }
      } else {
        Msg Info "Skipped verification of [file tail $x] as no VHDL file was specified."
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
    if {![regexp {^$} $line] & ![regexp {^--} $line] } {
      #Exclude empty lines and comments
      lappend f1 $line
    }
  }

  while {[gets $b line] != -1} {
    set line [regsub {^[\t\s]*(.*)?\s*} $line "\\1"]
    if {![regexp {^$} $line] & ![regexp {^--} $line] } {
      #Exclude empty lines and comments
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

  set top [get_property "top"  [current_fileset]]
  set topfile [lindex [get_files -compile_order sources -used_in synthesis] end]
  dict lappend properties $topfile "top=$top"

  foreach fs $all_filesets {
    if {$fs == "utils_1"} {
      # Skipping utility fileset
      continue
    }

    set all_files [get_files -quiet -of_objects [get_filesets $fs]]
    set fs_type [get_property FILESET_TYPE [get_filesets $fs]]

    if {[string equal $fs_type "SimulationSrcs"] && [llength $all_files] > 0} {
      set topsim [get_property "top"  [get_filesets $fs]]
      set runtime [get_property "$simulator.simulate.runtime"  [get_filesets $fs]]
      #getting file containing top module as explained here: https://forums.xilinx.com/t5/Vivado-TCL-Community/How-can-I-get-the-file-path-of-the-top-module-in-the-current/td-p/455740
      if {[string equal "$topsim" ""]} {
        Msg Warning "No top simulation module found for fileset $fs."
      } else {
        set simtopfile [lindex [get_files -compile_order sources -used_in simulation -of_objects [get_filesets $fs]] end]
        if {[string equal [get_files -of_objects [get_filesets $fs] $simtopfile] ""] } {
          Msg Warning "Top simulation file $simtopfile not found in fileset $fs."
        } else {
          dict lappend properties $simtopfile "topsim=$topsim"
          if {![string equal "$runtime" "1000ns"]} {
            #not writing default value
            dict lappend properties $simtopfile "runtime=$runtime"
          }
        }
      }

      foreach simulator [GetSimulators] {
        set wavefile [get_property "$simulator.simulate.custom_wave_do" [get_filesets $fs]]
        if {![string equal "$wavefile" ""]} {
          dict lappend properties $wavefile wavefile
          break
        }
      }
      foreach simulator [GetSimulators] {
        set dofile [get_property "$simulator.simulate.custom_udo" [get_filesets $fs]]
        if {![string equal "$dofile" ""]} {
          dict lappend properties $dofile dofile
          break
        }
      }
    }

    foreach f $all_files {
      # Ignore files that are part of the vivado/planahead project but would not be reflected
      # in list files (e.g. generated products from ip cores)

      set ignore 0
      # Generated files point to a parent composite file;
      # planahead does not have an IS_GENERATED property
      if {-1 != [lsearch -exact [list_property [GetFile $f]] IS_GENERATED]} {
        if { [lindex [get_property  IS_GENERATED [GetFile $f]] 0] != 0} {
          set ignore 1
        }
      }
      if {-1 != [lsearch -exact [list_property  $f] PARENT_COMPOSITE_FILE]} {
        set ignore 1
      }

      if {!$ignore} {
        if {[file extension $f] != ".coe"} {
          set f [file normalize $f]
        }
        lappend files $f
        set type  [get_property FILE_TYPE [GetFile $f]]
        set lib [get_property LIBRARY [GetFile $f]]


        # Type can be complex like VHDL 2008, in that case we want the second part to be a property
        if {[string equal [lindex $type 0] "VHDL"] && [llength $type] == 1} {
          set prop "93"
        } elseif {[string equal [lindex $type 0] "SystemVerilog"] } {
          set prop "SystemVerilog"
        } elseif {[string equal $type "Verilog Header"]} {
          set prop "verilog_header"
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
        } elseif {[string equal $type "Verilog Header"]} {
          dict lappend libraries "OTHER" $f
          if {![string equal $prop ""]} {
            dict lappend properties $f $prop
          }
        } elseif {[string equal [lindex $type 0] "SystemVerilog"] } {
          dict lappend libraries "OTHER" $f
          if {![string equal $prop ""]} {
            dict lappend properties $f $prop
          }
        } elseif {[string equal $type "IP"]} {
          dict lappend libraries "IP" $f
        } elseif {[string equal $fs_type "Constrs"]} {
          dict lappend libraries "XDC" $f
        } else {
          dict lappend libraries "OTHER" $f
        }

        if {[lindex [get_property -quiet used_in_synthesis  [GetFile $f]] 0] == 0} {
          dict lappend properties $f "nosynth"
        }
        if {[lindex [get_property -quiet used_in_implementation  [GetFile $f]] 0] == 0} {
          dict lappend properties $f "noimpl"
        }
        if {[lindex [get_property -quiet used_in_simulation  [GetFile $f]] 0] == 0} {
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
  dict lappend properties "Simulator" [get_property target_simulator [current_project]]
  return [list $libraries $properties]
}



## @brief Extract files, libraries and properties from the project's list files
#
# @param[in] args The arguments are \<list_path\> [options]
# * list_path path to the list file directory
# Options:
# * -list_files \<List files\> the file wildcard, if not specified all Hog list files will be looked for
# * -repo_path \<repo path\> the absolute of the top directory of the repository
# * -sha_mode forwarded to ReadListFile, see there for info
# * -ext_path \<external path\> path for external libraries forwarded to ReadListFile
# * -verbose enable verbose messages
#
# @return a list of 2 dictionaries: libraries and properties
# - libraries has library name as keys and a list of filenames as values
# - properties has as file names as keys and a list of properties as values
# - main_libs has library name as keys and a the correspondent top list filename as values

proc GetHogFiles args {

  if {[IsQuartus]} {
    load_package report
    if { [catch {package require cmdline} ERROR] } {
      puts "$ERROR\n If you are running this script on tclsh, you can fix this by installing 'tcllib'"
      return 1
    }
  }


  set parameters {
    {list_files.arg ""  "The file wildcard, if not specified all Hog list files will be looked for."}
    {repo_path.arg ""  "The absolute path of the top directory of the repository."}
    {sha_mode "Forwarded to ReadListFile, see there for info."}
    {ext_path.arg "" "Path for the external libraries forwarded to ReadListFile."}
    {verbose  "Verbose messages"}
  }
  set usage "USAGE: GetHogFiles \[options\] <list path>"
  if {[catch {array set options [cmdline::getoptions args $parameters $usage]}] ||  [llength $args] != 1 } {
    Msg Error [cmdline::usage $parameters $usage]
    return
  }
  set list_path [lindex $args 0]
  set list_files $options(list_files)
  set sha_mode $options(sha_mode)
  set ext_path $options(ext_path)
  set verbose $options(verbose)
  set repo_path $options(repo_path)

  if { $sha_mode == 1 } {
    set sha_mode_opt "-sha_mode"
  } else {
    set sha_mode_opt ""
  }
  if { $verbose==1 } {
    set verbose_opt "-verbose"
  } else {
    set verbose_opt ""
  }

  if { $list_files == "" } {
    set list_files {.src,.con,.sub,.sim,.ext}
  }
  set libraries [dict create]
  set properties [dict create]
  set list_files [glob -nocomplain -directory $list_path "*{$list_files}"]
  set main_libs [dict create]

  foreach f $list_files {
    set ext [file extension $f]
    if {$ext == ".ext"} {
      lassign [ReadListFile {*}"$sha_mode_opt $verbose_opt $f $ext_path"] l p m
    } else {
      lassign [ReadListFile {*}"$sha_mode_opt $verbose_opt $f $repo_path"] l p m
    }
    set libraries [MergeDict $l $libraries]
    set properties [MergeDict $p $properties]
    set main_libs [dict merge $m $main_libs]
  }
  return [list $libraries $properties $main_libs]
}


## @brief Parse possible commands in the first line of Hog files (e.g. \#Vivado, \#Simulator, etc)
#
# @param[in] list_path path to the list file directory
# @param[in] list_file the list file name
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
proc AddHogFiles { libraries properties main_libs {verbose 0}} {
  Msg Info "Adding source files to project..."

  foreach lib [dict keys $libraries] {
    # Msg Info "lib: $lib \n"
    set lib_files [dict get $libraries $lib]
    # Msg Info "Files in $lib: $lib_files \n"
    set rootlib [file rootname [file tail $lib]]
    set ext [file extension $lib]
    set main_lib [dict get $main_libs $lib]
    set simlib [file rootname [file tail $main_lib]]
    # Msg Info "lib: $lib ext: $ext simlib $simlib \n"
    switch $ext {
      .sim {
        set file_set "$simlib\_sim"
        # if this simulation fileset was not created we do it now
        if {[string equal [get_filesets -quiet $file_set] ""]} {
          create_fileset -simset $file_set
          # Set active when creating, by default it will be the latest simset to be created, unless is specified in the sim.conf
          current_fileset -simset [ get_filesets $file_set ]
          set simulation  [get_filesets $file_set]
          foreach simulator [GetSimulators] {
            set_property -name {$simulator.compile.vhdl_syntax} -value {2008} -objects $simulation
          }
          set_property SOURCE_SET sources_1 $simulation
        }
      }
      .con {
        set file_set "constrs_1"
      }
      default {
        set file_set "sources_1"
      }
    }
    # ADD NOW LISTS TO VIVADO PROJECT
    if {[IsXilinx]} {
      add_files -norecurse -fileset $file_set $lib_files

      if {$ext != ".ip"} {
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
              if {[IsVivado]} {
                set_property -name "file_type" -value "VHDL 2008" -objects $file_obj
              }
            } else {
              Msg Info "Filetype is VHDL 93 for $f"
            }
          }

          if {[lsearch -inline -regex $props "SystemVerilog"] > 0} {
            # ISE does not support SystemVerilog
            if {[IsVivado]} {
              set_property -name "file_type" -value "SystemVerilog" -objects $file_obj
              Msg Info "Filetype is SystemVerilog for $f"

            } else {
              Msg Warning "Xilinx PlanAhead/ISE does not support SystemVerilog. Property not set for $f"
            }
          }


          # Top synthesis module
          set top [lindex [regexp -inline {top\s*=\s*(.+?)\y.*} $props] 1]
          if { $top != "" } {
            Msg Info "Setting $top as top module for file set $file_set..."
            set globalSettings::synth_top_module $top
          }

          # XDC
          if {[lsearch -inline -regex $props "XDC"] >= 0 || [file ext $f] == ".xdc"} {
            if {$verbose == 1} {
              Msg Info "Setting filetype XDC for $f"
            }
            set_property -name "file_type" -value "XDC" -objects $file_obj
          }

          # Verilog headers
          if {[lsearch -inline -regex $props "verilog_header"] >= 0} {
            Msg Info "Setting verilog header type for $f..."
            set_property file_type {Verilog Header} [get_files $f]
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
          # # Top simulation module
          set top_sim [lindex [regexp -inline {topsim\s*=\s*(.+?)\y.*} $props] 1]
          if { $top_sim != "" } {
            Msg Info "Setting $top_sim as top module for simulation file set $file_set..."
            Msg Warning "Setting the simulation top module from simulation list files will be deprecated in future Hog releases. Please consider setting this property in the sim.conf file, by adding the following line under the \[$file_set\] section.\ntop=$top_sim"

            set_property "top"  $top_sim [get_filesets $file_set]
            current_fileset -simset [get_filesets $file_set]
          }

          # Simulation runtime
          set sim_runtime [lindex [regexp -inline {runtime\s*=\s*(.+?)\y.*} $props] 1]
          if { $sim_runtime != "" } {
            Msg Info "Setting simulation runtime to $sim_runtime for simulation file set $file_set..."
            Msg Warning "Setting the simulation runtime from simulation list files will be deprecated in future Hog releases. Please consider setting this property in the sim.conf file, by adding the following line under the \[$file_set\] section.\n<simulator_name>.simulate.runtime=$sim_runtime"
            set_property -name {xsim.simulate.runtime} -value $sim_runtime -objects [get_filesets $file_set]
            foreach simulator [GetSimulators] {
              set_property $simulator.simulate.runtime  $sim_runtime  [get_filesets $file_set]
            }
          }

          # Wave do file
          if {[lsearch -inline -regex $props "wavefile"] >= 0} {
            Msg Warning "Setting a wave do file from simulation list files will be deprecated in future Hog releases. Please consider setting this property in the sim.conf file, by adding the following line under the \[$file_set\] section.\n<simulator_name>.simulate.custom_wave_do=[file tail $f]"

            if {$verbose == 1} {
              Msg Info "Setting $f as wave do file for simulation file set $file_set..."
            }
            # check if file exists...
            if [file exists $f] {
              foreach simulator [GetSimulators] {
                set_property "$simulator.simulate.custom_wave_do" [file tail $f] [get_filesets $file_set]
              }
            } else {
              Msg Warning "File $f was not found."

            }
          }

          #Do file
          if {[lsearch -inline -regex $props "dofile"] >= 0} {
            Msg Warning "Setting a custom do file from simulation list files will be deprecated in future Hog releases. Please consider setting this property in the sim.conf file, by adding the following line under the \[$file_set\] section.\n<simulator_name>.simulate.custom_do=[file tail $f]"
            if {$verbose == 1} {
              Msg Info "Setting $f as udo file for simulation file set $file_set..."
            }
            if [file exists $f] {
              foreach simulator [GetSimulators] {
                set_property "$simulator.simulate.custom_udo" [file tail $f] [get_filesets $file_set]
              }
            } else {
              Msg Warning "File $f was not found."
            }
          }

          # Tcl
          if {[file ext $f] == ".tcl" && $ext != ".con"} {
            if { [lsearch -inline -regex $props "source"] >= 0} {
              Msg Info "Sourcing Tcl script $f..."
              source $f
            }
          }
        }

      } else {
        # IPs
        foreach f $lib_files {
          #ADDING FILE PROPERTIES
          set props [dict get $properties $f]
          # Lock the IP
          if {[lsearch -inline -regex $props "locked"] >= 0} {
            Msg Info "Locking IP $f..."
            set_property IS_MANAGED 0 [get_files $f]
          }

          # Generating Target for BD File
          if {[file ext $f] == ".bd"} {
            Msg Info "Generating Target for [file tail $f], please remember to commit the (possible) changed file."
            generate_target all [get_files $f]
          }

        }

      }
      Msg Info "[llength $lib_files] file/s added to $rootlib..."
    } elseif {[IsQuartus] } {
      #QUARTUS ONLY
      if { $ext == ".sim"} {
        Msg Warning "Simulation files not supported in Quartus Prime mode... Skipping $lib"
      } else {
        if {! [is_project_open] } {
          Msg Error "Project is closed"
        }
        foreach cur_file $lib_files {
          set file_type [FindFileType $cur_file]

          #ADDING FILE PROPERTIES
          set props [dict get $properties $cur_file]

          # Top synthesis module
          set top [lindex [regexp -inline {top\s*=\s*(.+?)\y.*} $props] 1]
          if { $top != "" } {
            Msg Info "Setting $top as top module for file set $file_set..."
            set globalSettings::synth_top_module $top
          }
          if {[string first "VHDL" $file_type] != -1 } {

            if {[string first "1987" $props] != -1 } {
              set hdl_version "VHDL_1987"
            } elseif {[string first "1993" $props] != -1 } {
              set hdl_version "VHDL_1993"
            } elseif {[string first "2008" $props] != -1 } {
              set hdl_version "VHDL_2008"
            } else {
              set hdl_version "default"
            }
            if { $hdl_version == "default" } {
              set_global_assignment -name $file_type $cur_file -library $rootlib
            } else {
              set_global_assignment -name $file_type $cur_file -hdl_version $hdl_version -library $rootlib
            }
          } elseif {[string first "SYSTEMVERILOG" $file_type] != -1 } {
            if {[string first "2005" $props] != -1 } {
              set hdl_version "systemverilog_2005"
            } elseif {[string first "2009" $props] != -1 } {
              set hdl_version "systemverilog_2009"
            } else {
              set hdl_version "default"
            }
            if { $hdl_version == "default" } {
              set_global_assignment -name $file_type $cur_file
            } else {
              set_global_assignment -name $file_type $cur_file -hdl_version $hdl_version
            }
          } elseif {[string first "VERILOG" $file_type] != -1 } {
            if {[string first "1995" $props] != -1 } {
              set hdl_version "verilog_1995"
            } elseif {[string first "2001" $props] != -1 } {
              set hdl_version "verilog_2001"
            } else {
              set hdl_version "default"
            }
            if { $hdl_version == "default" } {
              set_global_assignment -name $file_type $cur_file
            } else {
              set_global_assignment -name $file_type $cur_file -hdl_version $hdl_version
            }
          } elseif {[string first "SOURCE" $file_type] != -1 || [string first "COMMAND_MACRO" $file_type] != -1 } {
            set_global_assignment  -name $file_type $cur_file
            if { $ext == ".con"} {
              source $cur_file
            } elseif { $ext == ".src"} {

              # If this is a Platform Designer file then generate the system
              if {[string first "qsys" $props] != -1 } {
                # remove qsys from options since we used it
                set emptyString ""
                regsub -all {\{||qsys||\}} $props $emptyString props

                set qsysPath [file dirname $cur_file]
                set qsysName "[file rootname [file tail $cur_file]].qsys"
                set qsysFile "$qsysPath/$qsysName"
                set qsysLogFile "$qsysPath/[file rootname [file tail $cur_file]].qsys-script.log"

                set qsys_rootdir ""
                if {! [info exists ::env(QSYS_ROOTDIR)] } {
                  if {[info exists ::env(QUARTUS_ROOTDIR)] } {
                    set qsys_rootdir "$::env(QUARTUS_ROOTDIR)/sopc_builder/bin"
                    Msg Warning "The QSYS_ROOTDIR environment variable is not set! I will use $qsys_rootdir"
                  } else {
                    Msg CriticalWarning "The QUARTUS_ROOTDIR environment variable is not set! Assuming all quartus executables are contained in your PATH!"
                  }
                } else {
                  set qsys_rootdir $::env(QSYS_ROOTDIR)
                }

                set cmd "$qsys_rootdir/qsys-script"
                set cmd_options " --script=$cur_file"
                if {![catch {"exec $cmd -version"}] || [lindex $::errorCode 0] eq "NONE"} {
                  Msg Info "Executing: $cmd $cmd_options"
                  Msg Info "Saving logfile in: $qsysLogFile"
                  if { [ catch {eval exec -ignorestderr "$cmd $cmd_options >>& $qsysLogFile"} ret opt ]} {
                    set makeRet [lindex [dict get $opt -errorcode] end]
                    Msg CriticalWarning "$cmd returned with $makeRet"
                  }
                } else {
                  Msg Error " Could not execute command $cmd"
                  exit 1
                }
                # Check the system is generated correctly and move file to correct directory
                if { [file exists $qsysName] != 0} {
                  file rename -force $qsysName $qsysFile
                  # Write checksum to file
                  set qsysMd5Sum [Md5Sum $qsysFile]
                  # open file for writing
                  set fileDir [file normalize "./hogTmp"]
                  set fileName "$fileDir/.hogQsys.md5"
                  if {![file exists $fileDir]} {
                    file mkdir $fileDir
                  }
                  set hogQsysFile [open $fileName "a"]
                  set fileEntry "$qsysFile\t$qsysMd5Sum"
                  puts $hogQsysFile $fileEntry
                  close $hogQsysFile
                } else {
                  Msg ERROR "Error while moving the generated qsys file to final location: $qsysName not found!";
                }
                if { [file exists $qsysFile] != 0} {
                  if {[string first "noadd" $props] == -1} {
                    set qsysFileType [FindFileType $qsysFile]
                    set_global_assignment  -name $qsysFileType $qsysFile
                  } else {
                    regsub -all {noadd} $props $emptyString props
                  }
                  if {[string first "nogenerate" $props] == -1} {
                    GenerateQsysSystem $qsysFile $props
                  }

                } else {
                  Msg ERROR "Error while generating ip variations from qsys: $qsysFile not found!";
                }
              }
            }
          } elseif {[string first "QSYS" $file_type] != -1 } {
            set emptyString ""
            regsub -all {\{||\}} $props $emptyString props
            if {[string first "noadd" $props] == -1} {
              set_global_assignment  -name $file_type $cur_file
            } else {
              regsub -all {noadd} $props $emptyString props
            }

            #Generate IPs
            if {[string first "nogenerate" $props] == -1} {
              GenerateQsysSystem $cur_file $props
            }
          } else {
            set_global_assignment -name $file_type $cur_file -library $rootlib
          }
        }
      }
    }
  }

}

# @brief Function searching for extra IP/BD files added at creation time using user scripts, and writing the list in
# Project/proj/.hog/extra.files, with the correspondent md5sum
#
# @param[in] libraries The Hog libraries
proc CheckExtraFiles {libraries} {
  ### CHECK NOW FOR IP OUTSIDE OF LIST FILE (Vivado only!)
  if {[IsVivado]} {
    lassign [GetProjectFiles] prjLibraries prjProperties
    set prjIPs  [DictGet $prjLibraries IP]
    set prjXDCs  [DictGet $prjLibraries XDC]
    set prjOTHERs [DictGet $prjLibraries OTHER]
    set prjSrcDict  [DictGet $prjLibraries SRC]

    set prj_dir [get_property DIRECTORY [current_project]]
    file mkdir "$prj_dir/.hog"
    set extra_file_name "$prj_dir/.hog/extra.files"
    set new_extra_file [open $extra_file_name "w"]


    foreach prjIP $prjIPs {
      set ip_in_list 0
      foreach lib [dict keys $libraries] {
        set ext [file extension $lib]
        if {$ext == ".ip"} {
          set lib_files [dict get $libraries $lib]
          foreach list_ip $lib_files {
            if {[lsearch $prjIP $list_ip] != -1} {
              set ip_in_list 1
              break
            }
          }
        }
      }
      if {$ip_in_list == 0} {
        if {[file extension $prjIP] == ".bd"} {
          # Generating BD products to save md5sum of already modified BD
          Msg Info "Generating targets of $prjIP..."
          generate_target all [get_files $prjIP]
        }
        puts $new_extra_file "$prjIP [Md5Sum $prjIP]"
        Msg Info "$prjIP has been generated by an external script. Adding to $extra_file_name..."
      }
    }

    foreach prjXDC $prjXDCs {
      set xdc_in_list 0
      foreach lib [dict keys $libraries] {
        set ext [file extension $lib]
        if {$ext != ".ip"} {
          set lib_files [dict get $libraries $lib]
          foreach list_file $lib_files {
            if {[lsearch $prjXDC $list_file] != -1} {
              set xdc_in_list 1
              break
            }
          }
        }
      }
      if {$xdc_in_list == 0} {
        puts $new_extra_file "$prjXDC [Md5Sum $prjXDC]"
        Msg Info "$prjXDC has been generated by an external script. Adding to $extra_file_name..."
      }
    }

    foreach prjOTHER $prjOTHERs {
      set oth_in_list 0
      foreach lib [dict keys $libraries] {
        set ext [file extension $lib]
        if {$ext != ".ip"} {
          set prjOTHER_ext [file extension $prjOTHER]
          if {$prjOTHER_ext == ".coe"} {
            set prjOTHER [file normalize $prjOTHER]
          }
          set lib_files [dict get $libraries $lib]
          foreach list_file $lib_files {
            if {[lsearch $prjOTHER $list_file] != -1} {
              set oth_in_list 1
              break
            }
          }
        }
      }
      if {$oth_in_list == 0} {
        puts $new_extra_file "$prjOTHER [Md5Sum $prjOTHER]"
        Msg Info "$prjOTHER has been generated by an external script. Adding to $extra_file_name..."
      }
    }

    foreach prjSRCs [dict keys $prjSrcDict] {
      set prjSRCs [dict get $prjSrcDict $prjSRCs]
      foreach prjSRC $prjSRCs {
        set src_in_list 0
        foreach lib [dict keys $libraries] {
          set ext [file extension $lib]
          if {$ext == ".src"} {
            set lib_files [dict get $libraries $lib]
            foreach list_file $lib_files {
              if {[lsearch $prjSRC $list_file] != -1} {
                set src_in_list 1
                break
              }
            }
          }
          if {$src_in_list == 1} {
            break
          }
        }
        if {$src_in_list == 0} {
          puts $new_extra_file "$prjSRC [Md5Sum $prjSRC]"
          Msg Info "$prjSRC has been generated by an external script. Adding to $extra_file_name..."
        }
      }
    }

    close $new_extra_file
  }
}

## @brief Function used to read the list of files generated at creation time by tcl scripts in Project/proj/.hog/extra.files
#
#  @param[in] extra_file_name the path to the extra.files file
#  @returns a dictionary with the full name of the files as key and a SHA as value
#
proc ReadExtraFileList { extra_file_name } {
  set extra_file_dict [dict create]
  if [file exists $extra_file_name] {
    set file [open $extra_file_name "r"]
    set file_data [read $file]
    close $file

    set data [split $file_data "\n"]
    foreach line $data {
      if {![regexp {^ *$} $line] & ![regexp {^ *\#} $line] } {
        set ip_and_md5 [regexp -all -inline {\S+} $line]
        dict lappend extra_file_dict "[lindex $ip_and_md5 0]" "[lindex $ip_and_md5 1]"
      }
    }
  }
  return $extra_file_dict
}

## @brief Function used to generate a qsys system from a .qsys file.
#  The procedure adds the generated IPs to the project.
#
#  @param[in] qsysFile the Intel Platform Designed file (.qsys), containing the system to be generated
#  @param[in] commandOpts the command options to be used during system generation as they are in qsys-generate options
#
proc GenerateQsysSystem {qsysFile commandOpts} {
  if { [file exists $qsysFile] != 0} {
    set qsysPath [file dirname $qsysFile]
    set qsysName [file rootname [file tail $qsysFile] ]
    set qsysIPDir "$qsysPath/$qsysName"
    set qsysLogFile "$qsysPath/$qsysName.qsys-generate.log"

    set qsys_rootdir ""
    if {! [info exists ::env(QSYS_ROOTDIR)] } {
      if {[info exists ::env(QUARTUS_ROOTDIR)] } {
        set qsys_rootdir "$::env(QUARTUS_ROOTDIR)/sopc_builder/bin"
        Msg Warning "The QSYS_ROOTDIR environment variable is not set! I will use $qsys_rootdir"
      } else {
        Msg CriticalWarning "The QUARTUS_ROOTDIR environment variable is not set! Assuming all quartus executables are contained in your PATH!"
      }
    } else {
      set qsys_rootdir $::env(QSYS_ROOTDIR)
    }

    set cmd "$qsys_rootdir/qsys-generate"
    set cmd_options "$qsysFile --output-directory=$qsysIPDir $commandOpts"
    if {![catch {"exec $cmd -version"}] || [lindex $::errorCode 0] eq "NONE"} {
      Msg Info "Executing: $cmd $cmd_options"
      Msg Info "Saving logfile in: $qsysLogFile"
      if {[ catch {eval exec -ignorestderr "$cmd $cmd_options >>& $qsysLogFile"} ret opt]} {
        set makeRet [lindex [dict get $opt -errorcode] end]
        Msg CriticalWarning "$cmd returned with $makeRet"
      }
    } else {
      Msg Error " Could not execute command $cmd"
      exit 1
    }
    #Add generated IPs to project
    set qsysIPFileList  [concat [glob -nocomplain -directory $qsysIPDir -types f *.ip *.qip ] [glob -nocomplain -directory "$qsysIPDir/synthesis" -types f *.ip *.qip *.vhd *.vhdl ] ]
    foreach qsysIPFile $qsysIPFileList {
      if { [file exists $qsysIPFile] != 0} {
        set qsysIPFileType [FindFileType $qsysIPFile]
        set_global_assignment -name $qsysIPFileType $qsysIPFile
        # Write checksum to file
        set IpMd5Sum [Md5Sum $qsysIPFile]
        # open file for writing
        set fileDir [file normalize "./hogTmp"]
        set fileName "$fileDir/.hogQsys.md5"
        if {![file exists $fileDir]} {
          file mkdir $fileDir
        }
        set hogQsysFile [open $fileName "a"]
        set fileEntry "$qsysIPFile\t$IpMd5Sum"
        puts $hogQsysFile $fileEntry
        close $hogQsysFile
      }
    }
  } else {
    Msg ERROR "Error while generating ip variations from qsys: $qsysFile not found!"
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
# @param[in] runs_dir: the runs directory of the project. Typically called Projects/\<project name\>/\<project name\>.runs
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


  if {[string first "/eos/" $ip_path] == 0} {
    # IP Path is on EOS
    set on_eos 1
  } else {
    set on_eos 0
  }

  if {$on_eos == 1} {
    lassign [eos  "ls $ip_path"] ret result
    if  {$ret != 0} {
      Msg CriticalWarning "Could not find mother directory for ip_path: $ip_path."
      cd $old_path
      return -1
    } else {
      lassign [eos  "ls $ip_path"] ret result
      if  {$ret != 0} {
        Msg Info "IP repository path on eos does not exist, creating it now..."
        eos "mkdir $ip_path" 5
      } else {
        Msg Info "IP repository path on eos is set to: $ip_path"
      }
    }
  } else {
    file mkdir $ip_path
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
    if {$on_eos == 1} {
      lassign [eos "ls $ip_path/$file_name.tar"] ret result
      if {$ret != 0} {
        set will_copy 1
      } else {
        if {$force == 0 } {
          Msg Info "IP already in the EOS repository, will not copy..."
        } else {
          Msg Info "IP already in the EOS repository, will forcefully replace..."
          set will_copy 1
          set will_remove 1
        }
      }
    } else {
      if {[file exists "$ip_path/$file_name.tar"]} {
        if {$force == 0 } {
          Msg Info "IP already in the local repository, will not copy..."
        } else {
          Msg Info "IP already in the local repository, will forcefully replace..."
          set will_copy 1
          set will_remove 1
        }
      } else {
        set will_copy 1
      }
    }

    if {$will_copy == 1} {
      set ip_synth_files [glob -nocomplain $xci_path/$xci_ip_name*]
      set ip_synth_files_rel ""
      foreach ip_synth_file $ip_synth_files {
        lappend ip_synth_files_rel  [Relative $repo_path $ip_synth_files]
      }

      if {[llength $ip_synth_files] > 0} {
        Msg Info "Found some IP synthesised files matching $runs_dir/$file_name*"
        if {$will_remove == 1} {
          Msg Info "Removing old synthesised directory $ip_path/$file_name.tar..."
          if {$on_eos == 1} {
            eos "rm -rf $ip_path/$file_name.tar" 5
          } else {
            file delete -force "$ip_path/$file_name.tar"
          }
        }

        Msg Info "Creating local archive with ip generated files..."
        ::tar::create $file_name.tar [glob -nocomplain [Relative $repo_path $xci_path]  $ip_synth_files_rel]
        Msg Info "Copying generated files for $xci_name..."
        if {$on_eos == 1} {
          lassign [ExecuteRet xrdcp -f -s $file_name.tar  $::env(EOS_MGM_URL)//$ip_path/] ret msg
          if {$ret != 0} {
            Msg CriticalWarning "Something went wrong when copying the IP files to EOS. Error message: $msg"
          }
        } else {
          file copy -force "$file_name.tar" "$ip_path/"
        }

        Msg Info "Removing local archive"
        file delete $file_name.tar
      } else {
        Msg Warning "Could not find synthesized files matching $runs_dir/$file_name*"
      }
    }
  } elseif {$what_to_do eq "pull"} {
    if {$on_eos == 1} {
      lassign [eos "ls $ip_path/$file_name.tar"] ret result
      if  {$ret != 0} {
        Msg Info "Nothing for $xci_name was found in the EOS repository, cannot pull."
        cd $old_path
        return -1

      } else {
        set remote_tar "$::env(EOS_MGM_URL)//$ip_path/$file_name.tar"
        Msg Info "IP $xci_name found in the repository $remote_tar, copying it locally to $repo_path..."

        lassign [ExecuteRet xrdcp -f -r -s $remote_tar $repo_path] ret msg
        if {$ret != 0} {
          Msg CriticalWarning "Something went wrong when copying the IP files to EOS. Error message: $msg"
        } else {
          Msg Info "Extracting IP files from archive to $repo_path..."
          ::tar::untar $file_name.tar -dir $repo_path -noperms
          Msg Info "Removing local archive"
          file delete $file_name.tar
        }
      }
    } else {
      if {[file exists "$ip_path/$file_name.tar"]} {
        Msg Info "IP $xci_name found in local repository $ip_path/$file_name.tar, copying it locally to $repo_path..."
        file copy -force $ip_path/$file_name.tar $repo_path
        Msg Info "Extracting IP files from archive to $repo_path..."
        ::tar::untar $file_name.tar -dir $repo_path -noperms
        Msg Info "Removing local archive"
        file delete $file_name.tar
      } else {
        Msg Info "Nothing for $xci_name was found in the local IP repository, cannot pull."
        cd $old_path
        return -1
      }
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
    Msg Warning "Could not find $file_name."
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
        if {"$dictKey" == "include" && ([lsearch [split $dictValue " {}"] "/hog.yml" ] != "-1" || [lsearch [split $dictValue " {}"] "/hog-dynamic.yml" ] != "-1")} {
          set YML_REF [lindex [split $dictValue " {}"]  [expr [lsearch -dictionary [split $dictValue " {}"] "ref"]+1 ] ]
          set YML_NAME [lindex [split $dictValue " {}"]  [expr [lsearch -dictionary [split $dictValue " {}"] "file"]+1 ] ]
        }
      }
    }
    if {$YML_REF == ""} {
      Msg Warning "Hog version not specified in the .gitlab-ci.yml. Assuming that master branch is used."
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
    lassign [GitRet "log --format=%h -1 --abbrev=7 $YML_REF_F" $YML_FILES] ret EXPECTEDYML_SHA
    if {$ret != 0} {
      lassign [GitRet "log --format=%h -1 --abbrev=7 origin/$YML_REF_F" $YML_FILES] ret EXPECTEDYML_SHA
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
# Sometimes you need to remove the --. To do that just set files to " "
#
#  @returns a list of 2 elements: the return value (0 if no error occurred) and the output of the git command
proc GitRet {command {files ""}}  {
  global env
  if {$files eq " "} {
    set dashes ""
  } else {
    set dashes "--"
  }
  set ret [catch {exec -ignorestderr git {*}$command $dashes {*}$files} result]

  return [list $ret $result]
}

## @brief Cheks if file was committed into the repository
#
#
#  @param[in] File: file name
#
#  @returns 1 if file was committed and 0 if file was not committed
proc FileCommitted {File }  {
  set Ret 1
  set currentDir [pwd]
  cd [file dirname [file normalize $File]]
  set GitLog [Git ls-files [file tail $File]]
  if {$GitLog == ""} {
    Msg CriticalWarning "File [file normalize $File] is not in the git repository. Please add it with:\n git add [file normalize $File]\n"
    set Ret 0
  }
  cd $currentDir
  return $Ret
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
#  @param[in] args: the shell command
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


## @brief Gets MAX number of Threads property from property.conf file in Top/$proj_name directory.
#
# If property is not set returns default = 1
#
# @param[in] proj_dir:   the top folder of the project
#
# @return 1 if property is not set else the value of MaxThreads
#
proc GetMaxThreads {proj_dir} {
  set maxThreads 1
  if {[file exist $proj_dir/hog.conf]} {
    set properties [ReadConf [lindex [GetConfFiles $proj_dir] 0]]
    if {[dict exists $properties parameters]} {
      set propDict [dict get $properties parameters]
      if {[dict exists $propDict MAX_THREADS]} {
        set maxThreads [dict get $propDict MAX_THREADS]
      }
    }
  } else {
    Msg Warning "File $proj_dir/hog.conf not found. Max threads will be set to default value 1"
  }
  return $maxThreads
}



## @brief Returns the gitlab-ci.yml snippet for a CI stage and a defined project
#
# @param[in] proj_name:   The project name
# @param[in] ci_confs:    Dictionary with CI configurations
#
proc WriteGitLabCIYAML {proj_name {ci_conf ""}} {
  if { [catch {package require yaml 0.3.3} YAMLPACKAGE]} {
    Msg CriticalWarning "Cannot find package YAML.\n Error message: $YAMLPACKAGE. If you are tunning on tclsh, you can fix this by installing package \"tcllib\""
    return -1
  }

  set job_list []
  if {$ci_conf != ""} {
    set ci_confs [ReadConf $ci_conf]
    foreach sec [dict keys $ci_confs] {
      if {[string first : $sec] == -1} {
        lappend job_list $sec
      }
    }
  } else {
    set job_list {"generate_project" "simulate_project"}
    set ci_confs ""
  }

  set out_yaml [huddle create]
  foreach job $job_list {
    # Check main project configurations
    set huddle_tags [huddle list]
    set tag_section ""
    set sec_dict [dict create]

    if {$ci_confs != ""} {
      foreach var [dict keys [dict get $ci_confs $job]] {
        if {$var == "tags"} {
          set tag_section "tags"
          set tags [dict get [dict get $ci_confs $job] $var]
          set tags [split $tags ","]
          foreach tag $tags {
            set tag_list [huddle list $tag]
            set huddle_tags [huddle combine $huddle_tags $tag_list]
          }
        } else {
          dict set sec_dict $var [dict get [dict get $ci_confs $job] $var]
        }
      }
    }

    # Check if there are extra variables in the conf file
    set huddle_variables [huddle create "PROJECT_NAME" $proj_name "extends" ".vars"]
    if {[dict exists $ci_confs "$job:variables"]} {
      # puts "here"
      set var_dict [dict get $ci_confs $job:variables]
      foreach var [dict keys $var_dict] {
        # puts [dict get $var_dict $var]
        set value [dict get $var_dict "$var"]
        set var_inner [huddle create "$var" "$value"]
        set huddle_variables [huddle combine $huddle_variables $var_inner]
      }
    }


    set middle [huddle create "extends" ".$job" "variables" $huddle_variables]
    foreach sec [dict keys $sec_dict] {
      set value [dict get $sec_dict $sec]
      set var_inner [huddle create "$sec" "$value"]
      set middle [huddle combine $middle $var_inner]
    }
    if {$tag_section != ""} {
      set middle2 [huddle create "$tag_section" $huddle_tags]
      set middle [huddle combine $middle $middle2]
    }

    set outer [huddle create "$job:$proj_name" $middle ]
    set out_yaml [huddle combine $out_yaml $outer]
  }

  return [ string trimleft [ yaml::huddle2yaml $out_yaml ] "-" ]
}


proc FindNewestVersion { versions } {
  set new_ver 00000000
  foreach ver $versions {
    if {[ expr 0x$ver > 0x$new_ver ] } {
      set new_ver $ver
    }
  }
  return $new_ver
}

## Reset files in the repository
#
#  @param[in]    reset_file a file containing a list of files separated by new lines or spaces (Hog-CI creates such a file in Projects/hog_reset_files)
#
#  @return       Nothing
#
proc ResetRepoFiles {reset_file} {
  if {[file exists $reset_file]} {
    Msg Info "Found $reset_file, opening it..."
    set fp [open $reset_file r]
    set wild_cards [lsearch -all -inline -not -regexp [split [read $fp] "\n"] "^ *$"]
    close $fp
    Msg Info "Found the following files/wild cards to restore if modified: $wild_cards..."
    foreach w $wild_cards {
      set mod_files [GetModifiedFiles "." $w]
      if {[llength $mod_files] > 0} {
        Msg Info "Found modified $w files: $mod_files, will restore them..."
        RestoreModifiedFiles "." $w
      } else {
        Msg Info "No modified $w files found."
      }
    }
  }
}

## Search the Hog projects inside a directory
#
#  @param[in]    dir The directory to search
#
#  @return       The list of projects
#
proc SearchHogProjects {dir} {
  set projects_list {}
  if {[file exists $dir]} {
    if {[file isdirectory $dir]} {
      foreach proj_dir [glob -nocomplain -type d $dir/* ] {
        if {![regexp {^.*Top/+(.*)$} $proj_dir dummy proj_name]} {
          Msg Warning "Could not parse Top directory $dir"
          break
        }
        if { [file exists "$proj_dir/hog.conf" ] } {
          lappend projects_list $proj_name
        } else {
          foreach p [SearchHogProjects $proj_dir] {
            lappend projects_list $p
          }
        }
      }

    } else {
      Msg Error "Input $dir is not a directory!"
    }
  } else {
    Msg Error "Directory $dir doesn't exist!"
  }
  return $projects_list
}

## Returns the group name from the project directory
#
#  @param[in]    proj_dir project directory
#
#  @return       the group name without initial and final slashes
#
proc GetGroupName {proj_dir} {
  if {[regexp {^.*Projects/+(.*?)/*$} $proj_dir dummy dir]} {
    set group [file dir $dir]
    if { $group == "." } {
      set group ""
    }
  } else {
    Msg Warning "Could not parse project directory $proj_dir"
    set group ""
  }
  return $group
}

## Read a property configuration file and returns a dictionary
#
#  @param[in]    file_name the configuration file
#
#  @return       The dictionary
#
proc ReadConf {file_name} {
  package require inifile 0.2.3

  ::ini::commentchar "#"
  set f [::ini::open $file_name]
  set properties [dict create]
  foreach sec [::ini::sections $f] {
    set new_sec $sec
    set key_pairs [::ini::get $f $sec]

    #manipulate strings here:
    regsub -all {\{\"} $key_pairs "{" key_pairs
    #" Comment for VSCode
    regsub -all {\"\}} $key_pairs "}" key_pairs

    dict set properties $new_sec [dict create {*}$key_pairs]
  }

  ::ini::close $f

  return $properties
}

## Write a property configuration file from a dictionary
#
#  @param[in]    file_name the configuration file
#  @param[in]    config the configuration dictionary
#  @param[in]    comment comment to add at the beginning of configuration file
#
#
proc WriteConf {file_name config {comment ""}} {
  package require inifile 0.2.3

  ::ini::commentchar "#"
  set f [::ini::open $file_name w]

  foreach sec [dict keys $config] {
    set section [dict get $config $sec]
    dict for {p v} $section {
      ::ini::set $f $sec $p $v
    }
  }

  #write comment before the first section (first line of file)
  if {![string equal "$comment"  ""]} {
    ::ini::comment $f [lindex [::ini::sections $f] 0] "" $comment
  }
  ::ini::commit $f

  ::ini::close $f

}


## Check if a path is absolute or relative
#
#  @param[in]    the path to check
#
proc IsRelativePath {path} {
  if {[string index $path 0] == "/" || [string index $path 0] == "~"} {
    return 0
  } else {
    return 1
  }
}


# Check Git Version when sourcing hog.tcl
if {[GitVersion 2.7.2] == 0 } {
  Msg CriticalWarning "Found Git version older than 2.7.2. Hog might not work as expected.\n"
}


## Write the resource utilization table into a a file (Vivado only)
#
#  @param[in]    input the input .rpt report file from Vivado
#  @param[in]    output the output file
#  @param[in]    project_name the name of the project
#  @param[in]    run synthesis or implementation
proc WriteUtilizationSummary {input output project_name run} {
  set f [open $input "r"]
  set o [open $output "a"]
  puts $o "## $project_name $run Utilization report"
  struct::matrix util_m
  util_m add columns 12
  util_m add row
  if { [GetIDEVersion] >= 2021.0 } {
    util_m add row "|          **Site Type**         |  **Used**  | **Fixed** | **Prohibited** | **Available** | **Util%** |"  
  } else {
    util_m add row "|          **Site Type**         | **Used** | **Fixed** | **Available** | **Util%** |" 
  }
  util_m add row "|  --- | --- | --- | --- | --- |"

  set luts 0
  set regs 0
  set uram 0
  set bram 0
  set dsps 0
  set ios 0

  while {[gets $f line] >= 0} {
    if { ( [string first "| CLB LUTs" $line] >= 0 || [string first "| Slice LUTs" $line] >= 0 ) && $luts == 0 } {
      util_m add row $line
      set luts 1
    }
    if { ( [string first "| CLB Registers" $line] >= 0  || [string first "| Slice Registers" $line] >= 0  ) && $regs == 0} {
      util_m add row $line
      set regs 1
    }
    if { [string first "| Block RAM Tile" $line] >= 0 && $bram == 0 } {
      util_m add row $line
      set bram 1
    }
    if { [string first "URAM " $line] >= 0 && $uram == 0} {
      util_m add row $line
      set uram 1
    }
    if { [string first "DSPs" $line] >= 0 && $dsps == 0 } {
      util_m add row $line
      set dsps 1
    }
    if { [string first "Bonded IOB" $line] >= 0 && $ios == 0 } {
      util_m add row $line
      set ios 1
    }
  }
  util_m add row

  close $f
  puts $o [util_m format 2string]
  close $o
}

## Get the Date and time of a commit (or current time if Git < 2.9.3)
#
#  @param[in]    commit The commit
proc GetDateAndTime {commit} {
  set clock_seconds [clock seconds]

  if [GitVersion 2.9.3] {
    set date [Git "log -1 --format=%cd --date=format:%d%m%Y $commit"]
    set timee [Git "log -1 --format=%cd --date=format:00%H%M%S $commit"]
  } else {
    Msg Warning "Found Git version older than 2.9.3. Using current date and time instead of commit time."
    set date [clock format $clock_seconds  -format {%d%m%Y}]
    set timee [clock format $clock_seconds -format {00%H%M%S}]
  }
  return $date $timee
}

## Get the Project flavour
#
#  @param[in]    proj_name The project name
proc GetProjectFlavour {proj_name} {
  # Calculating flavour if any
  set flavour [string map {. ""} [file ext $proj_name]]
  if {$flavour != ""} {
    if [string is integer $flavour] {
      Msg Info "Project $proj_name has flavour = $flavour, the generic variable FLAVOUR will be set to $flavour"
    } else {
      Msg Warning "Project name has a unexpected non numeric extension, flavour will be set to -1"
      set flavour -1
    }

  } else {
    set flavour -1
  }
  return $flavour
}

## Setting the generic property
#
#  @param[in]    list of variables to be written in the generics
proc WriteGenerics {date timee commit version top_hash top_ver hog_hash hog_ver cons_ver cons_hash libs vers hashes ext_names ext_hashes user_ip_repos user_ip_vers user_ip_hashes flavour {xml_ver ""} {xml_hash ""}} {
  #####  Passing Hog generic to top file
  if {[IsXilinx]} {
    ### VIVADO
    # set global generic varibles
    set generic_string "GLOBAL_DATE=32'h$date GLOBAL_TIME=32'h$timee GLOBAL_VER=32'h$version GLOBAL_SHA=32'h0$commit TOP_SHA=32'h0$top_hash TOP_VER=32'h$top_ver HOG_SHA=32'h0$hog_hash HOG_VER=32'h$hog_ver CON_VER=32'h$cons_ver CON_SHA=32'h0$cons_hash"
    if {$xml_hash != "" && $xml_ver != ""} {
      set generic_string "$generic_string XML_VER=32'h$xml_ver XML_SHA=32'h0$xml_hash"
    }

    #set project specific lists
    foreach l $libs v $vers h $hashes {
      set ver "[string toupper $l]_VER=32'h$v "
      set hash "[string toupper $l]_SHA=32'h0$h"
      set generic_string "$generic_string $ver $hash"
    }

    foreach e $ext_names h $ext_hashes {
      set hash "[string toupper $e]_SHA=32'h0$h"
      set generic_string "$generic_string $hash"
    }

    foreach repo $user_ip_repos v $user_ip_vers h $user_ip_hashes {
      set repo_name [file tail $repo]
      set ver "[string toupper $repo_name]_VER=32'h$v "
      set hash "[string toupper $repo_name]_SHA=32'h0$h"
      set generic_string "$generic_string $ver $hash"
    }

    if {$flavour != -1} {
      set generic_string "$generic_string FLAVOUR=$flavour"
    }

    set_property generic $generic_string [current_fileset]

  }
}

## Returns the version of the IDE (Vivado,Quartus,PlanAhead) in use
#
#  @return       the version in astring format, e.g. 2020.2
#
proc GetIDEVersion {} {
  if {[IsXilinx]} {
    #Vivado or planAhead
    set ver [version -short]
  } elseif {[IsQuartus]} {
    # Quartus
    global quartus
    regexp {[\.0-9]+} $quartus(version) ver

  }
  return $ver
}

## Get the IDE (Vivado,Quartus,PlanAhead) version from the conf file she-bang
#
#  @param[in]    conf_file The hog.conf file
proc GetIDEFromConf {conf_file} {
  set f [open $conf_file "r"]
  set line [gets $f]
  close $f
  if {[regexp -all {^\# *(\w*) *(\d+\.\d+(?:.\d+)?)? *$} $line dummy ide version dummy]} {
    if {[info exists version] && $version != ""} {
      set ver $version
    } else {
      set ver 0.0.0
    }
    set ret [list $ide $ver]
  } else {
    Msg CriticalWarning "The first line of hog.conf should be \#<IDE name> <version>, where <IDE name>. is quartus, vivado, planahead and <version> the tool version, e.g. \#vivado 2020.2. Will assume vivado."
    set ret [list "vivado" "0.0.0"]
  }

  return $ret
}
