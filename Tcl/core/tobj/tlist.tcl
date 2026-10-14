namespace eval tlist {

  proc create {args} {
    ::set objects {}
    ::foreach obj $args { ::lappend objects [::tobj::asObj $obj] }
    return [tobj create List $objects]
  }

  # Keep every element as a String, including numeric and empty text
  proc createstr {args} {
    ::set objects {}
    ::foreach obj $args { ::lappend objects [tobj create String $obj] }
    return [tobj create List $objects]
  }

  proc append {listVar args} {
    upvar 1 $listVar listObj
    if {[llength $args] == 0} {
      # Report an invalid target before checking for missing items.
      if {![tobj isobj $listObj]}              { error "tlist append: not a tobj"        "" {INVALID_TOBJ}      }
      if {[dict get $listObj __t__] ne "List"} { error "tlist append: not a List object" "" {INVALID_TOBJ_LIST} }
      error "tlist append: no objects given" "" {INVALID_ARGS}
    }
    ::tobj::appendItems listObj $args "tlist append" {} 1
    return $listObj
  }

  proc get {listObj index} {
    if {![tobj isobj $listObj]}              { error "tlist get: not a tobj"        "" {INVALID_TOBJ}      }
    if {[dict get $listObj __t__] ne "List"} { error "tlist get: not a List object" "" {INVALID_TOBJ_LIST} }
    return [lindex [dict get $listObj __v__] $index]
  }

  proc getval {listObj index} {
    return [::tobj::unwrapScalar [get $listObj $index]]
  }

  proc length {listObj} {
    if {![tobj isobj $listObj]}              { error "tlist length: not a tobj"        "" {INVALID_TOBJ}      }
    if {[dict get $listObj __t__] ne "List"} { error "tlist length: not a List object" "" {INVALID_TOBJ_LIST} }
    return [llength [dict get $listObj __v__]]
  }

  proc remove {listObj index} {
    if {![tobj isobj $listObj]}              { error "tlist remove: not a tobj"        "" {INVALID_TOBJ}      }
    if {[dict get $listObj __t__] ne "List"} { error "tlist remove: not a List object" "" {INVALID_TOBJ_LIST} }
    _remove listObj $index
  }

  proc pop {listVar} {
    upvar 1 $listVar listObj
    if {![tobj isobj $listObj]}              { error "tlist pop: not a tobj"        "" {INVALID_TOBJ}      }
    if {[dict get $listObj __t__] ne "List"} { error "tlist pop: not a List object" "" {INVALID_TOBJ_LIST} }
    set popped [lindex [dict get $listObj __v__] end]
    _remove listObj end
    return $popped
  }

  proc _remove {listVar index} {
    upvar 1 $listVar obj
    lrange {} $index $index
    # remove/pop already checked the wrapper. Check only its payload here.
    set items [dict get $obj __v__]
    if {[catch {llength $items}]} {
      return -code error -errorcode {TOBJ TYPE} "List removal: malformed List value"
    }
    dict set obj __v__ ""
    set items [lreplace [_detachValue items] $index $index]
    dict set obj __v__ $items
    return $obj
  }

  # Clear the original reference before passing its value to lreplace.
  proc _detachValue {valueVar} {
    upvar 1 $valueVar value
    set held $value
    set value {}
    return $held
  }

  proc foreach {itemVar listObj body} {
    if {![tobj isobj $listObj]}              { error "tlist foreach: not a tobj"        "" {INVALID_TOBJ}      }
    if {[dict get $listObj __t__] ne "List"} { error "tlist foreach: not a List object" "" {INVALID_TOBJ_LIST} }
    upvar 1 $itemVar bound
    ::foreach item [dict get $listObj __v__] {
      ::set bound $item
      ::set _tlf_code [catch {uplevel 1 $body} _tlf_res _tlf_opts]
      switch -- $_tlf_code {
        0 {}
        3 { break }
        4 { continue }
        default {
          if {$_tlf_code == 2} { dict incr _tlf_opts -level }
          return -options $_tlf_opts $_tlf_res
        }
      }
    }
  }

  proc foreachval {itemVar listObj body} {
    if {![tobj isobj $listObj]}              { error "tlist foreachval: not a tobj"        "" {INVALID_TOBJ}      }
    if {[dict get $listObj __t__] ne "List"} { error "tlist foreachval: not a List object" "" {INVALID_TOBJ_LIST} }
    upvar 1 $itemVar bound
    ::foreach item [dict get $listObj __v__] {
      ::set bound [::tobj::unwrapScalar $item]
      ::set _tlv_code [catch {uplevel 1 $body} _tlv_res _tlv_opts]
      switch -- $_tlv_code {
        0 {}
        3 { break }
        4 { continue }
        default {
          if {$_tlv_code == 2} { dict incr _tlv_opts -level }
          return -options $_tlv_opts $_tlv_res
        }
      }
    }
  }

  proc elemExists {listObj value} {
    if {![tobj isobj $listObj]}              { error "tlist elemExists: not a tobj"        "" {INVALID_TOBJ}      }
    if {[dict get $listObj __t__] ne "List"} { error "tlist elemExists: not a List object" "" {INVALID_TOBJ_LIST} }
    ::foreach item [dict get $listObj __v__] {
      set t [tobj type $item]
      if {[::tobj::storageType $t] ni {Dict List} && [dict get $item __v__] eq $value} { return 1 }
    }
    return 0
  }

  proc index {listObj value} {
    if {![tobj isobj $listObj]}              { error "tlist index: not a tobj"        "" {INVALID_TOBJ}      }
    if {[dict get $listObj __t__] ne "List"} { error "tlist index: not a List object" "" {INVALID_TOBJ_LIST} }
    if {[tobj isobj $value]} { set needle [dict get $value __v__] } else { set needle $value }
    set i 0
    ::foreach item [dict get $listObj __v__] {
      set t [tobj type $item]
      if {[::tobj::storageType $t] ni {Dict List} && [dict get $item __v__] eq $needle} { return $i }
      incr i
    }
    return -1
  }

  namespace export create createstr append get getval length remove pop foreach foreachval elemExists index
  namespace ensemble create
}
