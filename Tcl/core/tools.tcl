
namespace eval Tools {

<<<<<<< HEAD

  # Manifest fields
  variable _fields {
    { name        ""  required}
    { ref_names   ""  required}

    { vendor      ""  optional}
    { description ""  optional}
    { version     ""  optional}
    { features    {}  optional}
    { flows       {}  optional}
    { commands    {}  optional}
    { custom      0   optional}
    { _source_path "" optional}
    { _git         {} optional}
  }

  proc _validate_manifest {tool_name raw_dict} {
    variable _fields
    set norm [dict create]
    dict for {k v} $raw_dict { dict set norm [string tolower $k] $v }
    set raw_dict $norm
    set result [dict create]
    foreach field $_fields {
      lassign $field fname fdefault frequired
      if {[dict exists $raw_dict $fname]} {
        dict set result $fname [dict get $raw_dict $fname]
      } elseif {$frequired eq "required"} {
        error "Tool '$tool_name': missing required field '$fname'"
      } else {
        dict set result $fname $fdefault
      }
    }
    return $result
  }

  proc detectActiveTool {} {
    foreach ns [namespace children ::Tools] {
      if {[info commands ${ns}::IsActive] eq ""} continue
      if {[catch {set result [${ns}::IsActive]} err]} continue
      if {$result} {
        return $ns
      }
    }
    return ""
  }

  proc PrintTools {} {
    puts "=================================================="
    puts "  Loaded Tools"
    puts "=================================================="
    set tools [namespace children ::Tools]
    if {[llength $tools] == 0} {
      puts "  (none)"
    } else {
      foreach ns $tools {
        ${ns}::_printTool
      }
    }
    puts "=================================================="
  }


  proc Launch {tool} {
    set tool_ns [ResolveAlias $tool]
    if {$tool_ns eq "" || [info commands ${tool_ns}::Launch] eq ""} {
      Msg Error "Tool '$tool' not found or has no Launch proc"
      return
    }
    if {[catch {${tool_ns}::Launch} err]} {
      Msg Error "Failed to launch tool '$tool': $err"
    }
  }

  proc ResolveAlias {alias} {
    if {$alias eq ""} { return "" }
    if {[string first "::" $alias] >= 0} {
      return [expr {[namespace exists $alias] ? $alias : ""}]
    }
    set needle [string tolower $alias]
    foreach ns [namespace children ::Tools] {
      if {[string tolower [namespace tail $ns]] eq $needle} { return $ns }
      if {[catch {set m [${ns}::GetManifest]} err]} { continue }
      if {[dict exists $m ref_names]} {
        foreach iname [dict get $m ref_names] {
          if {[string tolower $iname] eq $needle} { return $ns }
        }
      }
    }
    return ""
  }

  # Register tools from a directory
  # looks for ./<tool>/<tool>.tcl or  ./<tool>/main.tcl
  # Pass -custom to mark every tool sourced from this dir as user-defined.
  proc RegisterFromDir {dir args} {
    Msg Debug "Loading tools from $dir"
    if {![file isdirectory $dir]} { return }
    set is_custom [expr {"-custom" in $args}]
    foreach sub [lsort [glob -nocomplain -type d -directory $dir *]] {
      set tool_name [file tail $sub]
      set entry [file join $sub "$tool_name.tcl"]
      if {![file exists $entry]} {
        set entry [file join $sub "main.tcl"]
      }
      if {![file exists $entry]} {
        Msg Warning "Tool directory '$tool_name' has no '$tool_name.tcl' or 'main.tcl', skipping"
        continue
      }
      set _pre [namespace children ::Tools]
      if {[catch {namespace eval :: [list source $entry]} err]} {
        Msg Warning "failed to source [file tail $entry] for tool '$tool_name': $err"
        continue
      }
      foreach ns [namespace children ::Tools] {
        if {$ns in $_pre} continue
        if {![info exists ${ns}::Manifest]} continue
        namespace eval $ns [list variable Manifest]
        namespace eval $ns [list dict set Manifest _source_path $entry]
        
        # TODO: replace this with a real git/version lookup.
        set _git_placeholder [dict create \
          sha      "########"     \
          date     "2026-01-01"   \
          describe "v0.0.0"       \
        ]
        namespace eval $ns [list dict set Manifest _git $_git_placeholder]
        if {$is_custom} {
          namespace eval $ns [list dict set Manifest custom 1]
        }
      }
    }
  }

  # Build a raw command-node dict for the flow. Used to add flow to command registry
  proc _flowCmdDict {tool_ns flow_name flow_tdict} {
    set aliases [list]
    tlist foreachval a [tdict get $flow_tdict aliases] { lappend aliases $a }
    return [dict create \
      aliases       $aliases \
      description   [tdict getval $flow_tdict description] \
      options       [Flow::GetFlowOptions $tool_ns $flow_name] \
      requires_proj true \
      ide           [string tolower [namespace tail $tool_ns]] \
      flow_ref      $flow_name \
    ]
  }

  proc Init {} {
    set _required_procs {IsActive Launch Initialize}
    foreach ns [namespace children ::Tools] {
      set tool_name [namespace tail $ns]
      if {[catch {set m [namespace eval $ns {variable Manifest; set Manifest}]} err]} {
        Msg Warning "$tool_name does not define a Manifest, skipping"
        namespace delete $ns
        continue
      }
      if {[catch {_validate_manifest $tool_name $m} validated]} {
        Msg Warning "Skipping tool: $validated"
        namespace delete $ns
        continue
      }

      namespace eval $ns [list variable Manifest $validated]

      set missing {}
      foreach required $_required_procs {
        if {[info commands ${ns}::${required}] eq ""} {
          lappend missing $required
        }
      }
      if {[llength $missing] > 0} {
        Msg Warning "$tool_name is missing required procs: [join $missing {, }], skipping"
        namespace delete $ns
        continue
      }

      InjectCommonProcs $ns

      if {[dict exists $validated flows] && [llength [dict get $validated flows]] > 0} {
        Flow::RegisterFlowDict $ns [dict get $validated flows]
      }
    }

    set active [detectActiveTool]
    if {$active ne ""} {
      ::ActiveTool::Set $active
    }
  }

  # Create commands out of Tools
  # flows and commands are added under the {tool <tool>} tree
  proc BuildCommandTree {} {
    set tool_subs [dict create]
    foreach ns [namespace children ::Tools] {
      set tool_name [namespace tail $ns]
      if {[catch {set validated [${ns}::GetManifest]}]} { continue }

      # Register every tool under the TOOL subcommand tree
      set tool_key [string toupper $tool_name]
      set ref_aliases [list]
      if {[dict exists $validated ref_names]} {
        foreach rn [dict get $validated ref_names] { lappend ref_aliases $rn }
      }

      # Command subcommands from Manifest.commands.
      set _subs [dict create]
      set _cmd_aliases [list]
      if {[dict exists $validated commands]} {
        dict for {ck cv} [dict get $validated commands] {
          dict set _subs [string toupper $ck] $cv
          lappend _cmd_aliases [string toupper $ck]
          if {[dict exists $cv aliases]} {
            foreach a [dict get $cv aliases] { lappend _cmd_aliases [string toupper $a] }
          }
        }
      }


      # For flows, we want to register them in two places incase of command collision
      #  (a) tool <t> <flow>       - for ease of use, commands can override this path
      #  (b) tool <t> flow <flow>  - command shouldn't collide with this one
      set _flow_subs [dict create]
      tdict for {fname fnode} [Flow::GetToolFlows $ns] {
        set _fkey  [string toupper $fname]
        set _fcmd  [_flowCmdDict $ns $fname $fnode]
        dict set _flow_subs $_fkey $_fcmd

        set _collides 0
        foreach _fa [concat [list $_fkey] [dict get $_fcmd aliases]] {
          if {[string toupper $_fa] in $_cmd_aliases} { set _collides 1; break }
        }
        if {$_collides} {
          Msg Warning "Tool '$tool_name': flow '$fname' collides with a command; reach it via 'tool $tool_name flow $fname'"
        } else {
          dict set _subs $_fkey $_fcmd
        }
      }
      if {[dict size $_flow_subs] > 0} {
        dict set _subs FLOW [dict create \
          description "Flows provided by $tool_name. Usage: tool $tool_name flow <flow> <project>" \
          subcommands $_flow_subs \
        ]
      }

      set tool_subs_entry [dict create \
        description [dict get $validated description] \
        aliases     $ref_aliases \
        script      "Help::RenderTool [string tolower $tool_name]" \
      ]
      if {[dict size $_subs] > 0} {
        dict set tool_subs_entry subcommands $_subs
      }
      dict set tool_subs $tool_key $tool_subs_entry
    }

    if {[dict size $tool_subs] > 0} {
      Commands::RegisterCommand TOOL [dict create \
        description   "Tool-scoped commands. Usage: ./Hog/Do TOOL <tool> <command> \[project\] \[options\]" \
        passthrough   true \
        subcommands   $tool_subs \
        script {
          set _alias [lindex $::argv 1]
          if {$_alias eq ""} {
            Help::RenderPath {TOOL}
          } else {
            set _avail {}
            foreach ns [lsort [namespace children ::Tools]] { lappend _avail [string tolower [namespace tail $ns]] }
            Msg Error "Unknown tool '$_alias'. Available tools: [join $_avail {, }]"
            exit 1
          }
        } \
      ]
    }
  }

  proc GetToolForProject {project top_path} {
    set conf [file join $top_path $project hog.conf]
    if {![file exists $conf]} {
      Msg Error "hog.conf not found for project '$project' at $conf"
      return ""
    }
    set ide_name_and_ver [string tolower [GetIDEFromConf $conf]]
    set ide_name [lindex [regexp -all -inline {\S+} $ide_name_and_ver] 0]
    foreach ns [namespace children ::Tools] {
      if {[catch {set m [${ns}::GetManifest]} err]} { continue }
      if {![dict exists $m ref_names]} { continue }
      foreach iname [dict get $m ref_names] {
        if {[string tolower $iname] eq $ide_name} {
          return $ns
        }
      }
    }
    Msg Warning "No loaded tool matches IDE '$ide_name' (from $conf)"
    return ""
  }

  # we can inject procs into each tool's namespace to provide some common functionality
  # let's use use calls like Tools::Vivado::GetManifest and not have to define these for each tool
  proc InjectCommonProcs {tool_ns} {
    namespace eval $tool_ns {

      proc Supports {feature} {
        variable Manifest
        if {[dict exists $Manifest features $feature]} {
          return 1
        }
        return 0
      }

      proc GetManifest {} {
        variable Manifest
        return $Manifest
      }

      proc Has {method} {
        return [expr {[info commands [namespace current]::${method}] ne ""}]
      }

      proc _printTool {} {
        variable Manifest
        set injected {Has Supports GetManifest _printTool}
        set tool_name [namespace tail [namespace current]]

        set methods {}
        foreach cmd [lsort [info commands [namespace current]::*]] {
          set m [namespace tail $cmd]
          if {$m ni $injected && [string index $m 0] ne "_"} {
            lappend methods $m
          }
        }

        puts "\[$tool_name\]"
        puts "  Manifest: $Manifest"
        puts "  Methods: [join $methods {, }]"
      }
    }
  }
}




# Namespace wrapper around the current tool, should use this instead 
# of tool specific calls in most cases:
namespace eval ActiveTool {
  variable tool "tclsh"
  variable _fixed_procs {Set CurrentTool Refresh}
  variable _skip_procs {}


  proc CurrentTool {} {
    variable tool
    return $tool
  }

  proc Refresh {} {
    variable tool
    Set $tool
  }

  proc Set {tool_ns} {
    variable tool
    variable _fixed_procs
    variable _skip_procs

    foreach cmd [info commands ::ActiveTool::*] {
      set name [namespace tail $cmd]
      if {$name ni $_fixed_procs} {
        rename ::ActiveTool::$name ""
      }
    }

    if {$tool_ns eq ""} {
      return
    }

    set tool $tool_ns

    foreach tool_proc [info commands ${tool_ns}::*] {
      set name [namespace tail $tool_proc]

      if {[string index $name 0] eq "_"} continue
      if {$name in $_skip_procs}   continue
      if {$name in $_fixed_procs} continue

      # we can generate a wrapper around the actual call to add logging or 
      # other functionality without modifying the tool's code
      set proc_body [string map [list @_TOOL $tool_ns @_PROC_NAME $name] {
        Msg Debug "Calling @_TOOL::@_PROC_NAME with args: $args"
        set result [@_TOOL::@_PROC_NAME {*}$args]
        Msg Debug "Result from @_TOOL::@_PROC_NAME $result"
        return $result
||||||| parent of 58a89ed3 (added initial modular tool flow)
=======
  proc detectActiveTool {} {
    foreach ns [namespace children ::Tools] {
      if {[info commands ${ns}::IsActive] eq ""} continue
      if {[catch {set result [${ns}::IsActive]} err]} continue
      if {$result} {
        return $ns
      }
    }
    return ""
  }

  proc PrintTools {} {
    puts "=================================================="
    puts "  Loaded Tools"
    puts "=================================================="
    set tools [namespace children ::Tools]
    if {[llength $tools] == 0} {
      puts "  (none)"
    } else {
      foreach ns $tools {
        ${ns}::_printTool
      }
    }
    puts "=================================================="
  }


  proc Launch {tool} {
    set tools [namespace children ::Tools]
    set tool_ns ""
    foreach ns $tools {
      if {[string tolower [namespace tail $ns]] eq [string tolower $tool]} {
        set tool_ns $ns
        break
      }
    }
    if {[catch {${tool_ns}::Launch} err]} {
      Msg Error "Failed to launch tool '$tool': $err"
    }
  }

  proc Init {tools_dirs} {
    foreach dir $tools_dirs {
      Msg Debug "Loading tools from $dir"
      if {![file isdirectory $dir]} { continue }
      foreach f [lsort [glob -nocomplain -directory $dir *.tcl]] {
        if {[catch {namespace eval :: [list source $f]} err]} {
          Msg Warning "failed to source [file tail $f]: $err"
          continue
        }
      }
    }


    set _required_procs {IsActive Launch Initialize}
    foreach ns [namespace children ::Tools] {
      if {[catch {set m [namespace eval $ns {variable Manifest; set Manifest}]} err]} {
        Msg Warning "[namespace tail $ns] does not define a Manifest, skipping"
        namespace delete $ns
        continue
      }
      #TODO: if manifest does exist, should probably check for a set of required fields

      set missing {}
      foreach required $_required_procs {
        if {[info commands ${ns}::${required}] eq ""} {
          lappend missing $required
        }
      }
      if {[llength $missing] > 0} {
        Msg Warning "[namespace tail $ns] is missing required procs: [join $missing {, }], skipping"
        namespace delete $ns
        continue
      }

      InjectCommonProcs $ns
    }

    set active [detectActiveTool]
    if {$active ne ""} {
      ::ActiveTool::Set $active
    }
  }

  # we can inject procs into each tool's namespace to provide some common functionality
  # let's use use calls like Tools::Vivado::GetManifest and not have to define these for each tool
  proc InjectCommonProcs {tool_ns} {
    namespace eval $tool_ns {

      proc Supports {feature} {
        variable Manifest
        if {[dict exists $Manifest features $feature]} {
          return 1
        }
        return 0
      }

      proc GetManifest {} {
        variable Manifest
        return $Manifest
      }

      proc Has {method} {
        return [expr {[info commands [namespace current]::${method}] ne ""}]
      }

      proc _printTool {} {
        variable Manifest
        set injected {Has Supports GetManifest _printTool}
        set tool_name [namespace tail [namespace current]]

        set methods {}
        foreach cmd [lsort [info commands [namespace current]::*]] {
          set m [namespace tail $cmd]
          if {$m ni $injected && [string index $m 0] ne "_"} {
            lappend methods $m
          }
        }

        puts "\[$tool_name\]"
        puts "  Manifest: $Manifest"
        puts "  Methods: [join $methods {, }]"
      }
    }
  }
}




# Namespace wrapper around the current tool, should use this instead 
# of tool specific calls in most cases:
namespace eval ActiveTool {
  variable tool "tlcsh"
  variable _fixed_procs {Set CurrentTool}
  variable _skip_procs {}


  proc CurrentTool {} {
    variable tool
    return $tool
  }

  proc Set {tool_ns} {
    variable tool
    variable _fixed_procs
    variable _skip_procs

    foreach cmd [info commands ::ActiveTool::*] {
      set name [namespace tail $cmd]
      if {$name ni $_fixed_procs} {
        rename ::ActiveTool::$name ""
      }
    }

    if {$tool_ns eq ""} {
      return
    }

    set tool $tool_ns

    foreach tool_proc [info commands ${tool_ns}::*] {
      set name [namespace tail $tool_proc]

      if {[string index $name 0] eq "_"} continue
      if {$name in $_skip_procs}   continue
      if {$name in $_fixed_procs} continue

      # we can generate a wrapper around the actual call to add logging or 
      # other functionality without modifying the tool's code
      set proc_body [string map [list @_TOOL $tool_ns @_PROC_NAME $name] {
        Msg Debug "Calling @_TOOL::@_PROC_NAME with args: $args"
        set result [@_TOOL::@_PROC_NAME {*}$args]
        Msg Debug "Result from @_TOOL::@_PROC_NAME $result"
        return \$result
>>>>>>> 58a89ed3 (added initial modular tool flow)
      }]

      proc ::ActiveTool::$name {args} $proc_body
    }
  }
}
