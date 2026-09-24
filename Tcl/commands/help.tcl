Commands::RegisterCommand HELP {
  aliases     {H}
  description "Display this help message."
  passthrough true
  script {
    set _topic [Commands::Args]
    if {[llength $_topic] == 0} {
      Help::RenderTopLevel
    } else {
      Help::RenderPath $_topic
    }
  }
}

Commands::RegisterCommand HELP.FLOWS {
  aliases {F}
  description "Flow help. Usage: HELP FLOWS \[<tool>\] \[<flow>\]"
  script {
    Help::_banner
    set _tool_arg [Commands::Arg 0]
    set _flow_arg [Commands::Arg 1]

    if {$_tool_arg eq ""} {
      puts "TODO: dedicated flows overview page"
      return
    }

    # Resolve tool alias to namespace.
    set _tool_ns ""
    foreach ns [namespace children ::Tools] {
      if {[string tolower [namespace tail $ns]] eq [string tolower $_tool_arg]} {
        set _tool_ns $ns
        break
      }
    }
    if {$_tool_ns eq ""} {
      set _avail_list {}
      foreach ns [lsort [namespace children ::Tools]] { lappend _avail_list [string tolower [namespace tail $ns]] }
      puts "Unknown tool '$_tool_arg'. Available tools: [join $_avail_list {, }]"
      return
    }

    # GetChildren is a raw prefix-scan over real canons, never alias-aware, so
    # resolve the tool's real canon via GetCommand first, not a guessed
    # string (same pattern as Help::_tool_group_rows).
    set _tnode [Commands::GetCommand [string toupper [namespace tail $_tool_ns]]]
    set _flow_root "[tdict getval $_tnode canon].FLOW"

    if {$_flow_arg eq ""} {
      set _kids [Commands::GetChildren $_flow_root]
      if {[llength $_kids] == 0} {
        puts "\nTool [namespace tail $_tool_ns] declares no flows.\n"
        return
      }
      puts "\nFlows for [namespace tail $_tool_ns]:"
      foreach _c $_kids { puts [Help::_child_row [Commands::GetCommand $_c] 2] }
      puts ""
      return
    }

    set _fnode [Commands::GetCommand "$_flow_root.$_flow_arg"]
    if {$_fnode eq {}} {
      puts "Tool [namespace tail $_tool_ns] has no flow '$_flow_arg'."
      return
    }
    # A flow renders through the ordinary command page - it is an ordinary node.
    Help::RenderCommand $_fnode [list [string tolower [namespace tail $_tool_ns]] \
                                      FLOW [tdict getval $_fnode name]]
  }
}

Commands::RegisterCommand HELP.TOOLS {
  aliases     {TOOL T}
  description "Overview of registered tools (built-in vs custom). Usage: HELP TOOLS \[<tool>\]"
  script {
    Help::_banner
    set _which [Commands::Arg 0]
    if {$_which eq ""} { Help::RenderToolList } else { Help::RenderTool $_which }
  }
}


namespace eval Help {


  # accepts either a plain list of alias strings (commands) or a tlist (flows).
  proc _aliases {obj name} {
    set als {}
    if {[tobj isobj $obj] && [tobj type $obj] eq "List"} {
      foreach a [tobj value $obj] {
        set al [string tolower [tobj value $a]]
        if {$al ne [string tolower $name]} { lappend als $al }
      }
    } else {
      foreach a $obj {
        set al [string tolower $a]
        if {$al ne [string tolower $name]} { lappend als $al }
      }
    }
    return [expr {[llength $als] > 0 ? "([join $als {, }])" : ""}]
  }

  # expects a tlist of options; returns a plain string
  proc _options_string {obj_list {indent 0}} {
    set pad [string repeat " " $indent]
    set out ""
    foreach _option $obj_list {
      set n [llength $_option]
      if {$n == 2} {
        lassign $_option opt help
        append out [format "%s%-20s  %s\n" $pad "-$opt" $help]
      } elseif {$n == 3} {
        lassign $_option opt def help
        set suffix [expr {$def ne "" ? " (default: $def)" : ""}]
        append out [format "%s%-20s  %s%s\n" $pad "-$opt <arg>" $help $suffix]
      } else {
        Msg Warning "Custom option spec has invalid arity (expected 2 or 3): $_option"
      }
    }
    return $out
  }

  proc _banner {} {
    puts "[string repeat "=" 80]\nHog Launcher - Help\n[string repeat "=" 80]"
  }

  # Registered tool namespaces split as {builtin custom}
  proc _tool_groups {} {
    set _builtin {}
    set _custom  {}
    foreach ns [lsort [namespace children ::Tools]] {
      if {[catch {set m [${ns}::GetManifest]}]} continue
      if {[dict exists $m custom] && [dict get $m custom]} {
        lappend _custom $ns
      } else {
        lappend _builtin $ns
      }
    }
    return [list $_builtin $_custom]
  }

  # One indented line for a child node: "*NAME  (aliases)  description",
  # where * marks a node that needs a project.
  proc _child_row {node indent} {
    if {$node eq {}} { return "" }
    set name [tdict getval $node name]
    # Marker and name share one padded field, so a long name doesn't shift the
    # alias/description columns by the width of the "*".
    if {[Commands::Node::RequiresProj $node]} { set name "*$name" }
    return [format "%s%-17s %-12s  %s" \
      [string repeat " " $indent] \
      $name \
      [_aliases [tdict getobjor $node aliases [tlist create]] [tdict getval $node name]] \
      [tdict getor $node description ""]]
  }

  proc RenderPath {path} {
    _banner
    set _resolved [Commands::ResolvePath $path]

    if {[llength $_resolved] > 0 && [llength [dict get $_resolved remaining]] == 0} {
      # Matched a registered command
      set _node [dict get $_resolved node]
      if {[Commands::Node::IsTool $_node]} {
        RenderTool [string tolower [tdict getval $_node name]]
        return
      }
      RenderCommand $_node [dict get $_resolved path]
      return
    }

    # Single-segment path naming a flow that several tools provide -> overview.
    set _first [string toupper [lindex $path 0]]
    if {[llength $path] == 1 && [llength [Commands::ToolsWithFlow $_first]] > 0} {
      RenderFlows $_first
      return
    }

    puts "Unknown help topic: [join $path { }]"
  }


  # Top Level Help Page: ./Hog/Do HELP
  proc RenderTopLevel {} {
    _banner
    puts ""
    puts "usage: ./Hog/Do <directive> \[project\] \[OPTIONS\]"
    puts ""

    set _fmt_tool_row {{ns} {
      if {[catch {set m [${ns}::GetManifest]} err]} { return "" }
      set vendor [expr {[dict exists $m vendor] ? " ([dict get $m vendor])" : ""}]
      return [format "  %-12s %s%s" [string tolower [namespace tail $ns]] [dict get $m name] $vendor]
    }}
    lassign [_tool_groups] _builtin_tools _custom_tools
    puts "Built-in tools:"
    foreach ns $_builtin_tools {
      set _row [apply $_fmt_tool_row $ns]
      if {$_row ne ""} { puts $_row }
    }
    if {[llength $_custom_tools] > 0} {
      puts "\nCustom tools:"
      foreach ns $_custom_tools {
        set _row [apply $_fmt_tool_row $ns]
        if {$_row ne ""} { puts $_row }
      }
    }
    puts ""

    set _fmt_cmd_row {{cmd} {
      return [format "  %-10s  %s" [tdict getval $cmd name] [tdict getor $cmd description ""]]
    }}

    puts "General directives:"
    dict for {cname cmd} [::Commands::GetCommands] {
      if {[Commands::Node::IsTool $cmd]} { continue }
      if {[tdict getor $cmd custom 0]}  { continue }
      puts [apply $_fmt_cmd_row $cmd]
    }

    set _has_custom 0
    dict for {cname cmd} [::Commands::GetCommands] {
      if {[Commands::Node::IsTool $cmd]} { continue }
      if {![tdict getor $cmd custom 0]}  { continue }
      if {!$_has_custom} { puts "\nCustom commands:"; set _has_custom 1 }
      puts [apply $_fmt_cmd_row $cmd]
    }

    puts ""

    set _common_flows {
      CREATE         "Create the project, replace it if already existing."
      SYNTH          "Run synthesis only, create the project if not existing."
      IMPLEMENTATION "Run implementation only, project must already exist and be synthesised."
      SIMULATION     "Simulate the project, creating it if not existing."
      WORKFLOW       "Run the full workflow, creates the project if not existing."
      CREATEWORKFLOW "Create the project (even if existing) and run the complete workflow."
    }
    puts "Common project flows (require a project):"
    dict for {_fn _desc} $_common_flows {
      puts [format "  %-16s  %s" $_fn $_desc]
    }

    puts ""
    puts "Additional information:"
    puts "  Help for a specific directive:  ./Hog/Do HELP <directive>   or   ./Hog/Do <directive> --help"
    puts "  List every tool:                ./Hog/Do HELP TOOLS"
    puts "  Help for a tool:                ./Hog/Do HELP <tool>        or   ./Hog/Do HELP TOOLS <tool>"
    puts "  Help for a flow across tools:   ./Hog/Do HELP <flow>"
    puts "  Help for a tool's flow:         ./Hog/Do HELP FLOWS <tool> <flow>"
    puts ""
  }

  # Two lines per tool: identity, then what it offers.
  proc _tool_group_rows {label tools} {
    if {[llength $tools] == 0} { return }
    puts "\n$label"
    foreach ns $tools {
      set _m     [${ns}::GetManifest]
      set _short [string tolower [namespace tail $ns]]
      set _node  [Commands::GetCommand [string toupper [namespace tail $ns]]]

      set _als ""
      if {$_node ne {}} {
        set _als [_aliases [tdict getobjor $_node aliases [tlist create]] \
                           [tdict getval $_node name]]
      }

      # The node's own resolved canon (via GetCommand above)
      set _real_canon [expr {$_node ne {} ? [tdict getval $_node canon] : ""}]

      # Direct commands are the leaf children; FLOW/STAGE are the group children.
      set _ncmd 0
      foreach _c [Commands::GetChildren $_real_canon] {
        if {[llength [Commands::GetChildren $_c]] == 0} { incr _ncmd }
      }
      set _nflow  [llength [Commands::GetChildren "$_real_canon.FLOW"]]
      set _nstage [llength [Commands::GetChildren "$_real_canon.STAGE"]]

      set _offers {}
      if {$_nflow  > 0} { lappend _offers "$_nflow flow[expr {$_nflow  == 1 ? {} : {s}}]"   }
      if {$_nstage > 0} { lappend _offers "$_nstage stage[expr {$_nstage == 1 ? {} : {s}}]" }
      if {$_ncmd   > 0} { lappend _offers "$_ncmd command[expr {$_ncmd   == 1 ? {} : {s}}]" }
      if {[llength $_offers] == 0} { set _offers [list "nothing registered"] }

      # Aliases go last on the second line
      set _line2 [join $_offers {, }]
      if {$_als ne ""} { append _line2 "  aka [string trim $_als {()}]" }
      puts [format "  %-12s %s" $_short [dict get $_m name]]
      puts [format "  %-12s %s" ""      $_line2]
    }
  }

  # Tools overview: ./Hog/Do HELP TOOLS
  # One row per tool: aliases plus flow/stage/command counts
  proc RenderToolList {} {
    lassign [_tool_groups] _builtin _custom
    _tool_group_rows "Built-in tools:"          $_builtin
    _tool_group_rows "Custom tools (hog-tools/):" $_custom

    puts ""
    puts "  A tool's own page:      ./Hog/Do HELP TOOLS <tool>   (or HELP <tool>)"
    puts "  Run a tool's command:   ./Hog/Do <tool> <command> \[OPTIONS\]"
    puts "  Run a tool's flow:      ./Hog/Do <tool> FLOW <flow> <project>"
    puts ""
  }

  # Tool-level Help Page: ./Hog/Do HELP TOOLS <tool>
  proc RenderTool {alias} {
    set _tns [Tools::ResolveAlias [string tolower $alias]]
    if {$_tns eq "" || [catch {${_tns}::GetManifest} _m]} {
      set _avail_list {}
      foreach ns [lsort [namespace children ::Tools]] { lappend _avail_list [string tolower [namespace tail $ns]] }
      puts "Unknown tool '$alias'. Available tools: [join $_avail_list {, }]"
      return
    }
    set _canon [string tolower [namespace tail $_tns]]

    # Fetch the tool's own node via ResolvePath so alias walking is handled
    # automatically (e.g. vivado_vitis_classic → VIVADO).
    set _r     [Commands::ResolvePath [list $_canon]]
    set _tnode [expr {[llength $_r] > 0 ? [dict get $_r node] : {}}]

    set _tname     [dict get $_m name]
    set _alias_str ""
    if {$_tnode ne ""} {
      set _alias_str [_aliases [tdict getobjor $_tnode aliases [tlist create]] \
                               [tdict getval $_tnode name]]
    }
    puts "Tool: $_tname  $_alias_str"
    if {[dict get $_m vendor]      ne ""} { puts "  Vendor:      [dict get $_m vendor]" }
    if {[dict get $_m description] ne ""} { puts "  Description: [dict get $_m description]" }
    if {[dict get $_m version]     ne ""} { puts "  Version:     [dict get $_m version]" }
    if {[dict get $_m custom]}             { puts "  Origin:      custom (user-defined)" }
    if {[dict get $_m _source_path] ne ""} { puts "  Source:      [dict get $_m _source_path]" }
    puts "  Version Info:" 
    set _git [dict get $_m _git]
    if {[dict size $_git] > 0} {
      dict for {_gk _gv} $_git {
        if {$_gv ne ""} { puts [format "    %-10s %s" $_gk $_gv] }
      }
    }
    if {[llength [dict get $_m features]] > 0} {
      puts "  Features:    [join [dict get $_m features] {, }]"
    }
    puts ""
    if {$_tnode ne ""} {
      set _groups  {}
      set _cmd_hdr 0
      foreach _child_canon [Commands::GetChildren [tdict getval $_tnode canon]] {
        set _snode [Commands::GetCommand $_child_canon]
        if {$_snode eq {}} { continue }
        if {[llength [Commands::GetChildren $_child_canon]] > 0} {
          lappend _groups $_child_canon
          continue
        }
        if {!$_cmd_hdr} { puts "Usage: ./Hog/Do $_canon <command> \[OPTIONS\]\n\nCommands: (* - requires project)"; set _cmd_hdr 1 }
        puts [_child_row $_snode 2]
      }

      foreach _g $_groups {
        set _gname [string tolower [tdict getval [Commands::GetCommand $_g] name]]
        puts "\n[string totitle $_gname]s (run via 'tool $_canon $_gname <$_gname> <project>'):"
        foreach _c [Commands::GetChildren $_g] { puts [_child_row [Commands::GetCommand $_c] 2] }
      }
    }
    puts ""
  }


  # Flow-level Help Page: ./Hog/Do HELP <flow> - the same flow name across every
  # tool that provides it. Summaries only; the per-tool page has the options.
  proc RenderFlows {flow_name} {
    puts "Flows matching '$flow_name':"
    foreach _tool_key [Commands::ToolsWithFlow $flow_name] {
      set _r [Commands::ResolvePath [list $_tool_key FLOW $flow_name]]
      if {[llength $_r] == 0 || [llength [dict get $_r remaining]] > 0} { continue }
      set _fnode [dict get $_r node]
      if {$_fnode eq {}} { continue }
      set _short [string tolower $_tool_key]
      set _fname [tdict getval $_fnode name]
      puts ""
      puts " $_short: $_fname [_aliases [tdict getobjor $_fnode aliases [tlist create]] $_fname]"
      if {[tdict getor $_fnode custom 0]} { puts "   (custom flow — user-defined)" }
      if {[tdict getor $_fnode description ""] ne ""} {
        puts "   [tdict getor $_fnode description ""]"
      }
      set _stages [Commands::Node::FlattenStages $_fnode]
      if {[llength $_stages] > 0} { puts "   Stages: [join $_stages { -> }]" }
      puts "   Run './Hog/Do HELP FLOWS $_short [string tolower $_fname]' for full options."
    }
    puts ""
  }

  # Command-level Help Page: ./Hog/Do HELP <command>
  proc RenderCommand {_node _path} {
    # An author-supplied help body replaces the generated page entirely.
    set _custom_help [tdict getor $_node help ""]
    if {$_custom_help ne ""} { uplevel #0 $_custom_help; return }

    set _pretty   [join $_path { }]
    set _has_subs [expr {[llength [Commands::GetChildren [tdict getval $_node canon]]] > 0}]
    set _run      [Commands::Node::IsRunnable $_node]
    set _req_proj [tdict getor $_node requires_proj 0]
    set _proj_arg [expr {$_req_proj ? {<project> } : {}}]

    if {$_has_subs && $_run} {
      puts "Usage: ./Hog/Do $_pretty ${_proj_arg}\[<subcommand>\] \[OPTIONS\]"
    } elseif {$_has_subs} {
      puts "Usage: ./Hog/Do $_pretty ${_proj_arg}<subcommand> \[OPTIONS\]"
    } else {
      puts "Usage: ./Hog/Do $_pretty ${_proj_arg}\[OPTIONS\]"
    }
    if {$_req_proj} { puts " Requires: project" }
    puts ""
    puts "$_pretty [_aliases [tdict getobjor $_node aliases [tlist create]] [tdict getval $_node name]]:"
    puts " [tdict getor $_node description ""]"
    if {[tdict getor $_node custom 0]} { puts " (custom — user-defined)" }

    # Flattened, so @referenced flows show their spliced-in stages rather than
    # the raw "@CREATE" the author wrote.
    set _stages [Commands::Node::FlattenStages $_node]
    if {[llength $_stages] > 0} {
      puts "\n Stages:"
      puts "   [join $_stages { -> }]"
    }

    set _opts [Commands::GetCommandOptions $_node]
    if {$_run && [llength $_opts] > 0} {
      puts "\n Options:"
      puts "[_options_string $_opts 3]"
    }

    if {$_has_subs} {
      puts "\n Subcommands: (* - requires project)"
      foreach _child_canon [Commands::GetChildren [tdict getval $_node canon]] {
        puts [_child_row [Commands::GetCommand $_child_canon] 3]
      }
      puts ""
    }
  }
}
