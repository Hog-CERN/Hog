set ::hog_commands {
  HELP {
    aliases     {H}
    description "Display this help message."
    passthrough true
    subcommands {
      FLOWS {
        aliases {F}
        description "Flow help. Usage: HELP FLOWS \[<tool>\] \[<flow>\]"
        script {
          Help::_banner
          set _tool_arg [lindex $::argv 2]
          set _flow_arg [lindex $::argv 3]

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

          if {$_flow_arg eq ""} {
            puts "\nFlows for [namespace tail $_tool_ns]:"
            tdict for {_fn _fo} [Flow::GetToolFlows $_tool_ns] {
              puts [format "  %-20s  %s" $_fn [tdict getval $_fo description]]
            }
            puts ""
            return
          }

          Help::RenderToolFlow $_tool_ns [string toupper $_flow_arg]
        }
      }
      TOOLS {
        aliases {T}
        description "Overview of registered tools (built-in vs custom)."
        script {
          Help::_banner
          puts "TODO: dedicated tools overview page"
        }
      }
    }
    script {
      if {[llength $::argv] <= 1} {
        Help::RenderTopLevel
      } else {
        Help::RenderPath [lrange $::argv 1 end]
      }
      exit 0
    }
  }
}


namespace eval Help {


  # expects tobj list of aliases; returns a plain string
  proc _aliases {obj name} {
    set als {}
    tlist foreach a $obj {
      set al [string tolower [tobj value $a]]
      if {$al ne [string tolower $name]} { lappend als $al }
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


  proc RenderPath {path} {
    _banner
    set _resolved [Commands::ResolvePath $path]

    if {[llength $_resolved] > 0 && [llength [dict get $_resolved remaining]] == 0} {
      # Matched a registered command
      set _node [dict get $_resolved node]
      set _p    [dict get $_resolved path]
      if {[llength $_p] == 2 && [string toupper [lindex $_p 0]] eq "TOOL"} {
        RenderTool [lindex $_p 1]
        return
      }

      RenderCommand $_node $_p
      return
    }

    # Single-segment path matching a flow alias -> multi-tool flow overview.
    set _first [string toupper [lindex $path 0]]
    if {[llength $path] == 1 && [tdict exists $::Flow::_registry aliases $_first]} {
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
    set _tools [lsort [namespace children ::Tools]]
    set _builtin_tools [list]
    set _custom_tools  [list]
    foreach ns $_tools {
      if {[catch {set m [${ns}::GetManifest]}]} continue
      if {[dict exists $m custom] && [dict get $m custom]} {
        lappend _custom_tools $ns
      } else {
        lappend _builtin_tools $ns
      }
    }
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
      return [format "  %-10s  %s" [tdict getval $cmd name] [tdict getval $cmd description]]
    }}

    puts "General directives:"
    tdict for {cname cmd} [::Commands::GetCommands] {
      if {[tdict getval $cmd custom]} { continue }
      puts [apply $_fmt_cmd_row $cmd]
    }

    set _has_custom 0
    tdict for {cname cmd} [::Commands::GetCommands] {
      if {![tdict getval $cmd custom]} { continue }
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
    puts "  Help for a tool:                ./Hog/Do HELP <tool>        or   ./Hog/Do HELP TOOL <tool>"
    puts "  Help for a flow across tools:   ./Hog/Do HELP <flow>"
    puts "  Help for a tool's flow:         ./Hog/Do HELP FLOWS <tool> <flow>"
    puts ""
  }

  # Tool-level Help Page: ./Hog/Do HELP TOOL <tool>
  proc RenderTool {alias} {
    set _tns [Tools::ResolveAlias [string tolower $alias]]
    if {$_tns eq "" || [catch {${_tns}::GetManifest} _m]} {
      set _avail_list {}
      foreach ns [lsort [namespace children ::Tools]] { lappend _avail_list [string tolower [namespace tail $ns]] }
      puts "Unknown tool '$alias'. Available tools: [join $_avail_list {, }]"
      return
    }
    set _canon [string tolower [namespace tail $_tns]]

    # Fetch the TOOL <alias> subcommand node via ResolvePath so alias walking
    # is handled automatically (e.g. vivado_vitis_classic → VIVADO).
    set _r     [Commands::ResolvePath [list TOOL $_canon]]
    set _tnode [expr {[llength $_r] > 0 ? [dict get $_r node] : {}}]

    set _tname     [dict get $_m name]
    set _alias_str [expr {$_tnode ne "" ? [_aliases [tdict get $_tnode aliases] [tdict getval $_tnode name]] : ""}]
    puts "Tool: $_tname  $_alias_str"
    if {[dict get $_m vendor]      ne ""} { puts "  Vendor:      [dict get $_m vendor]" }
    if {[dict get $_m description] ne ""} { puts "  Description: [dict get $_m description]" }
    if {[dict get $_m version]     ne ""} { puts "  Version:     [dict get $_m version]" }
    if {[dict get $_m custom]}             { puts "  Origin:      custom (user-defined)" }
    if {[dict get $_m _source_path] ne ""} { puts "  Source:      [dict get $_m _source_path]" }
    set _git [dict get $_m _git]
    if {[dict size $_git] > 0} {
      dict for {_gk _gv} $_git {
        if {$_gv ne ""} { puts [format "  git.%-8s %s" $_gk $_gv] }
      }
    }
    if {[llength [dict get $_m features]] > 0} {
      puts "  Features:    [join [dict get $_m features] {, }]"
    }
    puts ""
    if {$_tnode ne "" && [tdict exists $_tnode subcommands]} {
      # Real commands only — flows are projected into the tree too but get
      # their own "Flows:" section below (and live under the FLOW group).
      set _cmd_hdr 0
      tdict for {_sname _snode} [tdict get $_tnode subcommands] {
        if {$_sname eq "FLOW" || [Commands::IsFlow $_snode]} { continue }
        if {!$_cmd_hdr} { puts "Usage: ./Hog/Do TOOL $_canon <command> \[OPTIONS\]\n\nCommands:"; set _cmd_hdr 1 }
        set _als  [_aliases [tdict get $_snode aliases] $_sname]
        set _desc [expr {[tdict exists $_snode description] ? [tdict getval $_snode description] : ""}]
        puts [format "  %-16s %-12s  %s" $_sname $_als $_desc]
      }
    }

    if {[catch {Flow::GetToolFlows $_tns} _flows]} { set _flows {} }
    set _flow_hdr 0
    tdict for {_fn _fo} $_flows {
      if {!$_flow_hdr} { puts "\nFlows (run via 'tool $_canon <flow> <project>'):"; set _flow_hdr 1 }
      set _fdesc [expr {[tdict exists $_fo description] ? [tdict getval $_fo description] : ""}]
      puts [format "  %-20s %s" $_fn $_fdesc]
    }
    puts ""
  }


  # Flow-level Help Page: ./Hog/Do HELP FLOWS <tool> <flow>
  proc RenderToolFlow {tool_ns flow_name args} {
    set _short [expr {"-short" in $args}]
    set _flow  [Flow::GetFlow $tool_ns $flow_name]
    if {[dict size $_flow] == 0} {
      puts "Tool [namespace tail $tool_ns] has no flow '$flow_name'."
      return
    }
    set _tool_short [string tolower [namespace tail $tool_ns]]

    puts " [namespace tail $tool_ns]: $flow_name [_aliases [tdict get $_flow aliases] [tdict getval $_flow name]]"
    if {[tdict exists $_flow custom] && [tdict getval $_flow custom]} {
      puts "   (custom flow — user-defined)"
    }
    if {[string length [tdict getval $_flow description]] > 0} {
      puts "   [tdict getval $_flow description]"
    }
    puts "   Stages:"
    puts "     [string map {" " " -> "} [Flow::GetFlowStages $tool_ns $flow_name]]"

    if {$_short} {
      puts "   Run './Hog/Do HELP FLOWS $_tool_short [string tolower $flow_name]' for full options."
    } else {
      puts "\n   Options:"
      puts "[_options_string [Flow::GetFlowOptions $tool_ns $flow_name] 5]"
    }
  }


  # Flow-level Help Page: ./Hog/Do HELP <flow> (multi-tool flow overview)
  proc RenderFlows {flow_name} {
    puts "Flows matching '$flow_name':"
    tlist foreach _flow [Flow::GetFlows $flow_name] {
      set _tns [tobj value [tdict get $_flow tool]]
      RenderToolFlow $_tns $flow_name -short
    }
  }



  # Command-level Help Page: ./Hog/Do HELP <command>
  proc RenderCommand {_node _path} {
    set _pretty [join $_path { }]

    # A projected flow node renders as a tool flow, not a generic command.
    if {[Commands::IsFlow $_node]} {
      set _tns [Tools::ResolveAlias [tobj value [tdict get $_node ide]]]
      RenderToolFlow $_tns [tobj value [tdict get $_node flow_ref]]
      return
    }

    set _has_subs [expr {![Commands::IsLeaf $_node]}]
    set _run      [Commands::IsRunnable $_node]

    if {$_has_subs && $_run} {
      puts "Usage: ./Hog/Do $_pretty \[<subcommand>\] \[OPTIONS\]"
    } elseif {$_has_subs} {
      puts "Usage: ./Hog/Do $_pretty <subcommand> \[OPTIONS\]"
    } else {
      puts "Usage: ./Hog/Do $_pretty \[OPTIONS\]"
    }
    puts "$_pretty [_aliases [tdict get $_node aliases] [tdict getval $_node name]]:"
    puts " [tdict getval $_node description]"

    if {$_run} {
      set _opt_list [list]
      tlist foreachval _option [tdict get $_node options] { lappend _opt_list $_option }
      if {[llength $_opt_list] > 0} {
        puts "\n Options:"
        puts "[_options_string $_opt_list 3]"
      }
    }

    if {$_has_subs} {
      puts "\n Subcommands:"
      tdict for {_sname _snode} [tdict get $_node subcommands] {
        set _als  [_aliases [tdict get $_snode aliases] $_sname]
        set _desc [expr {[tdict exists $_snode description] ? [tdict getval $_snode description] : ""}]
        puts [format "   %-16s %-12s  %s" $_sname $_als $_desc]
      }
      puts ""
    }
  }
}
