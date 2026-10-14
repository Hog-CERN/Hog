
namespace eval HogClass {

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
    if {[namespace exists $namespaceName]} { return $name }

    set fields {}
    eval $body

    tobj::RegisterClass $name $fields
    _createClassNamespace $namespaceName $name
    return $name
  }

  # Class operations
  proc Create {className args} {
    if {[catch {_createObject $className $args} result opts]} { _rethrow $result $opts }
    return $result
  }

  proc Fields {className} {
    if {[catch {tobj::ClassFields $className} result opts]} { _rethrow $result $opts }
    return [dict keys $result]
  }

  proc Is {className object} { expr {![catch {tobj::ValidateObject $className $object}]} }

  proc ToJson {className object args} {
    if {[catch {tobj::ValidateObject $className $object} result opts]} { _rethrow $result $opts }
    return [tobj tojson $object {*}$args]
  }

  proc Get {className object key args} {
    tobj::unwrapScalar [GetObj $className $object $key {*}$args]
  }

  proc GetOr {className object key value args} {
    set path [list $key $value {*}$args]
    if {[catch {
      tobj::RequireClass $className $object
      tobj::readPath $object [lrange $path 0 end-1] $className
    } obj opts]} {
      if {[dict get $opts -errorcode] eq {TOBJ MISSING}} { return [lindex $path end] }
      _rethrow $obj $opts
    }
    return [tobj::unwrapScalar $obj]
  }

  proc GetObj {className object key args} {
    if {[catch {
      tobj::RequireClass $className $object
      tobj::readPath $object [list $key {*}$args] $className
    } result opts]} { _rethrow $result $opts }
    return $result
  }

  proc GetObjOr {className object key value args} {
    set path [list $key $value {*}$args]
    if {[catch {
      tobj::RequireClass $className $object
      tobj::readPath $object [lrange $path 0 end-1] $className
    } obj opts]} {
      if {[dict get $opts -errorcode] eq {TOBJ MISSING}} { return [lindex $path end] }
      _rethrow $obj $opts
    }
    return $obj
  }

  proc Exists {className object key args} {
    if {[catch {
      tobj::RequireClass $className $object
      tobj::readPath $object [list $key {*}$args] $className
    } obj opts]} {
      if {[dict get $opts -errorcode] eq {TOBJ MISSING}} { return 0 }
      _rethrow $obj $opts
    }
    return 1
  }

  proc Set {className objectVar key value args} {
    upvar 1 $objectVar object
    set path [list $key $value {*}$args]
    if {[catch {
      tobj::RequireClass $className $object
      tobj::editPath object [lrange $path 0 end-1] set [lindex $path end] $className
    } result opts]} { _rethrow $result $opts }
  }

  proc Unset {className objectVar key args} {
    upvar 1 $objectVar object
    if {[catch {
      tobj::RequireClass $className $object
      tobj::editPath object [list $key {*}$args] unset {} $className
    } result opts]} { _rethrow $result $opts }
  }

  # The final argument supplies a native list or typed List of items.
  proc Append {className objectVar key value args} {
    upvar 1 $objectVar object
    set path [list $key $value {*}$args]
    if {[catch {
      tobj::RequireClass $className $object
      tobj::editPath object [lrange $path 0 end-1] append [lindex $path end] $className
    } result opts]} { _rethrow $result $opts }
  }

  # Private helpers

  # Alias to bind methods without adding a frame
  proc _createClassNamespace {namespaceName className} {
    namespace eval $namespaceName [list ::variable className $className]
    foreach method {
      Create Fields Is ToJson
      Get GetObj GetOr GetObjOr Exists Set Unset Append
    } {
      ::interp alias {} ${namespaceName}::$method {} ::HogClass::$method $className
    }
  }

  # options is a list of field overrides; active tracks recursive defaults
  proc _createObject {className options {active {}}} {
    set fields [::tobj::ClassFields $className]
    if {$className in $active} {
      _fail SCHEMA "cyclic object defaults: [join [linsert $active end $className] { -> }]"
    }
    if {[llength $options] % 2} { _fail USAGE "${className}::Create: expected -field value pairs" }
    set overrides {}
    foreach {option value} $options {
      if {![regexp {^-(.+)$} $option -> fieldName]} { _fail USAGE "${className}::Create: malformed option '$option' (expected -field)" }
      if {![dict exists $fields $fieldName]} { _fail SCHEMA "${className}::Create: '$fieldName' is not a declared field (declared: [dict keys $fields])" }
      dict set overrides $fieldName $value
    }
    set fieldValues {}
    dict for {fieldName spec} $fields {
      set type [dict get $spec type]
      if {[dict exists $overrides $fieldName]} {
        dict set fieldValues $fieldName [::tobj::coerce $type [dict get $overrides $fieldName] $className.$fieldName]
      } elseif {$type ni {String Number Bool Null Dict List} && [dict get $spec default] eq ""} {
        dict set fieldValues $fieldName [_createObject $type {} [linsert $active end $className]]
      } else {
        dict set fieldValues $fieldName [::tobj::coerce $type [dict get $spec default] $className.$fieldName]
      }
    }
    return [::tobj::create $className $fieldValues]
  }


  # Report TOBJ errors as HOGOBJ errors at the class command boundary.
  proc _rethrow {result opts} {
    set code [dict get $opts -errorcode]
    if {[lindex $code 0] eq "TOBJ"} {
      dict set opts -errorcode [list HOGOBJ [lindex $code 1]]
      if {[string match "unknown class '*" $result]} {
        set result [string replace $result 0 12 "unknown HogObject class"]
      }
    }
    return -options $opts $result
  }

  proc _fail {code msg} { return -code error -errorcode [list HOGOBJ $code] $msg }

  namespace export -clear field
  namespace ensemble create
}
