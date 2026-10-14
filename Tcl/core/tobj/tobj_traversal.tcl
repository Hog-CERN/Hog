# Shared path operations for tdict and classes
# The write path is mostly an optimization: translate keys through the __v__
# wrappers into a native dict path, without retaining extra container references.
# This lets Tcl update unshared containers without copying them at each edit.
# Traversal also checks container types and declared class fields. Writes validate
# replacement values before committing, so rejected edits leave the object intact.

namespace eval tobj {
  # Translate a Dict/class path into native dict keys, checking each ancestor.
  # Return {keys missingKeys expectedType context exists}; hold no object values.
  proc _planDictPath {obj path createMissing context {replaceParents 0}
      {action edit}} {
    set keys {}
    set count [llength $path]
    set position 0
    set expectedType ""
    foreach key $path {
      incr position
      set parentType $expectedType
      set expectedType ""
      if {[catch {dict get $obj __t__} objType] ||
          ![dict exists $obj __v__] || ($objType ne "Dict" && [storageType $objType] ne "Dict")} {
        # tdict writers can replace non-Dict ancestors.
        set parentContext $context
        if {$position > 1} { append parentContext .[join [lrange $path 0 [expr {$position - 2}]] .] }
        if {!$replaceParents || !$createMissing || $position == 1} {
          if {![isobj $obj]} { _fail TRAVERSE "$parentContext: not a typed container" }
          _fail TRAVERSE "$parentContext: cannot step into a $objType value (at '$key')"
        }
        if {$parentType ni {"" Dict}} {
          _fail TYPE "$context: cannot replace a declared $parentType field with a Dict"
        }
        set missingKeys [lrange $path [expr {$position - 1}] end]
        return [list $keys $missingKeys "" $context.[join $path .] 0]
      }
      if {$objType ne "Dict"} {
        # Build the field context only for class checks.
        set parentContext $context
        if {$position > 1} { append parentContext .[join [lrange $path 0 [expr {$position - 2}]] .] }
        set keyAction read
        if {$position == $count} { set keyAction $action }
        set expectedType [_fieldType $obj $key $parentContext $keyAction]
      }
      set exists [dict exists $obj __v__ $key]
      if {$exists} { set obj [dict get $obj __v__ $key] }
      lappend keys __v__ $key
      if {!$exists} {
        if {!$createMissing} {
          _fail MISSING "$context.[join [lrange $path 0 [expr {$position - 1}]] .]: no such key"
        }
        set missingKeys [lrange $path $position end]
        return [list $keys $missingKeys $expectedType $context.[join $path .] 0]
      }
      if {$position == $count} {
        return [list $keys {} $expectedType $context.[join $path .] 1]
      }
    }
    return {}
  }

  # Follow Dict/class keys only. Lists remain valid values at the end of a path.
  proc readPath {obj {path {}} {context tobj}} {
    type $obj
    foreach key $path {
      if {[catch {dict get $obj __t__} objType] || ![dict exists $obj __v__]} {
        _fail TRAVERSE "$context: not a typed container"
      }
      if {$objType ne "Dict"} {
        if {[storageType $objType] ne "Dict"} {
          _fail TRAVERSE "$context: cannot step into a $objType value (at '$key')"
        }
        _fieldType $obj $key $context read
      }
      if {![dict exists $obj __v__ $key]} { _fail MISSING "$context.$key: no such key" }
      set obj [dict get $obj __v__ $key]
      append context .$key
    }
    return $obj
  }

  # Mutate the caller's variable. replaceParents lets tdict replace non-Dict
  # ancestors and create missing append targets; class fields follow schemas.
  proc editPath {objVar path operation value {context tobj} {replaceParents 0}} {
    upvar 1 $objVar obj
    if {$operation ni {set append unset}} { _fail USAGE "unknown edit operation '$operation'" }
    if {![string is boolean -strict $replaceParents]} { _fail USAGE "editPath: replaceParents must be a boolean" }
    # tdict set/lappend may replace non-Dict parents and create missing leaves.
    set createMissing [expr {$operation eq "set" || ($operation eq "append" && $replaceParents)}]
    if {![llength $path]} {
      switch -- $operation {
        set {
          # Root replacement also requires a typed object and retains its class.
          type $obj
          set expectedType ""
          set objType [dict get $obj __t__]
          if {$objType ne "Dict" && [storageType $objType] eq "Dict"} {
            set expectedType $objType
          }
          set obj [coerce $expectedType $value $context]
        }
        append { appendItems obj $value $context }
        unset { _fail USAGE "cannot unset an empty path" }
      }
      return
    }
    set plan [_planDictPath $obj $path $createMissing $context $replaceParents $operation]
    lassign $plan keys missingKeys expectedType leafContext exists
    if {$operation eq "unset"} {
      dict unset obj {*}$keys
      return
    }
    # Build and validate replacements before touching the caller's variable.
    if {!$exists || $operation eq "set"} {
      if {$operation eq "set"} {
        set child [coerce $expectedType $value $leafContext]
      } else {
        set child [create List {}]
        appendItems child $value $leafContext $expectedType
      }
      foreach key [lreverse $missingKeys] {
        set child [dict create __t__ Dict __v__ [dict create $key $child]]
      }
      dict set obj {*}$keys $child
      return
    }
    # Detach the leaf to avoid copying it on append; reattach even on failure.
    set child [dict get $obj {*}$keys]
    dict set obj {*}$keys ""
    set code [catch {appendItems child $value $leafContext $expectedType} err opts]
    dict set obj {*}$keys $child
    if {$code} { return -options $opts $err }
    return
  }
}
