HogStruct::Define HogFile {
  field String path
  field String filename
  field String ext
  field String symlink_target
  field String library others
  field String fileset
  field Dict props
  field Dict user
}

namespace eval HogFile {
  proc Constructor {selfVar} {
    upvar 1 $selfVar self
    set path [Get $self path]
    if {$path eq ""} { return }
    if {[Get $self filename] eq ""} { Set self filename [file tail $path] }
    if {[Get $self ext] eq ""} { Set self ext [file extension $path] }
    if {[Get $self symlink_target] eq "" && [file exists $path] && [file type $path] eq "link"} {
      Set self symlink_target [GetLinkedFile $path]
    }
  }

  proc Identity {self} {
    return [list [Get $self path] [Get $self fileset] [Get $self library]]
  }

  proc Merge {selfVar other} {
    upvar 1 $selfVar self
    tobj::RequireStruct HogFile $self
    tobj::RequireStruct HogFile $other
    if {[Identity $self] ne [Identity $other]} { error "cannot merge different file assignments" }
    set props [Get $self props]
    tdict for {key value} [Get $other props] {
      if {![tdict exists $props $key]} { tdict set props $key $value }
    }
    Set self props $props
  }

}
