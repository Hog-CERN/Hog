
namespace eval Tools {

  proc detectActiveTool {} {
    foreach ns [namespace children ::Tools] {
      if {[info commands ${ns}::IsActive] eq ""} continue
      if {[catch {set result [${ns}::IsActive]} err]} continue
      if {$result} {
        return $ns
      }
    }
    return ""
  }

  proc PrintTools {} {
    puts "=================================================="
    puts "  Loaded Tools"
    puts "=================================================="
    set tools [namespace children ::Tools]
    if {[llength $tools] == 0} {
      puts "  (none)"
    } else {
      foreach ns $tools {
        ${ns}::_printTool
      }
    }
    puts "=================================================="
  }


  proc Launch {tool} {
    if {[string first "::" $tool] >= 0} {
      set tool_ns $tool
    } else {
      set tool_ns ""
      foreach ns [namespace children ::Tools] {
        if {[string tolower [namespace tail $ns]] eq [string tolower $tool]} {
          set tool_ns $ns
          break
        }
      }
    }
    if {$tool_ns eq "" || [info commands ${tool_ns}::Launch] eq ""} {
      Msg Error "Tool '$tool' not found or has no Launch proc"
      return
    }
    if {[catch {${tool_ns}::Launch} err]} {
      Msg Error "Failed to launch tool '$tool': $err"
    }
  }

  proc RegisterFromDir {dir} {
    Msg Debug "Loading tools from $dir"
    if {![file isdirectory $dir]} { return }
    foreach f [lsort [glob -nocomplain -directory $dir *.tcl]] {
      if {[catch {namespace eval :: [list source $f]} err]} {
        Msg Warning "failed to source [file tail $f]: $err"
        continue
      }
    }


    set _required_procs {IsActive Launch Initialize}
    foreach ns [namespace children ::Tools] {
      if {[catch {set m [namespace eval $ns {variable Manifest; set Manifest}]} err]} {
        Msg Warning "[namespace tail $ns] does not define a Manifest, skipping"
        namespace delete $ns
        continue
      }
      #TODO: if manifest does exist, should probably check for a set of required fields

      set missing {}
      foreach required $_required_procs {
        if {[info commands ${ns}::${required}] eq ""} {
          lappend missing $required
        }
      }
      if {[llength $missing] > 0} {
        Msg Warning "[namespace tail $ns] is missing required procs: [join $missing {, }], skipping"
        namespace delete $ns
        continue
      }

      InjectCommonProcs $ns

      if {[dict exists $m Flows]} {
        Flow::RegisterFlowDict $ns [dict get $m Flows]
      }
    }
  }

  proc Init {} {
    set active [detectActiveTool]
    if {$active ne ""} {
      ::ActiveTool::Set $active
    }
  }

  proc GetToolForProject {project top_path} {
    set conf [file join $top_path $project hog.conf]
    if {![file exists $conf]} {
      Msg Error "hog.conf not found for project '$project' at $conf"
      return ""
    }
    set ide_name_and_ver [string tolower [GetIDEFromConf $conf]]
    set ide_name [lindex [regexp -all -inline {\S+} $ide_name_and_ver] 0]
    foreach ns [namespace children ::Tools] {
      if {[catch {set m [${ns}::GetManifest]} err]} { continue }
      if {![dict exists $m ref_names]} { continue }
      foreach iname [dict get $m ref_names] {
        if {[string tolower $iname] eq $ide_name} {
          return $ns
        }
      }
    }
    Msg Error "No loaded tool matches IDE '$ide_name' (from $conf)"
    return ""
  }

  # we can inject procs into each tool's namespace to provide some common functionality
  # let's use use calls like Tools::Vivado::GetManifest and not have to define these for each tool
  proc InjectCommonProcs {tool_ns} {
    namespace eval $tool_ns {

      proc Supports {feature} {
        variable Manifest
        if {[dict exists $Manifest features $feature]} {
          return 1
        }
        return 0
      }

      proc GetManifest {} {
        variable Manifest
        return $Manifest
      }

      proc Has {method} {
        return [expr {[info commands [namespace current]::${method}] ne ""}]
      }

      proc _printTool {} {
        variable Manifest
        set injected {Has Supports GetManifest _printTool}
        set tool_name [namespace tail [namespace current]]

        set methods {}
        foreach cmd [lsort [info commands [namespace current]::*]] {
          set m [namespace tail $cmd]
          if {$m ni $injected && [string index $m 0] ne "_"} {
            lappend methods $m
          }
        }

        puts "\[$tool_name\]"
        puts "  Manifest: $Manifest"
        puts "  Methods: [join $methods {, }]"
      }
    }
  }
}




# Namespace wrapper around the current tool, should use this instead 
# of tool specific calls in most cases:
namespace eval ActiveTool {
  variable tool "tclsh"
  variable _fixed_procs {Set CurrentTool Refresh}
  variable _skip_procs {}


  proc CurrentTool {} {
    variable tool
    return $tool
  }

  proc Refresh {} {
    variable tool
    Set $tool
  }

  proc Set {tool_ns} {
    variable tool
    variable _fixed_procs
    variable _skip_procs

    foreach cmd [info commands ::ActiveTool::*] {
      set name [namespace tail $cmd]
      if {$name ni $_fixed_procs} {
        rename ::ActiveTool::$name ""
      }
    }

    if {$tool_ns eq ""} {
      return
    }

    set tool $tool_ns

    foreach tool_proc [info commands ${tool_ns}::*] {
      set name [namespace tail $tool_proc]

      if {[string index $name 0] eq "_"} continue
      if {$name in $_skip_procs}   continue
      if {$name in $_fixed_procs} continue

      # we can generate a wrapper around the actual call to add logging or 
      # other functionality without modifying the tool's code
      set proc_body [string map [list @_TOOL $tool_ns @_PROC_NAME $name] {
        Msg Debug "Calling @_TOOL::@_PROC_NAME with args: $args"
        set result [@_TOOL::@_PROC_NAME {*}$args]
        Msg Debug "Result from @_TOOL::@_PROC_NAME $result"
        return $result
      }]

      proc ::ActiveTool::$name {args} $proc_body
    }
  }
}
