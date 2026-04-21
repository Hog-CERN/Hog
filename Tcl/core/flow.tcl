
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
    variable _registry
    set tool [ActiveTool::CurrentTool]

    puts "Stages: [GetFlowStages $tool $flow]"
    foreach stage [GetFlowStages $tool $flow] {
      if {[string match "::*" $stage]} {
        #TODO: add pre/post to this
        $stage
      } else {
        if {[ActiveTool::Has @PRE_$stage]} { ActiveTool::@PRE_$stage }
        ActiveTool::$stage
        #TODO add flow control
        if {[ActiveTool::Has @POST_$stage]} { ActiveTool::@POST_$stage }
      }
    }
  }


  ################################################################################
  ## Syncing with Context
  ################################################################################
  variable _loading 0

  proc _on_registry_write {varname index op} {
    variable _loading
    if {$_loading} return
    if {[llength [info commands ::Context::SetObj]] == 0} return
    ::Context::SetObj flow_registry $::Flow::_registry
  }

  proc _on_context_load {args} { 
    variable _registry
    variable _loading
    if {[catch {::Context::GetObj flow_registry} reg]} { return }
    set _loading 1
    set _registry $reg
    set _loading 0
  }

  trace add variable  ::Flow::_registry  write ::Flow::_on_registry_write
  #trace add execution ::Context::Load    leave ::Flow::_on_context_load
}
