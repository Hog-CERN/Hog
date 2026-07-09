
# Typed object storage
# wraps variables in a dict containing type and value
# allows us to export data in a json format

namespace eval tobj {
  variable _types_ {String Number Bool Null Dict List}

  proc isobj {value} {
    return [expr {
      ![catch {dict size $value}] &&
      [dict exists $value __t__] &&
      [dict exists $value __v__]
    }]
  }

  proc create {type value} {
    variable _types_
    if {$type ni $_types_} {
      error "tobj: unknown type '$type'" "" {INVALID_TOBJ_TYPE}
    }
    return [dict create __t__ $type __v__ $value]
  }

  proc type {obj} {
    if {![isobj $obj]} { error "tobj: not a tobj" "" {INVALID_TOBJ} }
    return [dict get $obj __t__]
  }

  proc typeIs {obj type} {
    if {![isobj $obj]} { error "tobj: not a tobj" "" {INVALID_TOBJ} }
    return [expr {[dict get $obj __t__] eq $type}]
  }

  proc value {obj} {
    if {![isobj $obj]} { error "tobj: not a tobj" "" {INVALID_TOBJ} }
    return [dict get $obj __v__]
  }

  proc tojson {node {arg {}}} {
    if {![isobj $node]} { error "tobj: not a tobj" "" {INVALID_TOBJ} }
    return [_tojson $node [expr {$arg eq "-pretty" ? 0 : -1}]]
  }

  proc _tojson {node indent} {
    set type   [dict get $node __t__]
    set value  [dict get $node __v__]
    set pretty [expr {$indent >= 0}]
    set pad    [expr {$pretty ? [string repeat "  " $indent]            : ""}]
    set pad1   [expr {$pretty ? [string repeat "  " [expr {$indent+1}]] : ""}]
    set sep    [expr {$pretty ? ",\n" : ", "}]
    set next   [expr {$pretty ? $indent+1 : -1}]
    switch $type {
      Dict {
        if {$pretty && [dict size $value] == 0} { return "{}" }
        set pairs {}
        dict for {k child} $value {
          lappend pairs "${pad1}\"[_escape $k]\": [_tojson $child $next]"
        }
        if {$pretty} { return "{\n[join $pairs $sep]\n${pad}}" }
        return "{[join $pairs {, }]}"
      }
      List {
        if {$pretty && [llength $value] == 0} { return "\[\]" }
        set items {}
        foreach item $value { lappend items "${pad1}[_tojson $item $next]" }
        if {$pretty} { return "\[\n[join $items $sep]\n${pad}\]" }
        return "\[[join $items {, }]\]"
      }
      Number  { return $value }
      Bool    { return [expr {$value ? "true" : "false"}] }
      Null    { return "null" }
      default { return "\"[_escape $value]\"" }
    }
  }

  proc _escape {str} {
    return [string map {
      "\\" "\\\\"  "\"" "\\\""
      "\n" "\\n"   "\r" "\\r"  "\t" "\\t"
    } $str]
  }

  proc String {value}  { create String $value }
  proc Number {value}  { create Number $value }
  proc Bool   {value}  { create Bool   $value }
  proc Null   {}       { create Null   {}     }

  # Convert any tobj to a plain Tcl string
  #   String/Number → string
  #   Bool          → 1 or 0
  #   Null          → {} (empty string)
  #   List          → Tcl list
  #   Dict          → Tcl dict
  proc native {obj} {
    if {![isobj $obj]} { error "tobj native: not a tobj" "" {INVALID_TOBJ} }
    switch [type $obj] {
      List    {
        set _r {}
        foreach item [value $obj] { lappend _r [native $item] }
        return $_r
      }
      Dict    {
        set result {}
        dict for {k v} [value $obj] { dict set result $k [native $v] }
        return $result
      }
      Bool    { return [expr {[value $obj] ? 1 : 0}] }
      Null    { return {} }
      default { return [value $obj] }
    }
  }

  namespace export create type typeIs value isobj tojson native String Number Bool Null
  namespace ensemble create
}

# shorthand: 
proc tstr  {v} { tobj create String $v }
proc tnum  {v} { tobj create Number $v }
proc tbool {v} { tobj create Bool   $v }
proc tnull {}  { tobj create Null   {} }
proc tval    {obj} { tobj value  $obj }
proc tnative {obj} { tobj native $obj }

proc tinf {value} {
  if {$value eq {} || $value eq {null}}      { return [tobj Null]          }
  if {$value eq {true} || $value eq {false}} { return [tobj Bool   $value] }
  if {[string is double -strict $value]}     { return [tobj Number $value] }
  return [tobj String $value]
}

proc tlinf {args} {
  set result {}
  ::foreach arg $args {
    lappend result [tinf $arg]
  }
  return $result
}
 
namespace eval tlist {

  proc create {args} {
    ::set nodes {}
    ::foreach node $args { ::lappend nodes [expr {[tobj isobj $node] ? $node : [tinf $node]}] }
    return [tobj create List $nodes]
  }

  proc append {listVar args} {
    upvar 1 $listVar lst
    if {![tobj isobj $lst]}         { error "tlist append: not a tobj"      "" {INVALID_TOBJ}      }
    if {[tobj type $lst] ne "List"} { error "tlist append: not a List node" "" {INVALID_TOBJ_LIST} }
    if {[llength $args] == 0}       { error "tlist append: no nodes given"  "" {INVALID_ARGS}      }
    set current [tobj value $lst]
    ::foreach node $args { ::lappend current [expr {[tobj isobj $node] ? $node : [tinf $node]}] }
    set lst [tobj create List $current]
  }

  proc get {listVar index} {
    upvar 1 $listVar lst
    if {![tobj isobj $lst]}         { error "tlist get: not a tobj"      "" {INVALID_TOBJ}      }
    if {[tobj type $lst] ne "List"} { error "tlist get: not a List node" "" {INVALID_TOBJ_LIST} }
    return [lindex [tobj value $lst] $index]
  }

  proc getval {lst index} {
    if {![tobj isobj $lst]}         { error "tlist getval: not a tobj"      "" {INVALID_TOBJ}      }
    if {[tobj type $lst] ne "List"} { error "tlist getval: not a List node" "" {INVALID_TOBJ_LIST} }
    set item [lindex [tobj value $lst] $index]
    set t [tobj type $item]
    if {$t eq "Dict" || $t eq "List"} { return $item }
    return [tobj value $item]
  }

  proc length {listVar} {
    upvar 1 $listVar lst
    if {![tobj isobj $lst]}         { error "tlist length: not a tobj"      "" {INVALID_TOBJ}      }
    if {[tobj type $lst] ne "List"} { error "tlist length: not a List node" "" {INVALID_TOBJ_LIST} }
    return [llength [tobj value $lst]]
  }

  proc remove {lst index} {
    if {![tobj isobj $lst]}         { error "tlist remove: not a tobj"      "" {INVALID_TOBJ}      }
    if {[tobj type $lst] ne "List"} { error "tlist remove: not a List node" "" {INVALID_TOBJ_LIST} }
    set current [tobj value $lst]
    set lst [tobj create List [lreplace $current $index $index]]
  }

  proc pop {listVar} {
    upvar 1 $listVar lst
    if {![tobj isobj $lst]}         { error "tlist pop: not a tobj"      "" {INVALID_TOBJ}      }
    if {[tobj type $lst] ne "List"} { error "tlist pop: not a List node" "" {INVALID_TOBJ_LIST} }
    set current [tobj value $lst]
    set popped [lindex $current end]
    set lst [tobj create List [lreplace $current end end]]
    return $popped
  }


  proc foreach {itemVar lst body} {
    if {![tobj isobj $lst]}         { error "tlist foreach: not a tobj"      "" {INVALID_TOBJ}      }
    if {[tobj type $lst] ne "List"} { error "tlist foreach: not a List node" "" {INVALID_TOBJ_LIST} }
    ::foreach item [tobj value $lst] {
      uplevel 1 [list set $itemVar $item]
      uplevel 1 $body
    }
  }

  proc foreachval {itemVar lst body} {
    if {![tobj isobj $lst]}         { error "tlist foreachval: not a tobj"      "" {INVALID_TOBJ}      }
    if {[tobj type $lst] ne "List"} { error "tlist foreachval: not a List node" "" {INVALID_TOBJ_LIST} }
    ::foreach item [tobj value $lst] {
      set _t [tobj type $item]
      uplevel 1 [list set $itemVar [expr {$_t eq "Dict" || $_t eq "List" ? $item : [tobj value $item]}]]
      uplevel 1 $body
    }
  }

  proc elemExists {lst value} {
    if {![tobj isobj $lst]}         { error "tlist elemExists: not a tobj"      "" {INVALID_TOBJ}      }
    if {[tobj type $lst] ne "List"} { error "tlist elemExists: not a List node" "" {INVALID_TOBJ_LIST} }
    ::foreach item [tobj value $lst] {
      set t [tobj type $item]
      if {$t ne "Dict" && $t ne "List" && [tobj value $item] eq $value} { return 1 }
    }
    return 0
  }

  proc index {lst value} {
    if {![tobj isobj $lst]}         { error "tlist index: not a tobj"      "" {INVALID_TOBJ}      }
    if {[tobj type $lst] ne "List"} { error "tlist index: not a List node" "" {INVALID_TOBJ_LIST} }
    set needle [expr {[tobj isobj $value] ? $value : [tinf $value]}]
    set i 0
    ::foreach item [tobj value $lst] {
      set t [tobj type $item]
      if {$t eq "Dict" || $t eq "List"} { continue }
      if {$t eq $needle} { return $i }
      incr i
    }
    return -1
  }

  namespace export create append get getval length remove pop foreach foreachval elemExists index
  namespace ensemble create
}

namespace eval tdict {

  # key (tobj) key (tobj)...
  proc create {args} {
    if {[llength $args] % 2 != 0} {
      error "tdict create: args must be key-tobj pairs" "" {INVALID_ARGS}
    }
    ::set d [tobj create Dict {}]
    ::foreach {key obj} $args {
      _setPath d [list $key] [expr {[tobj isobj $obj] ? $obj : [tinf $obj]}]
    }
    return $d
  }

  # tdict set dictVar key ?key ...? tobjValue
  proc set {dictVar args} {
    if {[llength $args] < 2} {
      error "tdict set: usage: tdict set dictVar key ?key ...? tobjValue" "" {INVALID_ARGS}
    }
    upvar 1 $dictVar d
    if {![tobj isobj $d]}         { error "tdict set: not a tobj"      "" {INVALID_TOBJ}      }
    if {[tobj type $d] ne "Dict"} { error "tdict set: not a Dict node" "" {INVALID_TOBJ_DICT} }
    ::set keyPath [lrange $args 0 end-1]
    ::set obj [lindex $args end]
    _setPath d $keyPath [expr {[tobj isobj $obj] ? $obj : [tinf $obj]}]
  }

  proc _setPath {dictVar keyPath obj} {
    upvar 1 $dictVar d
    ::set key     [lindex $keyPath 0]
    ::set rest    [lrange $keyPath 1 end]
    ::set current [tobj value $d]
    if {[llength $rest] == 0} {
      dict set current $key $obj
    } else {
      if {[dict exists $current $key]} {
        ::set nested [dict get $current $key]
        if {![tobj isobj $nested] || [tobj type $nested] ne "Dict"} {
          ::set nested [tobj create Dict {}]
        }
      } else {
        ::set nested [tobj create Dict {}]
      }
      _setPath nested $rest $obj
      dict set current $key $nested
    }
    ::set d [tobj create Dict $current]
  }

  # tdict get dict key ?key ...?
  proc get {d args} {
    if {[llength $args] < 1} {
      error "tdict get: usage: tdict get dict key ?key ...?" "" {INVALID_ARGS}
    }
    if {![tobj isobj $d]}         { error "tdict get: not a tobj"      "" {INVALID_TOBJ}      }
    if {[tobj type $d] ne "Dict"} { error "tdict get: not a Dict node" "" {INVALID_TOBJ_DICT} }
    return [_getPath $d $args]
  }

  proc getval {d args} {
    ::set obj [get $d {*}$args]
    ::set t [tobj type $obj]
    if {$t eq "Dict" || $t eq "List"} { return $obj }
    return [tobj value $obj]
  }

  proc _getPath {d keyPath} {
    ::set key     [lindex $keyPath 0]
    ::set rest    [lrange $keyPath 1 end]
    ::set current [tobj value $d]
    if {![dict exists $current $key]} {
      error "tdict get: key '$key' not found" "" {INVALID_TOBJ_KEY}
    }
    ::set node [dict get $current $key]
    if {[llength $rest] == 0} { return $node }
    if {![tobj isobj $node] || [tobj type $node] ne "Dict"} {
      error "tdict get: '$key' is not a Dict node" "" {INVALID_TOBJ_DICT}
    }
    return [_getPath $node $rest]
  }

  proc exists {d args} {
    if {[llength $args] < 1} { return 0 }
    if {![tobj isobj $d] || [tobj type $d] ne "Dict"} { return 0 }
    return [expr {![catch {_getPath $d $args}]}]
  }

  proc keys {d args} {
    if {![tobj isobj $d]}         { error "tdict keys: not a tobj"      "" {INVALID_TOBJ}      }
    if {[tobj type $d] ne "Dict"} { error "tdict keys: not a Dict node" "" {INVALID_TOBJ_DICT} }
    if {[llength $args] > 0} {
      return [dict keys [tobj value $d] [lindex $args 0]]
    }
    return [dict keys [tobj value $d]]
  }

  proc size {dictVar} {
    upvar 1 $dictVar d
    if {![tobj isobj $d]}         { error "tdict size: not a tobj"      "" {INVALID_TOBJ}      }
    if {[tobj type $d] ne "Dict"} { error "tdict size: not a Dict node" "" {INVALID_TOBJ_DICT} }
    return [dict size [tobj value $d]]
  }

  proc for {kvPair d body} {
    if {![tobj isobj $d]}         { error "tdict for: not a tobj"      "" {INVALID_TOBJ}      }
    if {[tobj type $d] ne "Dict"} { error "tdict for: not a Dict node" "" {INVALID_TOBJ_DICT} }
    lassign $kvPair keyVar valVar
    dict for {_k _v} [tobj value $d] {
      uplevel 1 [list set $keyVar $_k]
      uplevel 1 [list set $valVar $_v]
      uplevel 1 $body
    }
  }

  # tdict lappend dictVar key ?key ...? tobjNode
  proc lappend {dictVar args} {
    if {[llength $args] < 2} {
      error "tdict lappend: usage: tdict lappend dictVar key ?key ...? tobjNode" "" {INVALID_ARGS}
    }
    upvar 1 $dictVar d
    if {![tobj isobj $d]}         { error "tdict lappend: not a tobj"      "" {INVALID_TOBJ}      }
    if {[tobj type $d] ne "Dict"} { error "tdict lappend: not a Dict node" "" {INVALID_TOBJ_DICT} }

    ::set keyPath [lrange $args 0 end-1]
    ::set obj     [lindex $args end]
    ::set obj     [expr {[tobj isobj $obj] ? $obj : [tinf $obj]}]
    if {[exists $d {*}$keyPath]} {
      ::set node [_getPath $d $keyPath]
      if {![tobj isobj $node] || [tobj type $node] ne "List"} {
        error "tdict lappend: existing value is not a List node" "" {INVALID_TOBJ_LIST}
      }
      ::set lst [tobj value $node]
    } else {
      ::set lst {}
    }
    ::lappend lst $obj
    _setPath d $keyPath [tobj create List $lst]
  }

  # tdict remove dictVar key ?key ...?
  proc remove {d args} {
    if {[llength $args] < 1} {
      error "tdict remove: usage: tdict remove dictr key ?key ...?" "" {INVALID_ARGS}
    }
    if {![tobj isobj $d]}         { error "tdict remove: not a tobj"      "" {INVALID_TOBJ}      }
    if {[tobj type $d] ne "Dict"} { error "tdict remove: not a Dict node" "" {INVALID_TOBJ_DICT} }
    _removePath d $args
  }

  proc _removePath {dictVar keyPath} {
    upvar 1 $dictVar d
    ::set key     [lindex $keyPath 0]
    ::set rest    [lrange $keyPath 1 end]
    ::set current [tobj value $d]
    if {![dict exists $current $key]} {
      error "tdict remove: key '$key' not found" "" {INVALID_TOBJ_KEY}
    }
    if {[llength $rest] == 0} {
      dict unset current $key
    } else {
      ::set nested [dict get $current $key]
      if {![tobj isobj $nested] || [tobj type $nested] ne "Dict"} {
        error "tdict remove: '$key' is not a Dict node" "" {INVALID_TOBJ_DICT}
      }
      _removePath nested $rest
      dict set current $key $nested
    }
    ::set d [tobj create Dict $current]
  }

  namespace export create set lappend get getval exists keys size for remove
  namespace ensemble create
}
