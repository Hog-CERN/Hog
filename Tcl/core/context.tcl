
source [file join [file dirname [info script]] tobj.tcl]

namespace eval DataStore {
  variable _store_template {
    namespace eval @DS@ {
      variable _ctx
      if {![info exists _ctx]} { set _ctx [tdict create] }

      proc Clear {} {
        variable _ctx
        set _ctx [tdict create]
      }

      proc GetFullDataStore {} {
        variable _ctx
        return $_ctx
      }

      proc Load {tDictNode} {
        if {![tobj isobj $tDictNode] || [tobj type $tDictNode] ne "Dict"} {
          error "@DS@::Load: expected Dict tobj" "" {CTX_INVALID_ARGS}
        }
        variable _ctx
        set _ctx $tDictNode
      }

      proc SetStr {args} {
        if {[llength $args] < 2} { error "@DS@::SetStr: too few args" "" {CTX_INVALID_ARGS} }
        variable _ctx
        tdict set _ctx {*}[lrange $args 0 end-1] [tobj String [lindex $args end]]
      }

      proc SetNum {args} {
        if {[llength $args] < 2} { error "@DS@::SetNum: too few args" "" {CTX_INVALID_ARGS} }
        variable _ctx
        tdict set _ctx {*}[lrange $args 0 end-1] [tobj Number [lindex $args end]]
      }

      proc SetBool {args} {
        if {[llength $args] < 2} { error "@DS@::SetBool: too few args" "" {CTX_INVALID_ARGS} }
        variable _ctx
        tdict set _ctx {*}[lrange $args 0 end-1] [tobj Bool [lindex $args end]]
      }

      proc SetNull {args} {
        if {[llength $args] < 1} { error "@DS@::SetNull: too few args" "" {CTX_INVALID_ARGS} }
        variable _ctx
        tdict set _ctx {*}$args [tobj Null]
      }

      proc SetObj {args} {
        if {[llength $args] < 2} { error "@DS@::SetObj: too few args" "" {CTX_INVALID_ARGS} }
        variable _ctx
        tdict set _ctx {*}[lrange $args 0 end-1] [lindex $args end]
      }

      proc Set {args} {
        if {[llength $args] < 2} { error "@DS@::Set: too few args" "" {CTX_INVALID_ARGS} }
        variable _ctx
        tdict set _ctx {*}[lrange $args 0 end-1] [tinf [lindex $args end]]
      }
      
      proc Lappend {args} {
        if {[llength $args] < 2} { error "@DS@::Lappend: too few args" "" {CTX_INVALID_ARGS} }
        variable _ctx
        set tl [tdict get $_ctx {*}[lrange $args 0 end-1]]
        if {![tobj isobj $tl] || [tobj type $tl] ne "List"} {
          error "@DS@::Lappend: not a List node at path" "" {CTX_NOT_A_LIST}
        }

        if {![tobj isobj [lindex $args end]]} {
          error "@DS@::Lappend: expected tobj for value" "" {CTX_INVALID_ARGS}
        }

        tlist append tl [lindex $args end]
        tdict set _ctx {*}[lrange $args 0 end-1] $tl
      }



      proc GetObj {args} {
        if {[llength $args] < 1} { error "@DS@::GetObj: too few args" "" {CTX_INVALID_ARGS} }
        variable _ctx
        if {![tdict exists $_ctx {*}$args]} { error "@DS@::GetObj: key not found: $args" "" {CTX_NOT_FOUND} }
        return [tdict get $_ctx {*}$args]
      }

      proc GetObjOr {args} {
        if {[llength $args] < 2} { error "@DS@::GetObjOr: too few args" "" {CTX_INVALID_ARGS} }
        variable _ctx
        set keys [lrange $args 0 end-1]
        set defaultObj [lindex $args end]
        if {[tdict exists $_ctx {*}$keys]} {
          return [tdict get $_ctx {*}$keys]
        }
        return $defaultObj
      }

      proc Get {args} {
        if {[llength $args] < 1} { error "@DS@::Get: too few args" "" {CTX_INVALID_ARGS} }
        variable _ctx
        if {![tdict exists $_ctx {*}$args]} { error "@DS@::Get: key not found: $args" "" {CTX_NOT_FOUND} }
        return [tobj value [tdict get $_ctx {*}$args]]
      }

      proc GetOr {args} {
        if {[llength $args] < 2} { error "@DS@::GetOr: too few args" "" {CTX_INVALID_ARGS} }
        variable _ctx
        set keys [lrange $args 0 end-1]
        set defaultObj [lindex $args end]
        if {[tdict exists $_ctx {*}$keys]} {
          return [tobj value [tdict get $_ctx {*}$keys]]
        }
        return $defaultObj
      }

      proc Exists {args} {
        if {[llength $args] < 1} { error "@DS@::Exists: too few args" "" {CTX_INVALID_ARGS} }
        variable _ctx
        return [tdict exists $_ctx {*}$args]
      }

      proc Remove {args} {
        if {[llength $args] < 1} { error "@DS@::Remove: too few args" "" {CTX_INVALID_ARGS} }
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
          error "@DS@::Keys: not a Dict node at path" "" {CTX_NOT_A_DICT}
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
          error "@DS@::SaveJsonToFile: file exists" "" {CTX_FILE_EXISTS}
        }
        set fh [open $filename w]
        puts $fh $json
        close $fh
      }

      proc SaveToFile {filename {overwrite 0}} {
        variable _ctx
        if {[file exists $filename] && !$overwrite} {
          error "@DS@::SaveToFile: file exists" "" {CTX_FILE_EXISTS}
        }
        set fh [open $filename w]
        puts $fh $_ctx
        close $fh
      }

      proc LoadFromFile {filename} {
        if {![file exists $filename]} {
          error "@DS@::LoadFromFile: file not found" "" {CTX_FILE_NOT_FOUND}
        }
        set fh [open $filename r]
        set data [string trim [read $fh]]
        close $fh
        if {![tobj isobj $data] || [tobj type $data] ne "Dict"} {
          error "@DS@::LoadFromFile: invalid context data" "" {CTX_INVALID_DATA}
        }
        #TODO: import json
        variable _ctx
        set _ctx $data
      }
    }


  }


  variable inIDE 0
  variable _stores [list]
  proc create {name} {
    variable _store_template

    if {[namespace exists $name]} {
      error "DataStore::create: namespace '$name' already exists" "" {NS_ALREADY_EXISTS}
    }
    variable _stores
    lappend _stores $name
    set ds [string map [list @DS@ $name] $_store_template]
    uplevel #0 $ds
  }

  proc Serialize {} {
    variable _stores
    set root [tdict create]
    foreach name $_stores {
      if {[namespace exists ::${name}]} {
        tdict set root $name [${name}::GetFullDataStore]
      }
    }
    return $root
  }

  proc Deserialize {tDictRoot} {
    if {![tobj isobj $tDictRoot] || [tobj type $tDictRoot] ne "Dict"} {
      error "DataStore::Deserialize: expected Dict tobj" "" {CTX_INVALID_ARGS}
    }
    foreach name [tdict keys $tDictRoot] {
      puts "Deserializing context store '$name'"
      if {![namespace exists ::${name}]} { create $name }
      ${name}::Load [tdict get $tDictRoot $name]
    }
    

  }

  proc _OnError {cmd } {
    set root [Serialize]

    set exitCode [expr {[llength $cmd] > 1 ? [lindex $cmd 1] : 0}]
    set exitInfo [tdict create]
    tdict set exitInfo code [tobj Number $exitCode]
    if {$exitCode != 0} {
      tdict set exitInfo error_info [tobj String [expr {[info exists ::errorInfo] ? $::errorInfo : ""}]]
      tdict set exitInfo error_code [tobj String [expr {[info exists ::errorCode] ? $::errorCode : ""}]]
    }

    set locs [dict create]
    for {set i 1} {$i <= [info frame]} {incr i} {
      set f [info frame $i]
      if {[dict exists $f level] && [dict exists $f file]} {
        dict set locs [dict get $f level] "[file tail [dict get $f file]]:[dict get $f line]"
      }
    }
    set stack_frames [list]
    for {set i 1} {$i <= [info level]} {incr i} {
      set loc [expr {[dict exists $locs $i] ? [dict get $locs $i] : "?"}]
      lappend stack_frames "[info level $i] ($loc)"
    }
    tdict set exitInfo stack_trace [tlist create {*}$stack_frames]

    tdict set root _exit $exitInfo

    set json [tobj tojson $root -pretty]
    set filename [file join [Repo::GetOr repo_path . ] .hog_context_error.json]
    set fh [open $filename w]
    puts $fh $json
    close $fh
  }

  proc _OnExit {cmd op} {
    set root [Serialize]

    set exitCode [expr {[llength $cmd] > 1 ? [lindex $cmd 1] : 0}]
    set exitInfo [tdict create]
    tdict set exitInfo code [tobj Number $exitCode]
    if {$exitCode != 0} {
      tdict set exitInfo error_info [tobj String [expr {[info exists ::errorInfo] ? $::errorInfo : ""}]]
      tdict set exitInfo error_code [tobj String [expr {[info exists ::errorCode] ? $::errorCode : ""}]]
    }
    tdict set root _exit $exitInfo

    set json [tobj tojson $root -pretty]
    set filename [file join [Repo::GetOr repo_path . ] .hog_context_exit.json]
    set fh [open $filename w]
    puts $fh $json
    close $fh
  }


  trace add execution exit enter DataStore::_OnExit
}