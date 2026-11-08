namespace eval tobj {
  variable builtinTypes {String Number Bool Null Dict List}

  proc isobj {value} {
    return [expr {
      ![catch {dict size $value}] &&
      [dict exists $value __t__] &&
      [dict exists $value __v__]
    }]
  }

  proc create {type value} {
    variable builtinTypes
    variable schemas
    if {$type ni $builtinTypes && ![dict exists $schemas $type]} {
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

  # JSON export

  proc tojson {obj {arg {}}} {
    if {$arg ni {{} -pretty}} { _fail USAGE "tobj tojson: expected optional -pretty, got '$arg'" }
    if {![isobj $obj]} { error "tobj: not a tobj" "" {INVALID_TOBJ} }
    return [_renderJson $obj [expr {$arg eq "-pretty" ? 0 : -1}]]
  }

  proc _renderJson {obj indent} {
    set type   [dict get $obj __t__]
    set value  [dict get $obj __v__]
    set pretty [expr {$indent >= 0}]
    set pad    [expr {$pretty ? [string repeat "  " $indent]            : ""}]
    set pad1   [expr {$pretty ? [string repeat "  " [expr {$indent+1}]] : ""}]
    set sep    [expr {$pretty ? ",\n" : ", "}]
    set next   [expr {$pretty ? $indent+1 : -1}]
    switch [storageType $type] {
      Dict {
        if {$pretty && $type eq "Dict" && [dict size $value] == 0} { return "{}" }
        set pairs {}
        if {$type ne "Dict"} {
          if {[dict exists $value __struct__]} { _fail SCHEMA "struct payload reserves __struct__" }
          lappend pairs "${pad1}\"__struct__\": \"[_escapeJson $type]\""
        }
        dict for {k child} $value {
          lappend pairs "${pad1}\"[_escapeJson $k]\": [_renderJson $child $next]"
        }
        if {$pretty} { return "{\n[join $pairs $sep]\n${pad}}" }
        return "{[join $pairs {, }]}"
      }
      List {
        if {$pretty && [llength $value] == 0} { return "\[\]" }
        set items {}
        foreach item $value { lappend items "${pad1}[_renderJson $item $next]" }
        if {$pretty} { return "\[\n[join $items $sep]\n${pad}\]" }
        return "\[[join $items {, }]\]"
      }
      Number  { return [_jsonNumber $value] }
      Bool    { return [expr {$value ? "true" : "false"}] }
      Null    { return "null" }
      default { return "\"[_escapeJson $value]\"" }
    }
  }

  proc _escapeJson {str} {
    variable jsonEscapes
    if {![info exists jsonEscapes]} {
      set jsonEscapes {
        "\\" "\\\\"  "\"" "\\\""
        "\b" "\\b"   "\f" "\\f"
        "\n" "\\n"   "\r" "\\r"  "\t" "\\t"
      }
      for {set code 0} {$code < 32} {incr code} {
        if {$code in {8 9 10 12 13}} { continue }
        lappend jsonEscapes [format %c $code] [format {\u%04x} $code]
      }
    }
    return [string map $jsonEscapes $str]
  }

  proc _jsonNumber {value} {
    set syntax {^-?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][+-]?[0-9]+)?$}
    if {[regexp $syntax $value]} { return $value }
    # Normalize Tcl-only forms (007, 0x10, +2, .5) without rounding integers.
    if {[catch {expr {$value + 0}} number] || ![regexp $syntax $number]} {
      _fail TYPE "cannot export '$value' as a JSON Number"
    }
    return $number
  }

  # Native values

  # Struct dicts include __struct__; Bool becomes 1/0 and Null an empty string.
  proc native {obj} {
    if {![isobj $obj]} { error "tobj native: not a tobj" "" {INVALID_TOBJ} }
    set type [dict get $obj __t__]
    switch [storageType $type] {
      List    {
        set items {}
        foreach item [dict get $obj __v__] { lappend items [native $item] }
        return $items
      }
      Dict {
        set result {}
        if {$type ne "Dict"} {
          if {[dict exists $obj __v__ __struct__]} { _fail SCHEMA "struct payload reserves __struct__" }
          dict set result __struct__ $type
        }
        dict for {key child} [dict get $obj __v__] { dict set result $key [native $child] }
        return $result
      }
      Bool    { return [expr {[dict get $obj __v__] ? 1 : 0}] }
      Null    { return {} }
      default { return [dict get $obj __v__] }
    }
  }

  # Unwrap scalars; leave Dicts, Lists, and struct values typed.
  proc unwrapScalar {obj} {
    if {[storageType [type $obj]] in {Dict List}} { return $obj }
    return [dict get $obj __v__]
  }

  proc asObj {value} {
    if {[isobj $value]} { return $value }
    return [tinf $value]
  }


  # Check the whole subtree, optionally against a declared type.
  proc _validateObj {obj context {type {}}} {
    if {![isobj $obj]} { _fail TYPE "$context: not a typed object" }
    if {$type eq ""} { set type [dict get $obj __t__] }
    if {$type ni {String Number Bool Null Dict List}} { ValidateStruct $type $obj; return }
    set actualType [dict get $obj __t__]
    if {$type eq "Dict" && $actualType ne "Dict" && [storageType $actualType] eq "Dict"} {
      ValidateStruct $actualType $obj
      return
    }
    if {$actualType ne $type} { _fail TYPE "$context: expected $type, got $actualType" }
    set payload [dict get $obj __v__]
    if {$type eq "Number" && ![string is double -strict $payload]}  { _fail TYPE "$context: bad Number '$payload'" }
    if {$type eq "Bool"   && ![string is boolean -strict $payload]} { _fail TYPE "$context: bad Bool '$payload'" }
    if {$type eq "Dict"} {
      if {[catch {dict size $payload}]} { _fail TYPE "$context: malformed Dict value" }
      dict for {key child} $payload { _validateObj $child $context.$key }
    } elseif {$type eq "List"} {
      if {[catch {llength $payload}]} { _fail TYPE "$context: malformed List value" }
      set i 0
      foreach child $payload {
        _validateObj $child "$context\[$i\]"
        incr i
      }
    }
  }

  # An empty expectedType infers the type of native values.
  proc coerce {expectedType value {context value}} {
    if {[isobj $value]} { _validateObj $value $context $expectedType; return $value }
    if {$expectedType eq ""} { return [tinf $value] }
    switch -- $expectedType {
      String { return [create String $value] }
      Number {
        if {![string is double -strict $value]} { _fail TYPE "$context: expected a Number, got '$value'" }
        return [create Number $value]
      }
      Bool {
        if {![string is boolean -strict $value]} { _fail TYPE "$context: expected a Bool, got '$value'" }
        return [create Bool [expr {$value ? 1 : 0}]]
      }
      Null {
        if {$value ne ""} { _fail TYPE "$context: expected Null (empty), got '$value'" }
        return [create Null {}]
      }
      Dict {
        if {[catch {dict size $value}]} { _fail TYPE "$context: expected a Tcl dict, got '$value'" }
        set entries {}
        dict for {key item} $value {
          if {[isobj $item]} {
            _validateObj $item $context.$key
          } else {
            set item [tinf $item]
          }
          dict set entries $key $item
        }
        return [create Dict $entries]
      }
      List {
        set items {}
        set i 0
        foreach item $value {
          if {[isobj $item]} {
            _validateObj $item "$context\[$i\]"
          } else {
            set item [tinf $item]
          }
          lappend items $item
          incr i
        }
        return [create List $items]
      }
      default { _fail TYPE "$context: expected a $expectedType struct (a typed object), got '$value'" }
    }
  }

  # Structs
  # we store struct values as __t__ <struct> __v__ key(field)->value
  # struct values have a stricter contract on what can and cannot be done to them
  # for example: fields are always present and we cannot unset them

  variable schemas
  if {![info exists schemas]} { set schemas [dict create] }

  proc storageType {type} {
    variable builtinTypes
    variable schemas
    if {$type in $builtinTypes} { return $type }
    if {[dict exists $schemas $type]} { return Dict }
    _fail TYPE "tobj: unknown type '$type'"
  }

  proc RegisterStruct {structName fields} {
    variable schemas
    variable builtinTypes
    if {$structName eq ""} { _fail SCHEMA "struct name must not be empty" }
    if {$structName in $builtinTypes} { _fail SCHEMA "invalid struct name '$structName': built-in types are reserved" }
    dict for {name spec} $fields {
      if {[string match __* $name]} { _fail SCHEMA "invalid field name '$name'" }
      set declaredType [dict get $spec type]
      set default [dict get $spec default]
      if {$declaredType in {String Number Bool Null Dict List}} { coerce $declaredType $default }
    }
    dict set schemas $structName $fields
    return $structName
  }

  proc StructFields {structName} {
    variable schemas
    if {![dict exists $schemas $structName]} { _fail STRUCT "unknown struct '$structName'" }
    return [dict get $schemas $structName]
  }

  proc _structName {obj} {
    variable schemas
    if {![isobj $obj]} { return "" }
    set structName [dict get $obj __t__]
    if {[dict exists $schemas $structName]} { return $structName }
    return ""
  }

  proc RequireStruct {structName obj} {
    variable schemas
    if {[dict exists $schemas $structName] && ![catch {dict get $obj __t__} got] &&
        $got eq $structName && [dict exists $obj __v__]} { return }
    set got [_structName $obj]
    if {$got ne ""} { _fail STRUCT "expected a $structName struct, got a $got struct" }
    _fail STRUCT "expected a $structName struct, got '[string range $obj 0 40]'"
  }

  # Struct fields must be declared and present, and cannot be unset
  proc _fieldType {obj key context action} {
    variable schemas
    set structName [dict get $obj __t__]
    if {![dict exists $schemas $structName]} { _fail STRUCT "unknown struct '$structName'" }
    if {![dict exists $schemas $structName $key]} { _fail SCHEMA "$context: '$key' is not a declared field of $structName" }
    if {![dict exists $obj __v__ $key]} { _fail SCHEMA "$context: field '$key' of $structName is missing" }
    if {$action eq "unset"} { _fail SCHEMA "$context.$key: cannot unset a declared field" }
    return [dict get $schemas $structName $key type]
  }

  proc ValidateStruct {structName obj} {
    set fields [StructFields $structName]
    RequireStruct $structName $obj
    set fieldValues [dict get $obj __v__]
    if {[catch {dict size $fieldValues}]} { _fail TYPE "$structName: malformed struct fields" }
    dict for {fieldName child} $fieldValues {
      if {![dict exists $fields $fieldName]} { _fail SCHEMA "$structName: '$fieldName' is not a declared field" }
    }
    dict for {fieldName spec} $fields {
      if {![dict exists $fieldValues $fieldName]} { _fail SCHEMA "$structName: field '$fieldName' is missing" }
      _validateObj [dict get $fieldValues $fieldName] $structName.$fieldName [dict get $spec type]
    }
    return 1
  }

  # List operations

  # tlist uses INVALID_TOBJ/INVALID_TOBJ_LIST for wrapper errors.
  proc listItems {obj context {tlistErrors 0}} {
    if {![isobj $obj]} {
      if {$tlistErrors} { error "$context: not a tobj" "" {INVALID_TOBJ} }
      _fail TYPE "$context: expected a List, found an untyped value"
    }
    set kind [dict get $obj __t__]
    if {$kind ne "List"} {
      if {$tlistErrors} { error "$context: not a List object" "" {INVALID_TOBJ_LIST} }
      _fail TYPE "$context: expected a List, found $kind"
    }
    set values [dict get $obj __v__]
    if {[catch {llength $values}]} { _fail TYPE "$context: malformed List value" }
    return $values
  }

  # Accept a native list or typed List; validate all items before changing obj.
  proc appendItems {objVar values context {expectedType {}} {tlistErrors 0}} {
    upvar 1 $objVar obj
    set current [listItems $obj $context $tlistErrors]
    if {$expectedType ne "" && $expectedType ne "List"} {
      _fail TYPE "$context: Append needs a declared List, found $expectedType"
    }
    if {[isobj $values]} { set values [listItems $values $context] }
    set new {}
    foreach item $values {
      lappend new [coerce "" $item $context]
    }
    dict set obj __v__ ""
    lappend current {*}$new
    dict set obj __v__ $current
    return
  }

  proc _fail {code msg} { return -code error -errorcode [list TOBJ $code] $msg }

  namespace export -clear create type typeIs value isobj tojson native
  namespace ensemble create
}

# Shorthand constructors and conversion
proc tstr  {v} { tobj create String $v }
proc tnum  {v} { tobj create Number $v }
proc tbool {v} { tobj create Bool   $v }
proc tnull {}  { tobj create Null   {} }
proc tval    {obj} { tobj value  $obj }
proc tnative {obj} { tobj native $obj }

proc tinf {value} {
  if {$value eq {} || $value eq {null}}      { return [tobj create Null {}] }
  if {$value eq {true} || $value eq {false}} { return [tobj create Bool $value] }
  if {[string is double -strict $value]}    { return [tobj create Number $value] }
  return [tobj create String $value]
}

proc tlinf {args} {
  set result {}
  ::foreach arg $args {
    lappend result [tinf $arg]
  }
  return $result
}

# Load path operations and container commands.
source [file join [file dirname [info script]] tobj_traversal.tcl]
source [file join [file dirname [info script]] tdict.tcl]
source [file join [file dirname [info script]] tlist.tcl]
