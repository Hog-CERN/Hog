namespace eval tdict {

  # Accept key/value pairs; infer types for native values.
  proc create {args} {
    if {[llength $args] % 2 != 0} {
      error "tdict create: args must be key-tobj pairs" "" {INVALID_ARGS}
    }
    ::set values {}
    ::foreach {key obj} $args { dict set values $key [::tobj::asObj $obj] }
    return [tobj create Dict $values]
  }

  # tdict set dictVar key ?key ...? tobjValue
  proc set {dictVar args} {
    if {[llength $args] < 2} {
      error "tdict set: usage: tdict set dictVar key ?key ...? tobjValue" "" {INVALID_ARGS}
    }
    upvar 1 $dictVar obj
    if {![tobj isobj $obj]}                                    { error "tdict set: not a tobj"        "" {INVALID_TOBJ}      }
    if {[::tobj::storageType [dict get $obj __t__]] ne "Dict"} { error "tdict set: not a Dict object" "" {INVALID_TOBJ_DICT} }
    if {[catch {::tobj::editPath obj [lrange $args 0 end-1] set [lindex $args end] "tdict set" 1} result opts]} {
      _rethrow $result $opts
    }
    return $obj
  }

  # tdict get dict key ?key ...?
  proc get {obj args} {
    if {[llength $args] < 1} {
      error "tdict get: usage: tdict get dict key ?key ...?" "" {INVALID_ARGS}
    }
    if {![tobj isobj $obj]}                                    { error "tdict get: not a tobj"        "" {INVALID_TOBJ}      }
    if {[::tobj::storageType [dict get $obj __t__]] ne "Dict"} { error "tdict get: not a Dict object" "" {INVALID_TOBJ_DICT} }
    return [_getPath $obj $args]
  }

  proc getval {obj args} {
    return [::tobj::unwrapScalar [get $obj {*}$args]]
  }

  # tdict getor dict key ?key ...? default
  # Return the default on lookup errors; class schema errors propagate.
  proc getor {obj args} {
    if {[llength $args] < 2} {
      error "tdict getor: usage: tdict getor dict key ?key ...? default" "" {INVALID_ARGS}
    }
    ::set path [lrange $args 0 end-1]
    # Use defaults for lookup failures, but report schema violations.
    if {[catch {get $obj {*}$path} obj opts]} {
      if {[lindex [dict get $opts -errorcode] 0] eq "TOBJ"} { return -options $opts $obj }
      return [lindex $args end]
    }
    return [::tobj::unwrapScalar $obj]
  }

  # tdict getobjor dict key ?key ...? defaultObj
  # Return typed values without unwrapping; use defaultObj on lookup errors.
  proc getobjor {obj args} {
    if {[llength $args] < 2} {
      error "tdict getobjor: usage: tdict getobjor dict key ?key ...? defaultObj" "" {INVALID_ARGS}
    }
    ::set path [lrange $args 0 end-1]
    if {[catch {get $obj {*}$path} obj opts]} {
      if {[lindex [dict get $opts -errorcode] 0] eq "TOBJ"} { return -options $opts $obj }
      return [lindex $args end]
    }
    return $obj
  }

  proc _getPath {obj path} {
    if {[catch {::tobj::readPath $obj $path "tdict get"} result opts]} {
      _rethrow $result $opts
    }
    return $result
  }

  proc exists {obj args} {
    if {[llength $args] < 1} { return 0 }
    if {![tobj isobj $obj] || [::tobj::storageType [dict get $obj __t__]] ne "Dict"} { return 0 }
    if {[catch {_getPath $obj $args} result opts]} {
      if {[lindex [dict get $opts -errorcode] 0] eq "TOBJ"} { return -options $opts $result }
      return 0
    }
    return 1
  }

  proc keys {obj args} {
    if {[llength $args] > 1} { error "tdict keys: usage: tdict keys dict ?pattern?" "" {INVALID_ARGS} }
    if {![tobj isobj $obj]}                                    { error "tdict keys: not a tobj"        "" {INVALID_TOBJ}      }
    if {[::tobj::storageType [dict get $obj __t__]] ne "Dict"} { error "tdict keys: not a Dict object" "" {INVALID_TOBJ_DICT} }
    if {[llength $args] > 0} {
      return [dict keys [dict get $obj __v__] [lindex $args 0]]
    }
    return [dict keys [dict get $obj __v__]]
  }

  proc size {obj} {
    if {![tobj isobj $obj]}                                    { error "tdict size: not a tobj"        "" {INVALID_TOBJ}      }
    if {[::tobj::storageType [dict get $obj __t__]] ne "Dict"} { error "tdict size: not a Dict object" "" {INVALID_TOBJ_DICT} }
    return [dict size [dict get $obj __v__]]
  }

  proc for {kvPair obj body} {
    if {[llength $kvPair] != 2} { error "tdict for: expected exactly two variable names" "" {INVALID_ARGS} }
    if {![tobj isobj $obj]}                                    { error "tdict for: not a tobj"        "" {INVALID_TOBJ}      }
    if {[::tobj::storageType [dict get $obj __t__]] ne "Dict"} { error "tdict for: not a Dict object" "" {INVALID_TOBJ_DICT} }
    lassign $kvPair keyVar valVar
    upvar 1 $keyVar boundKey $valVar boundValue
    dict for {_k _v} [dict get $obj __v__] {
      ::set boundKey $_k
      ::set boundValue $_v
      ::set _tdf_code [catch {uplevel 1 $body} _tdf_res _tdf_opts]
      switch -- $_tdf_code {
        0 {}
        3 { break }
        4 { continue }
        default {
          # Account for this procedure only when propagating a Tcl return.
          if {$_tdf_code == 2} { dict incr _tdf_opts -level }
          return -options $_tdf_opts $_tdf_res
        }
      }
    }
  }

  # tdict filter dict key|value pattern
  # Keep entries whose key or value matches the glob; unwrap scalar values.
  proc filter {obj mode pattern} {
    if {![tobj isobj $obj]}                                    { error "tdict filter: not a tobj"        "" {INVALID_TOBJ}      }
    if {[::tobj::storageType [dict get $obj __t__]] ne "Dict"} { error "tdict filter: not a Dict object" "" {INVALID_TOBJ_DICT} }
    ::set result {}
    dict for {k v} [dict get $obj __v__] {
      switch -- $mode {
        key   {
          if {[string match $pattern $k]} { dict set result $k $v }
        }
        value {
          if {[tobj isobj $v] && [::tobj::storageType [dict get $v __t__]] ni {Dict List}} {
            ::set vraw [dict get $v __v__]
          } else {
            ::set vraw $v
          }
          if {[string match $pattern $vraw]} { dict set result $k $v }
        }
        default { error "tdict filter: unknown mode '$mode'" "" {INVALID_ARGS} }
      }
    }
    return [tobj create Dict $result]
  }

  # tdict lappend dictVar key ?key ...? tobjObj
  proc lappend {dictVar args} {
    if {[llength $args] < 2} {
      error "tdict lappend: usage: tdict lappend dictVar key ?key ...? tobjObj" "" {INVALID_ARGS}
    }
    upvar 1 $dictVar obj
    if {![tobj isobj $obj]}                                    { error "tdict lappend: not a tobj"        "" {INVALID_TOBJ}      }
    if {[::tobj::storageType [dict get $obj __t__]] ne "Dict"} { error "tdict lappend: not a Dict object" "" {INVALID_TOBJ_DICT} }

    ::set values [list [lindex $args end]]
    if {[catch {
      ::tobj::editPath obj [lrange $args 0 end-1] append $values "tdict lappend" 1
    } result opts]} { _rethrow $result $opts }
    return $obj
  }

  # tdict remove dictValue key ?key ...? -> a new Dict; caller variable is unchanged
  proc remove {obj args} {
    if {[llength $args] < 1} {
      error "tdict remove: usage: tdict remove dictValue key ?key ...?" "" {INVALID_ARGS}
    }
    if {![tobj isobj $obj]}                                    { error "tdict remove: not a tobj"        "" {INVALID_TOBJ}      }
    if {[::tobj::storageType [dict get $obj __t__]] ne "Dict"} { error "tdict remove: not a Dict object" "" {INVALID_TOBJ_DICT} }
    if {[catch {::tobj::editPath obj $args unset {} "tdict remove"} result opts]} {
      _rethrow $result $opts
    }
    return $obj
  }

  proc _rethrow {result opts} {
    ::set code [dict get $opts -errorcode]
    if {[lindex $code 0] eq "TOBJ"} {
      switch -- [lindex $code 1] {
        SCHEMA - CLASS { }
        MISSING { dict set opts -errorcode INVALID_TOBJ_KEY }
        TYPE    { dict set opts -errorcode INVALID_TOBJ_TYPE }
        default { dict set opts -errorcode INVALID_TOBJ_DICT }
      }
    }
    return -options $opts $result
  }

  namespace export create set lappend get getval getor getobjor exists keys size for filter remove
  namespace ensemble create
}
