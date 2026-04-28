
namespace eval Flow {
  # _registry shape:
  #   aliases -> tdict: <alias> -> tdict { <tool_ns> -> flow_name }
  #   tools -> tdict:
  #     <tool_ns> -> tdict:
  #       flows   -> tdict:
  #         <flow> -> tdict:
  #           aliases     -> tlist
  #           stages      -> tlist
  #           description -> tstring
  #           options     -> tlist
  
  variable _registry
  if {![info exists _registry]} {
    set _registry [tdict create aliases [tdict create] tools [tdict create]]
  }

  variable _fields {
    { name        ""     optional}
    { stages      ""     required}

    { aliases     ""     optional}
    { description ""     optional}
    { options     ""     optional}
  }


  proc _valid_alias {tool alias} {
    variable _registry
    if {$alias eq ""} { return 0 }
    if {[tdict exists $_registry aliases $alias $tool]} { return 0 }
    return 1
  }

  proc _validate_flow {key raw_dict} {
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
        } else {
          dict set result name $key
        }
        continue
      }
      if {[dict exists $raw_dict $fname]} {
        dict set result $fname [dict get $raw_dict $fname]
      } elseif {$frequired eq "required"} {
        error "Flow '$name': missing required field '$fname'"
      } else {
        dict set result $fname $fdefault
      }
    }
    return $result
  }

  proc RegisterCustomFlows {flow_dir} {
    if {![file isdirectory $flow_dir]} { return }

    foreach f [lsort [glob -nocomplain -directory $flow_dir *.tcl]] {
      unset -nocomplain ::custom_flows
      if {[catch {namespace eval :: [list source $f]} err]} {
        Msg Warning "failed to source [file tail $f]: $err"
        continue
      }
      if {![info exists ::custom_flows]} {
        Msg Warning "custom_flows variable not found in [file tail $f], skipping"
        continue
      }
      if {[catch {dict size $::custom_flows}]} {
        Msg Warning "custom_flows is not a dictionary in [file tail $f]"
        continue
      }
      dict for {custom_tool flows} $::custom_flows {
        if {![regexp -nocase "::Tools::$custom_tool" [namespace children ::Tools] tool_ns]} {
          Msg Warning "Could not find tool '$custom_tool' for custom flow in [file tail $f], skipping"
          continue
        }
        RegisterFlowDict $tool_ns $flows
      }
    }
  }

  proc RegisterFlow {tool_ns key raw_dict} {
    variable _registry

    if {[catch {_validate_flow $key $raw_dict} validated]} {
      Msg Warning "Skipping flow '$key' in tool '$tool_ns': $validated"
      return
    }

    if {![tdict exists $_registry tools $tool_ns]} {
      tdict set _registry tools $tool_ns [tdict create flows [tdict create]]
    }

    set name [string toupper [dict get $validated name]]

    if {![_valid_alias $tool_ns $name]} {
      Msg Warning "Flow '$name' in tool '$tool_ns' is not valid or already exists as an alias, skipping"
      return
    }

    set aliases [list]
    foreach alias [dict get $validated aliases] {
      set alias [string toupper $alias]
      if {[_valid_alias $tool_ns $alias]} {
        lappend aliases $alias
      } else {
        Msg Warning "Alias '$alias' for flow '$name' in tool '$tool_ns' is not valid or already exists, skipping"
      }
    }

    tdict set _registry tools $tool_ns flows $name [tdict create \
      name        [tstr $name] \
      tool        [tstr $tool_ns] \
      aliases     [tlist create {*}$aliases] \
      stages      [tlist create {*}[dict get $validated stages]] \
      description [tstr [dict get $validated description]] \
      options     [tlist create {*}[dict get $validated options]] \
    ]

    foreach alias "$name $aliases" {
      if {![tdict exists $_registry aliases $alias]} {
        tdict set _registry aliases $alias [tdict create]
      }
      tdict set _registry aliases $alias $tool_ns [tstr $name]
    }
  }

  proc RegisterFlowDict {tool_ns flows_dict} {
    dict for {name raw} $flows_dict {
      RegisterFlow $tool_ns $name $raw
    }
  }



  proc _flatten_options {tool flow} {
    variable _registry

    if {![tdict exists $_registry aliases $flow $tool]} { return {} }
    set resolved [tobj value [tdict get $_registry aliases $flow $tool]]
    if {![tdict exists $_registry tools $tool flows $resolved]} { return {} }

    set result {}
    set seen   {}

    tlist foreach opt_tobj [tdict get $_registry tools $tool flows $resolved options] {
      set spec     [tobj value $opt_tobj]
      set opt_name [lindex $spec 0]
      if {$opt_name ni $seen} {
        lappend result $spec
        lappend seen   $opt_name
      }
    }

    tlist foreach stage [tdict get $_registry tools $tool flows $resolved stages] {
      set sname [tobj value $stage]
      if {[string match "@*" $sname]} {
        foreach spec [_flatten_options $tool [string range $sname 1 end]] {
          set opt_name [lindex $spec 0]
          if {$opt_name ni $seen} {
            lappend result $spec
            lappend seen   $opt_name
          }
        }
      }
    }
    return $result
  }

  proc _flatten_stages {tool flow} {
    variable _registry

    if {![tdict exists $_registry aliases $flow $tool]} {
      Msg Warning "Flow or alias '$flow' not found for tool '$tool'"
      return {}
    }
    set resolved [tobj value [tdict get $_registry aliases $flow $tool]]

    if {![tdict exists $_registry tools $tool flows $resolved]} {
      Msg Warning "Flow '$resolved' not found for tool '$tool'"
      return {}
    }

    set result {}
    tlist foreach stage [tdict get $_registry tools $tool flows $resolved stages] {
      set name [tobj value $stage]
      if {[string match "@*" $name]} {
        lappend result {*}[_flatten_stages $tool [string range $name 1 end]]
      } else {
        lappend result $name
      }
    }
    return $result
  }


  proc GetFlows {alias} {
    variable _registry
    if {![tdict exists $_registry aliases $alias]} { return [tlist create] }
    set result [tlist create]
    tdict for {tool_ns _unused} [tdict get $_registry aliases $alias] {
      set flow [GetFlow $tool_ns $alias]
      tdict set flow tool [tstr $tool_ns]
      tlist append result $flow
    }
    return $result
  }

  proc AliasExists {alias} {
    variable _registry
    return [tdict exists $_registry aliases $alias]
  }

  proc AliasExistsForTool {alias tool} {
    variable _registry
    return [tdict exists $_registry aliases $alias $tool]
  }

  proc GetFlowStages {tool flow} {
    variable _registry
    if {![tdict exists $_registry tools $tool]} {
      Msg Warning "Tool '$tool' not found in registry"
      return {}
    }
    return [_flatten_stages $tool $flow]
  }

  proc GetFlowOptions {tool flow} {
    variable _registry
    if {![tdict exists $_registry tools $tool]} {
      Msg Warning "Tool '$tool' not found in registry"
      return {}
    }
    return [_flatten_options $tool $flow]
  }

  proc GetToolFlows {tool_ns} {
    variable _registry
    if {![tdict exists $_registry tools $tool_ns flows]} { return [tdict create] }
    return [tdict get $_registry tools $tool_ns flows]
  }

  proc GetFlow {tool_ns alias} {
    variable _registry
    set alias [string toupper $alias]
    if {![tdict exists $_registry aliases $alias $tool_ns]} { return [tdict create] }
    set flow_name [tobj value [tdict get $_registry aliases $alias $tool_ns]]
    if {![tdict exists $_registry tools $tool_ns flows $flow_name]} { return [tdict create] }
    return [tdict get $_registry tools $tool_ns flows $flow_name]
  }
  


  proc Run {flow} {
    set tool [ActiveTool::CurrentTool]
    set _flow_name [tdict getval [GetFlow $tool $flow] name]

    FlowControl::Run [GetFlowStages $tool $flow] $_flow_name
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

  proc Produce {args} {
    variable _state
    set tok [_tokens]
    foreach token $args {
      if {$token ni $tok} { lappend tok $token }
    }
    tdict set _state tokens [tlist create {*}$tok]
  }

  proc Require {args} {
    variable _state
    set tok [_tokens]
    set stg [tdict getval $_state stage]
    foreach token $args {
      if {$token ni $tok} {
        tdict set _state status abort
        tdict set _state reason "Required token '$token' not found while executing proc [lindex [info level -1] 0]. "

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
  }

  proc RequireOr {token script} {
    variable _state
    set tok [_tokens]
    set stg [tdict getval $_state stage]
    if {$token ni $tok} {
      uplevel 1 "${script}\nFlowControl::Require $token"
    } 
  }

  proc Has {args} {
    set tok [_tokens]
    foreach token $args {
      if {$token ni $tok} { return 0 }
    }
    return 1
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
    tdict set _state stages [tlist create {*}$stages]
    tdict set _state status [tstr continue]
    tdict set _state reason [tstr ""]
    set _i 0

    Msg Info "Running flow $flow: $stages"

    while {$_i < [llength [_stages]]} {
      set stage [lindex [_stages] $_i]
      tdict set _state stage [tstr $stage]
      set prev [_stages]

      if {[string match "::*" $stage]} {
        $stage
      } else {
        if {[ActiveTool::Has @PRE_$stage]}  { ActiveTool::@PRE_$stage  }
        ActiveTool::$stage
        if {[ActiveTool::Has @POST_$stage]} { ActiveTool::@POST_$stage }
      }

      if {[_stages] ne $prev} {
        Msg Info "Flow $flow updated: [_stages]"
      }

      set status [tdict getval $_state status]
      set reason [tdict getval $_state reason]
      switch $status {
        abort {
          Msg Error "Flow $flow aborted at '$stage': $reason"
          return -code error $reason
        }
        exit {
          if {$reason ne ""} { Msg Info "Flow $flow exiting after '$stage': $reason" }
          return
        }
      }

      incr _i
    }
  }

}
