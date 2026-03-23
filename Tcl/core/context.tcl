
# This will be used to maintain project context throughout the flow
# Tools can query this instead of having to pass around variabls
# basically just a wrapper around a dict, but will be used to 
# store and retrieve values in a more structured way.
#
# if we wanted to play nice with non tcl tools, maybe we implement faux "typing" 
# by requiring types when adding elements to the context
# for example: 
# Context::Set String LaunchSettings project_name "MyProject"
# Context::Set List   LaunchSettings sources [list "file1.v" "file2.v"]
#
# {
#  Launch Settings {
#   type { dict }
#   value {
#     project_name {type {String} value {"MyProject"}}
#     sources {type {list} value {{file1.v} {file2.v}}}
#   }
#  }
# }
#
# this would let us 'easily' export/import json for communication with other tools 


namespace eval Context {
  variable _ctx
  if {![info exists _ctx]} { set _ctx [dict create] }

  proc Clear {} {
    variable _ctx
    set _ctx [dict create]
    return $_ctx
  }

  proc Load {inputDict} {
    if {![_isDict $inputDict]} { error "ERR_INVALID_DICT" "" ERR_INVALID_DICT }
    variable _ctx
    set _ctx $inputDict
    return $_ctx
  }

  proc GetFullContext {} {
    _validate {} 0
    variable _ctx
    return $_ctx
  }

  proc Set {args} {
    _validate $args 2

    variable _ctx
    set value [lindex $args end]
    set keyPath [lrange $args 0 end-1]

    if {[catch {dict set _ctx {*}$keyPath $value}]} { error "ERR_TYPE_CONFLICT" "" ERR_TYPE_CONFLICT }
    return $value
  }

  proc Get {args} {
    _validate $args 1

    variable _ctx
    if {![dict exists $_ctx {*}$args]} { error "ERR_NOT_FOUND" "" ERR_NOT_FOUND }
    return [dict get $_ctx {*}$args]
  }

  proc GetOr {defaultValue args} {
    _validate $args 1

    variable _ctx
    if {[dict exists $_ctx {*}$args]} { return [dict get $_ctx {*}$args] }
    return $defaultValue
  }

  proc Has {args} {
    _validate $args 1

    variable _ctx
    return [dict exists $_ctx {*}$args]
  }

  proc Remove {args} {
    _validate $args 1

    variable _ctx
    if {[dict exists $_ctx {*}$args]} {
      dict unset _ctx {*}$args
      return 1
    }

    return 0
  }

  proc Append {args} {
    _validate $args 2

    variable _ctx
    set suffix [lindex $args end]
    set keyPath [lrange $args 0 end-1]

    if {[dict exists $_ctx {*}$keyPath]} {
      set current [dict get $_ctx {*}$keyPath]
    } else {
      set current ""
    }

    set updated "$current$suffix"
    if {[catch {dict set _ctx {*}$keyPath $updated}]} {
      error "ERR_TYPE_CONFLICT" "" ERR_TYPE_CONFLICT
    }
    return $updated
  }

  proc Lappend {args} {
    _validate $args 2

    variable _ctx
    set item [lindex $args end]
    set keyPath [lrange $args 0 end-1]

    if {[dict exists $_ctx {*}$keyPath]} {
      set current [dict get $_ctx {*}$keyPath]
    } else {
      set current [list]
    }

    set updated [concat $current [list $item]]
    if {[catch {dict set _ctx {*}$keyPath $updated}]} {
      error "ERR_TYPE_CONFLICT" "" ERR_TYPE_CONFLICT
    }
    return $updated
  }

  proc Merge {inputDict} {
    if {![_isDict $inputDict]} { error "ERR_INVALID_DICT" "" ERR_INVALID_DICT }
    _validate {} 0

    variable _ctx
    set _ctx [dict merge $_ctx $inputDict]
    return $_ctx
  }

  proc Size {} {
    _validate {} 0

    variable _ctx
    return [dict size $_ctx]
  }

  proc Keys {args} {
    _validate {} 0

    variable _ctx

    if {[llength $args] == 0} { return [dict keys $_ctx] }

    if {![dict exists $_ctx {*}$args]} { return [list] }

    set value [dict get $_ctx {*}$args]
    if {[catch {dict keys $value} keys]} { error "ERR_NOT_A_DICT" "" ERR_NOT_A_DICT }

    return $keys
  }
  
  proc SaveToFile {filename {overwrite false}} {
    variable _ctx

    # check if file exists

    if {![file exists $filename]} {
      set fileId [open $filename "w"]
    } elseif {$overwrite} {
      set fileId [open $filename "w"]
    } else {
      error "ERR_FILE_EXISTS" "" ERR_FILE_EXISTS
    }

    puts $fileId "$_ctx"
    close $fileId
  }

  proc LoadFromFile {filename} {
    if {![file exists $filename]} { error "ERR_FILE_NOT_FOUND" "" ERR_FILE_NOT_FOUND }

    set fileId [open $filename "r"]
    set fileContent [read $fileId]
    close $fileId

    if {![_isDict $fileContent]} { error "ERR_INVALID_DICT" "" ERR_INVALID_DICT }

    variable _ctx
    set _ctx $fileContent
    return $_ctx
  }


  proc _isDict {value} { 
    return [expr {![catch {dict size $value}]}] 
  }

  proc _ctxValid {} {
    variable _ctx
    return [_isDict $_ctx]
  }

  proc _validate {args {minArgs 0} {checkCtx 1}} {
    if {[llength $args] < $minArgs} { error "not enough arguments" "" ERR_INVALID_ARGS }
    if {$checkCtx && ![_ctxValid]} { error "invalid context" "" ERR_INVALID_CONTEXT }
  }
}
