
namespace eval HogStruct {

  proc field {type name args} {
    upvar 1 fields fields
    if {[llength $args] > 1} { _fail USAGE "usage: field type name ?default?" }
    if {[llength $args]} {
      set default [lindex $args 0]
    } elseif {$type in {Number Bool}} {
      set default 0
    } else {
      set default ""
    }
    dict set fields $name [dict create type $type default $default]
  }

  proc Define {name body} {
    set namespaceName [regsub -all {::+} ::$name ::]
    if {$namespaceName ne "::"} { regsub {::$} $namespaceName {} namespaceName }
    if {![catch {::tobj::StructFields $name}]} { return $name }

    set fields {}
    eval $body

    tobj::RegisterStruct $name $fields
    _createStructNamespace $namespaceName $name
    return $name
  }

  # Struct operations
  proc Create {structName args} {
    if {[catch {_createStruct $structName $args} result opts]} { _rethrow $result $opts }
    return $result
  }

  proc Fields {structName} {
    if {[catch {tobj::StructFields $structName} result opts]} { _rethrow $result $opts }
    return [dict keys $result]
  }

  proc Is {structName value} { expr {![catch {tobj::ValidateStruct $structName $value}]} }

  proc ToJson {structName value args} {
    if {[catch {tobj::ValidateStruct $structName $value} result opts]} { _rethrow $result $opts }
    return [tobj tojson $value {*}$args]
  }

  proc Get {structName value key args} {
    tobj::unwrapScalar [GetObj $structName $value $key {*}$args]
  }

  proc GetOr {structName self key value args} {
    set path [list $key $value {*}$args]
    if {[catch {
      tobj::RequireStruct $structName $self
      tobj::readPath $self [lrange $path 0 end-1] $structName
    } obj opts]} {
      if {[dict get $opts -errorcode] eq {TOBJ MISSING}} { return [lindex $path end] }
      _rethrow $obj $opts
    }
    return [tobj::unwrapScalar $obj]
  }

  proc GetObj {structName value key args} {
    if {[catch {
      tobj::RequireStruct $structName $value
      tobj::readPath $value [list $key {*}$args] $structName
    } result opts]} { _rethrow $result $opts }
    return $result
  }

  proc GetObjOr {structName self key value args} {
    set path [list $key $value {*}$args]
    if {[catch {
      tobj::RequireStruct $structName $self
      tobj::readPath $self [lrange $path 0 end-1] $structName
    } obj opts]} {
      if {[dict get $opts -errorcode] eq {TOBJ MISSING}} { return [lindex $path end] }
      _rethrow $obj $opts
    }
    return $obj
  }

  proc Exists {structName value key args} {
    if {[catch {
      tobj::RequireStruct $structName $value
      tobj::readPath $value [list $key {*}$args] $structName
    } obj opts]} {
      if {[dict get $opts -errorcode] eq {TOBJ MISSING}} { return 0 }
      _rethrow $obj $opts
    }
    return 1
  }

  proc Set {structName selfVar key value args} {
    upvar 1 $selfVar self
    set path [list $key $value {*}$args]
    if {[catch {
      tobj::RequireStruct $structName $self
      tobj::editPath self [lrange $path 0 end-1] set [lindex $path end] $structName
    } result opts]} { _rethrow $result $opts }
  }

  proc Unset {structName valueVar key args} {
    upvar 1 $valueVar value
    if {[catch {
      tobj::RequireStruct $structName $value
      tobj::editPath value [list $key {*}$args] unset {} $structName
    } result opts]} { _rethrow $result $opts }
  }

  # The final argument supplies a native list or typed List of items.
  proc Append {structName selfVar key value args} {
    upvar 1 $selfVar self
    set path [list $key $value {*}$args]
    if {[catch {
      tobj::RequireStruct $structName $self
      tobj::editPath self [lrange $path 0 end-1] append [lindex $path end] $structName
    } result opts]} { _rethrow $result $opts }
  }

  # Private helpers

  # Alias to bind methods without adding a frame
  proc _createStructNamespace {namespaceName structName} {
    namespace eval $namespaceName [list ::variable structName $structName]
    foreach method {
      Create Fields Is ToJson
      Get GetObj GetOr GetObjOr Exists Set Unset Append
    } {
      ::interp alias {} ${namespaceName}::$method {} ::HogStruct::$method $structName
    }
  }

  # options is a list of field overrides; active tracks recursive defaults
  proc _createStruct {structName options {active {}}} {
    set fields [::tobj::StructFields $structName]
    if {$structName in $active} {
      _fail SCHEMA "cyclic struct defaults: [join [linsert $active end $structName] { -> }]"
    }
    if {[llength $options] % 2} { _fail USAGE "${structName}::Create: expected -field value pairs" }
    set overrides {}
    foreach {option value} $options {
      if {![regexp {^-(.+)$} $option -> fieldName]} { _fail USAGE "${structName}::Create: malformed option '$option' (expected -field)" }
      if {![dict exists $fields $fieldName]} { _fail SCHEMA "${structName}::Create: '$fieldName' is not a declared field (declared: [dict keys $fields])" }
      dict set overrides $fieldName $value
    }
    set fieldValues {}
    dict for {fieldName spec} $fields {
      set type [dict get $spec type]
      if {[dict exists $overrides $fieldName]} {
        dict set fieldValues $fieldName [::tobj::coerce $type [dict get $overrides $fieldName] $structName.$fieldName]
      } elseif {$type ni {String Number Bool Null Dict List} && [dict get $spec default] eq ""} {
        dict set fieldValues $fieldName [_createStruct $type {} [linsert $active end $structName]]
      } else {
        dict set fieldValues $fieldName [::tobj::coerce $type [dict get $spec default] $structName.$fieldName]
      }
    }
    set value [::tobj::create $structName $fieldValues]
    # Constructors use the same selfVar/upvar convention as other mutators.
    # Run here so newly constructed nested defaults are initialized too;
    # supplied existing values are only coerced/validated, never reconstructed.
    set constructor ::${structName}::Constructor
    if {[info procs $constructor] ne ""} {
      $constructor value
      ::tobj::ValidateStruct $structName $value
    }
    return $value
  }


  # Report TOBJ errors as HOGSTRUCT errors at the struct command boundary.
  proc _rethrow {result opts} {
    # Tcl's errorinfo names procedures and relative lines, but loses their
    # source locations as the stack unwinds. Save the live caller locations
    # once, at the innermost struct boundary, for the launcher's diagnostics.
    if {![dict exists $opts -hoglocations]} {
      set locations {}
      for {set i [expr {[info frame] - 1}]} {$i > 0} {incr i -1} {
        set frame [info frame $i]
        if {[dict exists $frame file] && [dict exists $frame line]} {
          # The catch container repeats its whole body, rather than identifying
          # a call site. Its active statement is captured in a separate frame.
          if {[regexp {^\s*(::)?catch\s} [dict get $frame cmd]]} { continue }
          lappend locations [dict create file [dict get $frame file] line [dict get $frame line] command [dict get $frame cmd]]
        }
      }
      dict set opts -hoglocations $locations
    }
    set code [dict get $opts -errorcode]
    if {[lindex $code 0] eq "TOBJ"} {
      dict set opts -errorcode [list HOGSTRUCT [lindex $code 1]]
      if {[string match "unknown struct '*" $result]} {
        set result [string replace $result 0 13 "unknown HogStruct"]
      }
    }
    return -options $opts $result
  }

  proc _fail {code msg} { return -code error -errorcode [list HOGSTRUCT $code] $msg }

  namespace export -clear field
  namespace ensemble create
}
