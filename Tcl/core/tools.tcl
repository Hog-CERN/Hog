
namespace eval Tools {

  # Register bare tool command
  Commands::RegisterCommand TOOL {
    description  "Every registered tool. Usage: <tool>" 
    aliases tools 
  }

  # Manifest fields - identity/metadata only.
  variable _fields {
    { name        ""  required}
    { ref_name   ""   optional}
    { vendor      ""  optional}
    { description ""  optional}
    { version     ""  optional}
    { features    {}  optional}
    { custom      0   optional}
    { _source_path "" optional}
    { _git         {} optional}
  }

  proc _validate_manifest {tool_name raw_dict} {
    variable _fields
    set norm [dict create]
    dict for {k v} $raw_dict { dict set norm [string tolower $k] $v }
    set raw_dict $norm
    set result [dict create]
    foreach field $_fields {
      lassign $field fname fdefault frequired
      if {[dict exists $raw_dict $fname]} {
        dict set result $fname [dict get $raw_dict $fname]
      } elseif {$frequired eq "required"} {
        error "Tool '$tool_name': missing required field '$fname'"
      } else {
        dict set result $fname $fdefault
      }
    }
    return $result
  }

  # The booting parent stamps HOG_ACTIVE_TOOL before exec'ing an IDE child, so a
  # fresh process just reads its identity instead of trying to figure it out.
  # In-process tools never reach here - their Launch calls ActiveTool::Set direct.
  proc detectActiveTool {} {
    if {![info exists ::env(HOG_ACTIVE_TOOL)] || $::env(HOG_ACTIVE_TOOL) eq ""} { return "" }
    return [ResolveAlias $::env(HOG_ACTIVE_TOOL)]
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


  # Throws on failure (errorcode {HOG_TOOL_FAILED <exit>}) so a failed IDE child
  # can't surface as a success. The top-level entry maps that code to its own
  # exit status - see launch.tcl.
  proc Launch {tool} {
    set tool_ns [ResolveAlias $tool]
    if {$tool_ns eq "" || [info commands ${tool_ns}::Launch] eq ""} {
      return -code error -errorcode {HOG_TOOL_FAILED 1} \
        "Tool '$tool' not found or has no Launch proc"
    }
    # Stamp identity for any IDE child this Launch execs; restore so a nested
    # boot can't leave the parent mislabeled.
    set _had  [info exists ::env(HOG_ACTIVE_TOOL)]
    set _prev [expr {$_had ? $::env(HOG_ACTIVE_TOOL) : ""}]
    set ::env(HOG_ACTIVE_TOOL) [string tolower [namespace tail $tool_ns]]
    set _code [catch {${tool_ns}::Launch} result _opts]
    if {$_had} { set ::env(HOG_ACTIVE_TOOL) $_prev } else { unset ::env(HOG_ACTIVE_TOOL) }
    if {$_code} {
      # A non-zero IDE child makes exec throw with -errorcode
      # {CHILDSTATUS <pid> <exit>}; carry that exit code up rather than
      # flattening every failure to 1.
      set _child 1
      if {[dict exists $_opts -errorcode]} {
        set _ec [dict get $_opts -errorcode]
        if {[lindex $_ec 0] eq "CHILDSTATUS" && [llength $_ec] >= 3} {
          set _child [lindex $_ec 2]
        }
      }
      return -code error -errorcode [list HOG_TOOL_FAILED $_child] \
        "Tool '$tool' failed (exit $_child): $result"
    }
    return $result
  }

  proc ResolveAlias {alias} {
    if {$alias eq ""} { return "" }
    if {[string first "::" $alias] >= 0} {
      return [expr {[namespace exists $alias] ? $alias : ""}]
    }
    set needle [string tolower $alias]
    foreach ns [namespace children ::Tools] {
      if {[string tolower [namespace tail $ns]] eq $needle} { return $ns }
      if {[catch {set m [${ns}::GetManifest]} err]} { continue }
      if {[dict exists $m ref_name]} {
        foreach iname [dict get $m ref_name] {
          if {[string tolower $iname] eq $needle} { return $ns }
        }
      }
    }
    return ""
  }

  # Register tools from a directory
  # looks for ./<tool>/<tool>.tcl or  ./<tool>/main.tcl
  # Pass -custom to mark every tool sourced from this dir as user-defined.
  # Each file self-registers via RegisterTool
  proc RegisterFromDir {dir args} {
    Msg Debug "Loading tools from $dir"
    if {![file isdirectory $dir]} { return }
    set is_custom [expr {"-custom" in $args}]
    foreach sub [lsort [glob -nocomplain -type d -directory $dir *]] {
      set tool_name [file tail $sub]
      set entry [file join $sub "$tool_name.tcl"]
      if {![file exists $entry]} {
        set entry [file join $sub "main.tcl"]
      }
      if {![file exists $entry]} {
        Msg Warning "Tool directory '$tool_name' has no '$tool_name.tcl' or 'main.tcl', skipping"
        continue
      }
      Hog::SourceFile $entry $is_custom "tool '$tool_name'"
    }
  }

  # Git commit/tag info for whatever entry file a tool was sourced from.
  proc _gitInfoFor {entry} {
    set git_info { commit "unknown" date "unknown" ver "unknown" }
    if {$entry eq ""} { return $git_info }
    set cwd [pwd]
    cd [file dirname $entry]
    set git_ret [GitRet [list log -n 1 --decorate "--format=commit {%h} tag {%d} date {%ad}" --date=short] .]
    cd $cwd

    if {[lindex $git_ret 0] == 0 && [llength [lindex $git_ret 1]] > 0} {
      set git_info [lindex $git_ret 1]
      set _hog_tag ""
      set _ver_tag ""
      foreach t [split [dict get $git_info tag] ","] {
        set t [string trim $t " \t()"]
        if {$_hog_tag eq "" && [regexp {^tag:\s+(Hog\d{4}\.\d+(?:\.\d+)*)$} $t -> _found]} {
          set _hog_tag $_found
        } elseif {$_ver_tag eq "" && [regexp {^tag:\s+(v\d+(?:\.\d+)+)$} $t -> _found]} {
          set _ver_tag $_found
        }
      }
      if {$_hog_tag ne ""}      { dict set git_info ver $_hog_tag } \
      elseif {$_ver_tag ne ""} { dict set git_info ver $_ver_tag } \
      else                     { dict set git_info ver "unknown" }
    }
    return $git_info
  }

  # Registers the tool namespace calling this 
  # creates a command group for the tool, 
  # injects RegisterCommand/RegisterFlow/RegisterStage
  proc RegisterTool {ns manifest_dict} {
    set tool_name [namespace tail $ns]
    if {[catch {_validate_manifest $tool_name $manifest_dict} validated]} {
      Msg Warning "Skipping tool '$tool_name': $validated"
      return
    }
    set is_custom [set ::Hog::_loading_custom]
    dict set validated custom       $is_custom
    dict set validated _source_path [set ::Hog::_loading_source]
    dict set validated _git         [_gitInfoFor [set ::Hog::_loading_source]]

    namespace eval $ns [list variable Manifest $validated]
    InjectCommonProcs $ns

    set tool_key    [string toupper $tool_name]
    set tool_canon  "TOOL.$tool_key"
    set ref_aliases [expr {[dict exists $validated ref_name] ? [dict get $validated ref_name] : {}}]

    Commands::RegisterCommand $tool_canon [dict create \
      description [dict get $validated description] \
      aliases     $ref_aliases \
    ] {*}[expr {$is_custom ? "-custom" : ""}] -source [set ::Hog::_loading_source]

    Commands::AddAlias $tool_key $tool_canon
    foreach a $ref_aliases { Commands::AddAlias $a $tool_canon }
  }

  # Register Stage to tool's command tree, registered under TOOL.<TOOL>.STAGE
  #
  #   RegisterStage Implement {produces {...} requires {...}}
  #   RegisterStage Implement {produces {...} requires {...}} { <body> }
  # 
  proc RegisterStage {tool_ns name spec args} {
    if {[llength $args] > 1} {
      Msg Warning "RegisterStage '$name': expected 'name spec ?body?'"
      return
    }
    set tool_short [string tolower [namespace tail $tool_ns]]
    if {[llength $args] == 1} {
      proc ${tool_ns}::${name} {} [lindex $args 0]
    }

    set raw [dict create \
      script        "${tool_ns}::${name}" \
      ide           $tool_short \
      requires_proj true \
    ]

    foreach k {description help aliases options produces requires} {
      if {[dict exists $spec $k]} { dict set raw $k [dict get $spec $k] }
    }

    set tool_key    [string toupper [namespace tail $tool_ns]]
    set stage_group "TOOL.$tool_key.STAGE"

    if {[Commands::GetCommand $stage_group] eq {}} {
      Commands::RegisterCommand $stage_group [dict create description \
        "Individual stages of [namespace tail $tool_ns]'s flows.\
         Usage: $tool_short stage <stage> <project>"]
    }
    Commands::RegisterCommand "TOOL.$tool_key.STAGE.$name" $raw
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
      if {![dict exists $m ref_name]} { continue }
      foreach iname [dict get $m ref_name] {
        if {[string tolower $iname] eq $ide_name} {
          return $ns
        }
      }
    }
    Msg Warning "No loaded tool matches IDE '$ide_name' (from $conf)"
    return ""
  }

  # we can inject procs into each tool's namespace to provide some common functionality
  # let's use use calls like Tools::Vivado::GetManifest and not have to define these for each tool
  proc InjectCommonProcs {tool_ns} {
    namespace eval $tool_ns {

      if {[info commands Launch] eq ""} {
        proc Launch {} {
          ActiveTool::Set [namespace current]
          return "no_ide"
        }
      }

      if {[info commands Initialize] eq ""} {
        proc Initialize {} {}
      }

      # Injected into tool's namespace to simplify registration process
      # key can be dotted -> ping.pong registers the pong command under ping
      proc RegisterCommand {key raw_dict} {
        set ns [namespace current]
        if {![dict exists $raw_dict ide]} { dict set raw_dict ide [string tolower [namespace tail $ns]] }
        Commands::RegisterCommand "TOOL.[string toupper [namespace tail $ns]].$key" $raw_dict
      }

      proc RegisterFlow {key raw_dict} {
        Flow::RegisterFlow [namespace current] $key $raw_dict
      }

      # RegisterStage <name> {spec} declares against an existing proc;
      # RegisterStage <name> {spec} {body} also defines it.
      proc RegisterStage {name spec args} {
        Tools::RegisterStage [namespace current] $name $spec {*}$args
      }

      proc GetManifest {} {
        variable Manifest
        return $Manifest
      }

      proc Has {method} {
        return [expr {[info commands [namespace current]::${method}] ne ""}]
      }

      proc _printTool {} {
        #TODO: Clean this up probably 
        variable Manifest
        set injected {Has GetManifest _printTool}
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



# Which tool's process we are in - "tclsh" at the top level, or a tool namespace
# once an IDE child has booted (or an in-process tool has flipped itself active).
# Identity only; stage resolution goes through the command tree
namespace eval ActiveTool {
  variable tool "tclsh"

  proc CurrentTool {} {
    variable tool
    return $tool
  }

  proc Set {tool_ns} {
    variable tool
    if {$tool_ns ne ""} { set tool $tool_ns }
  }
}
