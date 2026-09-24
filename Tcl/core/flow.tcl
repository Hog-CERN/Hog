
namespace eval Flow {

  # A top-level command may NOT claim any of these
  # names/aliases, even if no flow currently uses them — this protects the core
  # project workflow from being shadowed by a stray command.
  variable ReservedFlowNames {
    CREATE CREATEWORKFLOW WORKFLOW
    SYNTHESIS SYNTH IMPLEMENTATION IMPL IMPLEMENT
    SIMULATION SIMULATE BITSTREAM
  }

  foreach _reserved_name $Flow::ReservedFlowNames {
    Commands::AddNameGuard $_reserved_name \
      "'$_reserved_name' is a reserved project-flow verb; a top-level command\
        would shadow the same-named flow on every tool. Rename it, or reach\
        the flow via 'tool <tool> flow $_reserved_name <project>'."
  }
  unset _reserved_name



  # Registers a flow for 'tool' (name/alias or namespace) as the command node <TOOL>.FLOW.<NAME>.
  proc RegisterFlow {tool key raw_dict args} {
    set tool_ns [expr {[namespace exists $tool] ? $tool : [Tools::ResolveAlias $tool]}]
    if {$tool_ns eq ""} {
      Msg Warning "Skipping flow '$key': unknown tool '$tool'"
      return
    }
    set tool_key   [string toupper [namespace tail $tool_ns]]
    set tool_short [string tolower [namespace tail $tool_ns]]

    set norm {}
    dict for {k v} $raw_dict { dict set norm [string tolower $k] $v }
    set raw_dict $norm

    dict set raw_dict requires_proj true
    dict set raw_dict ide           $tool_short

    set flow_group "TOOL.$tool_key.FLOW"
    if {[Commands::GetCommand $flow_group] eq {}} {
      Commands::RegisterCommand $flow_group [dict create description \
        "Flows provided by [namespace tail $tool_ns].\
         Usage: $tool_short flow <flow> <project>"]
    }
    Commands::RegisterCommand "TOOL.$tool_key.FLOW.[string toupper $key]" $raw_dict {*}$args
  }

  proc RegisterCustomFlows {flow_dir} {
    if {![file isdirectory $flow_dir]} { return }
    foreach f [lsort [glob -nocomplain -directory $flow_dir *.tcl]] {
      Hog::SourceFile $f 1
    }
  }

}


# File-backed store for whatever FlowControl::Produce records while a stage
# runs. One file per name, holding a bare Tcl dict
# stored in Project/<Project>/.hog/tokens/
# {
#   producer <>
#   describe <>
#   mtime <>
#   path <>
#   file_mtime <>
# }
#
# path and file_mtime only exist if the token is backed by a file generated elsewhere
namespace eval Artifact {

  # "" when no project is current - callers must treat that as "no store".
  proc _dir {} {
    if {![CurrentProject::Exists project_name]} { return "" }
    return [file join [CurrentProject::Get build_dir] .hog tokens]
  }

  proc Write {name record} {
    set dir [_dir]
    if {$dir eq ""} {
      Msg Warning "Artifact::Write $name: no project is current, nothing persisted"
      return
    }
    file mkdir $dir
    set fh [open [file join $dir "$name.tcl"] w]
    puts $fh $record
    close $fh
  }

  proc Read {name} {
    set dir [_dir]
    if {$dir eq ""} { return {} }
    set path [file join $dir "$name.tcl"]
    if {![file exists $path]} { return {} }
    set fh [open $path r]
    set record [read $fh]
    close $fh
    return $record
  }

  proc Exists {name} {
    set dir [_dir]
    if {$dir eq ""} { return 0 }
    return [file exists [file join $dir "$name.tcl"]]
  }

  proc Remove {name} {
    set dir [_dir]
    if {$dir eq ""} { return }
    file delete -force [file join $dir "$name.tcl"]
  }
}

namespace eval FlowControl {
  variable _state
  if {![info exists _state]} {
    set _state [tdict create \
      stages [tlist create]  \
      status [tstr continue] \
      reason [tstr ""]       \
      tokens [tlist create]  \
      stage  [tstr ""]       \
    ]
  }
  variable _i 0

  proc _stages {} {
    variable _state
    set r {}
    tlist foreachval s [tdict get $_state stages] { lappend r $s }
    return $r
  }
  proc _set_stages {lst} {
    variable _state
    tdict set _state stages [tlist create {*}$lst]
  }
  proc _tokens {} {
    variable _state
    set r {}
    tlist foreachval t [tdict get $_state tokens] { lappend r $t }
    return $r
  }


  ################################################################################ 
  # Stage Dependency Management
  ################################################################################ 

  # True only while a real stage is running (inside Run's loop):
  # gates artifacts from being stored without a current project or from within a stage
  proc _stage_context {} {
    variable _state
    return [expr {[tdict getval $_state stage] ne "" && [CurrentProject::Exists project_name]}]
  }

  # Creates a persitant artifact
  # 'mtime' is call-time ([clock seconds])
  #   - used for cross token comparisions
  # 'file_mtime' is the payload's own filesystem mtime at write time, 
  #   - used only to detect an out of hog modification
  proc _persist {name path} {
    variable _state
    set producer [StageProc [tdict getval $_state stage]]
    if {$producer eq ""} { set producer [tdict getval $_state stage] }
    set record [dict create producer $producer describe [Repo::Get Tag] mtime [clock seconds]]
    if {$path ne ""} {
      if {![file exists $path]} {
        return -code error "Produce $name: no file at '$path' - the stage claimed to have\
          written it, but it isn't there."
      }
      dict set record path       $path
      dict set record file_mtime [file mtime $path]
    }
    Artifact::Write $name $record
  }

  # Walks the whole ancestor chain (each producer's declared 'requires'); Warns only;
  proc _check_freshness {name {_seen {}}} {
    if {$name in $_seen} { return }
    lappend _seen $name
    set record [Artifact::Read $name]
    if {[dict size $record] == 0} { return }
    set my_mtime [dict get $record mtime]
    foreach producer_canon [Commands::ProducersOf $name] {
      set pnode [Commands::GetCommand $producer_canon]
      if {$pnode eq {}} continue
      set upstream [tdict getobjor $pnode requires [tlist create]]
      tlist foreachval up_name $upstream {
        set up_record [Artifact::Read $up_name]
        # A required artifact that was never produced is normal (conditional
        # artifacts), not something to warn about.
        if {[dict size $up_record] == 0} continue
        if {[dict get $up_record mtime] > $my_mtime} {
          Msg Warning "'$name' (produced by $producer_canon) is older than '$up_name',\
            which it requires - '$up_name' was produced more recently. Consider rebuilding\
            '$name'."
        }
        _check_freshness $up_name $_seen
      }
    }
  }

  # Produce name ?path? - given a path, always persists (the artifact is the
  # payload). Given none, it's a plain in-memory token that never persists on
  # its own - a per-process fact (e.g. VIVADO_INITIALIZED) must not leak into
  # a later process via a stale record.
  proc Produce {name {path {}}} {
    variable _state
    set tok [_tokens]
    if {$name ni $tok} {
      lappend tok $name
      tdict set _state tokens [tlist create {*}$tok]
    }
    if {$path ne "" && [_stage_context]} { _persist $name $path }
  }

  # Opt-in for a bare token that's a durable fact about the filesystem, not
  # the live interpreter, and should be checkable from a later process.
  proc ProducePersistent {name} {
    Produce $name
    if {[_stage_context]} { _persist $name {} }
  }

  # The membership check Require/RequireOr delegate to: in-memory list first,
  # then - if stage-attributed - the on-disk store. A stale record (file
  # gone, or its mtime changed since recorded) is dropped and reported absent.
  proc Has {args} {
    variable _state
    set tok [_tokens]
    set can_check_disk [_stage_context]
    foreach token $args {
      if {$token in $tok} { continue }
      if {!$can_check_disk || ![Artifact::Exists $token]} { return 0 }
      set record [Artifact::Read $token]
      if {[dict exists $record path]} {
        set path [dict get $record path]
        if {![file exists $path]} {
          Msg Warning "Artifact '$token' was recorded (by [dict get $record producer]) but its\
            file is missing: $path - dropping the stale record."
          Artifact::Remove $token
          return 0
        }
        if {[dict exists $record file_mtime] && [file mtime $path] != [dict get $record file_mtime]} {
          Msg Warning "Artifact '$token' at $path has changed on disk since it was recorded (by\
            [dict get $record producer]) - dropping the stale record."
          Artifact::Remove $token
          return 0
        }
      }
      _check_freshness $token
    }
    return 1
  }

  proc Require {args} {
    variable _state
    foreach token $args {
      if {[Has $token]} continue
      set producers [Commands::ProducersOf $token]
      set by [expr {[llength $producers] > 0 ? " (produced by [join $producers {, }])" : ""}]
      tdict set _state status abort
      tdict set _state reason "Required token '$token' not found$by while executing proc [lindex [info level -1] 0]. "

      set _flow_run_level -1
      for {set i 1} {$i < [info level]} {incr i} {
        if {[lindex [info level $i] 0] eq "FlowControl::Run"} {
          set _flow_run_level $i
          break
        }
      }

      if {$_flow_run_level < 0} {
        Msg Warning "Require called outside of FlowControl::Run. Don't know what to do... returning..."
        return
      }
      return -level [expr {[info level] - $_flow_run_level}]
    }
  }

  proc RequireOr {token script} {
    if {![Has $token]} {
      uplevel 1 "${script}\nFlowControl::Require $token"
    }
  }

  # On-disk path of a produced artifact - "" if none was recorded.
  proc ArtifactPath {name} {
    set record [Artifact::Read $name]
    if {![dict exists $record path]} { return "" }
    return [dict get $record path]
  }

  proc ClearTokens {} {
    variable _state
    tdict set _state tokens [tlist create]
  }

  ################################################################################ 
  # Flow Control Management
  ################################################################################ 

  proc AppendStages {new} {
    set stages [_stages]
    lappend stages {*}$new
    _set_stages $stages
  }

  proc InsertStagesAfter {anchor new} {
    set stages [_stages]
    set idx [lsearch -exact $stages $anchor]
    if {$idx >= 0} {
      set stages [linsert $stages [expr {$idx + 1}] {*}$new]
    } else {
      Msg Warning "FlowControl InsertStagesAfter: '$anchor' not found... skipping..."
    }
    _set_stages $stages
  }

  proc InsertStagesBefore {anchor new} {
    set stages [_stages]
    set idx [lsearch -exact $stages $anchor]
    if {$idx >= 0} {
      set stages [linsert $stages $idx {*}$new]
    } else {
      Msg Warning "FlowControl InsertStagesBefore: '$anchor' not found... skipping..."
    }
    _set_stages $stages
  }

  proc InsertStages {new} {
    variable _i
    set stages [_stages]
    _set_stages [linsert $stages [expr {$_i + 1}] {*}$new]
  }

  proc RemoveStages {to_remove} {
    set stages [_stages]
    foreach s $to_remove {
      set idx [lsearch -exact $stages $s]
      while {$idx >= 0} {
        set stages [lreplace $stages $idx $idx]
        set idx [lsearch -exact $stages $s]
      }
    }
    _set_stages $stages
  }

  proc ReplaceStage {old new_stages} {
    set stages [_stages]
    set idx [lsearch -exact $stages $old]
    if {$idx >= 0} {
      _set_stages [lreplace $stages $idx $idx {*}$new_stages]
    } else {
      Msg Warning "FlowControl ReplaceStage: '$old' not found"
    }
  }

  # Stage name -> fully-qualified proc. "::Foo::Bar" is used verbatim (cross-
  # tool stages); a bare name resolves against the <TOOL>.STAGE node if
  # registered (aliases, artifact contract), else a plain proc in the active
  # tool's namespace. Returns "" when there is no active tool to resolve against.
  proc StageProc {stage} {
    if {[string match "::*" $stage]} { return $stage }
    set tool_ns [ActiveTool::CurrentTool]
    if {$tool_ns eq "" || $tool_ns eq "tclsh"} { return "" }
    set node [Commands::GetCommand "TOOL.[string toupper [namespace tail $tool_ns]].STAGE.$stage"]
    if {$node ne {}} { return [tdict getval $node script] }
    return ${tool_ns}::${stage}
  }

  proc ClearRemaining {} {
    variable _i
    _set_stages [lrange [_stages] 0 $_i]
  }

  proc ExitFlow {{reason ""}} {
    variable _state
    tdict set _state status [tstr exit]
    tdict set _state reason [tstr $reason]
  }

  proc Run {stages flow} {
    variable _state
    variable _i

    # Catches a flow with no stages, or every @ref unresolved (FlattenStages
    # already warned) - otherwise the loop below just silently no-ops.
    if {[llength $stages] == 0} {
      Msg Error "Flow $flow has no stages to run - it either declares none, or\
        every stage it @references failed to resolve."
      return -code error "flow '$flow' has no stages"
    }

    tdict set _state stages [tlist create {*}$stages]
    tdict set _state status [tstr continue]
    tdict set _state reason [tstr ""]
    set _i 0

    Msg Info "Running flow $flow: $stages"

    while {$_i < [llength [_stages]]} {
      set stage [lindex [_stages] $_i]
      tdict set _state stage [tstr $stage]
      set prev [_stages]

      # Resolved per iteration - a stage may insert more stages, or a tool
      # may define its proc lazily.
      set _proc [StageProc $stage]
      if {$_proc eq "" || [info commands $_proc] eq ""} {
        tdict set _state status [tstr abort]
        tdict set _state reason [tstr "stage '$stage' has no implementation\
          ([expr {$_proc eq "" ? "no active tool to resolve it against" : "no proc $_proc"}])"]
      } else {
        set _ns [namespace qualifiers $_proc]
        if {[info commands ${_ns}::@PRE_$stage] ne ""}  { ${_ns}::@PRE_$stage }
        Msg Debug "Flow $flow: stage '$stage' -> $_proc"
        $_proc
        if {[info commands ${_ns}::@POST_$stage] ne ""} { ${_ns}::@POST_$stage }
      }

      if {[_stages] ne $prev} {
        Msg Info "Flow $flow updated: [_stages]"
      }

      set status [tdict getval $_state status]
      set reason [tdict getval $_state reason]
      switch $status {
        abort {
          tdict set _state stage [tstr ""]
          Msg Error "Flow $flow aborted at '$stage': $reason"
          return -code error $reason
        }
        exit {
          tdict set _state stage [tstr ""]
          if {$reason ne ""} { Msg Info "Flow $flow exiting after '$stage': $reason" }
          return
        }
      }

      incr _i
    }
    # Cleared here too, so a call between flows doesn't inherit this stage.
    tdict set _state stage [tstr ""]
  }

}
