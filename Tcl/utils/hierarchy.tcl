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
  if { $ext eq ".v" || $ext eq ".sv" || $ext eq ".mem" || $ext eq ".vh" || $ext eq ".yaml" || $ext eq ".svh"}  {
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
    foreach {full name} [regexp -inline -all -nocase {entity\s+(\w+)\s+is} $txt] {
      # puts "Found entity: $name"
      set module_name $name
      # puts $module_name
    }
    # Find instantiations (label : entity work.child ... OR label : child)
    foreach {im inst lib match} [regexp -all -inline -nocase {(\w+)\s*:\s*entity\s+(\w+)\.(\w+)} $txt] {
      set child [lindex $im 0]
      # To be safe, only register if child is also a known module/entity
      if {[string equal -nocase $lib "work"]} {
        lappend modules $inst:$top_lib.$match
      } else {
        lappend modules $inst:$lib.$match
      }
    }
    # Find component instantiations (component child is ... end component)
    foreach {im component} [regexp -all -inline -nocase {component\s+(\w+)\s+} $txt] {
      # puts "Found component: $component"
      # lappend modules ips.$component
      # Find component instantiation labels (label : component_name ...)
      foreach {cm label} [regexp -inline -all -nocase [format {(\w+)\s+:\s+%s} $component] $txt] {
        # puts "Found component instantiation: $label / $component"
        lappend modules $label:ips.$component
      }
    }

  }


  if {$modules != ""} {
    dict set dep_dict $top_lib.$module_name $modules
  }
  dict set modules_dict $top_lib.$module_name $f
  return [list $dep_dict $modules_dict]
}

proc print_hierarchy {topfile topdeps toppath alldeps allmods repo_path {label ""} {indent 0} {last 0}} {
  # Indentation string
  set indent_str ""
  for {set i 0} {$i < $indent} {incr i} {
    if {$i == [expr {$indent - 1}]} {
      if {$last} {
        append indent_str "    "
      } else {
        append indent_str "|   "
      }
    } else {
      append indent_str "|   "
    }
  }

  # Connector string
  if {$indent > 0} {
    if {$last} {
      set connector "└── "
    } else {
      set connector "├── "
    }
  } else {
    set connector ""
  }

  if {$label != ""} {
    puts "${indent_str}${connector}$label:$topfile ([Relative [file normalize $repo_path] $toppath 1])"
  } else {
    puts "${indent_str}${connector}$topfile ([Relative [file normalize $repo_path] $toppath 1])"
  }

  set num_deps [llength $topdeps]
  set i 0
  foreach f $topdeps {
    incr i
    set label [lindex [split $f ":"] 0]
    set f [string range $f [expr {[string first ":" $f] + 1}] end]
    set file_deps [DictGet $alldeps $f]
    set file_path [DictGet $allmods $f]
    if {$i == $num_deps} {
      print_hierarchy $f $file_deps $file_path $alldeps $allmods $repo_path $label [expr {$indent + 1}] 1
    } else {
      print_hierarchy $f $file_deps $file_path $alldeps $allmods $repo_path $label [expr {$indent + 1}] 0
    }
  }
}

# ---------------- MAIN ----------------

source Hog/Tcl/hog.tcl

#parsing command options
if {[catch {package require cmdline} ERROR]} {
  puts "$ERROR\n If you are running this script on tclsh, you can fix this by installing 'tcllib'"
  return
}

lassign [GetHogFiles -ext_path "" \
        -list_files ".src,.ext" "Top/l0mdt/vu13p/l0mdt_vu13p_ull_empty/list/" "."]\
        listLibraries listProperties listSrcSets


# Find top module in the list of libraries
dict for {f p} $listProperties {
  set top [lindex [regexp -inline {\ytop\s*=\s*(.+?)\y.*} $p] 1]
  if {$top != ""} {
    # puts "Top module found: $top"
    break
  }
}

set mods [dict create]
set deps [dict create]

dict for {lib files} $listLibraries {
  # puts "Library: $lib"
  # puts "Files: $files"
  foreach f $files {
    # puts "Processing file: $f"
    if {![file exists $f]} {
      puts "Error: File '$f' does not exist in library '$lib'."
      continue
    }
    lassign [parse_hdl $f $lib] f_deps f_modules
    # puts "Dependencies: $f_deps"
    # puts "Modules: $f_modules"
    # puts "Full dep: $deps"
    # puts "Full modules: $mods"
    set deps [MergeDict $deps $f_deps]
    set mods [MergeDict $mods $f_modules]
    # if {[dict size $f_deps] != 0} {
    #   if {[dict size $deps] == 0} {
    #     set deps $f_deps
    #   } else {
    #   }
    # }
    # set mods [MergeDict $mods $f_modules]
    # if {[dict size $modules] == 0} {
    #   set modules $f_modules
    # } else {
    #   if {[dict size $f_modules] != 0} {
    #     set modules [MergeDict $modules f_modules]
    #   }
    # }
  }
}

# puts "Modules found:"
# puts $mods
# puts "Dependencies found:"
# puts $deps

# set files [list example/src/adder.vhd example/top/top_example.vhd TestSubmodule/src/different_adder.vhd]

set topmodule ""
set topdeps [list]
dict for {f dep} $deps {
  # Search for top module
  if {[string first $top $f] != -1} {
    # puts "Top module '$top' found in file '$f'."
    set topmodule $f
    set topdeps $dep
    set toppath [DictGet $mods $f]
    break
  }
}

print_hierarchy $topmodule $topdeps $toppath $deps $mods "."


# if {![dict exists $modules $top]} {
#     puts "Warning: top module/entity '$top' not found in parsed sources."
# }

# print_hierarchy $top $insts