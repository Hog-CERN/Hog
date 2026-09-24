namespace eval Commands {
  
  # alias_index: qualified alias -> canonical path (plain dict, string -> string)
  #   Top-level canonical:  "VIVADO"        -> "VIVADO"
  #   Top-level alias:      "VI"            -> "VIVADO"
  #   Scoped canonical:     "VIVADO.FLOW"   -> "VIVADO.FLOW"
  #   Scoped alias:         "VIVADO.C"      -> "VIVADO.FLOW.CREATE"
  #
  # nodes: canonical path -> Node tdict

  variable alias_index {}
  variable nodes       {}
  variable name_guards {}


  # Current Node executing:
  variable _current_node {}
  variable _current_path {}

  proc CurrentNode {} {
    variable _current_node
    return $_current_node
  }

  proc CurrentPath {} {
    variable _current_path
    return $_current_path
  }

  # Positional arguments of the running command as a plain Tcl list: 
  # every non-flag token left over after the command path resolved (see
  # ParseArgv). Index 0 is the project by convention, also mirrored as
  # Launcher project/project_name.
  #
  # Read these instead of $::argv: an inline Hog::Do has no private argv, and
  # argv indices shift whenever the command path changes length.
  proc Args {} {
    set _a [Launcher::GetOr args {}]
    if {$_a eq {}} { return {} }
    return [tnative $_a]
  }

  # Safe indexed accessor - out-of-range yields $default rather than an error.
  proc Arg {index {default ""}} {
    set _v [lindex [Args] $index]
    if {$_v eq ""} { return $default }
    return $_v
  }

  # CommandNode
  # Represents anything that can be run from cmdline, such as tool, flow, stage, command
  # Distinguished mostly by looking at the nodes key:
  # TOOL.<> is a tool; TOOL.<>.FLOW.<> is a flow; TOOL.<>.STAGE.<> is a stage, 
  # everything else a command
  namespace eval Node {

    # Field table: {name type default}
    #
    # 'script' and 'stages' are the two mutually exclusive action fields; stages
    # win if an author sets both (Lint reports it).
    #
    # 'produces'/'requires' are the per-stage artifact contract (handled by flowcontrol)
    variable _fields {
      { name          str  ""    }
      { aliases       list ""    }
      { description   str  ""    }
      { help          str  ""    }
      { script        str  ""    }
      { stages        list {}    }
      { produces      list {}    }
      { requires      list {}    }
      { options       list {}    }
      { ide           str  tclsh }
      { requires_proj bool 0     }
      { api           bool 0     }
      { passthrough   bool 0     }
    }


    proc New {key raw_dict} {
      variable _fields
      set norm [dict create]
      dict for {k v} $raw_dict { dict set norm [string tolower $k] $v }
      set raw_dict $norm

      set node [tdict create]
      foreach field $_fields {
        lassign $field fname ftype fdefault

        switch -- $fname {
          name {
            set name [expr {
              [dict exists $raw_dict name] && [dict get $raw_dict name] ne ""
                ? [string toupper [string trim [dict get $raw_dict name]]] : [string toupper $key]
            }]
            if {$name eq ""} { error "Command has no name" }
            if {[string first "." $name] >= 0} { error "Command '$name': name may not contain '.'" }
            tdict set node name [tstr $name]
            continue
          }

          aliases {
            set aliases {}
            foreach a [expr {[dict exists $raw_dict aliases] ? [dict get $raw_dict aliases] : {}}] {
              set au [string toupper $a]
              if {$au ne "" && [string first "." $au] < 0 && $au ne [tdict getval $node name] && $au ni $aliases} { lappend aliases $au }
            }
            tdict set node aliases [tlist create {*}$aliases]
            continue
          }
        }

        if {[dict exists $raw_dict $fname] && [dict get $raw_dict $fname] ne ""} {
          set v [dict get $raw_dict $fname]
        } else {
          set v $fdefault
        }
        switch -- $ftype {
          str  { tdict set node $fname [tstr  [string trim $v]] }
          bool { tdict set node $fname [tbool $v] }
          list { tdict set node $fname [tlist create {*}$v] }
        }
      }

      return $node
    }

    proc HasStages   {node} { return [expr {[tlist length [tdict getobjor $node stages [tlist create]]] > 0}] }
    proc IsRunnable  {node} { return [expr {[tdict getval $node script] ne "" || [HasStages $node]}] }
    proc RequiresProj {node} { return [tdict getval $node requires_proj] }

    proc IsTool {node} { return [regexp {^TOOL\.[^.]+$} [tdict getor $node canon ""]] }
    proc IsFlow  {node} { return [regexp {^TOOL\.[^.]+\.FLOW\.[^.]+$}  [tdict getor $node canon ""]] }
    proc IsStage {node} { return [regexp {^TOOL\.[^.]+\.STAGE\.[^.]+$} [tdict getor $node canon ""]] }

    # Resolve an "@<FLOW>" stage reference against the node's siblings, so a flow
    # references a peer flow by bare name ("@CREATE", not "VIVADO.FLOW.CREATE").
    # Goes through GetCommand, so the reference may be an alias.
    proc _sibling {node ref} {
      set canon [tdict getval $node canon]
      set idx   [string last "." $canon]
      if {$idx < 0} { return {} }
      return [::Commands::GetCommand "[string range $canon 0 [expr {$idx-1}]].$ref"]
    }

    # Expand a node's stage list, splicing "@<FLOW>" references in place.
    #
    # Deliberately lazy - resolved per run/help rather than snapshotted at
    # registration, so a flow may reference one that registers later in the file
    # (or in another file entirely).
    proc FlattenStages {node} { return [dict get [_walk_stages $node] stages] }


    # The traversal behind both FlattenStages and Commands::Lint. Returns:
    #   stages  -> the flattened stage list
    #   badrefs -> {{owner_canon @ref} ...}  a reference naming no sibling flow
    #   cycles  -> {{owner_canon chain} ...} a reference that closes a loop
    #
    # Each problem carries the canon of the node that *declared* the offending reference
    proc _walk_stages {node {_seen {}}} {
      set canon [tdict getval $node canon]
      if {$canon in $_seen} {
        return [dict create stages {} badrefs {} cycles [list [list $canon $_seen]]]
      }
      lappend _seen $canon
      set stages  {}
      set badrefs {}
      set cycles  {}
      tlist foreachval s [tdict getobjor $node stages [tlist create]] {
        if {![string match "@*" $s]} { lappend stages $s; continue }
        set rnode [_sibling $node [string range $s 1 end]]
        if {$rnode eq {}} { lappend badrefs [list $canon $s]; continue }
        set sub [_walk_stages $rnode $_seen]
        lappend stages  {*}[dict get $sub stages]
        lappend badrefs {*}[dict get $sub badrefs]
        lappend cycles  {*}[dict get $sub cycles]
      }
      return [dict create stages $stages badrefs $badrefs cycles $cycles]
    }

    # Options of a node plus those of every flow it @references.
    proc FlattenOptions {node {_seen {}}} {
      set canon [tdict getval $node canon]
      if {$canon in $_seen} { return {} }
      lappend _seen $canon

      # Self first, then each @referenced flow. No warning on an unresolvable ref here 
      # Commands::Lint reports them once per invocation instead of once per traversal.
      set specs {}
      tlist foreachval o [tdict getobjor $node options [tlist create]] { lappend specs $o }
      tlist foreachval s [tdict getobjor $node stages [tlist create]] {
        if {![string match "@*" $s]} continue
        set rnode [_sibling $node [string range $s 1 end]]
        if {$rnode ne {}} { lappend specs {*}[FlattenOptions $rnode $_seen] }
      }

      # First spec for an option name wins, so a flow overrides an inherited default.
      set result {}
      set names  {}
      foreach spec $specs {
        set n [lindex $spec 0]
        if {$n ni $names} { lappend result $spec; lappend names $n }
      }
      return $result
    }

    proc Run {node {path {}}} {
      if {![IsRunnable $node]} {
        error "Cannot run '[tdict getval $node name]' - no script or stages defined"
      }
      set _prev_node ${::Commands::_current_node}
      set _prev_path ${::Commands::_current_path}
      set ::Commands::_current_node $node
      set ::Commands::_current_path $path

      # Stages and Flows must run through FlowControl
      if {[HasStages $node]} {
        set _code [catch {FlowControl::Run [FlattenStages $node] [tdict getval $node name]} _res _opts]
      } elseif {[IsStage $node]} {
        set _name [tdict getval $node name]
        set _code [catch {FlowControl::Run [list $_name] $_name} _res _opts]
      } else {
        set _code [catch {uplevel #0 [tdict getval $node script]} _res _opts]
      }
      set ::Commands::_current_node $_prev_node
      set ::Commands::_current_path $_prev_path
      return -options $_opts $_res
    }
  }

  # Register a single reserved name and the reason it's rejected
  proc AddNameGuard {name reason} {
    variable name_guards
    dict set name_guards [string toupper $name] $reason
  }

  proc _veto {name} {
    variable name_guards
    set key [string toupper $name]
    if {[dict exists $name_guards $key]} { return [dict get $name_guards $key] }
    return ""
  }

  # Resolves any alias - bare ("VIVADO") or dotted ("VIVADO.FLOW.CREATE") - to
  # its real canon. 
  #
  # Walks the dotted commande tree, resolving aliases at each level
  # 'VIVADO.FLOW.C' 
  # 'VIVADO' -> TOOL.VIVADO
  # 'TOOL.VIVADO.FLOW' -> TOOL.VIVADO.FLOW
  # 'TOOL.VIVADO.FLOW.C' -> TOOL.VIVADO.FLOW.CREATE
  proc _canon {alias} {
    variable alias_index
    if {$alias eq ""} { return "" }
    set key [string toupper $alias]
    if {[dict exists $alias_index $key]} { return [dict get $alias_index $key] }
    set parts [split $key "."]
    if {[llength $parts] < 2} { return "" }
    set canon [_canon [lindex $parts 0]]
    if {$canon eq ""} { return "" }
    foreach part [lrange $parts 1 end] {
      set canon [_canon_child $canon $part]
      if {$canon eq ""} { return "" }
    }
    return $canon
  }

  proc _canon_child {parent token} {
    variable alias_index
    set key "$parent.[string toupper $token]"
    if {[dict exists $alias_index $key]} { return [dict get $alias_index $key] }
    return ""
  }

  # Registration internals

  # Registers one node: assigns its canonical path, indexes it and its aliases.
  #   node:   the built Node tdict (from Node::New) to register
  #   parent: the parent's own canon, or "" for top-level
  #   is_custom: set when sourcing custom commands
  #   source: file where this was generated from
  proc _register_at {node parent is_custom source} {
    variable alias_index
    variable nodes

    set bare_name [tdict getval $node name]
    set canon     [expr {$parent eq "" ? $bare_name : "$parent.$bare_name"}]
    tdict set node custom      [tbool $is_custom]
    tdict set node canon       [tstr $canon]
    tdict set node source_path [tstr $source]

    set name $bare_name
    set aliases {}
    tlist foreachval a [tdict getval $node aliases] { lappend aliases $a }

    dict set nodes $canon $node

    dict set alias_index $canon $canon
    foreach a [list $name {*}$aliases] {
      set key [expr {$parent eq "" ? $a : "$parent.$a"}]
      if {$key ne $canon && ![dict exists $alias_index $key]} {
        dict set alias_index $key $canon
      }
    }
  }

  # Direct children of a path, derived from nodes' keys
  proc GetChildren {canon} {
    variable nodes
    set prefix "$canon."
    set plen   [string length $prefix]
    set result {}
    dict for {k v} $nodes {
      if {[string equal -length $plen $prefix $k] && [string first "." $k $plen] < 0} {
        lappend result $k
      }
    }
    return $result
  }

  proc _deregister {canon} {
    variable alias_index
    variable nodes

    if {![dict exists $nodes $canon]} { return }

    foreach child [GetChildren $canon] { _deregister $child }

    foreach k [dict keys [dict filter $alias_index value $canon]] {
      dict unset alias_index $k
    }

    dict unset nodes $canon
  }

  # Public registration API

  # Registers 'key' at the top level, or under an existing node if 'key' is dotted (e.g. "PARENT.CHILD").
  proc RegisterCommand {key raw_dict args} {
    variable alias_index
    variable nodes
    set is_custom [expr {"-custom" in $args}]
    set source ""
    if {[set _si [lsearch -exact $args -source]] >= 0} { set source [lindex $args [expr {$_si+1}]] }

    set idx      [string last "." $key]
    set bare_key [expr {$idx < 0 ? $key : [string range $key [expr {$idx+1}] end]}]
    set parent   ""
    if {$idx >= 0} {
      set parent [_canon [string toupper [string range $key 0 [expr {$idx-1}]]]]
      if {$parent eq "" || ![dict exists $nodes $parent]} {
        Msg Warning "RegisterCommand: parent for '$key' not found"
        return
      }
      set parent_node [dict get $nodes $parent]
      if {"-custom" ni $args} { set is_custom [tobj value [tdict get $parent_node custom]] }
      if {$source eq ""}      { set source    [tdict getval $parent_node source_path] }
    } else {
      # Top-level: fall back to Hog::_loading_* context
      if {"-custom" ni $args} { set is_custom [set ::Hog::_loading_custom] }
      if {$source eq ""}      { set source    [set ::Hog::_loading_source] }
    }

    if {[catch {Node::New $bare_key $raw_dict} node]} {
      Msg Warning "Skipping command '$key': $node"
      return
    }
    set name [tdict getval $node name]

    # Name guards are top-level only - they stop a stray command shadowing a flow, not nested paths.
    if {$parent eq "" && [set why [_veto $name]] ne ""} {
      Msg Warning "Command '$name' rejected: $why"
      return
    }
    set existing [expr {$parent eq "" ? [_canon $name] : [_canon_child $parent $name]}]
    if {$existing ne ""} {
      Msg Warning "Command '$name' already exists, skipping"
      return
    }

    # Filter conflicting aliases before registering (scoped to the same parent)
    set clean {}
    tlist foreachval a [tdict getval $node aliases] {
      set a_existing [expr {$parent eq "" ? [_canon $a] : [_canon_child $parent $a]}]
      if {$parent eq "" && [set why [_veto $a]] ne ""} {
        Msg Warning "Alias '$a' for '$name' rejected: $why"
      } elseif {$a_existing ne ""} {
        Msg Warning "Alias '$a' for '$name' already exists, skipping alias"
      } else {
        lappend clean $a
      }
    }
    tdict set node aliases [tlist create {*}$clean]

    _register_at $node $parent $is_custom $source
  }

  # Used to manually register aliases in the aliase dict; 
  # allows us to register alias <TOOL> -> TOOL.<TOOL>
  proc AddAlias {alias canon} {
    variable alias_index
    variable nodes
    if {![dict exists $nodes $canon]} {
      Msg Warning "AddAlias: '$canon' does not exist, skipping alias '$alias'"
      return
    }
    set key [string toupper $alias]
    if {[set why [_veto $key]] ne ""} {
      Msg Warning "Alias '$alias' for '$canon' rejected: $why"
      return
    }
    if {[dict exists $alias_index $key]} {
      if {[dict get $alias_index $key] ne $canon} {
        Msg Warning "Alias '$alias' already exists, skipping (wanted for '$canon')"
      }
      return
    }
    dict set alias_index $key $canon
  }

  # Sources a command file, which must call RegisterCommand;
  # sets the custom/source context so users don't have to
  proc RegisterCommandsFile {f args} {
    Hog::SourceFile $f [expr {"-custom" in $args}]
  }

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


  # Replace a node's content in-place (including aliases);
  proc UpdateCommand {key new_dict} {
    variable nodes
    variable alias_index
    set canon [string toupper $key]
    if {![dict exists $nodes $canon]} { set canon [_canon $canon] }
    if {$canon eq "" || ![dict exists $nodes $canon]} {
      Msg Warning "UpdateCommand: '$key' not found - use RegisterCommand to add new commands"
      return
    }
    set idx    [string last "." $canon]
    set bare   [expr {$idx < 0 ? $canon : [string range $canon [expr {$idx+1}] end]}]
    set parent [expr {$idx < 0 ? "" : [string range $canon 0 [expr {$idx-1}]]}]
    if {[catch {Node::New $bare $new_dict} node]} {
      Msg Warning "UpdateCommand: skipping '$canon': $node"
      return
    }
    set existing [dict get $nodes $canon]
    tdict set node custom      [tdict get $existing custom]
    tdict set node canon       [tdict get $existing canon]
    tdict set node source_path [tdict get $existing source_path]

    # Drop this node's old scoped aliases, then re-add whatever the new dict specifies.
    foreach k [dict keys $alias_index] {
      if {$k ne $canon && [dict get $alias_index $k] eq $canon} { dict unset alias_index $k }
    }
    set clean {}
    tlist foreachval a [tdict getval $node aliases] {
      set a_existing [expr {$parent eq "" ? [_canon $a] : [_canon_child $parent $a]}]
      if {[set why [_veto $a]] ne ""} {
        Msg Warning "Alias '$a' for '$bare' rejected: $why"
      } elseif {$a_existing ne "" && $a_existing ne $canon} {
        Msg Warning "Alias '$a' for '$bare' already exists, skipping alias"
      } else {
        lappend clean $a
      }
    }
    tdict set node aliases [tlist create {*}$clean]
    foreach a $clean {
      set a_key [expr {$parent eq "" ? $a : "$parent.$a"}]
      if {$a_key ne $canon} { dict set alias_index $a_key $canon }
    }

    dict set nodes $canon $node
  }

  # Remove a top-level command and recursively deregister everything under it.
  proc RemoveCommand {key} {
    variable nodes
    set canon [string toupper $key]
    if {![dict exists $nodes $canon]} { set canon [_canon $canon] }
    if {$canon eq "" || [string first "." $canon] >= 0 || ![dict exists $nodes $canon]} {
      Msg Warning "RemoveCommand: '$key' not found"
      return
    }
    _deregister $canon
  }


  proc AliasExists {alias} {
    variable alias_index
    return [dict exists $alias_index [string toupper $alias]]
  }

  proc Run {cmd} {
    set canon [_canon [string toupper $cmd]]
    if {$canon eq ""} { Msg Error "Unknown command '$cmd'"; return }
    variable nodes
    Node::Run [dict get $nodes $canon]
  }

  proc GetCommand {cmd} {
    variable nodes
    set canon [_canon [string toupper $cmd]]
    if {$canon eq "" || ![dict exists $nodes $canon]} { return {} }
    return [dict get $nodes $canon]
  }

  # The bare tool name a canon lives under
  proc _tool_of {canon} {
    if {[regexp {^TOOL\.([^.]+)\.} $canon -> bare]} { return $bare }
    return ""
  }

  # Every flow (in the same tool) whose own, unflattened 'stages' list names this stage directly - not via @ref 
  proc _flows_naming_stage {node} {
    set canon [tdict getval $node canon]
    if {![Node::IsStage $node]} { return {} }
    set stage_name [string toupper [tdict getval $node name]]
    set result {}
    foreach flow_canon [GetChildren "TOOL.[_tool_of $canon].FLOW"] {
      set fnode [GetCommand $flow_canon]
      if {$fnode eq {}} continue
      tlist foreachval s [tdict getobjor $fnode stages [tlist create]] {
        if {[string match "@*" $s]} continue
        if {[string toupper $s] eq $stage_name} { lappend result $fnode; break }
      }
    }
    return $result
  }

  # Accepts either a command name string or a resolved tdict node.
  # A node with stages inherits the options of every flow it @references, so this
  # flattens rather than reading the raw field - both RunRequest's cmdline parse
  # and the help page need the inherited set. A stage node has no @refs of its
  # own, but may still need options only a referencing flow declared
  proc GetCommandOptions {cmd_or_node} {
    if {[tobj isobj $cmd_or_node] && [tobj type $cmd_or_node] eq "Dict"} {
      set node $cmd_or_node
    } else {
      set node [GetCommand $cmd_or_node]
    }
    if {$node eq {}} { return {} }
    if {[Node::HasStages $node]} { return [Node::FlattenOptions $node] }

    set result {}
    set names  {}
    tlist foreachval o [tdict get $node options] {
      set n [lindex $o 0]
      if {$n ni $names} { lappend result $o; lappend names $n }
    }
    foreach fnode [_flows_naming_stage $node] {
      foreach spec [Node::FlattenOptions $fnode] {
        set n [lindex $spec 0]
        if {$n ni $names} { lappend result $spec; lappend names $n }
      }
    }
    return $result
  }

  # Returns canon -> tdict node for every command up to 'depth' levels deep
  # (1 = top-level only, 2 = top-level + their direct children, etc).
  proc GetCommands {{depth 1}} {
    variable nodes
    set result {}
    dict for {canon node} $nodes {
      if {[llength [split $canon "."]] <= $depth} { dict set result $canon $node }
    }
    return $result
  }

  # A stage name -> the proc that should implement it, resolved against the tool that *owns* the node.
  proc _owning_stage_proc {canon stage} {
    if {[string match "::*" $stage]} { return $stage }
    set tool_bare [_tool_of $canon]
    set snode     [GetCommand "TOOL.$tool_bare.STAGE.$stage"]
    if {$snode ne {}} { return [tdict getval $snode script] }
    set tool_ns [Tools::ResolveAlias [string tolower $tool_bare]]
    if {$tool_ns eq ""} { return "" }
    return ${tool_ns}::${stage}
  }

  # Reports declarations that contradict themselves, across the whole tree,
  # Warns and changes nothing; HOG_STRICT=1 makes it fail the run instead
  #
  # This is a *report*, not a constraint. Every check here answers "did you mean this?"
  #
  # Several of these conditions are also caught at run time i.e.:
  #   FlowControl::Run refuses an empty stage list
  #   StageProc aborts on a missing proc
  #
  # Returns the problem count.
  proc Lint {} {
    variable nodes
    set problems {}
    set seen_cycles {}

    dict for {canon node} $nodes {
      set children   [GetChildren $canon]
      set has_script [expr {[tdict getval $node script] ne ""}]
      set has_stages [Node::HasStages $node]
      set is_flow  [Node::IsFlow  $node]
      set is_stage [Node::IsStage $node]

      if {$has_script && $has_stages} {
        lappend problems "$canon declares both 'script' and 'stages'.\
          Node::Run branches on 'stages' first, so the script is dead code."
      }

      if {[tdict getval $node passthrough] && [llength $children] == 0} {
        lappend problems "$canon is 'passthrough true' but has no children.\
          The flag only changes how a following token is resolved against\
          children, so it does nothing here."
      }

      if {[Node::RequiresProj $node] && [llength $children] > 0 && \
          ![tdict getval $node passthrough]} {
        lappend problems "$canon requires a project and has children, but is not\
          'passthrough true'. Its project argument will be read as a subcommand\
          name and rejected."
      }

      if {$is_flow && ![Node::RequiresProj $node]} {
        lappend problems "$canon is a flow with 'requires_proj false'. Flows are\
          project-scoped by definition; this one cannot be reached as a flow."
      }

      # A declared stage's script is a proc name, so it is checkable. This is how
      # a typo in 2-arg 'RegisterStage DoNothing' gets caught - the node registers
      # happily and names a proc that was never defined.
      if {$is_stage} {
        set p [tdict getval $node script]
        if {$p ne "" && [info commands $p] eq ""} {
          lappend problems "$canon declares a stage backed by '$p', which is not\
            a defined proc. Two-arg RegisterStage names a proc the tool must\
            already define; three-arg RegisterStage defines it for you."
        }
      }

      if {$is_flow && !$has_stages} {
        lappend problems "$canon is a flow that declares no stages.\
          Running it would do nothing."
      }
      if {!$has_stages} continue

      set walk [Node::_walk_stages $node]

      # Only problems this node itself declared - every node is visited, so
      # filtering here reports each one once, against its author, instead of once
      # per flow that @references it.
      foreach bad [dict get $walk badrefs] {
        lassign $bad owner ref
        if {$owner ne $canon} continue
        lappend problems "$canon references unknown flow '$ref'. It will be\
          skipped, silently shortening the stage list."
      }

      foreach cyc [dict get $walk cycles] {
        lassign $cyc owner chain
        if {$owner ne $canon} continue
        # A cycle is discovered once from each participant (A->B->A is found
        # walking A *and* walking B), so key on the unordered set to name it once.
        set sig [lsort -unique [concat $chain $owner]]
        if {$sig in $seen_cycles} continue
        lappend seen_cycles $sig
        lappend problems "circular @reference: [join $chain { -> }] -> $owner.\
          Flattening survives it, but the stage list is not what was intended."
      }

      if {[llength [dict get $walk stages]] == 0} {
        lappend problems "$canon flattens to no stages - every stage it\
          @references is unresolvable. Running it will fail."
      }

      # Bare names only, checked where they are written rather than where they are
      # spliced in. A stage with its own STAGE node is checked above, at that node.
      tlist foreachval st [tdict getobjor $node stages [tlist create]] {
        if {[string match "@*" $st]} continue
        set tool_bare [_tool_of $canon]
        if {[GetCommand "TOOL.$tool_bare.STAGE.$st"] ne {}} continue
        set p [_owning_stage_proc $canon $st]
        if {$p eq "" || [info commands $p] eq ""} {
          lappend problems "$canon names stage '$st', which resolves to no proc\
            ([expr {$p eq "" ? "no tool owns '$tool_bare'" : "no proc $p"}])."
        }
      }
    }

    if {[llength $problems] == 0} { return 0 }

    set strict [expr {[info exists ::env(HOG_STRICT)] &&
                      $::env(HOG_STRICT) ni {"" 0 false no}}]
    foreach p $problems {
      Msg [expr {$strict ? "CriticalWarning" : "Warning"}] "Lint: $p"
    }
    if {$strict} {
      error "Commands::Lint found [llength $problems] problem(s) with HOG_STRICT set" \
        "" {HOG_LINT_FAILED}
    }
    return [llength $problems]
  }


  # Bare tool names (e.g. {VIVADO QUARTUS}) whose FLOW subtree holds the specified flow
  # Returns the bare tools name 
  proc ToolsWithFlow {name} {
    variable nodes
    set needle [string toupper $name]
    set result {}
    dict for {canon _n} $nodes {
      if {![regexp {^TOOL\.([^.]+)\.FLOW$} $canon -> tool_name]} { continue }
      if {[_canon_child $canon $needle] ne ""} { lappend result $tool_name }
    }
    return $result
  }

  # Every node, anywhere in the tree, that declares producing 'name' - the
  # reverse of a node's own 'produces' field. 
  # Used for cross-tool "who makes this" discovery and by 
  # FlowControl::_check_freshness to find an artifact's declared upstreams.
  # Returns list of stages
  proc ProducersOf {name} {
    variable nodes
    set result {}
    dict for {canon node} $nodes {
      if {[tlist elemExists [tdict getobjor $node produces [tlist create]] $name]} {
        lappend result $canon
      }
    }
    return $result
  }

  # Resolution

  # Walk argv_list through the command tree.
  # Returns: {node <tdict> path <list> remaining <list>} or {} on failure.
  proc ResolvePath {argv_list} {
    variable alias_index
    variable nodes
    if {[llength $argv_list] == 0} { return {} }

    set first [string toupper [lindex $argv_list 0]]
    set canon [_canon $first]
    if {$canon eq "" || ![dict exists $nodes $canon]} { return {} }

    set node      [dict get $nodes $canon]
    set path      [list [lindex $argv_list 0]]
    set remaining [lrange $argv_list 1 end]

    while {[llength [GetChildren $canon]] > 0 && [llength $remaining] > 0} {
      set token      [lindex $remaining 0]
      set next_canon [_canon_child $canon [string toupper $token]]
      if {$next_canon eq "" || ![dict exists $nodes $next_canon]} break
      set canon     $next_canon
      set node      [dict get $nodes $next_canon]
      lappend path  $token
      set remaining [lrange $remaining 1 end]
    }

    return [dict create node $node path $path remaining $remaining]
  }

  proc _strip_top {token} {
    return [string trimright [regsub {^(\./)?Top/} $token ""] "/ "]
  }

  proc ParseArgv {argv top_path} {
    if {[llength $argv] >= 2 && ![string match "-*" [lindex $argv 1]]} {
      set argv [lreplace $argv 1 1 [_strip_top [lindex $argv 1]]]
    }

    # Flow shorthand: <flow> <proj> -> <tool> <flow> <proj>, where <tool> is
    # whichever tool the project's hog.conf names.
    set directive [string toupper [lindex $argv 0]]
    if {$directive ne "" && ![AliasExists $directive] && [llength $argv] >= 2} {
      set proj [lindex $argv 1]
      if {[file exists [file join $top_path $proj hog.conf]]} {
        set tool [Tools::GetToolForProject $proj $top_path]
        if {$tool ne ""} {
          set tool_key [string toupper [namespace tail $tool]]
          if {[_canon_child "TOOL.$tool_key.FLOW" $directive] ne ""} {
            set argv [concat [list $tool_key FLOW $directive] [lrange $argv 1 end]]
          }
        }
      }
    }

    set directive [string toupper [lindex $argv 0]]
    set resolved  [ResolvePath $argv]
    if {[llength $resolved] > 0} {
      set node [dict get $resolved node]
      set path [dict get $resolved path]
      set rest [dict get $resolved remaining]
    } else {
      set node {}
      set path [list $directive]
      set rest [lrange $argv 1 end]
    }

    # Every leading non-flag leftover is a positional argument. Stop at the first
    # flag so option *values* ("-num 2") are never mistaken for positionals.
    # Index 0 is the project by convention - most commands want only that, but
    # multi-positional commands read the rest via Commands::Arg.
    set pargs {}
    while {[llength $rest] > 0 && ![string match "-*" [lindex $rest 0]]} {
      lappend pargs [lindex $rest 0]
      set rest      [lrange $rest 1 end]
    }
    set options $rest

    # args[0] is the project, so normalize it in place rather than keeping a raw
    # and a cooked copy that can disagree: "Top/example/" and "example" must look
    # identical to a command reading Commands::Arg 0.
    set project_name ""
    if {[llength $pargs] > 0} {
      set project_name [_strip_top [lindex $pargs 0]]
      set pargs        [lreplace $pargs 0 0 $project_name]
    }

    return [dict create \
      node         $node \
      typed_path   $path \
      args         $pargs \
      project      [file tail $project_name] \
      project_name $project_name \
      options      $options \
    ]
  }

  # True when the node's target ide is the process we're already in
  # (tclsh at top level, or the active tool inside a booted IDE).
  proc _InContext {ide} {
    set here [ActiveTool::CurrentTool]
    if {$ide eq "tclsh"} { return [expr {$here eq "tclsh"}] }
    return [expr {[Tools::ResolveAlias $ide] eq $here}]
  }

  # Run a resolved node inline in the current process.
  proc _RunInContext {node full_path} {
    cd [Repo::Get repo_path]
    set ide [tdict getval $node ide]
    if {$ide ne "tclsh"} {
      set ::DataStore::inIDE 1
      set tool [Tools::ResolveAlias $ide]
      Launcher::Set ide       $tool
      CurrentProject::Set ide $tool
      if {[info commands ${tool}::Initialize] ne ""} { ${tool}::Initialize }
    }
    Node::Run $node $full_path
  }

  # Decides ran/usage/boot for a resolved node. Runs it inline when its ide is
  # the current process; otherwise returns a boot verdict for the caller to launch the right IDE.
  proc Dispatch {node typed_path project} {
    set label     [join $typed_path { }]
    set full_path [expr {$project ne "" ? [concat $typed_path [list $project]] : $typed_path}]

    if {$node eq {}} {
      set directive [string toupper [lindex $typed_path 0]]
      set tools     [ToolsWithFlow $directive]
      if {[llength $tools] > 0} {
        return -code error "Flow '$directive' requires a project\
          (provided by [join [string tolower $tools] {, }]).\
          Usage: ./Hog/Do $directive <project>"
      }
      return -code error "Unknown directive '$directive'. Run './Hog/Do HELP' for usage."
    }

    set node_canon   [tdict getval $node canon]
    set has_children [expr {[llength [GetChildren $node_canon]] > 0}]
    set has_action   [Node::IsRunnable $node]

    if {$has_children && $project ne "" && ![tdict getval $node passthrough] && \
        [_canon_child $node_canon [string toupper $project]] eq ""} {
      return [list usage $typed_path "'$label' has no subcommand '[string toupper $project]'"]
    }

    if {!$has_action} {
      if {$has_children} { return [list help $typed_path] }
      return -code error "Command '$label' is not executable"
    }

    if {[tdict getval $node requires_proj] && $project eq ""} {
      return -code error "Command '$label' requires a project. Usage: ./Hog/Do [join $typed_path { }] <project>"
    }

    set ide [tdict getval $node ide]
    if {[_InContext $ide]} {
      _RunInContext $node $full_path
      return [list ran]
    }
    return [list boot $ide]
  }

  # Parse argv into a request and mirror it onto the Launcher DataStore.
  # Does not load projects or execute - callers own that ordering.
  proc Resolve {argv} {
    set directive [string toupper [lindex $argv 0]]
    set request   [ParseArgv $argv [Repo::Get top_path]]

    Launcher::Set directive    $directive
    Launcher::Set cmd          [expr {[dict get $request node] ne {} ? [tdict getval [dict get $request node] canon] : ""}]
    Launcher::Set full_cmd     [dict get $request typed_path]
    Launcher::Set args         [tlist createstr {*}[dict get $request args]]
    Launcher::Set project      [dict get $request project]
    Launcher::Set project_name [dict get $request project_name]

    # Raw, unparsed flags; RunRequest replaces this with the parsed tdict.
    Launcher::Set options      [tlist createstr {*}[dict get $request options]]
    return $request
  }

  # Validate + parse options + Dispatch a resolved request. Returns the verdict
  # (ran/boot/usage/help); throws on error. Never calls exit.
  proc RunRequest {request} {
    set node       [dict get $request node]
    set typed_path [dict get $request typed_path]
    set project    [dict get $request project]
    set raw_opts   [dict get $request options]

    if {"--help" in $raw_opts || "-help" in $raw_opts || "-h" in $raw_opts || "-?" in $raw_opts} {
      Help::RenderPath $typed_path
      return [list help]
    }

    if {$project ne "" && $node ne "" && [Node::RequiresProj $node]} {
      set _conf [file join [Repo::Get top_path] $project hog.conf]
      if {![file exists $_conf]} {
        return -code error "Project '$project' not found (no hog.conf at $_conf)."
      }
    }

    set opt_specs [GetCommandOptions $node]
    set options   $raw_opts
    array unset _parsed
    array set _parsed {}
    if {[llength $opt_specs] > 0} {
      if {[catch {array set _parsed [cmdline::getoptions options $opt_specs ""]} err]} {
        return -code error "Option error: $err"
      }
    }
    set _t [tdict create]
    foreach k [array names _parsed] { tdict set _t $k [tinf $_parsed($k)] }
    Launcher::Set options $_t

    set verdict [Dispatch $node $typed_path $project]
    switch -- [lindex $verdict 0] {
      ran { return $verdict }
      help {
        Help::RenderPath [lindex $verdict 1]
        return [list help]
      }
      usage {
        lassign $verdict _ path message
        Msg Warning $message
        catch { Help::RenderPath $path }
        return $verdict
      }
      boot {
        lassign $verdict _ ide
        Launcher::Set ide $ide
        Tools::Launch $ide
        # A tool with no real IDE binary flips itself active in this process
        # instead of spawning a child - if we're now in its context, re-dispatch
        # so it runs inline (a real IDE already ran it in the booted child).
        if {[_InContext $ide]} {
          return [RunRequest $request]
        }
        return $verdict
      }
      default { return -code error "Unexpected dispatch verdict: $verdict" }
    }
  }

  # JSON export

  proc ToJson {{flag {}}} {
    variable alias_index
    variable nodes
    set ai [tdict create]
    dict for {k v} $alias_index { tdict set ai $k [tstr $v] }
    set nd [tdict create]
    dict for {canon node} $nodes {
      # children isn't stored on the node - compute it here for export only.
      tdict set node children [tlist create {*}[GetChildren $canon]]
      tdict set nd $canon $node
    }
    set root [tdict create alias_index $ai nodes $nd]
    if {$flag eq "-pretty"} { return [tobj tojson $root -pretty] }
    return [tobj tojson $root]
  }

}
