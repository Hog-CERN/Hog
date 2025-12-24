# Extract hierarchy from VHDL + Verilog HDL files
# Usage: tclsh extract_hierarchy.tcl top_module file1.v file2.v file3.vhd ...

proc parse_hdl {f toplib} {
  set module_name ""
  set modules_dict [dict create]
  set dep_dict [dict create]
  set modules ""
  set top_lib [file rootname $toplib]
  set ext [file extension $f]
  set fh [open $f r]
  set txt [read $fh]
  close $fh


  # ------------ VERILOG ------------
  if { $ext eq ".mem" || $ext eq ".vh" || $ext eq ".yaml" || $ext eq ".svh"}  {
      # Find modules
      # foreach {full name body} [regexp -inline -all {module\s+(\w+)[^;]*;([\s\S]*?)endmodule} $txt] {
          # set module_name $name
          return [list $dep_dict $modules_dict]

          # # Find instantiations (child_module instance_name (...))
          # foreach im [regexp -all -inline {(\w+)\s+\w+\s*\(} $body] {
          #   set child [lindex $im 0]
          #   dict lappend insts $name $child
          # }
      # }
  }

  if { $ext eq ".xci" || $ext eq ".bd"} {
    set module_name "[file tail [file rootname $f]]"
  }

  # ------------ VHDL ------------
  if { $ext eq ".vhd" || $ext eq ".vhdl" } {
    # Find entities
    foreach {full name} [regexp -inline -all -nocase {entity[ \t\r\n]+(\w+)[ \t\r\n]+is} $txt] {
      # puts "Found entity: $name"
      set module_name $name
      # puts $module_name
    }
    # Find instantiations (label : entity work.child ... OR label : child)
    foreach {im inst lib match} [regexp -all -inline -nocase {(\w+)\s*:\s*entity\s+(\w+)[\s\n\r]*\.[\s\n\r]*(\w+)} $txt] {
      set child [lindex $im 0]
      # To be safe, only register if child is also a known module/entity
      if {[string equal -nocase $lib "work"]} {
      lappend modules $inst:$top_lib.$match
      } else {
      lappend modules $inst:$lib.$match
      }
    }
    # Find component instantiations (component child is ... end component)
    foreach {im component} [regexp -all -inline -nocase {component[ \t\r\n]+(\w+)[ \t\r\n]+is} $txt] {
      # puts "Found component: $component"
      # lappend modules ips.$component
      # Find component instantiation labels (label : component_name ...)
      foreach {cm label} [regexp -inline -all -nocase [format {(\w+)[ \t\r\n]*:[ \t\r\n]*%s} $component] $txt] {
        # puts "Found component instantiation: $label / $component"
        lappend modules $label:ips.$component
      }
    }
  }

  # ---- Verilog ---------
  if {[IsVerilog $f]} {
    foreach {full name} [regexp -all -inline -line {^(?!\s*//)\s*module\s+(\w+)} $txt] {
      set module_name $name
    }
    set pattern {^\s*(\w+)\s*(?:#\s*\([^;]*\))?\s+(\w+)\s*\(}
    foreach {full module inst} [regexp -all -inline -line $pattern $txt] {
      if {$inst != "if" && $inst != "for" && $inst != "while"} {
        lappend modules $inst:$top_lib.$module
      }
    }
  }

  if {$modules != ""} {
    dict set dep_dict $top_lib.$module_name $modules
  }
  dict set modules_dict $top_lib.$module_name $f
  return [list $dep_dict $modules_dict]
}

# Recursive procedure to print hierarchical module dependencies
proc print_hierarchy {topfile topdeps toppath alldeps allmods repo_path output_file {label ""} {indent 0} {last 0} } {
    # We use a variable to track whether each ancestor level was the last node
    variable last_flags
    if {![info exists last_flags]} {
        set last_flags {}
    }

    # Build indentation string
    set indent_str ""
    for {set i 0} {$i < [llength $last_flags]} {incr i} {
        if {[lindex $last_flags $i]} {
            append indent_str "     "   ;# previous level was last → no vertical bar
        } else {
            append indent_str "│    "
        }
    }

    # Choose connector symbols
    if {$indent > 0} {
        if {$last} {
            set connector "└── "
        } else {
            set connector "├── "
        }
    } else {
        set connector ""
    }

    # Print current node (if not the very first root path)
    if {[Relative [file normalize $repo_path] $toppath 1] != ""} {
        if {$label != ""} {
            puts "${indent_str}${connector}$label:$topfile ([Relative [file normalize $repo_path] $toppath 1])"
            if {$output_file != ""} {
              puts $output_file "${indent_str}${connector}$label:$topfile ([Relative [file normalize $repo_path] $toppath 1])"
            }
        } else {
            puts "${indent_str}${connector}$topfile ([Relative [file normalize $repo_path] $toppath 1])"
            if {$output_file != ""} {
              puts $output_file "${indent_str}${connector}$topfile ([Relative [file normalize $repo_path] $toppath 1])"
            }
        }
    }

    # Prepare for recursion
    set num_deps [llength $topdeps]
    if {$num_deps == 0} {
        return
    }

    # Push this node’s “last” status onto the stack
    lappend last_flags $last

    # Recurse through dependencies
    set i 0
    foreach f $topdeps {
        incr i
        set label [lindex [split $f ":"] 0]
        set f [string range $f [expr {[string first ":" $f] + 1}] end]
        set file_deps [DictGet $alldeps $f]
        set file_path [DictGet $allmods $f]
        print_hierarchy $f $file_deps $file_path $alldeps $allmods $repo_path $output_file\
            $label [expr {$indent + 1}] [expr {$i == $num_deps}]
    }

    # Pop this level’s flag before returning
    set last_flags [lrange $last_flags 0 end-1]
}

proc Hierarchy {listProperties listLibraries repo_path {output_path ""} {compile_order 0}} {
  # Find top module in the list of libraries
  dict for {f p} $listProperties {
    set top [lindex [regexp -inline {\ytop\s*=\s*(.+?)\y.*} $p] 1]
    if {$top != ""} {
      break
    }
  }

  set mods [dict create]
  set deps [dict create]

  dict for {lib files} $listLibraries {
    foreach f $files {
      # puts "Processing file: $f"
      if {![file exists $f]} {
        puts "Error: File '$f' does not exist in library '$lib'."
        continue
      }

      lassign [parse_hdl $f $lib] f_deps f_modules
      set deps [MergeDict $deps $f_deps]
      set mods [MergeDict $mods $f_modules]
    }
  }

  set topmodule ""
  set topdeps [list]
  dict for {m path} $mods {
    # Search for top module
    if {[string first $top $m] != -1} {
      # puts "Top module '$top' found in file '$f'."
      set topmodule $m
      set topdeps [DictGet $deps $m]
      set toppath $path
      break
    }
  }

  if {$output_path != ""} {
    set output_file [open $repo_path/$output_path "w"]
  } else {
    set output_file ""
  }
  print_hierarchy $topmodule $topdeps $toppath $deps $mods $repo_path $output_file

  if {$output_path != ""} {
    close $output_file
  }

  # Generate compile order file if requested
  if {$compile_order} {
    set compile_order_file "$repo_path/compile_order.txt"
    set compile_fp [open $compile_order_file "w"]
    puts $compile_fp "# Compile order for $topmodule"
    puts $compile_fp "# Generated by Hog hierarchy command"

    # Perform topological sort to get compile order
    set visited [dict create]
    set order [list]

    proc visit {module deps visited order_var} {
      upvar $order_var order
      upvar $visited visited_dict

      if {[dict exists $visited_dict $module]} {
        return
      }

      dict set visited_dict $module 1

      # Visit dependencies first
      if {[dict exists $deps $module]} {
        foreach dep [dict get $deps $module] {
          # Extract module name from dep (format: label:lib.module)
          set dep_module [lindex [split $dep ":"] end]
          visit $dep_module $deps visited_dict order
        }
      }

      # Add this module to the order
      lappend order $module
    }

    # Start from top module
    visit $topmodule $deps visited order

    # Reverse the order for compilation (dependencies first)
    set order [lreverse $order]

    # Write the compile order
    foreach module $order {
      if {[dict exists $mods $module]} {
        set file_path [dict get $mods $module]
        puts $compile_fp $file_path
      }
    }

    close $compile_fp
    puts "Compile order file generated: $compile_order_file"
  }
}
