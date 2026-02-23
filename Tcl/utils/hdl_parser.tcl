
proc token_value {token} { return [dict get $token value ] }
proc token_type  {token} { return [dict get $token type  ] }
proc token_line  {token} { return [dict get $token line  ] }
proc token_col   {token} { return [dict get $token col   ] }

proc tokenize {code token_patterns keywords {case_sensitive 1}} {
  set tokens {}
  set line 1
  set line_start 0
  set cursor 0

  set keyword_dict [dict create]
  foreach kw $keywords {
    dict set keyword_dict $kw 1
  }

  set code_len [string length $code]
  while {$cursor < $code_len} {
    set found_match 0


    # this is an attempt at "optimizing" the regex matching by only checking a window of the code
    # we double the window size if no match is found and try again
    set window_size 200
    while {!$found_match && $cursor < $code_len} {
      set window_end [expr {min($cursor + $window_size - 1, $code_len - 1)}]
      set window [string range $code $cursor $window_end]

      foreach item $token_patterns {
        set type [lindex $item 0]
        set pattern [lindex $item 1]
        # set re [string cat {^(} $pattern {)}]
        set re "^($pattern)"

        if {[regexp -- $re $window allmatch submatch]} {
          set value $submatch
          set match_len [string length $allmatch]

          set column [expr {$cursor - $line_start + 1}]

          if {$type == "NEWLINE"} {
            incr line
            set line_start [expr {$cursor + $match_len}]
          } elseif {$type != "WHITESPACE" && $type != "COMMENT"} {

            if {!$case_sensitive} {
              set value [string tolower $value]
            }

            if {$type == "IDENTIFIER" && [dict exists $keyword_dict $value]} {
              set type "KEYWORD"
            }
            lappend tokens [dict create type $type value $value line $line column $column]
          }

          set cursor [expr {$cursor + $match_len}]
          set found_match 1
          break
        }
      }

      if {!$found_match && $window_end >= $code_len - 1} {
        break
      }

      if {!$found_match} {
        set window_size [expr {$window_size * 2}]
        Msg Warning "No match found at index $cursor, increasing window size to $window_size"
      }
    }

    if {!$found_match} {
      puts stderr "Error: Tokenizer stuck at index $cursor on char '[string index $code $cursor]'"
      incr cursor
    }
  }

  return $tokens
}


# hdl_node
#   type: "vhdl_entity", "vhdl_architecture", "verilog_module", etc.
#   name: module name
#   file_path: path to the source file
#   line: line number of declaration
#   entity: name of the parent entity, for arch/body
#   libraries: [
#      library_node dict {
#         name: library name, e.g., "ieee"
#         uses: list of usesg, e.g., "IEEE.STD_LOGIC_1164.all"
#      }
#   ]
#   components_declared: [
#      component_node dict {
#         name: component name
#         line: line number
#       }
#   ]
#   instantiations: [
#      instantiation_node dict {
#         mod_name: name of the instantiated module
#         type: "entity_inst", "component_inst"
#         inst_name: instance label
#         line: line number
#       }
#    ]

proc create_hdl_node {type name file_path line {libraries ""} {components_declared ""} {instantiations ""} {entity ""}} {
  return [dict create type $type name $name file_path $file_path line $line \
  libraries $libraries components_declared $components_declared instantiations $instantiations entity $entity]
}

proc create_instantiation_node {mod_name type inst_name line} {
  return [dict create mod_name $mod_name type $type inst_name $inst_name line $line]
}

proc hdl_node_string {hdl_node} {

  set node_info  "Node Type: [dict get $hdl_node type]"
  append node_info "\n  Name: [dict get $hdl_node name]"
  append node_info "\n  File Path: [dict get $hdl_node file_path]"
  append node_info "\n  Declared on line: [dict get $hdl_node line]"
  if {[dict exists $hdl_node entity] && [dict get $hdl_node entity] ne ""} {
    append node_info "\n  Entity: [dict get $hdl_node entity]"
  }

  if {[dict get $hdl_node type] eq "vhdl_entity" || [dict get $hdl_node type] eq "vhdl_package" \
  || [dict get $hdl_node type] eq "vhdl_architecture" || [dict get $hdl_node type] eq "vhdl_package_body"} {
    append node_info "\n  Libraries:"
    set libraries [dict get $hdl_node libraries]
    if {[llength $libraries] == 0} {
        append node_info " (None)"
    } else {
        foreach lib $libraries {
            append node_info "\n    - Library: [dict get $lib name]"
            set uses [dict get $lib uses]
            if {[llength $uses] > 0} {
                append node_info "\n      Uses:"
                foreach use $uses {
                    append node_info "\n        - $use"
                }
            }
        }
    }

    if {[dict get $hdl_node type] eq "vhdl_architecture"} {
        append node_info "\n  Components Declared:"
        set components_declared [dict get $hdl_node components_declared]
        if {[llength $components_declared] == 0} {
          append node_info " (None)"
        } else {
          foreach comp $components_declared {
            append node_info "\n    - [dict get $comp name] (line [dict get $comp line])"
          }
        }
        append node_info "\n  Instantiations:"
        set instantiations [dict get $hdl_node instantiations]
        if {[llength $instantiations] == 0} {
          append node_info " (None)"
        } else {
          foreach inst $instantiations {
            # tclint-disable-next-line line-length
            append node_info "\n    - Name: [dict get $inst mod_name], Instance: [dict get $inst inst_name] type: [dict get $inst type] (line [dict get $inst line])"
          }
        }
    }
  } elseif {[dict get $hdl_node type] eq "verilog_module"} {
    append node_info "\n  Instantiations:"
    set instantiations [dict get $hdl_node instantiations]
    if {[llength $instantiations] == 0} {
      append node_info " (None)"
    } else {
      foreach inst $instantiations {
        # tclint-disable-next-line line-length
        append node_info "\n    - Name: [dict get $inst mod_name], Instance: [dict get $inst inst_name] type: [dict get $inst type] (line [dict get $inst line])"
      }
    }
  }

  return $node_info
}






########## VERILOG #########

set verilog_keywords {
  always and assign automatic
  begin buf bufif0 bufif1 case casex
  casez cell cmos config
  deassign default defparam design disable
  edge else end endcase endconfig endfunction endgenerate
  endmodule endprimitive endspecify endtable endtask event
  for force forever fork function generate genvar highz0
  highz1 if ifnone incdir include initial inout input instance integer
  join large liblist library localparam macromodule medium module nand negedge
  nmos nor noshowcancelled not notif0 notif1 or output parameter pmos
  posedge primitive pull0 pull1 pulldown pullup pulsestyle_onevent pulsestyle_ondetect rcmos real
  realtime reg release repeat rnmos rpmos rtran rtranif0 rtranif1 scalared
  showcancelled signed small specify specparam strong0 strong1 supply0 supply1 table
  task time tran tranif0 tranif1 tri tri0 tri1 triand trior
  trireg unsigned1 use uwire vectored wait wand weak0 weak1 while
  wire wor xnor xor
}

set verilog_token_patterns {
  {COMMENT         {//[^\n]*|/\*.*?\*/}}
  {NEWLINE         {\n}}
  {WHITESPACE      {[ \t\r]+}}
  {STRING          {"[^\"]*"}}
  {NUMBER          {\d['\d_hHbsodxza-fA-F]*}}
  {IDENTIFIER      {[a-zA-Z_][a-zA-Z0-9_$]*}}
  {OPERATOR        {[+\-*/%<>=!&|~^?@:]+}}
  {LPAREN          {\(}}
  {RPAREN          {\)}}
  {LBRACE          {\{}}
  {RBRACE          {\}}}
  {LBRACK          {\[}}
  {RBRACK          {\]}}
  {COMMA           {,}}
  {SEMICOLON       {;}}
  {DOT             {\.}}
  {POUND           {#}}
  {DIRECTIVE       {\`[a-zA-Z_][a-zA-Z0-9_]*}}
  {MISMATCH        {.}}
}

proc tokenize_verilog {code} {
  global verilog_token_patterns verilog_keywords
  return [tokenize $code $verilog_token_patterns $verilog_keywords 1]
}

proc find_verilog_constructs {tokens filename} {
  set results [list]
  set state "TOP_LEVEL"
  set current_module ""
  set current_module_insts [list]

  for {set i 0} {$i < [llength $tokens]} {incr i} {
    set token [lindex $tokens $i]
    set type  [token_type $token]
    set value [token_value $token]

    if {$state == "TOP_LEVEL"} {
      if {$type == "KEYWORD" && $value == "module"} {
        if {$i + 1 < [llength $tokens]} {
          set next_token [lindex $tokens [expr {$i + 1}]]
          if {[token_type $next_token] == "IDENTIFIER"} {
            set current_module [token_value $next_token]
            set state "IN_MODULE_HEADER"
            set current_module_insts [list];
          }
        }
      }
    } elseif {$state == "IN_MODULE_HEADER"} {
      if {$type == "SEMICOLON"} {
        set state "IN_MODULE_BODY"
      }
    } elseif {$state == "IN_MODULE_BODY"} {
      if {$type == "KEYWORD" && $value == "endmodule"} {

        set decl_node [create_hdl_node "verilog_module" $current_module $filename [dict get $token line] "" "" $current_module_insts]
        lappend results $decl_node

        set state "TOP_LEVEL"
        set current_module ""
        continue
      }

      if {$type == "IDENTIFIER"} {
        if {$i + 2 < [llength $tokens]} {
          set token2 [lindex $tokens [expr {$i + 1}]]
          set token3 [lindex $tokens [expr {$i + 2}]]

          if {[token_type $token2 ] == "IDENTIFIER" && [token_type $token3] == "LPAREN"} {
            set inst_dict [create_instantiation_node $value "inst" [token_value $token2] [token_line $token]]
            lappend current_module_insts $inst_dict
          } elseif {[token_type $token2] == "POUND" && [token_type $token3] == "LPAREN"} {
            # find last )
            set old_token $token
            incr i 3
            set depth 1
            while {$i < [llength $tokens]} {
              set token [lindex $tokens $i]
              if {[token_type $token] == "LPAREN" } {
                incr depth
              }

              if {[token_type $token] == "RPAREN" } {
                incr depth -1
                if {$depth == 0} {
                  incr i
                  break
                }
              }
              incr i
            }

            set token [lindex $tokens $i]
            if {[token_type $token] == "IDENTIFIER"} {
              set inst_dict [create_instantiation_node [token_value $old_token] "inst" [token_value $token] [token_line $token]]
              lappend current_module_insts $inst_dict
            }
          }
        }
      }
    }
  }
  return $results
}


########## VHDL ##########

set vhdl_keywords {
  abs access after alias all and architecture array assert attribute
  begin block body buffer bus case component configuration constant
  disconnect downto else elsif end entity exit file for function
  generate generic group guarded if impure in inertial inout is
  label library linkage literal loop map mod nand new next nor not
  null of on open or others out package port postponed procedure
  process pure range record register reject rem report return rol
  ror select severity signal shared sla sll sra srl subtype then
  to transport type unaffected units until use variable wait when
  while with xnor xor
}

set vhdl_token_patterns {
  {COMMENT         {--[^\n]*}}
  {NEWLINE         {\n}}
  {WHITESPACE      {[ \t\r]+}}
  {STRING          {"[^"]*"}}
  {CHAR_LITERAL    {'[^']'}}
  {NUMBER          {\d['\d_.]*}}
  {IDENTIFIER      {[a-zA-Z][a-zA-Z0-9_]*}}
  {OPERATOR        {[:=<>|/*&.+-]}}
  {LPAREN          {\(}}
  {RPAREN          {\)}}
  {COMMA           {,}}
  {SEMICOLON       {;}}
  {MISMATCH        {.}}
}

proc tokenize_vhdl {code} {
  global vhdl_token_patterns vhdl_keywords
  return [tokenize $code $vhdl_token_patterns $vhdl_keywords 0]
}


proc parse_vhdl_architecture_header {tokens index} {
  set architecture_components [list]
  set i $index
  for {set i $index} {$i < [llength $tokens]} {incr i} {
    set token  [lindex $tokens $i]
    set type   [token_type $token]
    set value  [token_value $token]

    if {$type == "KEYWORD" && $value == "begin"} {
      break
    }

    # Look for component declarations
    if {$type == "KEYWORD" && $value == "component"} {
      if {[expr {$i + 2}] < [llength $tokens]} {
        set comp_name_tok [lindex $tokens [expr {$i + 1}]]
        set is_tok [lindex $tokens [expr {$i + 2}]]

        if {[token_type $comp_name_tok] == "IDENTIFIER" &&
            [token_type $is_tok] == "KEYWORD" && [token_value $is_tok] == "is"} {
          lappend architecture_components [dict create name [token_value $comp_name_tok] line [token_line $comp_name_tok]]
        }
      }
    }
  }
  return [dict create index $i components $architecture_components]
}

proc parse_vhdl_architecture_body {tokens index arch_name} {
  set architecture_insts [list]
  set i $index
  for {set i $index} {$i < [llength $tokens]} {incr i} {
    set token  [lindex $tokens $i]
    set type   [token_type $token]
    set value  [token_value $token]

    if {$type == "KEYWORD" && $value == "end"} {
      if {$i + 2 < [llength $tokens]} {
        set token2 [lindex $tokens [expr {$i + 1}]]
        set token3 [lindex $tokens [expr {$i + 2}]]
        if { [token_value $token2] == "$arch_name" && [token_type $token3] == "SEMICOLON"} {
          break
        }
      }
    }

    # Look for instantiations in the concurrent part
    if {$type == "IDENTIFIER"} {
      if {$i + 2 < [llength $tokens]} {
        set inst_tok $token
        set token2 [lindex $tokens [expr {$i + 1}]]
        set token3 [lindex $tokens [expr {$i + 2}]]
        # Entity instantiation: INST_NAME : entity ENTITY_NAME ...
        if {[token_value $token2] == ":" && [token_value $token3] == "entity"} {
          incr i 3
          set entity_inst_name ""
          while {$i < [llength $tokens]} {
            set token  [lindex $tokens $i]
            set type   [token_type $token]
            set value  [token_value $token]

            if {$value == "generic" || $value == "port" || $type == "SEMICOLON"} {
              break
            }
            set entity_inst_name "${entity_inst_name}${value}"
            incr i
          }
          if {$entity_inst_name != ""} {
            lappend architecture_insts [create_instantiation_node $entity_inst_name "entity_inst" [token_value $inst_tok] [token_line $inst_tok]]
          }
        # Component instantiation: INST_NAME : COMPONENT COMPONENT_NAME ...
        } elseif {[token_value $token2] == ":" && [token_value $token3] == "component"} {
          set token4 [lindex $tokens [expr {$i + 3}]]
          set comp_inst_name [token_value $token4]
          lappend architecture_insts [create_instantiation_node $comp_inst_name "component_inst" [token_value $token] [token_line $token]]

        # Component instantiation: INST_NAME : COMPONENT_NAME ...
        } elseif {[token_value $token2] == ":" && [token_type $token3] == "IDENTIFIER"} {
          set is_instantiation 0
          # look for port or generic followed by map after token3
          for {set k [expr {$i + 3}]} {$k < [llength $tokens]} {incr k} {
            set check_token [lindex $tokens $k]
            set check_value [token_value $check_token]
            set check_type [token_type $check_token]

            if {$check_type == "SEMICOLON"} {
              break
            }
            if {$check_type == "KEYWORD" && ($check_value eq "port" || $check_value eq "generic")} {
              if {[expr {$k + 1}] < [llength $tokens]} {
                set next_token [lindex $tokens [expr {$k + 1}]]
                if {[token_value $next_token] eq "map"} {
                  set is_instantiation 1
                  break
                }
              }
            }
          }

          if {$is_instantiation} {
            set comp_inst_name [token_value $token3]
            lappend architecture_insts [create_instantiation_node $comp_inst_name "component_inst" [token_value $inst_tok] [token_line $inst_tok]]
          }
        }
      }
    }
  }
  return [dict create index $i insts $architecture_insts]
}

proc parse_vhdl_architecture_content {arch tokens index} {
  set i $index

  set header_info [parse_vhdl_architecture_header $tokens $i]
  set i [dict get $header_info index]
  set architecture_components [dict get $header_info components]

  if {$i < [llength $tokens] && [token_value [lindex $tokens $i]] eq "begin"} {
    incr i
  }
  set body_info [parse_vhdl_architecture_body $tokens $i $arch]
  set i [dict get $body_info index]
  set architecture_insts [dict get $body_info insts]

  return [dict create index $i components $architecture_components insts $architecture_insts]
}

proc skip_vhdl_package_spec {tokens index} {
  set i $index
  while {$i < [llength $tokens]} {
    set current_tok [lindex $tokens $i]
    set current_val [token_value $current_tok]
    if {$current_val eq "end"} {
      if {[expr {$i + 1} < [llength $tokens]]} {
        set next_token [lindex $tokens [expr {$i + 1}]]
        if {[token_value $next_token] eq "package"} {
          set i [expr {$i + 1}]
          break
        }
      }
    }
    incr i
  }
  return $i
}

proc skip_vhdl_package_body {tokens index} {
  set i $index
  while {$i < [llength $tokens]} {
    set current_tok [lindex $tokens $i]
    set current_val [token_value $current_tok]
    if {$current_val eq "end"} {
      if {[expr {$i + 2} < [llength $tokens]]} {
        set next_token [lindex $tokens [expr {$i + 1}]]
        set next_next_token [lindex $tokens [expr {$i + 2}]]
        if {[token_value $next_token] eq "package" && [token_value $next_next_token] eq "body"} {
          set i [expr {$i + 2}]
          break
        }
      }
    }
    incr i
  }
  return $i
}

proc find_vhdl_constructs {tokens filename} {
  set results [list]
  set libraries_map [dict create]

  for {set i 0} {$i < [llength $tokens]} {incr i} {
    set token  [lindex $tokens $i]
    set type   [token_type $token]
    set value  [token_value $token]

    if {$type == "KEYWORD" && $value == "library"} {
      set i [expr {$i + 1}]
      while {$i < [llength $tokens]} {
        set token [lindex $tokens $i]
        set type [token_type $token]
        set value [token_value $token]

        if {$type == "IDENTIFIER"} {
          set lib_name [string tolower $value]
          if {![dict exists $libraries_map $lib_name]} {
            dict set libraries_map $lib_name [list]
          }
        } elseif {$type == "SEMICOLON"} {
          break
        }
        incr i
      }
    } elseif {$type == "KEYWORD" && $value == "use"} {
      if {$i + 1 < [llength $tokens]} {
        set use_path_start_idx [expr {$i + 1}]
        set use_path ""
        for {set j $use_path_start_idx} {$j < [llength $tokens]} {incr j} {
          set use_token [lindex $tokens $j]
          if {[token_type $use_token] == "SEMICOLON"} {
            set i $j
            break
          }
          append use_path [token_value $use_token]
        }
        if {$use_path != ""} {
          set use_path_parts [split $use_path .]
          set lib_name [string tolower [lindex $use_path_parts 0]]
          if {![dict exists $libraries_map $lib_name]} {
            dict set libraries_map $lib_name [list]
          }
          dict lappend libraries_map $lib_name $use_path
        }
      }
    } elseif {$type == "KEYWORD" && $value == "entity"} {
      if {$i + 2 < [llength $tokens]} {
        set name_tok [lindex $tokens [expr {$i + 1}]]
        set is_tok [lindex $tokens [expr {$i + 2}]]
        if {[token_type $name_tok] == "IDENTIFIER" && [token_value $is_tok] == "is"} {
          set entity_name [token_value $name_tok]
          set final_libraries [list]
          dict for {lib_name use_paths} $libraries_map {
              lappend final_libraries [dict create name $lib_name uses $use_paths]
          }
          set entity_node [create_hdl_node "vhdl_entity" $entity_name $filename [token_line $name_tok] $final_libraries]
          lappend results $entity_node
        }
      }
    } elseif {$type == "KEYWORD" && $value == "package"} {
      if {[expr {$i + 1} < [llength $tokens]]} {
        set next_token [lindex $tokens [expr {$i + 1}]]

        if {[token_type $next_token] == "IDENTIFIER"} {
          set package_name [token_value $next_token]
          set package_line [token_line $next_token]
          set i [expr {$i + 2}]

          if {$i < [llength $tokens]} {
              set current_tok [lindex $tokens $i]
              set current_val [token_value $current_tok]
              if {[token_type $current_tok] == "KEYWORD" && $current_val eq "is"} {
                # package declaration
                set i [skip_vhdl_package_spec $tokens $i]
                set final_libraries [list]
                dict for {lib_name use_paths} $libraries_map {
                  lappend final_libraries [dict create name $lib_name uses $use_paths]
                }
                set package_node [create_hdl_node "vhdl_package" $package_name $filename $package_line $final_libraries]
                lappend results $package_node
                continue
            }
          }
        } elseif {[token_value $next_token] == "body" } {
          # package body
          set i [skip_vhdl_package_body $tokens $i]
          set final_libraries [list]
          dict for {lib_name use_paths} $libraries_map {
            lappend final_libraries [dict create name $lib_name uses $use_paths]
          }
          set package_body_node [create_hdl_node "vhdl_package_body" $package_name $filename $package_line $final_libraries]
          lappend results $package_body_node
          continue
        }
      }
    } elseif {$type == "KEYWORD" && $value == "architecture"} {
      if {$i + 4 < [llength $tokens]} {
        set arch_name_tok [lindex $tokens [expr {$i + 1}]]
        set of_tok [lindex $tokens [expr {$i + 2}]]
        set entity_name_tok [lindex $tokens [expr {$i + 3}]]
        set is_tok [lindex $tokens [expr {$i + 4}]]

        if {[token_type $arch_name_tok] == "IDENTIFIER" && [token_value $of_tok] == "of" \
        && [token_type $entity_name_tok] == "IDENTIFIER" && [token_value $is_tok] == "is"} {
          set arch_name [token_value $arch_name_tok]
          set entity_name [token_value $entity_name_tok]

          set arch_info [parse_vhdl_architecture_content $arch_name $tokens [expr $i + 1]]
          set i [dict get $arch_info index]
          set components [dict get $arch_info components]
          set insts [dict get $arch_info insts]
          set final_libraries [list]
          dict for {lib_name use_paths} $libraries_map {
            lappend final_libraries [dict create name $lib_name uses $use_paths]
          }

          set arch_node [create_hdl_node "vhdl_architecture" $arch_name $filename [token_line $arch_name_tok] $final_libraries $components $insts $entity_name]
          lappend results $arch_node
        }
      }
    }
  }
  return $results
}


proc parse_hdl_file {filename} {

  if {![file exists $filename]} {
    puts "Error: file not found: $filename"
    return ""
  }

  set fp [open $filename r]
  set code [read $fp]
  close $fp


  # skip protected files
  set first_line [lindex [split $code "\n"] 0]
  set first_line_trimmed [string trim $first_line]
  if {$first_line_trimmed eq "`pragma protect begin_protected" ||
      $first_line_trimmed eq "`protect begin_protected"} {
    return {}
  }

  set extension [string tolower [file extension $filename]]

  set tokens {}
  set constructs {}

  switch -- $extension {
    ".v" -
    ".vh" -
    ".sv" {
      set t_tokenize [time {set tokens [tokenize_verilog $code]} 1]
      set t_constructs [time {set constructs [find_verilog_constructs $tokens $filename]} 1]
    }
    ".vhd" -
    ".vhdl" {
      set t_tokenize [time {set tokens [tokenize_vhdl $code]} 1]
      set t_constructs [time {set constructs [find_vhdl_constructs $tokens $filename]} 1]
    }
    default {
      return {}
    }
  }

  # Extract microseconds and convert to milliseconds
  set tokenize_us [lindex $t_tokenize 0]
  set constructs_us [lindex $t_constructs 0]
  set tokenize_ms [expr {$tokenize_us / 1000.0}]
  set constructs_ms [expr {$constructs_us / 1000.0}]

  #puts "\[PERFORMACE\] Tokenization: $tokenize_ms ms, Construct discovery: $constructs_ms ms for file $filename"

  return $constructs
}
