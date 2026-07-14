
namespace eval Commands {
  # _registry shape:
  #   aliases  -> tdict<alias, name>   (top-level entry-point aliases)
  #   cmds     -> tdict<name, node>    (top-level commands)
  #
  # A command node is a GROUP if it also has `subcommands`. It is RUNNABLE if
  # `script` is non-empty. Both may be true (a group with a default action).

  variable _registry
  if {![info exists _registry]} {
    set _registry [tdict create \
      aliases [tdict create] \
      cmds    [tdict create] \
    ]
  }

  variable _fields {
    { name            ""     optional}

    { aliases         ""     optional}
    { description     ""     optional}

    { script          ""     optional}
    { subcommands     {}     optional}

    { options         ""     optional}
    { requires_proj   false  optional}
    { ide             tclsh  optional}
    { no_exit         false  optional}
    { api             false  optional}
    { passthrough     false  optional}
    { flow_ref        ""     optional}
  }


  proc _valid_alias {alias} {
    variable _registry
    if {$alias eq ""} { return 0 }
    if {[tdict exists $_registry aliases $alias]} { return 0 }
    return 1
  }

  proc _validate_cmd {key raw_dict} {
    variable _fields
    set norm [dict create]
    dict for {k v} $raw_dict { dict set norm [string tolower $k] $v }
    set raw_dict $norm
    set result [dict create]
    foreach field $_fields {
      lassign $field fname fdefault frequired
      if {$fname eq "name"} {
        if {[dict exists $raw_dict name] && [dict get $raw_dict name] ne ""} {
          dict set result name [dict get $raw_dict name]
        } elseif {$key ne ""} {
          dict set result name $key
        } else {
          Msg Error "missing required field 'name'"
        }
        continue
      }
      if {[dict exists $raw_dict $fname]} {
        dict set result $fname [dict get $raw_dict $fname]
      } elseif {$frequired eq "required"} {
        Msg Error "missing required field '$fname'"
      } else {
        dict set result $fname $fdefault
      }
    }
    set has_script [expr {[dict get $result script] ne ""}]
    set has_subs   [expr {[llength [dict get $result subcommands]] > 0}]
    set has_flow   [expr {[dict get $result flow_ref] ne ""}]
    if {!$has_script && !$has_subs && !$has_flow} {
      Msg Error "command '[dict get $result name]' has none of 'script', 'subcommands', or 'flow_ref'"
    }
    return $result
  }

  # Build a tdict node for the command
  proc _build_node {key raw_dict is_custom} {
    set validated [_validate_cmd $key $raw_dict]
    set name [string toupper [dict get $validated name]]

    # Normalize aliases
    set aliases [list]
    foreach a [dict get $validated aliases] {
      set au [string toupper $a]
      if {$au eq "" || $au eq $name || $au in $aliases} continue
      lappend aliases $au
    }
    set aliases_tobjs [list]
    foreach a $aliases { lappend aliases_tobjs [tstr $a] }

    set node [tdict create \
      name          [tstr  $name] \
      aliases       [tlist create {*}$aliases_tobjs] \
      description   [tstr  [dict get $validated description]] \
      script        [tstr  [dict get $validated script]] \
      options       [tlist create {*}[dict get $validated options]] \
      requires_proj [tbool [dict get $validated requires_proj]] \
      ide           [tstr  [dict get $validated ide]] \
      no_exit       [tbool [dict get $validated no_exit]] \
      api           [tbool [dict get $validated api]] \
      passthrough   [tbool [dict get $validated passthrough]] \
      flow_ref      [tstr  [dict get $validated flow_ref]] \
      custom        [tbool $is_custom] \
    ]

    if {[llength [dict get $validated subcommands]] > 0} {
      set sub_cmds    [tdict create]
      set sub_aliases [tdict create]
      dict for {sub_key sub_raw} [dict get $validated subcommands] {
        if {[catch {_build_node $sub_key $sub_raw $is_custom} sub_node]} {
          Msg Warning "Skipping subcommand '$sub_key' of '$name': $sub_node"
          continue
        }
        set sub_name [tdict getval $sub_node name]
        if {[tdict exists $sub_aliases $sub_name]} {
          Msg Warning "Subcommand '$sub_name' of '$name' already exists, skipping"
          continue
        }
        tdict set sub_cmds    $sub_name $sub_node
        tdict set sub_aliases $sub_name [tstr $sub_name]
        tlist foreach a_tobj [tdict get $sub_node aliases] {
          set a [tobj value $a_tobj]
          if {[tdict exists $sub_aliases $a]} {
            Msg Warning "Alias '$a' for subcommand '$sub_name' of '$name' already exists, skipping"
            continue
          }
          tdict set sub_aliases $a [tstr $sub_name]
        }
      }
      tdict set node subcommands $sub_cmds
      tdict set node sub_aliases $sub_aliases
    }

    return $node
  }

  proc RegisterCommand {key raw_dict args} {
    variable _registry
    set is_custom [expr {"-custom" in $args}]
    if {[catch {_build_node $key $raw_dict $is_custom} node]} {
      Msg Warning "Skipping command '$key': $node"
      return
    }
    set name [tdict getval $node name]
    if {[Flow::IsReservedFlowName $name]} {
      Msg Warning "Command '$name' uses a reserved flow verb and cannot be registered, skipping"
      return
    }
    if {![_valid_alias $name]} {
      Msg Warning "Command '$name' is not valid or already exists as an alias, skipping"
      return
    }
    tdict set _registry aliases $name [tstr $name]
    tlist foreach a_tobj [tdict get $node aliases] {
      set a [tobj value $a_tobj]
      if {[Flow::IsReservedFlowName $a]} {
        Msg Warning "Alias '$a' for command '$name' is a reserved flow, skipping"
        continue
      }
      if {![_valid_alias $a]} {
        Msg Warning "Alias '$a' for command '$name' is not valid or already exists, skipping"
        continue
      }
      tdict set _registry aliases $a [tstr $name]
    }
    tdict set _registry cmds $name $node
  }

  # ::hog_command  — single command dict
  # ::hog_commands — dict of commands keyed by name
  # -custom to mark commands as user-defined.
  proc RegisterCommandsFile {f args} {
    unset -nocomplain ::hog_command ::hog_commands
    if {[catch {namespace eval :: [list source $f]} err]} {
      Msg Warning "failed to source [file tail $f]: $err"
      return
    }

    if {[info exists ::hog_commands]} {
      if {[catch {dict size $::hog_commands}]} {
        Msg Warning "hog_commands is not a dictionary in [file tail $f], skipping"
        return
      }
      dict for {key raw} $::hog_commands {
        RegisterCommand $key $raw {*}$args
      }
      return
    }

    if {[info exists ::hog_command]} {
      if {[catch {dict size $::hog_command}]} {
        Msg Warning "hog_command is not a dictionary in [file tail $f], skipping"
        return
      }
      RegisterCommand "" $::hog_command {*}$args
      return
    }

    Msg Warning "neither hog_command nor hog_commands set in [file tail $f], skipping"
  }

  # Commands can be organized as either:
  #   $dir/<name>.tcl           — single-file command
  #   $dir/<name>/<name>.tcl    — directory-style command (fallback: main.tcl)
  # For directory-style commands only the entry file is sourced; the entry
  # file is responsible for sourcing any siblings it wants to compose.
  proc RegisterCommandsDir {dir args} {
    if {![file isdirectory $dir]} { return }
    foreach f [lsort [glob -nocomplain -directory $dir *.tcl]] {
      RegisterCommandsFile $f {*}$args
    }
    foreach sub [lsort [glob -nocomplain -type d -directory $dir *]] {
      set name  [file tail $sub]
      set entry [file join $sub "$name.tcl"]
      if {![file exists $entry]} { set entry [file join $sub "main.tcl"] }
      if {![file exists $entry]} {
        Msg Warning "Command directory '$name' has no '$name.tcl' or 'main.tcl', skipping"
        continue
      }
      RegisterCommandsFile $entry {*}$args
    }
  }


  proc AliasExists {alias} {
    variable _registry
    return [tdict exists $_registry aliases $alias]
  }

  # node has no subcommands
  proc IsLeaf {node} {
    return [expr {![tdict exists $node subcommands]}]
  }

  proc IsRunnable {node} {
    if {![tdict exists $node script]} { return 0 }
    return [expr {[tdict getval $node script] ne ""}]
  }

  proc IsFlow {node} {
    if {![tdict exists $node flow_ref]} { return 0 }
    return [expr {[tdict getval $node flow_ref] ne ""}]
  }

  proc IsExecutable {node} {
    return [expr {[IsRunnable $node] || [IsFlow $node]}]
  }

  proc RunNode {node} {
    if {![IsRunnable $node]} {
      Msg Error "Cannot run command '[tdict getval $node name]' — no script defined"
      return
    }
    uplevel #0 [tdict getval $node script]
  }

  proc Run {cmd} {
    variable _registry
    if {![tdict exists $_registry aliases $cmd]} {
      Msg Error "Unknown command '$cmd'"
      return
    }
    set name [tdict getval $_registry aliases $cmd]
    set node [tdict get $_registry cmds $name]
    RunNode $node
  }

  proc GetCommandOptions {cmd} {
    set node [GetCommand $cmd]
    if {$node eq "" || ![IsRunnable $node]} { return {} }
    set result {}
    tlist foreach opt_tobj [tdict get $node options] {
      lappend result [tobj value $opt_tobj]
    }
    return $result
  }

  proc GetCommand {cmd} {
    variable _registry
    if {![tdict exists $_registry aliases $cmd]} { return {} }
    set name [tdict getval $_registry aliases $cmd]
    if {![tdict exists $_registry cmds $name]} { return {} }
    return [tdict get $_registry cmds $name]
  }

  proc GetCommands {} {
    variable _registry
    if {![tdict exists $_registry cmds]} {return {}}
    return [tdict get $_registry cmds]
  }

  # warn if a flow is hidden by a command with same name
  proc WarnFlowShadows {} {
    variable _registry
    if {![tdict exists $_registry aliases]} { return }
    if {![info exists ::Flow::_registry] || ![tdict exists $::Flow::_registry aliases]} { return }
    tdict for {alias _name} [tdict get $_registry aliases] {
      if {![tdict exists $::Flow::_registry aliases $alias]} { continue }
      set _tools {}
      tdict for {tns _fn} [tdict get $::Flow::_registry aliases $alias] {
        lappend _tools [string tolower [namespace tail $tns]]
      }
      Msg Warning "Command '$alias' shadows flow '$alias' (tool(s): [join $_tools {, }]). Bare '$alias <proj>' runs the command; \
      use 'tool <tool> flow $alias <proj>' for the flow."
    }
  }

  # Walk a nested subcommand path from argv. Returns a dict:
  #   node      — the resolved node (group or leaf)
  #   path      — list of canonical names traversed
  #   remaining — argv tail after the consumed path
  # Returns empty dict if the first token doesn't resolve.
  proc ResolvePath {argv_list} {
    variable _registry
    if {[llength $argv_list] == 0} { return {} }
    set first [string toupper [lindex $argv_list 0]]
    if {![tdict exists $_registry aliases $first]} { return {} }
    set name [tdict getval $_registry aliases $first]
    set node [tdict get $_registry cmds $name]
    set path [list $name]
    set remaining [lrange $argv_list 1 end]
    while {[tdict exists $node subcommands]} {
      if {[llength $remaining] == 0} break
      set seg [string toupper [lindex $remaining 0]]
      if {![tdict exists $node sub_aliases $seg]} break
      set sub_name [tdict getval $node sub_aliases $seg]
      if {![tdict exists $node subcommands $sub_name]} break
      set node      [tdict get $node subcommands $sub_name]
      lappend path  $sub_name
      set remaining [lrange $remaining 1 end]
    }
    return [dict create node $node path $path remaining $remaining]
  }

  # Parse the full argv into a dict:
  #   cmd          — resolved command node (tdict) (empty if unrecognised)
  #   full_cmd     — list of canonical names consumed  (e.g. {TOOL VIVADO CMD})
  #   project      — bare project name  (file tail, Top/-stripped)
  #   project_name — project as typed   (useful for path-based lookups)
  #   options      — remaining flags/values after the project positional

  proc ParseArgv {argv top_path} {
    if {[llength $argv] >= 2 && ![string match "-*" [lindex $argv 1]]} {
      set argv [lreplace $argv 1 1 \
        [string trimright [regsub {^(\./)?Top/} [lindex $argv 1] ""] "/ "]]
    }

    # Allow shorthand commands for flows:
    # `<flow> <proj>` -> `TOOL <tool> FLOW <flow> <proj>`
    set _d [string toupper [lindex $argv 0]]
    if {$_d ne "" && ![AliasExists $_d] && [llength $argv] >= 2} {
      set proj [lindex $argv 1]
      if {[file exists [file join $top_path $proj hog.conf]]} {
        set _tool [Tools::GetToolForProject $proj $top_path]
        if {$_tool ne "" && [Flow::AliasExistsForTool $_d $_tool]} {
          set argv [concat [list TOOL [string tolower [namespace tail $_tool]] FLOW $_d] \
                            [lrange $argv 1 end]]
        }
      }
    }

    set directive [string toupper [lindex $argv 0]]
    set resolved  [ResolvePath $argv]
    if {[llength $resolved] > 0} {
      set node      [dict get $resolved node]
      set path      [dict get $resolved path]
      set rest      [dict get $resolved remaining]
    } else {
      set node      {}
      set path      [list $directive]
      set rest      [lrange $argv 1 end]
    }
    set project_name ""
    set options      $rest
    if {[llength $rest] > 0 && ![string match "-*" [lindex $rest 0]]} {
      set project_name [lindex $rest 0]
      set options      [lrange $rest 1 end]
    }
    set project [file tail $project_name]
    return [dict create \
      cmd          $node         \
      full_cmd     $path         \
      project      $project      \
      project_name $project_name \
      options      $options      \
    ]
  }

  # Validate and run a resolved command. Returns:
  #   "ran"        — ran successfully in tclsh (caller returns normally)
  #   "boot <ide>" — caller must boot the named IDE (tool pass will finish it)
  # Exits on any validation error or option parse failure.
  proc RunCommand {cmd full_cmd project options} {
    set label [join $full_cmd { }]

    if {$cmd eq ""} {
      set directive [string toupper [lindex $full_cmd 0]]
      if {[Flow::AliasExists $directive]} {
        Msg Error "Flow '$directive' requires a project. Usage: ./Hog/Do $directive <project>"
      } else {
        Msg Error "Unknown directive '$directive'. Run './Hog/Do HELP' for usage."
      }
      exit 1
    }

    if {[tdict exists $cmd subcommands] && $project ne ""
        && ![tdict exists $cmd sub_aliases [string toupper $project]]
        && ![tdict getval $cmd passthrough]} {
      Msg Error "'$label' has no subcommand '$project'. Run './Hog/Do HELP $label' for a list."
      exit 1
    }

    if {![IsExecutable $cmd]} {
      Msg Error "Command '$label' requires a subcommand. Run './Hog/Do HELP $label' for a list."
      exit 1
    }

    if {[tdict getval $cmd requires_proj] && $project eq ""} {
      Msg Error "Command '$label' requires a project. Run './Hog/Do HELP' for usage."
      exit 1
    }

    if {[tdict getval $cmd requires_proj] && $project ne ""} {
      set _conf [file join [Repo::Get top_path] $project hog.conf]
      if {![file exists $_conf]} {
        Msg Error "Project '$project' not found (no hog.conf at $_conf)."
        exit 1
      }
    }

    # Parse options defined by this command.
    set opt_specs [list]
    tlist foreach o [tdict get $cmd options] { lappend opt_specs [tobj value $o] }
    if {[catch {array set parsed_opts [cmdline::getoptions options $opt_specs ""]} err]} {
      Msg Error "Option error for '$label': $err"
      exit 1
    }
    set opts_tdict [tdict create]
    foreach k [array names parsed_opts] { tdict set opts_tdict $k [tinf $parsed_opts($k)] }
    Launcher::Set options $opts_tdict

    set ide [tdict getval $cmd ide]
    if {$ide eq "tclsh" && ![IsFlow $cmd]} {
      cd [Repo::Get repo_path]
      RunNode $cmd
      return "ran"
    }
    return [list boot $ide]
  }

}
