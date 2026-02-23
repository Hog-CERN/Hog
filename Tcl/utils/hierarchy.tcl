#
#  data structure:
#  hier_meta {
#    all_modules {
#      module_key {
#        name {}
#        library {}
#        type {}
#        file_path {}
#        references {}  # list of module_keys
#        properties {}
#      }
#    }
#
#    proj_files {
#      file_path {
#        file_path {}
#        ext {}
#        library {}
#        properties {}
#      }
#    }
#  }


source $tcl_path/utils/hdl_parser.tcl

proc PrintOrWrite {output_file msg} {
  if {$output_file ne ""} {
    puts $output_file $msg
  } else {
    puts $msg
  }
}

proc _create_hier_meta {} {
  set hier_meta [dict create]
  dict set hier_meta all_modules {}
  dict set hier_meta proj_files {}
  dict set heir_meta parsed_files_cache {}
  return $hier_meta
}

proc _compute_file_checksum {file_path} {
  if {![file exists $file_path]} {
    return ""
  }

  if {[catch {package require md5 2.0.7} result]} {
    # Fall back to command line md5sum
    if {[catch {exec md5sum $file_path} output]} {
      return ""
    }
    return [lindex $output 0]
  } else {
    return [string tolower [md5::md5 -hex -file $file_path]]
  }
}


proc is_known_library {hier_meta_ref lib_name} {
  upvar 1 $hier_meta_ref hier_meta
  return [dict exists $hier_meta libraries known_libs $lib_name]
}

proc is_ignored_module {module_key ignore_patterns} {
  foreach pattern $ignore_patterns {
    if {[string match $pattern $module_key]} {
      return 1
    }
  }
  return 0
}

proc _create_proj_file_info {file_path library properties} {
  set file_info [dict create]
  dict set file_info file_path $file_path
  dict set file_info library $library
  dict set file_info properties $properties
  dict set file_info ext [file extension $file_path]
  return $file_info
}

proc file_info_path {file_info} {return [dict get $file_info file_path] }
proc file_info_library {file_info} { return [dict get $file_info library] }
proc file_info_properties {file_info} { return [dict get $file_info properties] }
proc file_info_ext {file_info} { return [dict get $file_info ext] }

proc _store_module {hier_meta_ref mod_name mod_library mod_type file_path references_list props} {
  upvar 1 $hier_meta_ref hier_meta

  set key "${mod_library}.${mod_type}.${mod_name}"
  set mod [dict create]
  dict set mod name $mod_name
  dict set mod library $mod_library
  dict set mod type $mod_type
  dict set mod file_path $file_path
  dict set mod references $references_list
  dict set mod properties $props
  dict set mod color "white"

  dict set hier_meta all_modules $key $mod
}

proc _hier_parse_hdl {hier_meta_ref file_info} {
  upvar 1 $hier_meta_ref hier_meta

  set top_control 0
  if {[string first "top_control" $file_info] != -1} {
    set top_control 1
  }

  set top_l0mdt 0
  if {[string first "top_l0mdt" $file_info] != -1} {
    set top_l0mdt 1
  }

  #Msg Info "Parsing HDL file: [file_info_path $file_info]"
  set f [file_info_path $file_info]
  if {![file exists $f]} { return }

  set library [file_info_library $file_info]
  set file_properties [file_info_properties $file_info]
  set ext [string tolower [file extension $f]]

  Msg Debug "Parsing $f"
  set discovered_modules [list]

  set hdl_constructs [parse_hdl_file $f]
  foreach node $hdl_constructs {
    Msg Debug "[hdl_node_string $node]"
    # if {$top_control == 1 || $top_l0mdt == 1} {
    #   puts "Node: "
    #   puts "$node"
    # }
    set node_type [dict get $node type]
    set node_name [dict get $node name]

    set references [list]
    foreach component [dict get $node components_declared] {
      lappend references "unknown.component.[dict get $component name]"
    }

    foreach inst [dict get $node instantiations] {
      if { [dict get $inst type] == "component_inst"} {
        lappend references "unknown.component.[dict get $inst mod_name]"
      } elseif { [dict get $inst type] == "entity_inst"} {
        set split_name [split [dict get $inst mod_name] "."]
        lappend references "[lindex $split_name 0].component.[lindex $split_name 1]"
      }
    }

    foreach lib [dict get $node libraries ] {
      foreach use [dict get $lib uses] {
        set split_name [split $use "."]
        lappend references "[lindex $split_name 0].vhdl_package.[lindex $split_name 1]"
      }
    }

    set references [lsort -unique $references]
    dict set node references $references

    set mod_properties [dict create]
    if {$ext eq ".v" || $ext eq ".sv" || [lsearch -exact $file_properties "SystemVerilog"] != -1} {
        if {$ext eq ".sv" || [lsearch -exact $file_properties "SystemVerilog"] != -1} {
            dict set mod_properties filetype "SystemVerilog"
        } else {
            dict set mod_properties filetype "Verilog"
        }
    } elseif {$ext eq ".vhd" || $ext eq ".vhdl"} {
        set knownYears {93 2008 2019}
        set year 2008
        foreach y $knownYears {
            if {[lsearch -exact $file_properties $y] != -1} {
                set year $y
                break
            }
        }
        dict set mod_properties filetype "VHDL$year"
    }

    dict set node properties $mod_properties
    dict set node library $library
    dict set node color "white"

    if {$node_type == "vhdl_architecture"} {
      set key "${library}.${node_type}.[dict get $node entity].${node_name}"
    } else {
      set key "${library}.${node_type}.${node_name}"
    }

    dict set hier_meta all_modules $key $node
    lappend discovered_modules $key
  }
  return $discovered_modules
}

proc _hier_parse_ip {hier_meta_ref file_info {include_gen_prods 0}} {
  upvar 1 $hier_meta_ref hier_meta

  set f [file_info_path $file_info]
  if {![file exists $f]} { return }

  set library [file_info_library $file_info]
  set name [file rootname [file tail $f]]
  set mod_properties [dict create]
  dict set mod_properties filetype "XCI"

  set output_dir "."
  if {[catch {open $f r} fid]} {
    Msg Warning "Warning: Could not open XCI file: $f"
  } else {
    set content [read $fid]
    close $fid

    if {[regexp {"OUTPUTDIR":\s*\[\s*\{\s*"value":\s*"([^"]+)"} $content -> dir_value]} {
      set output_dir $dir_value
    }
  }

  set xci_dir [file dirname $f]
  set resolved_output_dir [file normalize [file join $xci_dir $output_dir]]

  # Recursively scan for HDL files (max 5 levels deep)
  set hdl_files [list]
  set dirs_to_scan [list [list $resolved_output_dir 0]]

  if { $include_gen_prods == 1} {
    while {[llength $dirs_to_scan] > 0} {
      set current [lindex $dirs_to_scan 0]
      set dirs_to_scan [lrange $dirs_to_scan 1 end]
      set current_dir [lindex $current 0]
      set current_depth [lindex $current 1]

      if {$current_depth >= 5} { continue }
      if {![file isdirectory $current_dir]} { continue }

      set entries [glob -nocomplain -directory $current_dir *]
      foreach entry $entries {
        if {[file isfile $entry]} {
          set ext [string tolower [file extension $entry]]
          if {$ext eq ".vhd" || $ext eq ".v" || $ext eq ".sv"} {
            lappend hdl_files $entry
          }
        } elseif {[file isdirectory $entry]} {
          set dir_name [file tail $entry]
          # Skip hdl and synth directories
          if {$dir_name ne "synth"} {
            lappend dirs_to_scan [list $entry [expr {$current_depth + 1}]]
          }
        }
      }
    }
  }

  set file_properties [file_info_properties $file_info]
  set all_subs [list]

  foreach hdl_file $hdl_files {
    set ext [string tolower [file extension $hdl_file]]

    # a lot of xci's share submodules, so we can just reuse the ones we already parsed
    set file_checksum [_compute_file_checksum $hdl_file]
    if {$file_checksum ne "" && [dict exists $hier_meta parsed_files_cache $file_checksum]} {
      Msg Debug "Reusing previously parsed modules for $hdl_file"
      set discovered_modules [dict get $hier_meta parsed_files_cache $file_checksum]
      set all_subs [concat $all_subs $discovered_modules]
      continue
    }



    set hdl_file_info [_create_proj_file_info $hdl_file $library $file_properties]
    set discovered_modules [list]

    if {$ext eq ".vhd" || $ext eq ".vhdl" || $ext eq ".v" || $ext eq ".sv"} {
      set discovered_modules [_hier_parse_hdl hier_meta $hdl_file_info]
    }

    if {$file_checksum ne ""} {
      dict set hier_meta parsed_files_cache $file_checksum $discovered_modules
    }

    set all_subs [concat $all_subs $discovered_modules]
  }

  set all_subs [lsort -unique $all_subs]

  if {[llength $all_subs] == 0} {
    # if no submodules, we probably haven't generated the output, so store xci as component
    # so other rtl can find it
    _store_module hier_meta $name $library "component" $f $all_subs $mod_properties
  }
  _store_module hier_meta $name $library "xci" $f $all_subs $mod_properties



}


proc _hier_parse_file {hier_meta_ref file_info {include_gen_prods 0}} {
  upvar 1 $hier_meta_ref hier_meta

  set ext [string tolower [file_info_ext $file_info]]
  if {$ext eq ".vhd" || $ext eq ".vhdl" || $ext eq ".v" || $ext eq ".sv"} {
    _hier_parse_hdl hier_meta $file_info
  } elseif {$ext eq ".xci"} {
    _hier_parse_ip hier_meta $file_info $include_gen_prods
  } elseif {$ext eq ".bd"} {
    _hier_parse_bd hier_meta $file_info
  } else {
    Msg Warning "Warning: unrecognized file type for [file_info_path $file_info]"
  }


}

proc _hier_submodule_append {hier_meta_ref parent_key sub_key} {
  upvar 1 $hier_meta_ref hier_meta

  if {[dict exists $hier_meta all_modules $parent_key]} {
    set mod [dict get $hier_meta all_modules $parent_key]
    dict lappend mod references $sub_key
    dict set hier_meta all_modules $parent_key $mod
  }
}


proc _reference_resolver {hier_meta_ref} {
  upvar 1 $hier_meta_ref hier_meta

  set package_bodies [ dict filter [dict get $hier_meta all_modules] script {k v} {expr {[dict get $v type] eq "vhdl_package_body"}}]
  set architectures  [ dict filter [dict get $hier_meta all_modules] script {k v} {expr {[dict get $v type] eq "vhdl_architecture"}}]

  dict for {package_body body_info} $package_bodies {
    set entity_key [split $package_body "."]
    set entity_key "[lindex $entity_key 0].vhdl_package.[lindex $entity_key 2]"
    if {[dict exists [dict get $hier_meta all_modules] $entity_key]} {
      _hier_submodule_append hier_meta $entity_key $package_body
      continue
    }
  }

  dict for {architecture arch_info} $architectures {
    # if {[string first "top_l0mdt" $architecture] != -1} {
    #   puts $architecture
    #   puts $arch_info
    #   # exit 0
    # }
    # if {[string first "top_control" $architecture] != -1} {
    #   puts $architecture
    #   puts $arch_info
    #   # exit 0
    # }
    set entity_key [split $architecture "."]
    set entity_key "[lindex $entity_key 0].vhdl_entity.[lindex $entity_key 2]"
    if {[dict exists [dict get $hier_meta all_modules] $entity_key]} {
      _hier_submodule_append hier_meta $entity_key $architecture
      continue
    }
  }


  set total_resolved 0
  set resolution_list [list]

  dict for {mod_key mod} [dict get $hier_meta all_modules] {
    set references_data [dict get $mod references]
    set new_references [list]
    set mod_lib [dict get $mod library]
    set top_control 0
    if { [string first "top_control" $mod_key] != -1 } {
      set top_control 1
    }

    foreach ref $references_data {
      # puts "Processing ref: $ref in mod: $mod_key"
      set parts   [split $ref "."]
      set library [lindex $parts 0]
      set type    [lindex $parts 1]
      set name    [lindex $parts 2]


      set found 0
      set resolved_mod_name ""

      if { ($library != "unknown" && $library != "work" && $type != "component") || ($library == "unknown" && $type != "component") } {
        # puts "Keeping reference as-is: $ref"
        lappend new_references $ref
        continue;
      }

      set ref_lib ""
      if { $library != "unknown"} {
        set ref_lib $library
      } else {
        set ref_lib $mod_lib
      }


      set pattern "${library}\.\[vhdl_entity|verilog_module\]\\.$name\$"
      set matches [ dict filter [dict get $hier_meta all_modules] script {k v} {expr {[regexp $pattern $k]}}]
      if {[dict size $matches] == "0"}  {
        set pattern ".*\.\[vhdl_entity|verilog_module\]\\.$name\$"
        set matches [ dict filter [dict get $hier_meta all_modules] script {k v} {expr {[regexp $pattern $k]}}]
      }

      if {[dict size $matches] == "0"}  {
        lappend new_references $ref
        Msg Debug "No match found"
        # puts "Debug: No match found for ref: $ref in mod: $mod_key"
      } else {
        dict for {k v} $matches {
          lappend new_references $k
          Msg Debug "Mod: $mod_key resolved $ref to $k"
          # puts "Debug: Mod: $mod_key resolved $ref to $k"
          incr total_resolved
          break
        }
      }
    }

    dict set hier_meta all_modules $mod_key references $new_references
  }


  return [dict create total $total_resolved resolutions $resolution_list]
}

proc dfs_sort {hier_meta_ref top_module} {
  upvar 1 $hier_meta_ref hier_meta


  proc _dfs_visit {hier_meta_ref node sorted_ref bad_nodes_ref} {
    upvar 1 $hier_meta_ref hier_meta
    upvar 1 $sorted_ref sorted
    upvar 1 $bad_nodes_ref bad_nodes

    if {![dict exists $hier_meta all_modules $node]} {
      return
    }

    set mod [dict get $hier_meta all_modules $node]
    set color [dict get $mod color]

    if {$color eq "gray"} {
      Msg Warning "Warning: Circular dependency detected at $node"
      if {[lsearch -exact $bad_nodes $node] == -1} {
        lappend bad_nodes $node
      }
      return
    }

    if {$color eq "black"} {
      return
    }

    dict set mod color "gray"
    dict set hier_meta all_modules $node $mod


    set references [dict get $mod references]
    foreach child $references {
      _dfs_visit hier_meta $child sorted bad_nodes
    }

    set mod [dict get $hier_meta all_modules $node]
    dict set mod color "black"
    dict set hier_meta all_modules $node $mod
    lappend sorted $node
  }


  set sorted [list]
  set bad_nodes [list]

  _dfs_visit hier_meta $top_module sorted bad_nodes

  if {[llength $bad_nodes] > 0} {
    return [dict create success 0 sorted {} cycles 1 bad_nodes $bad_nodes]
  }

  return [dict create success 1 sorted $sorted cycles 0 bad_nodes {}]
}


proc _debug_string_hier_meta {hier_meta_ref {indent 0}} {
  upvar 1 $hier_meta_ref hier_meta

  set ind [string repeat "  " $indent]
  set s "${ind}=== ALL MODULES ==="
  dict for {key mod} [dict get $hier_meta all_modules] {
    append s "\n${ind}$key:"
    dict for {field value} $mod {
      append s "\n${ind}  $field: $value"
    }
    append s "\n"
  }

  append s "\n${ind}=== PROJECT FILES ==="
  dict for {file finfo} [dict get $hier_meta proj_files] {
    append s "\n${ind}$file:"
    dict for {field value} $finfo {
      append s "\n${ind}  $field: $value"
    }
    append s "\n"
  }
  return $s
}



proc Hierarchy {listProperties listLibraries repo_path {output_path ""} \
{compile_order 0} {light ""} {top_module_override ""} {ignore_opt_list ""} {include_ieee 0} {include_gen_prods 0}} {
  set hier_meta [_create_hier_meta]

  set top_module ""

  set ignore_list [list]

  if {$include_ieee == 0} {
    lappend ignore_list "ieee.*.*"
    lappend ignore_list "std.*.*"
  }

  foreach pat [split $ignore_opt_list ","] {
    set pat [string trim $pat]
    if {$pat ne ""} {
      if {![regexp {^[\w*]+\.[\w*]+\.[\w*]+$} $pat]} {
        Msg Warning "Warning: ignore pattern '$pat' does not match expected format <lib>.<type>.<name> (wildcards * allowed), ignoring"
      } else {
        lappend ignore_list $pat
      }
    }
  }

  if {$top_module_override ne ""} {
    set top_module $top_module_override
    Msg Warning "Using specified top module: $top_module"
  }

  dict for {lib files} $listLibraries {
    set lib [file rootname $lib]

    foreach f $files {
      set props ""
      if {[dict exists $listProperties $f]} {

        set fprops [dict get $listProperties $f]
        if {$top_module eq ""} {
          set top [lindex [regexp -inline {\ytop\s*=\s*(.+?)\y.*} $fprops] 1]
          if {$top != ""} {
            set ext [file extension $f]
            if {$ext eq ".vhd" || $ext eq ".vhdl"} {
              set top_module "${lib}.vhdl_entity.${top}"
            } elseif { $ext eq ".v" || $ext eq ".sv"} {
              set top_module "${lib}.verilog_module.${top}"
            } else {
              set top_module "${lib}.component.${top}"
            }
          }
        }

        set props $fprops
      }
      dict set hier_meta proj_files $f [_create_proj_file_info $f $lib $props]
    }
  }

  if {$top_module_override eq ""} {
    Msg Info "Top module from properties: $top_module"
  }

  set t_parse [time {
    dict for {file file_info} [dict get $hier_meta proj_files] {
      _hier_parse_file hier_meta $file_info $include_gen_prods
    }
  } 1]
  set parse_us [lindex $t_parse 0]
  set parse_ms [expr {$parse_us / 1000.0}]

  Msg Info "Completed initial parsing in $parse_ms ms"

  set t_resolve [time {
    set resolve_result [_reference_resolver hier_meta]
  } 1]
  set resolve_us [lindex $t_resolve 0]
  set resolve_ms [expr {$resolve_us / 1000.0}]

  set total [dict get $resolve_result total]
  set resolutions [dict get $resolve_result resolutions]
  Msg Info "Completed reference resolution: $total references resolved in $resolve_ms ms"


  if {$output_path != ""} {
    set output_file [open $repo_path/$output_path "w"]
  } else {
    set output_file ""
    puts ""
  }


  set sorted_modules [dfs_sort hier_meta $top_module]
  set bad_nodes [dict get $sorted_modules bad_nodes]

  #Msg Debug "[_debug_string_hier_meta hier_meta]"
  set p [dict create]
  if {$compile_order} {
    print_compile_order hier_meta [dict get $sorted_modules sorted] $output_file
  } else {
    set p [print_hierarchy hier_meta $top_module $output_file $ignore_list $bad_nodes $light]
    PrintOrWrite $output_file "\n\n=====Packages in project:====="
    dict for {lib pkg_list} $p {
      if {[llength $pkg_list] == 0} {
        continue
      }
      PrintOrWrite $output_file "Library: $lib"
      foreach pkg_entry $pkg_list {
        PrintOrWrite $output_file "  Package: $pkg_entry"
      }
    }
  }

  if {$output_path != ""} {
    close $output_file
  }
}

proc print_compile_order {hier_meta_ref sorted_list {output_file ""}} {
  upvar 1 $hier_meta_ref hier_meta

  set groups [list]
  set curr_file_type ""
  set curr_files [list]

  foreach mod_key $sorted_list {
    set mod [dict get $hier_meta all_modules $mod_key]
    set file_path [dict get $mod file_path]
    set props [dict get $mod properties]
    set file_type [dict get $props filetype]

    if {$file_type ne $curr_file_type} {
      if {$curr_file_type ne ""} {
        lappend groups [list $curr_file_type $curr_files]
      }
      set curr_file_type $file_type
      set curr_files [list $file_path]
    } else {
      lappend curr_files $file_path
    }
  }

  if {$curr_file_type ne ""} {
    lappend groups [list $curr_file_type $curr_files]
  }

  foreach group $groups {
    set type [lindex $group 0]
    set files [lsort -unique [lindex $group 1]]
    set output_line "$type \{$files\}"
    PrintOrWrite $output_file $output_line
  }
}

proc print_hierarchy {hier_meta_ref module {output_file ""} {ignore_list ""} \
{bad_nodes ""} {light 0} {indent 0} {stack_ref ""} {last_properties_ref ""} {is_last 1}} {
  upvar 1 $hier_meta_ref hier_meta

  set package_dict {}

  if {[is_ignored_module $module $ignore_list]} {
    return
  }

  if {$stack_ref eq ""} {
    set stack [list]
    set last_properties [list]
  } else {
    upvar 1 $stack_ref stack
    upvar 1 $last_properties_ref last_properties
  }


  if {![dict exists $hier_meta all_modules $module]} {
    set parts [split $module "."]
    set lib [lindex $parts 0]
    set type [lindex $parts 1]
    set name [lindex $parts 2]
    set file_path ""
    set module_exists 0
  } else {

    set mod [dict get $hier_meta all_modules $module]
    # puts $mod
    set name [dict get $mod name]
    set type [dict get $mod type]
    set lib [dict get $mod library]
    set file_path [dict get $mod file_path]
    set module_exists 1


    # for vhdl entities with 1 architecture in the same file, just use that architecture
    if {$type eq "vhdl_entity" && $module_exists} {
      set references [dict get $mod references]
      set arch_refs [list]
      foreach ref $references {
        if {[string match "${lib}.vhdl_architecture.${name}.*" $ref]} {
          lappend arch_refs $ref
        }
      }
      if {[llength $arch_refs] == 1} {
        set arch_key [lindex $arch_refs 0]
        if {[dict exists $hier_meta all_modules $arch_key]} {
          set arch_mod [dict get $hier_meta all_modules $arch_key]
          set arch_file_path [dict get $arch_mod file_path]
          if {$arch_file_path eq $file_path} {
            set p [print_hierarchy hier_meta $arch_key $output_file $ignore_list $bad_nodes $light $indent stack last_properties $is_last]
            set package_dict [MergeDict $p $package_dict]
            return $package_dict
          }
        }
      }
    }
  }

  set is_circular 0
  if {[lsearch -exact $stack $module] != -1} {
    if {[lsearch -exact $bad_nodes $module] != -1} {
      set is_circular 1
    }
  }

  if {!$is_circular} {
    lappend stack $module
  }

  set indent_str ""
  for {set i 0} {$i < [llength $last_properties]} {incr i} {
    if {[lindex $last_properties $i]} {
      append indent_str "  "
    } else {
      append indent_str "│ "
    }
  }

  if {$indent > 0} {
      if {$is_last} {
          set connector "└─ "
      } else {
          set connector "├─ "
      }
  } else {
      set connector ""
  }

  if {$light} {
    set path_str ""
  } else {
    set path_str " - ${file_path}"
  }

  if {$type == "vhdl_architecture"} {
    set name "[dict get $mod entity].$name"
  }


  if {[string first "vhdl_package" $type] == -1} {
    if {!$module_exists} {
      set msg "${indent_str}${connector}${lib}.${name} (${type})"
    } elseif {$is_circular} {
      set msg "${indent_str}${connector}${lib}.${name} (${type})${path_str} \[WARNING: circular reference detected\]"
    } else {
      set msg "${indent_str}${connector}${lib}.${name} (${type})${path_str}"
    }
  } else {
    if {[DictGet $package_dict "$lib"] == ""} {
      dict set package_dict "$lib" [list]
    }
    set package_list [DictGet $package_dict "$lib"]
    if {![IsInList $package_list "${name} ${path_str}"] } {
      lappend package_list "${name} ${path_str}"
      dict set package_dict "$lib" $package_list
    }
    return $package_dict
  }

  PrintOrWrite $output_file $msg

  if {$is_circular || !$module_exists} {
    return $package_dict
  }

  set references [dict get $mod references]
  set all_subs [lsort -unique $references]

  # Filter out ignored modules before processing
  set filtered_subs [list]
  foreach sub $all_subs {
    if {![is_ignored_module $sub $ignore_list]} {
      lappend filtered_subs $sub
    }
  }

  set num_subs [llength $filtered_subs]
  set sub_idx 0
  foreach sub $filtered_subs {
    incr sub_idx
    set is_last_child [expr {$sub_idx == $num_subs}]

    lappend last_properties $is_last
    set p [print_hierarchy hier_meta $sub $output_file $ignore_list $bad_nodes $light [expr {$indent + 1}] stack last_properties $is_last_child]
    set package_dict [MergeDict $p $package_dict]
    set last_properties [lrange $last_properties 0 end-1]
  }

  set stack [lrange $stack 0 end-1]
  return $package_dict
}



proc get_rtl_refs {node {name ""}} {
  set out [dict create]

  if {$name ne "" && ![catch {dict get $node reference_info} refinfo]} {
    set rt ""; set rn ""
    catch {set rt [dict get $refinfo ref_type]}
    catch {set rn [dict get $refinfo ref_name]}
    if {[string equal $rt "hdl"] && $rn ne ""} {
      dict set out $name $rn
    }
  }

  if {![catch {dict get $node components} comps]} {
    dict for {cname cnode} $comps {
      set childMap [get_rtl_refs $cnode $cname]
      set out [dict merge $out $childMap]
    }
  }

  dict for {k v} $node {
    if {$k eq "components" || $k eq "reference_info"} {continue}
    if {[catch {dict size $v}]} {continue}
    set childMap [get_rtl_refs $v $k]
    set out [dict merge $out $childMap]
  }

  return $out
}

proc _hier_parse_bd {hier_meta_ref file_info} {
  upvar 1 $hier_meta_ref hier_meta

  set f [file_info_path $file_info]

  if {![file exists $f]} { return }

  set library [file_info_library $file_info]
  set file_properties [file_info_properties $file_info]

  set name [file rootname [file tail $f]]
  set mod_properties [dict create]
  dict set mod_properties filetype "BD"

  set bd_file [open $f r]
  set bd_json [read $bd_file]
  close $bd_file
  set bd_design $bd_json

  set lines [split $bd_design "\n"]
  set filtered_lines {}
  foreach line $lines {
    if {[string first "\\" $line] == -1} {
      lappend filtered_lines $line
    }
  }
  set bd_design [join $filtered_lines "\n"]

  regsub -all {":\s*\{} $bd_design " \{" bd_design
  regsub -all {:\s*("(?:[^"\\]|\\.)*")} $bd_design { {\1}} bd_design
  regsub -all {"} $bd_design {} bd_design
  regsub -all {,} $bd_design {} bd_design
  regsub -all {:\s* \{} $bd_design {\{} bd_design
  regsub -all {\[} $bd_design "\{" bd_design
  regsub -all {\]} $bd_design "\}" bd_design

  set bd_design [string range $bd_design 1 end-1]

  if {[catch {dict size $bd_design} err]} {
    Msg Warning "Warning: malformed bd_design in $f, skipping"
    return {}
  }

  set bd_design [lindex $bd_design 1]

  set unknown_modules {}
  dict for {m v} [get_rtl_refs $bd_design] {
    if {[lsearch -exact $unknown_modules $v] == -1} {
      lappend unknown_modules "unknown.component.$v"
    }
  }
  _store_module hier_meta $name $library component $f $unknown_modules $mod_properties

}
