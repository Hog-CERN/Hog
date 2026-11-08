
namespace eval DataStore {
  variable stores
  if {![info exists stores]} { set stores [dict create] }

  proc Create {structName name args} {
    variable stores

    if {[llength $args] > 1} { _fail USAGE "usage: DataStore::Create structName name ?value?" }

    set name [_storeName $name]
    if {$name eq ""} { _fail DATASTORE "datastore name must not be empty" }

    if {[namespace exists ::$name] || [namespace which -command ::$name] ne ""} {
      _fail DATASTORE "cannot create datastore '$name': a namespace or command with that name already exists"
    }
    if {[llength $args]} {
      set value [lindex $args 0]
      if {[catch {tobj::ValidateStruct $structName $value} result opts]} { HogStruct::_rethrow $result $opts }
    } else {
      set value [::${structName}::Create]
    }
    _createStore ::$name $structName $value
    dict set stores $name $structName
    return $name
  }

  proc Names {} {
    variable stores
    return [dict keys $stores]
  }

  proc Exists {name} {
    variable stores
    return [dict exists $stores [_storeName $name]]
  }

  proc StructOf {name} {
    variable stores
    set name [_storeName $name]
    if {![dict exists $stores $name]} { _fail DATASTORE "no datastore named '$name'" }
    return [dict get $stores $name]
  }

  proc Delete {name} {
    variable stores
    set name [_storeName $name]
    StructOf $name
    namespace delete ::$name
    rename ::$name {}
    # Drop descendant stores too, comparing literal names rather than globs.
    set prefix ${name}::
    foreach store [dict keys $stores] {
      if {$store eq $name || [string first $prefix $store] == 0} {
        dict unset stores $store
      }
    }
    return $stores
  }

  # Normalize namespace name
  proc _storeName {name} {
    regsub -all {::+} ::$name :: name
    return [regsub -all {^::|::$} $name {}]
  }


  # Add functions and variables to <datastore> namespace
  proc _createStore {namespaceName structName value} {
    namespace eval $namespaceName {
      variable structName
      variable data
    }

    set ${namespaceName}::structName $structName
    set ${namespaceName}::data $value

    proc $namespaceName {} [list set ${namespaceName}::data]

    namespace eval $namespaceName {
      proc Get {key args} {
        variable structName
        variable data
        HogStruct::Get $structName $data $key {*}$args
      }

      proc GetOr {key value args} {
        variable structName
        variable data
        HogStruct::GetOr $structName $data $key $value {*}$args
      }

      proc GetObj {key args} {
        variable structName
        variable data
        HogStruct::GetObj $structName $data $key {*}$args
      }

      proc GetObjOr {key value args} {
        variable structName
        variable data
        HogStruct::GetObjOr $structName $data $key $value {*}$args
      }

      proc Exists {key args} {
        variable structName
        variable data
        HogStruct::Exists $structName $data $key {*}$args
      }

      proc ToJson {args} {
        variable structName
        variable data
        HogStruct::ToJson $structName $data {*}$args
      }

      proc Set {key value args} {
        variable structName
        variable data
        HogStruct::Set $structName data $key $value {*}$args
      }

      proc Unset {key args} {
        variable structName
        variable data
        HogStruct::Unset $structName data $key {*}$args
      }

      proc Append {key value args} {
        variable structName
        variable data
        HogStruct::Append $structName data $key $value {*}$args
      }

      proc Load {newValue} {
        variable structName
        variable data
        if {[catch {tobj::ValidateStruct $structName $newValue} result opts]} { HogStruct::_rethrow $result $opts }
        set data $newValue
        return
      }

      proc Reset {args} {
        variable structName
        variable data
        set data [::${structName}::Create {*}$args]
        return
      }
    }
  }

  proc _fail {code message} { return -code error -errorcode [list HOGSTRUCT $code] $message }
}
