
namespace eval HogProject {

  HogStruct::Define HogProject {
    field String project_name
    field String project
    field String group_name
    field String design
    field String repo_path
    field String project_path
    field String conf_path
    field String list_path
    field String build_dir
    field String top_name
    field String synth_top_module
    field Dict config; # files[fileset][library][path] -> HogFile
    field Dict files
    field List dependencies
    field Dict tools; # Tool name -> tool-owned project data
    field Dict user
  }

  proc Constructor {selfVar} {
    upvar 1 $selfVar self
    set name [Get $self project_name]
    if {$name eq ""} { return }

    set repoPath [Get $self repo_path]
    if {$repoPath eq ""} { set repoPath . }
    set repoPath [file normalize $repoPath]
    Set self repo_path $repoPath

    set defaults [dict create \
      project [file tail $name] group_name [file dirname $name] design $name \
      project_path [file join $repoPath Top $name] \
      build_dir [file join $repoPath Projects $name] top_name [file rootname [file tail $name]]]

    dict for {key value} $defaults {
      if {[Get $self $key] eq ""} { Set self $key $value }
    }

    set defaults [dict create \
      conf_path [file join [Get $self project_path] "hog.conf"] \
      list_path [file join [Get $self project_path] "list"] \
      synth_top_module "top_[Get $self top_name]"]

    dict for {key value} $defaults {
      if {[Get $self $key] eq ""} { Set self $key $value }
    }
  }

  proc LoadConfig {selfVar} {
    upvar 1 $selfVar self
    tobj::RequireStruct HogProject $self
    set config [tdict create]
    set path [Get $self conf_path]
    if {[file exists $path]} {
      dict for {section values} [ReadConf $path] {
        tdict set config $section [tdict create {*}$values]
      }
    }
    Set self config $config
  }

  proc LoadFiles {selfVar {extPath ""} {tool ""}} {
    upvar 1 $selfVar self
    tobj::RequireStruct HogProject $self

    if {$extPath eq "" && [info exists ::env(HOG_EXTERNAL_PATH)]} { set extPath $::env(HOG_EXTERNAL_PATH) }
    set result [ListFile::Read [Get $self list_path] [Get $self repo_path] $extPath $tool]
    Set self files [dict get $result files]
    Set self dependencies [dict get $result dependencies]
  }

  proc WriteToDisk {self args} {
    tobj::RequireStruct HogProject $self
    set writeLists 1
    set writeConf 1
    set extPath ""
    set tool ""
    while {[llength $args]} {
      set option [lindex $args 0]
      set args [lrange $args 1 end]
      switch -- $option {
        -no-listfiles { set writeLists 0 }
        -no-conf { set writeConf 0 }
        -ext-path - -tool {
          if {![llength $args]} { error "missing value for $option" }
          if {$option eq "-tool"} { set tool [lindex $args 0] } else { set extPath [lindex $args 0] }
          set args [lrange $args 1 end]
        }
        default { error "unknown write option $option" }
      }
    }
    if {$extPath eq "" && [info exists ::env(HOG_EXTERNAL_PATH)]} { set extPath $::env(HOG_EXTERNAL_PATH) }
    if {$writeConf} {
      set confPath [Get $self conf_path]
      set header $tool
      if {[file exists $confPath]} {
        set channel [open $confPath r]
        set code [catch {set firstLine [gets $channel]} result options]
        close $channel
        if {$code} { return -options $options $result }
        if {[string match {#*} $firstLine]} { set header [string trim [string range $firstLine 1 end]] }
      }
      if {$header eq ""} { error "creating hog.conf requires -tool" }
    }

    if {$writeLists} {
      ListFile::Write [Get $self files] [Get $self list_path] [Get $self repo_path] $extPath $tool
    }
    if {$writeConf} {
      file mkdir [file dirname $confPath]
      if {[WriteConf $confPath [tnative [Get $self config]] $header] eq "1"} { error "could not write $confPath" }
      if {[file size $confPath] == 0} {
        set channel [open $confPath w]
        set code [catch {puts $channel "#$header"} result options]
        close $channel
        if {$code} { return -options $options $result }
      }
    }
    return
  }

  proc GetFiles {self args} {
    tobj::RequireStruct HogProject $self
    if {[llength $args] % 2} { error "expected -fileset name, -library name, or -file regex pairs" }
    set filters {}
    foreach {option pattern} $args {
      if {$option ni {-file -library -fileset}} { error "unknown file filter $option" }
      dict set filters $option $pattern
    }
    set result {}
    set files [Get $self files]
    set filesets [tdict keys $files]
    if {[dict exists $filters -fileset]} { set filesets [list [dict get $filters -fileset]] }
    foreach fileset $filesets {
      if {![tdict exists $files $fileset]} { continue }
      set byLibrary [tdict get $files $fileset]
      set libraries [tdict keys $byLibrary]
      if {[dict exists $filters -library]} { set libraries [list [dict get $filters -library]] }
      foreach library $libraries {
        if {![tdict exists $byLibrary $library]} { continue }
        tdict for {path file} [tdict get $byLibrary $library] {
          if {[dict exists $filters -file] && ![regexp -- [dict get $filters -file] $path]} { continue }
          lappend result $file
        }
      }
    }
    return [tlist create {*}$result]
  }

  proc GetFile {self fileset library path} { Get $self files $fileset $library [file normalize $path] }

  proc GetLibraries {self} {
    set libraries {}
    tdict for {fileset byLibrary} [Get $self files] {
      foreach library [tdict keys $byLibrary] { dict set libraries $library 1 }
    }
    return [tlist createstr {*}[dict keys $libraries]]
  }
  proc GetFilesets {self} { tlist createstr {*}[tdict keys [Get $self files]] }

  proc AddFile {selfVar file} {
    upvar 1 $selfVar self
    tobj::RequireStruct HogProject $self
    tobj::RequireStruct HogFile $file
    set path [file normalize [HogFile::Get $file path]]
    HogFile::Set file path $path
    set fileset [HogFile::Get $file fileset]
    set library [HogFile::Get $file library]
    Set self files $fileset $library $path $file
  }

  proc RemoveFile {selfVar file} {
    upvar 1 $selfVar self
    tobj::RequireStruct HogProject $self
    tobj::RequireStruct HogFile $file
    set path [file normalize [HogFile::Get $file path]]
    set fileset [HogFile::Get $file fileset]
    set library [HogFile::Get $file library]
    if {![Exists $self files $fileset $library $path]} { return }
    Unset self files $fileset $library $path
    if {![tdict size [Get $self files $fileset $library]]} { Unset self files $fileset $library }
    if {![tdict size [Get $self files $fileset]]} { Unset self files $fileset }
  }

  proc SHAFiles {self} {
    set paths {}
    tlist foreachval path [Get $self dependencies] {
      dict set paths $path 1
      if {[file exists $path] && [file type $path] eq "link"} { dict set paths [GetLinkedFile $path] 1 }
    }
    tlist foreach file [GetFiles $self] {
      dict set paths [HogFile::Get $file path] 1
      set target [HogFile::Get $file symlink_target]
      if {$target ne ""} { dict set paths $target 1 }
    }
    return [dict keys $paths]
  }
}
