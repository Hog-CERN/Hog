
set ::hog_commands {
  HELP {
    aliases {H}
    description "Display this help message." 
    script {
      set _sub  [string toupper [lindex $::argv 1]]
      set _arg2 [lindex $::argv 2]

      # expects tobj list of aliases
      # returns a plain string
      proc _aliases {obj name} {
        set als {}
        tlist foreach a $obj {
          set al [string tolower [tobj value $a]]
          if {$al ne [string tolower $name]} { lappend als $al }
        }
        return [expr {[llength $als] > 0 ? "([join $als {, }])" : ""}]
      }

      # expects a tlist of options
      # returns a plain string
      proc _options_string {obj {indent 0}} {
        set pad [string repeat " " $indent]
        set out ""

        tlist foreachval _option $obj {
          set n [llength $_option]
          if {$n == 2} {
            lassign $_option opt help
            append out "${pad}-$opt      $help"
          } elseif {$n == 3} {
            lassign $_option opt def help
            append out "${pad}-$opt <arg>"
            if {$def ne ""} {
              append out "    $help (default: $def)"
            } else {
              append out "    $help"
            }
          } else {
            Msg Warning "Custom option spec has invalid arity (expected 2 or 3): $custom_option"
          }
          append out "\n"
        }
        return $out
      }

      puts "[string repeat "=" 80]\nHog Launcher - Help\n[string repeat "=" 80]"

      if {$_sub eq "" } {
        puts ""
        puts "usage: ./Hog/Do <directive> \[project\] \[OPTIONS\]"
        puts ""

        set _tools [lsort [namespace children ::Tools]]
        puts "Supported tools:"
        foreach ns $_tools {
          if {[catch {set m [${ns}::GetManifest]} err]} continue
          set vendor [expr {[dict exists $m vendor] ? " ([dict get $m vendor])" : ""}]
          puts [format "  %-12s %s%s" [string tolower [namespace tail $ns]] [dict get $m name] $vendor]
        }
        puts ""

        puts "General directives:"
        tdict for {cname cmd} [::Commands::GetCommands] {
          if { [tdict getval $cmd requires_proj]} {continue}
          puts [format "  %-8s  %s" [tdict getval $cmd name] [tdict getval $cmd description]]
        }

        puts "\nProject Directives:"
        tdict for {cname cmd} [::Commands::GetCommands] {
          if { ![tdict getval $cmd requires_proj]} {continue}
          puts [format "  %-8s  %s" [tdict getval $cmd name] [tdict getval $cmd description]]
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
        puts "  To list help for a specific directive:"
        puts "    ./Hog/Do HELP <directive> or ./Hog/Do <directive> --help"
        puts "  To list information about a tool:"
        puts "    ./Hog/Do HELP TOOLS <tool>"
        puts "  To list all flows for a specific tool:"
        puts "    ./Hog/Do HELP FLOWS <tool>"
        puts ""

      } elseif {$_sub eq "FLOWS"} {
        set _tool_ns ""
        foreach ns [namespace children ::Tools] {
          if {[string tolower [namespace tail $ns]] eq [string tolower $_arg2]} { set _tool_ns $ns; break }
        }
        if {$_tool_ns eq ""} {
          set _avail [join [lmap ns [lsort [namespace children ::Tools]] { string tolower [namespace tail $ns] }] {, }]
          puts [expr {$_arg2 eq "" ? "Usage: ./Hog/Do HELP FLOWS <tool>\nAvailable tools: $_avail"
                                   : "Unknown tool '$_arg2'. Available tools: $_avail"}]
        } else {
          puts "\nFlows for [namespace tail $_tool_ns]:"
          tdict for {_fn _fo} [Flow::GetToolFlows $_tool_ns] {
            puts [format "  %-12s  %s" $_fn [tdict getval $_fo description]]
          }
          puts ""
        }

      } elseif {$_sub eq "TOOLS"} {
        puts "TODO: "
      } else {
        if {[tdict exists $::Commands::_registry aliases $_sub]} {


          puts "Usage: ./Hog/Do $_sub \[OPTIONS\]"
          set _cmd [Commands::GetCommand $_sub]
          puts "[tdict getval $_cmd name] [_aliases [tdict get $_cmd aliases] [tdict get $_cmd name] ]:"
          puts " [tdict getval $_cmd description]"
          puts "\n Options:"
          puts "[_options_string [tdict get $_cmd options] 3]"
        
        } elseif {[tdict exists $::Flow::_registry aliases $_sub]} {

          puts "Flows matching '$_sub':"
          tlist foreach _flow [Flow::GetFlows $_sub] {
            puts " [namespace tail [tdict getval $_flow tool]]: [tdict getval $_flow name] [_aliases [tdict get $_flow aliases] [tdict getval $_flow name]]"
            if {[string length [tdict getval $_flow description]] > 0} {
              puts "   [tdict getval $_flow description]"
            }
            puts "   Stages:"
            set _stages [list]
            tlist foreachval _stage [tdict getval $_flow stages] {lappend _stages $_stage}
            puts "     [string map {" " " -> "} $_stages]"

            puts "\n   Options:"
            puts "[_options_string [tdict get $_flow options] 5]"

          }

        } else {
          puts "Unknown directive '$_sub'. Run './Hog/Do HELP' for a list."
        }
      }

      exit 0
    }
  }
}


