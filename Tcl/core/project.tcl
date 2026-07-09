# HogProjectObj
#   project_name     tstr  - full path relative to Top/, e.g. "group/myproj"
#   project          tstr  - file tail (e.g. "myproj")
#   group_name       tstr  - directory group (file dirname of project_name)
#   design           tstr  - same as project_name (legacy compat)
#   project_path     tstr  - absolute path to Top/<project_name>
#   conf_path        tstr  - absolute path to hog.conf
#   list_path        tstr  - absolute path to the list/ directory
#   build_dir        tstr  - absolute path to Projects/<project_name>
#   top_name         tstr  - file rootname of project tail
#   synth_top_module tstr  - conventional RTL top ("top_<top_name>")
#   config           tdict - hog.conf sections (ide, parameters, generics…)
#   list_files       tlist - absolute paths to .src/.sim/.con/.ipb files
#   libraries        tlist - union of all library names across parsed files
#   filesets         tlist - union of all fileset names
#   project_files    tdict - path -> HogFileObj for every parsed source file
#   user             tdict - reserved for caller/tool metadata; Hog never writes here

namespace eval HogProjectObj {

  proc New {project_name {repo_path .} args} {
    set top_path  [file normalize [file join $repo_path Top]]
    set proj_path [file normalize [file join $top_path $project_name]]
    set top_name  [file rootname [file tail $project_name]]

    set p [tdict create \
      project_name     [tstr $project_name] \
      project          [tstr [file tail $project_name]] \
      group_name       [tstr [file dirname $project_name]] \
      design           [tstr $project_name] \
      project_path     [tstr $proj_path] \
      conf_path        [tstr [file normalize [file join $proj_path hog.conf]]] \
      list_path        [tstr [file normalize [file join $proj_path list]]] \
      build_dir        [tstr [file normalize [file join $repo_path Projects $project_name]]] \
      top_name         [tstr $top_name] \
      synth_top_module [tstr "top_${top_name}"] \
      config           [tdict create] \
      list_files       [tlist create] \
      libraries        [tlist create] \
      filesets         [tlist create] \
      project_files    [tdict create] \
      user             [tdict create] \
    ]
    if {[dict exists $args -config]}        { tdict set p config        [dict get $args -config] }
    if {[dict exists $args -user]}          { tdict set p user          [dict get $args -user] }
    return $p
  }

}


namespace eval Projects {

  # Load a project from disk — reads hog.conf and returns a HogProjectObj.
  proc GetInfo {project_name {repo_path .}} {
    set p         [HogProjectObj::New $project_name $repo_path]
    set conf_path [tdict getval $p conf_path]
    if {[file exists $conf_path]} {
      set PROPERTIES [ReadConf $conf_path]
      dict for {section content} $PROPERTIES {
        dict for {key val} $content {
          Msg Debug "Setting property $key to $val for section $section"
          tdict set p config $section $key $val
        }
      }
    }
    return $p
  }

  # Return a tdict of all projects in the repo (project_name → HogProjectObj).
  proc GetAll {{repo_path .}} {
    set top_path [file normalize $repo_path/Top]
    set ret [tdict create]
    foreach conf [lsort [findFiles [file normalize $top_path] hog.conf]] {
      set name [Relative $top_path [file dirname $conf]]
      tdict set ret $name [GetInfo $name $repo_path]
    }
    return $ret
  }

  # Populate list_files, libraries, filesets, project_files on hog_project.
  # Mutates the project dict in-place via upvar.
  # This lets us lazy load the files as needed rather than parsing every 
  # projects listfile at once
  proc LoadListFiles {hog_projectVar {ext_path ""} {tool ""}} {
    upvar 1 $hog_projectVar p

    set list_path [tdict getval $p list_path]
    set repo_path [Repo::Get repo_path]

    if {$tool eq ""} {
      set _conf [file normalize [file join [file dirname $list_path] hog.conf]]
      if {[file exists $_conf]} {
        set tool [string tolower [lindex [GetIDEFromConf $_conf] 0]]
      }
    }

    foreach list_file [lsort [glob -nocomplain -directory $list_path "*"]] {
      set ext [file extension $list_file]
      if {$ext ni {.src .con .sim .ext .ipb}} { continue }
      if {$ext eq ".ext" && $ext_path eq ""} {
        Msg Warning "Skipping $list_file: no ext_path provided."
        continue
      }
      set root_path [expr {$ext eq ".ext" ? $ext_path : $repo_path}]
      set lib       [file rootname [file tail $list_file]]
      set lf_list   [tdict get $p list_files]
      tlist append lf_list [tstr [file normalize $list_file]]
      tdict set p list_files $lf_list
      _ParseListFile p $list_file $root_path $lib "" $tool
    }

    # Auto-discover HLS components in hog.conf without a .src list file.
    set proj_conf [file normalize [file join [file dirname $list_path] hog.conf]]
    if {[file exists $proj_conf]} {
      set hls_configs [GetHlsConfigsFromProjConf $proj_conf $repo_path]
      set tracked [dict create]
      tdict for {fp _} [tdict get $p project_files] { dict set tracked $fp 1 }
      dict for {comp_name cfg_abs} $hls_configs {
        if {[dict exists $tracked $cfg_abs]} { continue }
        set lib_name "${comp_name}.src"
        _AddFile p [ListFile::HogFileObj::New $cfg_abs -library $lib_name -fileset sources_1]
        dict set tracked $cfg_abs 1
        foreach hls_extra [ExpandHlsConfigFiles $cfg_abs] {
          if {[dict exists $tracked $hls_extra]} { continue }
          _AddFile p [ListFile::HogFileObj::New $hls_extra -library $lib_name -fileset sources_1]
          dict set tracked $hls_extra 1
        }
      }
    }
  }

  # Merge a HogFileObj into the project's libraries/filesets/project_files.
  proc _AddFile {hog_projectVar hog_file} {
    upvar 1 $hog_projectVar p

    set path  [tobj value [tdict get $hog_file path]]
    set libs  [tdict get $p libraries]
    set fsets [tdict get $p filesets]
    set files [tdict get $p project_files]

    tlist foreach lib [tdict get $hog_file libraries] {
      if {![tlist elemExists $libs [tobj value $lib]]} { tlist append libs $lib }
    }
    tlist foreach fs [tdict get $hog_file filesets] {
      if {![tlist elemExists $fsets [tobj value $fs]]} { tlist append fsets $fs }
    }

    if {[tdict exists $files $path]} {
      set existing [tdict get $files $path]
      ListFile::HogFileObj::Merge existing $hog_file
      tdict set files $path $existing
    } else {
      tdict set files $path $hog_file
    }

    tdict set p libraries     $libs
    tdict set p filesets      $fsets
    tdict set p project_files $files
  }

  # Parse a single list file into the project.
  proc _ParseListFile {hog_projectVar list_file path lib fileset tool} {
    upvar 1 $hog_projectVar p

    set ext [file extension $list_file]
    if {$fileset eq ""} {
      switch $ext {
        .sim    { set fileset $lib }
        .con    { set fileset "constrs_1" }
        default { set fileset "sources_1" }
      }
    }

    set fp [open $list_file r]
    set data [ExtractFilesSection [split [read $fp] "\n"]]
    close $fp

    foreach line $data {
      if {[regexp {^[\t\s]*$} $line] || [regexp {^[\t\s]*#} $line]} { continue }

      set tokens  [regexp -all -inline {\S+} $line]
      set srcfile "$path/[lindex $tokens 0]"
      set srcfiles [glob -nocomplain $srcfile]

      if {$srcfiles != $srcfile && ![string equal $srcfiles ""]} {
        Msg Debug "Wildcard source expanded from $srcfile to $srcfiles"
      } elseif {![file exists $srcfile]} {
        Msg CriticalWarning "File: $srcfile (from list file: $list_file) does not exist."
        continue
      }

      foreach vhdlfile $srcfiles {
        if {![file exists $vhdlfile]} { continue }
        set vhdlfile   [file normalize $vhdlfile]
        set fext       [file extension $vhdlfile]
        set raw_tokens [lrange $tokens 1 end]

        lassign [ListFile::Codec::ExtractMeta $raw_tokens $lib] file_lib ref_path remaining

        if {$fext eq $ext} {
          set ref_path [expr {$ref_path eq "" ? $path : [file normalize $path/$ref_path]}]
          _ParseListFile p $vhdlfile $ref_path $file_lib $fileset $tool
          continue
        }

        if {$fext in {.src .sim .con}} {
          Msg Error "$vhdlfile cannot be included in $list_file; $fext must be their own list file."
        }

        set hog_file [ListFile::Codec::Decode $vhdlfile $ext $file_lib $fileset $remaining $tool]
        _AddFile p $hog_file

        if {$ext eq ".src" && $fext eq ".cfg"} {
          set lib_name [tlist getval [tdict get $hog_file libraries] 0]
          foreach hls_extra [ExpandHlsConfigFiles $vhdlfile] {
            if {$hls_extra eq $vhdlfile} { continue }
            Msg Debug "HLS cfg expansion: adding $hls_extra to $lib_name"
            _AddFile p [ListFile::HogFileObj::New $hls_extra -library $lib_name -fileset $fileset]
          }
        }
      }
    }
  }

  # Query a loaded HogProjectObj's project_files with optional regex filters.
  #
  # Options:
  #   -library <regex>  match files whose library name matches regex
  #   -fileset <regex>  match files whose fileset name matches regex
  #   -file    <regex>  match files whose absolute path matches regex
  #   -symlinks <bool>  if 1 (default), append symlink_target paths (-as paths only)
  #   -as paths|objects return a list of path strings (default) or HogFileObj tdicts
  proc GetProjectFiles {hog_project args} {
    set lib_pat  [expr {[dict exists $args -library]  ? [dict get $args -library]  : ""}]
    set fs_pat   [expr {[dict exists $args -fileset]  ? [dict get $args -fileset]  : ""}]
    set file_pat [expr {[dict exists $args -file]     ? [dict get $args -file]     : ""}]
    set symlinks [expr {[dict exists $args -symlinks] ? [dict get $args -symlinks] : 1}]
    set as       [expr {[dict exists $args -as]       ? [dict get $args -as]       : "objects"}]

    set result [expr {$as eq "tdict" ? [tdict create] : {}}]
    tdict for {fp hog_file} [tdict get $hog_project project_files] {
      if {$lib_pat ne ""} {
        set ok 0
        tlist foreach lib [tdict get $hog_file libraries] {
          if {[regexp -- $lib_pat [tobj value $lib]]} { set ok 1; break }
        }
        if {!$ok} { continue }
      }
      if {$fs_pat ne ""} {
        set ok 0
        tlist foreach fs [tdict get $hog_file filesets] {
          if {[regexp -- $fs_pat [tobj value $fs]]} { set ok 1; break }
        }
        if {!$ok} { continue }
      }
      if {$file_pat ne "" && ![regexp -- $file_pat $fp]} { continue }

      if {$as eq "tdict"} {
        tdict set result $fp $hog_file
      } elseif {$as eq "objects"} {
        lappend result $hog_file
      } else {
        lappend result $fp
        if {$symlinks} {
          set target [tdict getval $hog_file symlink_target]
          if {$target ne ""} { lappend result $target }
        }
      }
    }
    return $result
  }

  # All tracked paths for SHA computation: list files (+ their symlink targets)
  # plus all project_files
  proc SHAFiles {hog_project} {
    set paths {}
    tlist foreachval lf [tdict get $hog_project list_files] {
      lappend paths $lf
      if {[file exists $lf] && [file type $lf] eq "link"} {
        lappend paths [GetLinkedFile $lf]
      }
    }
    lappend paths {*}[GetProjectFiles $hog_project -as paths]
    return $paths
  }
}
