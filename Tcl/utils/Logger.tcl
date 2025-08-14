#   Copyright 2018-2025 The University of Birmingham
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

# @file Logger.tcl
# Logger functions for the Hog project


set DEBUG_MODE 0

proc setDebugMode {mode} {
  global DEBUG_MODE
  set DEBUG_MODE $mode
}

proc getDebugMode {} {
  global DEBUG_MODE
  return $DEBUG_MODE
}

proc printDebugMode {} {
  global DEBUG_MODE
  if {$DEBUG_MODE} {
    Msg Info "DEBUG_MODE is set to $DEBUG_MODE"
  } else {
    Msg Info "DEBUG_MODE is not set or is 0"
  }
}

## @brief Safely get a value from a dictionary
#
# @param[in] d    The dictionary to search
# @param[in] args The keys to look for
proc dictSafeGet {d args} {
  if {[dict exists $d {*}$args]} {
    return [dict get $d {*}$args]
  } else {
    return ""
  }
}

## @brief The Hog Printout Msg function
#
# @param[in] level The severity level (status, info, warning, critical, error, debug)
# @param[in] msg   The message to print
# @param[in] title The title string to be included in the header of the message [Hog:$title] (default "")
proc Msg {level fmsg {title ""}} {
  foreach msg [split $fmsg "\n"] {
    set level [string tolower $level]
    if {$title == ""} {set title [lindex [info level [expr {[info level] - 1}]] 0]}
    if {$level == 0 || $level == "status" || $level == "extra_info"} {
      set vlevel {STATUS}
      set qlevel info
    } elseif {$level == 1 || $level == "info"} {
      set vlevel {INFO}
      set qlevel info
    } elseif {$level == 2 || $level == "warning"} {
      set vlevel {WARNING}
      set qlevel warning
    } elseif {$level == 3 || [string first "critical" $level] != -1} {
      set vlevel {CRITICAL WARNING}
      set qlevel critical_warning
    } elseif {$level == 4 || $level == "error"} {
      set vlevel {ERROR}
      set qlevel error
    } elseif {$level == 5 || $level == "debug"} {
      if {([info exists ::DEBUG_MODE] && $::DEBUG_MODE == 1) || (
        [info exists ::env(HOG_DEBUG_MODE)] && $::env(HOG_DEBUG_MODE) == 1
      )} {
        set vlevel {STATUS}
        set qlevel extra_info
        set msg "DEBUG: \[Hog:$title\] $msg"
      } else {
        return
      }
    } else {
      puts "Hog Error: level $level not defined"
      exit -1
    }
    if {[IsXilinx]} {
      # Vivado
      set status [catch {send_msg_id Hog:$title-0 $vlevel $msg}]
      if {$status != 0} {
        exit $status
      }
    } elseif {[IsQuartus]} {
      # Quartus
      post_message -type $qlevel "Hog:$title $msg"
      if {$qlevel == "error"} {
        exit 1
      }
    } else {
      # Tcl Shell / Libero
      if {$vlevel != "STATUS"} {
        puts "$vlevel: \[Hog:$title\] $msg"
      } else {
        # temporary solution to avoid removing of leading
        set HogEnvDict [Hog::LoggerLib::GetTOMLDict]
        if {
          ([dictSafeGet $HogEnvDict terminal colored] > 0) ||
          ([info exists ::env(HOG_COLOR)] &&
            ([string match "ENABLED" $::env(HOG_COLOR)] ||
              ([string is integer -strict $::env(HOG_COLOR)] && $::env(HOG_COLOR) > 0)
            )
          )||
          ([dictSafeGet $HogEnvDict terminal logger] > 0) ||
          ([info exists ::env(HOG_LOGGER)] && ([string match "ENABLED" $::env(HOG_LOGGER)]))
        } {
          puts "LogHelp:$msg"
        } else {
          puts $msg
        }
      }
      if {$qlevel == "error"} {
        exit 1
      }
    }
  }
}

## @brief Prints a message with selected severity and optionally write into a log file
#
# @param[in] msg        The message to print
# @param[in] severity   The severity of the message
# @param[in] outFile    The path of the output logfile
#
proc MsgAndLog {msg {severity "CriticalWarning"} {outFile ""}} {
  Msg $severity $msg
  if {$outFile != ""} {
    set directory [file dir $outFile]
    if {![file exists $directory]} {
      Msg Info "Creating $directory..."
      file mkdir $directory
    }

    set oF [open "$outFile" a+]
    puts $oF $msg
    close $oF
  }
}


# @brief Print the Hog Logo
#
# @param[in] repo_path The main path of the git repository (default .)
proc Logo {{repo_path .}} {
  # Msg Warning "HOG_LOGO_PRINTED : $HOG_LOGO_PRINTED"
  if {![info exists ::env(HOG_LOGO_PRINTED)] || $::env(HOG_LOGO_PRINTED) eq "0"} {
    if {
    [info exists ::env(HOG_COLOR)] && ([string match "ENABLED" $::env(HOG_COLOR)] || [string is integer -strict $::env(HOG_COLOR)] && $::env(HOG_COLOR) > 0)
    } {
      set logo_file "$repo_path/Hog/images/hog_logo_color.txt"
    } else {
      set logo_file "$repo_path/Hog/images/hog_logo.txt"
    }

    cd $repo_path/Hog
    set ver [Git {describe --always}]
    set old_path [pwd]
    # set ver [Git {describe --always}]

    if {[file exists $logo_file]} {
      set f [open $logo_file "r"]
      set data [read $f]
      close $f
      set lines [split $data "\n"]
      foreach l $lines {
        if {[regexp {(Version:)[ ]+} $l -> prefix]} {
          set string_len [string length $l]

          set version_string "* Version: $ver"
          set version_len [string length $version_string]
          append version_string [string repeat " " [expr {$string_len - $version_len - 1}]] "*"
          set l $version_string
        }
        Msg Status $l
      }
    } {
      Msg CriticalWarning "Logo file: $logo_file not found"
    }


    # Msg Status "Version: $ver"
    cd $old_path
  }
}

# Define the procedure to print the content of a file
#
# @param[in] filename The name of the file to read and print
#
# @brief This procedure opens the file, reads its content, and prints it to the console.
proc PrintFileContent {filename} {
    # Open the file for reading
    set file [open $filename r]

    # Read the content of the file
    set content [read $file]

    # Close the file
    close $file

    # Print the content of the file
    puts $content
}



## Print a tree-like structure of Hog list file content
#
#  @param[in]    data the list of lines read from a list file
#  @param[in]    repo_path the path of the repository
#  @param[in]    indentation a string containing a number of spaces to indent the tree
proc PrintFileTree {{data} {repo_path} {indentation ""}} {
  # Msg Debug "PrintFileTree called with data: $data, repo_path: $repo_path, indentation: $indentation"
  set print_list {}
  set last_printed ""
  foreach line $data {
    if {![regexp {^[\t\s]*$} $line] & ![regexp {^[\t\s]*\#} $line]} {
      lappend print_list "$line"
    }
  }
  set i 0

  foreach p $print_list {
    incr i
    if {$i == [llength $print_list]} {
      set pad "└──"
    } else {
      set pad "├──"
    }
    set file_name [lindex [split $p] 0]
    if {[file exists [file normalize [lindex [glob -nocomplain $repo_path/$file_name] 0]]]} {
      set exists ""
    } else {
      set exists "  !!!!!   NOT FOUND   !!!!!"
    }

    Msg Status "$indentation$pad$p$exists"
    set last_printed $file_name
  }

  return $last_printed
}




namespace eval Hog::LoggerLib {

  variable toml_dict {}
  variable fullPath

  ## @brief gets the full path to the file in the user home folder
  #
  # @param[in] filename  The name of the file to get the path for
  #
  # @returns  The full path to the file in the user's home directory, or 0 if file doesn't exist
  #
  proc GetUserFilePath {filename} {
    set homeDir [file normalize ~]
    set fullPath [file join $homeDir $filename]
    if {[file exists $fullPath]} {
      return $fullPath
    } else {
      return 0
    }
  }


  ## @brief Parse a TOML format file and return the data as a dictionary
  #
  # @param[in] toml_file  The path to the TOML file to parse
  #
  # @returns  A nested dictionary containing the TOML data, or -1 in case of failure
  #
  proc ParseTOML {toml_file} {
  variable toml_dict

  # set toml_dict [dict create \
  #   terminal [dict create logger 0 colored 0] \
  #   verbose [dict create level 4 pidshow 0 linecounter 0 msgtypeCounter 0] \
  # ]
    if {![file exists $toml_file]} {
      Msg Warning "TOML file $toml_file does not exist"
      return -1
    }
    if {[catch {open $toml_file r} file_handle]} {
      Msg Error "Cannot open TOML file $toml_file: $file_handle"
      return -1
    }
    # set toml_dict [dict create]
    set current_section ""
    set line_number 0
    set in_multiline_string 0
    set multiline_buffer ""
    set multiline_key ""
    while {[gets $file_handle line] >= 0} {
      incr line_number
      # Handle multiline strings
      if {$in_multiline_string} {
        if {[string match "*\"\"\"*" $line]} {
          # End of multiline string
          set end_pos [string first "\"\"\"" $line]
          append multiline_buffer [string range $line 0 [expr $end_pos - 1]]
          if {$current_section eq ""} {
            dict set toml_dict $multiline_key $multiline_buffer
          } else {
            dict set toml_dict $current_section $multiline_key $multiline_buffer
          }
          set in_multiline_string 0
          set multiline_buffer ""
          set multiline_key ""
        } else {
          append multiline_buffer $line "\n"
        }
        continue
      }
      # Remove comments (but preserve # inside strings)
      set clean_line ""
      set in_quotes 0
      set quote_char ""
      for {set i 0} {$i < [string length $line]} {incr i} {
        set char [string index $line $i]
        if {!$in_quotes && ($char eq "\"" || $char eq "'")} {
          set in_quotes 1
          set quote_char $char
          append clean_line $char
        } elseif {$in_quotes && $char eq $quote_char} {
          set in_quotes 0
          set quote_char ""
          append clean_line $char
        } elseif {!$in_quotes && $char eq "#"} {
          break
        } else {
          append clean_line $char
        }
      }
      set line [string trim $clean_line]
      # Skip empty lines
      if {$line eq ""} {
        continue
      }
      # Handle section headers [section] or [section.subsection]
      if {[regexp {^\[([^\]]+)\]$} $line match section_name]} {
        set current_section $section_name
        # Initialize section if it doesn't exist
        if {![dict exists $toml_dict $current_section]} {
          dict set toml_dict $current_section [dict create]
        }
        continue
      }
      # Handle key-value pairs
      if {[regexp {^([^=]+)=(.*)$} $line match raw_key raw_value]} {
        set key [string trim $raw_key]
        set value [string trim $raw_value]
        # Handle multiline strings
        if {[string match "*\"\"\"*" $value] && ![string match "*\"\"\"*\"\"\"*" $value]} {
          set start_pos [string first "\"\"\"" $value]
          set multiline_key $key
          set multiline_buffer [string range $value [expr $start_pos + 3] end]
          append multiline_buffer "\n"
          set in_multiline_string 1
          continue
        }
        # Parse the value
        set parsed_value [ParseTOMLValue $value]
        # Handle arrays and nested keys
        if {[string match "*.*" $key]} {
          set key_parts [split $key "."]
          set dict_ref toml_dict
          if {$current_section ne ""} {
            lappend dict_ref $current_section
          }
          for {set i 0} {$i < [expr [llength $key_parts] - 1]} {incr i} {
            set part [lindex $key_parts $i]
            lappend dict_ref $part
            if {![dict exists {*}$dict_ref]} {
              dict set {*}$dict_ref [dict create]
            }
          }
          set final_key [lindex $key_parts end]
          lappend dict_ref $final_key
          dict set {*}$dict_ref $parsed_value
        } else {
          # Simple key
          if {$current_section eq ""} {
            dict set toml_dict $key $parsed_value
          } else {
            dict set toml_dict $current_section $key $parsed_value
          }
        }
      }
    }
    close $file_handle
    return $toml_dict
  }

  ## @brief Parse a TOML value and convert it to appropriate TCL type
  #
  # @param[in] value  The raw value string from TOML
  #
  # @returns  The parsed value in appropriate TCL format
  #
  proc ParseTOMLValue {value} {
    set value [string trim $value]
    # Handle boolean values
    if {$value eq "true"} {
      return 1
    } elseif {$value eq "false"} {
      return 0
    }
    # Handle strings (quoted)
    if {[regexp {^"(.*)"$} $value match string_content]} {
      # Handle escape sequences
      set string_content [string map {\\" \" \\\\ \\ \\n \n \\t \t \\r \r} $string_content]
      return $string_content
    } elseif {[regexp {^'(.*)'$} $value match string_content]} {
      # Single quoted strings (literal)
      return $string_content
    }
    # Handle arrays
    if {[string match {\[*\]} $value]} {
      set array_content [string range $value 1 end-1]
      set array_content [string trim $array_content]
      if {$array_content eq ""} {
        return [list]
      }
      set elements [list]
      set current_element ""
      set bracket_depth 0
      set in_quotes 0
      set quote_char ""
      for {set i 0} {$i < [string length $array_content]} {incr i} {
        set char [string index $array_content $i]
        if {!$in_quotes && ($char eq "\"" || $char eq "'")} {
          set in_quotes 1
          set quote_char $char
          append current_element $char
        } elseif {$in_quotes && $char eq $quote_char} {
          set in_quotes 0
          set quote_char ""
          append current_element $char
        } elseif {!$in_quotes && $char eq "\["} {
          incr bracket_depth
          append current_element $char
        } elseif {!$in_quotes && $char eq "\]"} {
          incr bracket_depth -1
          append current_element $char
        } elseif {!$in_quotes && $char eq "," && $bracket_depth == 0} {
          lappend elements [ParseTOMLValue [string trim $current_element]]
          set current_element ""
        } else {
          append current_element $char
        }
      }
      if {$current_element ne ""} {
        lappend elements [ParseTOMLValue [string trim $current_element]]
      }
      return $elements
    }
    # Handle numbers (integers and floats)
    if {[string is integer $value]} {
      return [expr {int($value)}]
    } elseif {[string is double $value]} {
      return [expr {double($value)}]
    }
    # Handle dates/times as strings for now
    if {[regexp {^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}} $value]} {
      return $value
    }
    # Return as string if nothing else matches
    return $value
  }

  ## @brief Get a value from a TOML dictionary using dot notation
  #
  # @param[in] toml_dict  The dictionary returned by ParseTOML
  # @param[in] key_path   The key path in dot notation (e.g., "section.subsection.key")
  #
  # @returns  The value if found, or empty string if not found
  #
  proc GetTOMLValue {toml_dict key_path} {
    set key_parts [split $key_path "."]
    set current_dict $toml_dict
    foreach part $key_parts {
      if {[dict exists $current_dict $part]} {
        set current_dict [dict get $current_dict $part]
      } else {
        return ""
      }
    }
    return $current_dict
  }

  ## @brief Print a TOML dictionary in a readable format
  #
  # @param[in] toml_dict  The dictionary to print
  # @param[in] indent   Internal parameter for indentation (default: 0)
  #
  proc PrintTOMLDict {toml_dict {indent 0}} {
    set indent_str [string repeat "  " $indent]
    dict for {key value} $toml_dict {
      if {[string is list $value] && [llength $value] > 1 && [string is list [lindex $value 0]]} {
        # This is likely a nested dictionary
        Msg Debug "${indent_str}${key}:"
        if {[catch {dict for {subkey subvalue} $value {}} result]} {
          # Not a dictionary, print as value
          Msg Debug "${indent_str}  $value"
        } else {
          PrintTOMLDict $value [expr {$indent + 1}]
        }
      } elseif {[string is list $value] && [llength $value] > 0} {
        # This is an array
        Msg Debug "${indent_str}${key}: \[list of [llength $value] items\]"
        foreach item $value {
          Msg Debug "${indent_str}  - $item"
        }
      } else {
        Msg Debug "${indent_str}${key}: $value"
      }
    }
  }

  ## @brief Access the dictionary of the parsed TOML file
  #
  # @returns  The dictionary containing the parsed TOML data
  proc GetTOMLDict {} {
    variable toml_dict
    if {[info exists toml_dict]} {
      return $toml_dict
    }
  }



}


