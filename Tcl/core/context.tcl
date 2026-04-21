
source [file join [file dirname [info script]] tobj.tcl]
namespace eval Context {
  variable _ctx
  if {![info exists _ctx]} { set _ctx [tdict create] }

  proc Clear {} {
    variable _ctx
    set _ctx [tdict create]
  }

  proc GetFullContext {} {
    variable _ctx
    return $_ctx
  }

  proc Load {tDictNode} {
    if {![tobj isobj $tDictNode] || [tobj type $tDictNode] ne "Dict"} {
      error "Context::Load: expected Dict tobj" "" {CTX_INVALID_ARGS}
    }
    variable _ctx
    set _ctx $tDictNode
  }

  proc SetStr {args} {
    if {[llength $args] < 2} { error "Context::SetStr: too few args" "" {CTX_INVALID_ARGS} }
    variable _ctx
    tdict set _ctx {*}[lrange $args 0 end-1] [tobj String [lindex $args end]]
  }

  proc SetNum {args} {
    if {[llength $args] < 2} { error "Context::SetNum: too few args" "" {CTX_INVALID_ARGS} }
    variable _ctx
    tdict set _ctx {*}[lrange $args 0 end-1] [tobj Number [lindex $args end]]
  }

  proc SetBool {args} {
    if {[llength $args] < 2} { error "Context::SetBool: too few args" "" {CTX_INVALID_ARGS} }
    variable _ctx
    tdict set _ctx {*}[lrange $args 0 end-1] [tobj Bool [lindex $args end]]
  }

  proc SetNull {args} {
    if {[llength $args] < 1} { error "Context::SetNull: too few args" "" {CTX_INVALID_ARGS} }
    variable _ctx
    tdict set _ctx {*}$args [tobj Null]
  }

  proc SetObj {args} {
    if {[llength $args] < 2} { error "Context::SetObj: too few args" "" {CTX_INVALID_ARGS} }
    variable _ctx
    tdict set _ctx {*}[lrange $args 0 end-1] [lindex $args end]
  }

  proc Set {args} {
    if {[llength $args] < 2} { error "Context::Set: too few args" "" {CTX_INVALID_ARGS} }
    variable _ctx
    tdict set _ctx {*}[lrange $args 0 end-1] [tinf [lindex $args end]]
  }
  
  proc Lappend {args} {
    if {[llength $args] < 2} { error "Context::Lappend: too few args" "" {CTX_INVALID_ARGS} }
    variable _ctx
    set tl [tdict get $_ctx {*}[lrange $args 0 end-1]]
    if {![tobj isobj $tl] || [tobj type $tl] ne "List"} {
      error "Context::Lappend: not a List node at path" "" {CTX_NOT_A_LIST}
    }

    if {![tobj isobj [lindex $args end]]} {
      error "Context::Lappend: expected tobj for value" "" {CTX_INVALID_ARGS}
    }

    tlist append tl [lindex $args end]
    tdict set _ctx {*}[lrange $args 0 end-1] $tl
  }



  proc GetObj {args} {
    if {[llength $args] < 1} { error "Context::GetObj: too few args" "" {CTX_INVALID_ARGS} }
    variable _ctx
    if {![tdict exists $_ctx {*}$args]} { error "Context::GetObj: key not found" "" {CTX_NOT_FOUND} }
    return [tdict get $_ctx {*}$args]
  }

  proc GetObjOr {defaultObj args} {
    variable _ctx
    if {[llength $args] >= 1 && [tdict exists $_ctx {*}$args]} {
      return [tdict get $_ctx {*}$args]
    }
    return $defaultObj
  }

  proc Get {args} {
    if {[llength $args] < 1} { error "Context::Get: too few args" "" {CTX_INVALID_ARGS} }
    variable _ctx
    if {![tdict exists $_ctx {*}$args]} { error "Context::Get: key not found" "" {CTX_NOT_FOUND} }
    return [tobj value [tdict get $_ctx {*}$args]]
  }

  proc GetOr {defaultObj args} {
    variable _ctx
    if {[llength $args] >= 1 && [tdict exists $_ctx {*}$args]} {
      return [tobj value [tdict get $_ctx {*}$args]]
    }
    return $defaultObj
  }

  proc Has {args} {
    if {[llength $args] < 1} { error "Context::Has: too few args" "" {CTX_INVALID_ARGS} }
    variable _ctx
    return [tdict exists $_ctx {*}$args]
  }

  proc Remove {args} {
    if {[llength $args] < 1} { error "Context::Remove: too few args" "" {CTX_INVALID_ARGS} }
    variable _ctx
    if {![tdict exists $_ctx {*}$args]} { return 0 }
    tdict remove _ctx {*}$args
    return 1
  }

  proc Size {} {
    variable _ctx
    return [tdict size _ctx]
  }

  proc Keys {args} {
    variable _ctx
    if {[llength $args] == 0} { return [tdict keys $_ctx] }
    if {![tdict exists $_ctx {*}$args]} { return {} }
    set sub [tdict get $_ctx {*}$args]
    if {![tobj isobj $sub] || [tobj type $sub] ne "Dict"} {
      error "Context::Keys: not a Dict node at path" "" {CTX_NOT_A_DICT}
    }
    return [dict keys [tobj value $sub]]
  }

  proc ToJson {{flag {}}} {
    variable _ctx
    if {$flag eq "-pretty"} { return [tobj tojson $_ctx -pretty] }
    return [tobj tojson $_ctx]
  }

  proc SaveJsonToFile {filename {overwrite 0}} {
    variable _ctx
    set json [ToJson -pretty]
     if {[file exists $filename] && !$overwrite} {
      error "Context::SaveJsonToFile: file exists" "" {CTX_FILE_EXISTS}
    }
    set fh [open $filename w]
    puts $fh $json
    close $fh
  }

  proc SaveToFile {filename {overwrite 0}} {
    variable _ctx
    if {[file exists $filename] && !$overwrite} {
      error "Context::SaveToFile: file exists" "" {CTX_FILE_EXISTS}
    }
    set fh [open $filename w]
    puts $fh $_ctx
    close $fh
  }

  proc LoadFromFile {filename} {
    if {![file exists $filename]} {
      error "Context::LoadFromFile: file not found" "" {CTX_FILE_NOT_FOUND}
    }
    set fh [open $filename r]
    set data [string trim [read $fh]]
    close $fh
    if {![tobj isobj $data] || [tobj type $data] ne "Dict"} {
      error "Context::LoadFromFile: invalid context data" "" {CTX_INVALID_DATA}
    }
    #TODO: import json
    variable _ctx
    set _ctx $data
  }
}
