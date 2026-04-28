
namespace eval Commands {
  # _registry shape:
  #   aliases -> tdict: <alias> -> cmd_name
  #   cmds    -> tdict:
  #     <cmd> -> tdict:
  #       aliases       -> tlist
  #       script        -> string 
  #       description   -> string
  #       options       -> tlist
  #       requires_proj -> bool
  #       ide           -> String
  #       no_exit       -> Bool
  #       custom        -> Bool

  variable _registry
  if {![info exists _registry]} {
    set _registry [tdict create aliases [tdict create] cmds [tdict create]]
  }

  variable _fields {
    { name            ""     optional}
    { script          ""     required}

    { aliases         ""     optional}
    { description     ""     optional}
    { options         ""     optional}
    { requires_proj   false  optional}
    { ide             tclsh  optional}
    { no_exit         false  optional}
  }


  proc _valid_alias {alias} {
    variable _registry
    if {$alias eq ""} { return 0 }
    if {[tdict exists $_registry aliases $alias]} { return 0 }
    return 1
  }

  proc _validate_cmd {key raw_dict} {
    variable _fields
    set norm [dict create]
    dict for {k v} $raw_dict { dict set norm [string tolower $k] $v }
    set raw_dict $norm
    set result [dict create]
    foreach field $_fields {
      lassign $field fname fdefault frequired
      if {$fname eq "name"} {
        if {[dict exists $raw_dict name] && [dict get $raw_dict name] ne ""} {
          dict set result name [dict get $raw_dict name]
        } elseif {$key ne ""} {
          dict set result name $key
        } else {
          error "missing required field 'name'"
        }
        continue
      }
      if {[dict exists $raw_dict $fname]} {
        dict set result $fname [dict get $raw_dict $fname]
      } elseif {$frequired eq "required"} {
        error "missing required field '$fname'"
      } else {
        dict set result $fname $fdefault
      }
    }
    return $result
  }

  proc RegisterCommand {key raw_dict args} {
    variable _registry
    if {[catch {_validate_cmd $key $raw_dict} validated]} {
      Msg Warning "Skipping command '$key': $validated"
      return
    }
    set is_custom [expr {"-custom" in $args}]
    set name [dict get $validated name]

    set name [string toupper $name]

    if {![_valid_alias $name]} {
      Msg Warning "Command '$name' is not valid or already exists as an alias, skipping"
      return
    }
    tdict set _registry aliases $name [tstr $name]
    set aliases [list]

    foreach alias [dict get $validated aliases] {
      set alias [string toupper $alias]
      if {[_valid_alias $alias]} {
        tdict set _registry aliases $alias [tstr $name]
        lappend aliases $alias
      } else {
        Msg Warning "Alias '$alias' for command '$name' is not valid or already exists, skipping"
      }
    }

    tdict set _registry cmds $name [tdict create \
      name          [tstr $name] \
      aliases       [tlist create {*}$aliases] \
      script        [tstr  [dict get $validated script]] \
      description   [tstr  [dict get $validated description]] \
      options       [tlist create {*}[dict get $validated options]] \
      requires_proj [tbool [dict get $validated requires_proj]] \
      ide           [tstr  [dict get $validated ide]] \
      no_exit       [tbool [dict get $validated no_exit]] \
      custom        [tbool $is_custom] \
    ]
  }

  # ::hog_command  — single command dict
  # ::hog_commands — dict of commands keyed by name 
  # -custom to mark commands as user-defined.
  proc RegisterCommandsFile {f args} {
    unset -nocomplain ::hog_command ::hog_commands
    if {[catch {namespace eval :: [list source $f]} err]} {
      Msg Warning "failed to source [file tail $f]: $err"
      return
    }

    if {[info exists ::hog_commands]} {
      if {[catch {dict size $::hog_commands}]} {
        Msg Warning "hog_commands is not a dictionary in [file tail $f], skipping"
        return
      }
      dict for {key raw} $::hog_commands {
        RegisterCommand $key $raw {*}$args
      }
      return
    }

    if {[info exists ::hog_command]} {
      if {[catch {dict size $::hog_command}]} {
        Msg Warning "hog_command is not a dictionary in [file tail $f], skipping"
        return
      }
      RegisterCommand "" $::hog_command {*}$args
      return
    }

    Msg Warning "neither hog_command nor hog_commands set in [file tail $f], skipping"
  }

  proc RegisterCommandsDir {dir args} {
    if {![file isdirectory $dir]} { return }
    foreach f [lsort [glob -nocomplain -directory $dir *.tcl]] {
      RegisterCommandsFile $f {*}$args
    }
  }


  proc AliasExists {alias} {
    variable _registry
    return [tdict exists $_registry aliases $alias]
  }

  proc Run {cmd} {
    variable _registry
    if {![tdict exists $_registry aliases $cmd]} {
      Msg Error "Unknown command '$cmd'"
      return
    }
    set name   [tobj value [tdict get $_registry aliases $cmd]]
    set script [tobj value [tdict get $_registry cmds $name script]]
    uplevel #0 $script
  }

  proc GetCommandOptions {cmd} {
    variable _registry
    if {![tdict exists $_registry aliases $cmd]} { return {} }
    set name [tobj value [tdict get $_registry aliases $cmd]]
    set result {}
    tlist foreach opt_tobj [tdict get $_registry cmds $name options] {
      lappend result [tobj value $opt_tobj]
    }
    return $result
  }

  proc GetCommand {cmd} {
    variable _registry
    if {![tdict exists $_registry aliases $cmd]} { return {} }
    set name [tobj value [tdict get $_registry aliases $cmd]]
    if {![tdict exists $_registry cmds $name]} { return {} }
    return [tdict get $_registry cmds $name]
  }

  proc GetCommands {} {
    variable _registry
    if {![tdict exists $_registry cmds]} {return {}}
    return [tdict get $_registry cmds]
  }

}
