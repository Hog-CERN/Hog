
namespace eval ListFile {

  # HogFileObj
  #
  # Shape (tdict):
  #   path           tstr   — absolute path to the file
  #   filename       tstr   — file name only
  #   ext            tstr   — file extension
  #   symlink_target tstr   — resolved real path when file is a symlink; "" otherwise
  #   libraries  tlist  — library names this file belongs to
  #   filesets   tlist  — fileset names this file belongs to
  #   props      tdict  — key, value property pairs
  #   user       tdict  — open namespace for caller-defined metadata
  #
  namespace eval HogFileObj {

    proc New {path args} {
      set ext [file extension $path]
      set is_link [expr {[file exists $path] && [file type $path] eq "link"}]
      set hog_file [tdict create \
        path           [tstr $path] \
        filename       [tstr [file tail $path]] \
        ext            [tstr $ext] \
        symlink_target [tstr [expr {$is_link ? [GetLinkedFile $path] : ""}]] \
        libraries [tlist create] \
        filesets  [tlist create] \
        props     [tdict create] \
        user      [tdict create] \
      ]
      if {[dict exists $args -library]} {
        tdict set hog_file libraries [tlist create [tstr [dict get $args -library]]]
      }
      if {[dict exists $args -fileset]} {
        tdict set hog_file filesets [tlist create [tstr [dict get $args -fileset]]]
      }
      if {[dict exists $args -props]} {
        tdict set hog_file props [dict get $args -props]
      }
      if {[dict exists $args -user]} {
        tdict set hog_file user [dict get $args -user]
      }
      return $hog_file
    }

    # Merge src into dst: append missing libraries/filesets, add missing props.
    proc Merge {dstVar src} {
      upvar 1 $dstVar dst
      tlist foreach lib [tdict get $src libraries] {
        if {![tlist elemExists [tdict get $dst libraries] [tobj value $lib]]} {
          tdict lappend dst libraries $lib
        }
      }
      tlist foreach fs [tdict get $src filesets] {
        if {![tlist elemExists [tdict get $dst filesets] [tobj value $fs]]} {
          tdict lappend dst filesets $fs
        }
      }
      set dst_props [tdict get $dst props]
      tdict for {k v} [tdict get $src props] {
        if {![tdict exists $dst_props $k]} { tdict set dst_props $k $v }
      }
      tdict set dst props $dst_props
    }

    # Filter a tdict of HogFileObjs (path -> HogFileObj).
    # Returns a new tdict containing only entries that satisfy all given patterns.
    #
    # Options:
    #   -library <regex>   include only files whose library name matches
    #   -fileset <regex>   include only files whose fileset matches
    #   -file    <regex>   include only files whose path matches
    proc Filter {hog_files args} {
      set lib_pat  [expr {[dict exists $args -library] ? [dict get $args -library] : ""}]
      set fs_pat   [expr {[dict exists $args -fileset] ? [dict get $args -fileset] : ""}]
      set file_pat [expr {[dict exists $args -file]    ? [dict get $args -file]    : ""}]

      set result [tdict create]
      tdict for {path fobj} $hog_files {
        if {$lib_pat ne ""} {
          set ok 0
          tlist foreach lib [tdict get $fobj libraries] {
            if {[regexp -- $lib_pat [tobj value $lib]]} { set ok 1; break }
          }
          if {!$ok} { continue }
        }
        if {$fs_pat ne ""} {
          set ok 0
          tlist foreach fs [tdict get $fobj filesets] {
            if {[regexp -- $fs_pat [tobj value $fs]]} { set ok 1; break }
          }
          if {!$ok} { continue }
        }
        if {$file_pat ne "" && ![regexp -- $file_pat $path]} { continue }
        tdict set result $path $fobj
      }
      return $result
    }
  }

  namespace eval Codec {
    variable _table {}

    # Register a codec for a file extension pattern.
    #
    #   library_rule  should return a string to set library
    #
    #   tool          Scope this codec to a specific tool (default: global).
    #
    #   decoder       Dict with optional keys:
    #     pre         Script. Implicit locals: hog_file (HogFileObj), raw_tokens, file_lib, list_ext.
    #                 Set `_done 1` to skip built-in decode.
    #     post        Script. Implicit locals: hog_file (HogFileObj), raw_tokens. 
    #                 Called after library + prop parsing.
    #   encoder       Dict with optional keys:
    #     pre         Script. Implicit locals: hog_file (HogFileObj), tokens (list).
    #                 Set `_done 1` to skip default prop encoding.
    #     post        Script. Implicit locals: hog_file (HogFileObj), tokens (list).
    #                 Called after default encoding to add/modify tokens.
    #
    # Every field is optional. Last registered codec wins on pattern+tool conflict.
    proc RegisterCodec {pattern codec_dict} {
      variable _table
      set row [dict create \
        pattern      $pattern \
        library_rule [expr {[dict exists $codec_dict library_rule] ? [dict get $codec_dict library_rule] : ""}] \
        tool         [expr {[dict exists $codec_dict tool]         ? [dict get $codec_dict tool]         : ""}] \
        decoder_pre  "" \
        decoder_post "" \
        encoder_pre  "" \
        encoder_post "" \
      ]
      if {[dict exists $codec_dict decoder]} {
        set dec [dict get $codec_dict decoder]
        if {[dict exists $dec pre]}  { dict set row decoder_pre  [dict get $dec pre] }
        if {[dict exists $dec post]} { dict set row decoder_post [dict get $dec post] }
      }
      if {[dict exists $codec_dict encoder]} {
        set enc [dict get $codec_dict encoder]
        if {[dict exists $enc pre]}  { dict set row encoder_pre  [dict get $enc pre] }
        if {[dict exists $enc post]} { dict set row encoder_post [dict get $enc post] }
      }
      lappend _table $row
    }

    # Find the best matching codec for a file extension + tool.
    # Tool-specific beats global; last registered wins within each tier.
    # Returns the codec dict, or "" if nothing matches.
    proc _FindCodec {ext tool} {
      variable _table
      set global_match ""
      set tool_match   ""
      foreach row $_table {
        set pattern  [dict get $row pattern]
        set row_tool [dict get $row tool]
        if {![regexp -- $pattern $ext]}           { continue }
        if {$row_tool ne "" && $row_tool ne $tool} { continue }
        if {$row_tool ne ""} { set tool_match $row } else { set global_match $row }
      }
      return [expr {$tool_match ne "" ? $tool_match : $global_match}]
    }

    # Check if a codec is registered for the given file.
    proc IsRegistered {file {tool ""}} {
      return [expr {[_FindCodec [file extension $file] $tool] ne ""}]
    }

    # Extract lib= and path= meta tokens. Returns {file_lib ref_path remaining}.
    proc ExtractMeta {raw_tokens default_lib} {
      set file_lib  $default_lib
      set ref_path  ""
      set remaining {}
      foreach p $raw_tokens {
        regsub { *= *} $p "=" p
        if {[string match "lib=*" $p]} {
          set file_lib [string range $p 4 end]
        } elseif {[string match "path=*" $p]} {
          set ref_path [string range $p 5 end]
        } else {
          lappend remaining $p
        }
      }
      return [list $file_lib $ref_path $remaining]
    }

    # Parse raw property tokens into a tdict.
    # Bare words become key="1"; 
    # key=value pairs become key="value";
    # Values containing commas become a tlist of tstr
    proc ParseTokens {raw_tokens} {
      set props [tdict create]
      foreach p $raw_tokens {
        regsub { *= *} $p "=" p
        set pos [string first "=" $p]
        if {$pos == -1} {
          tdict set props $p [tstr "1"]
        } else {
          set key [string range $p 0 [expr {$pos-1}]]
          set val [string range $p [expr {$pos+1}] end]
          if {[string first "," $val] >= 0} {
            set items [list]
            foreach item [split $val ","] {
              set item [string trim $item]
              if {$item ne ""} { lappend items [tstr $item] }
            }
            tdict set props $key [tlist create {*}$items]
          } else {
            tdict set props $key [tstr $val]
          }
        }
      }
      return $props
    }


    # Decode a list-file entry into a HogFileObj.
    # Scripts in the codec run in THIS proc's local scope — they can read/mutate
    # $hog_file, $raw_tokens, $file_lib, $list_ext directly (no upvar needed).
    proc Decode {file list_ext file_lib fileset raw_tokens tool} {
      set ext   [file extension $file]
      set codec [_FindCodec $ext $tool]
      set hog_file [ListFile::HogFileObj::New $file -fileset $fileset]

      if {$codec eq ""} {
        tdict set hog_file libraries [tlist create [tstr "others.src"]]
        tdict set hog_file props [ParseTokens $raw_tokens]
        return $hog_file
      }

      # Decoder pre: set `_done 1` to skip built-in decode.
      set _done 0
      set pre [dict get $codec decoder_pre]
      if {$pre ne ""} { eval $pre }
      if {$_done} { return $hog_file }

      # Built-in: apply library_rule and parse prop tokens.
      set lib_rule [dict get $codec library_rule]
      if {$lib_rule ne ""} {
        tdict set hog_file libraries [tlist create [tstr [subst $lib_rule]]]
      }
      tdict set hog_file props [ParseTokens $raw_tokens]

      # Decoder post: modify entry after built-in.
      set post [dict get $codec decoder_post]
      if {$post ne ""} { eval $post }

      return $hog_file
    }

    # Encode a single prop key+value into one list-file token.
    # Flag (value "1"): bare key.
    # List: key=item1,item2,...
    # Scalar: key=value.
    proc EncodeProp {key v} {
      if {[tobj type $v] eq "List"} {
        set items [list]
        tlist foreach item $v { lappend items [tobj value $item] }
        return "${key}=[join $items ","]"
      }
      set val [tobj value $v]
      if {$val eq "1"} { return $key }
      return "${key}=${val}"
    }

    # Convert a HogFileObj's props to a list of raw tokens.
    proc EncodeProps {hog_file {tool ""}} {
      set ext   [tdict getval $hog_file ext]
      set codec [_FindCodec $ext $tool]
      set tokens {}

      # Encoder pre: set `_done 1` to skip default prop encoding.
      set _done 0
      set pre [expr {$codec ne "" ? [dict get $codec encoder_pre] : ""}]
      if {$pre ne ""} { eval $pre }
      if {$_done} { return $tokens }

      # Default prop encoding via EncodeProp (flag / list / scalar).
      tdict for {k v} [tdict get $hog_file props] {
        lappend tokens [EncodeProp $k $v]
      }

      # Encoder post: add/modify tokens after default.
      set post [expr {$codec ne "" ? [dict get $codec encoder_post] : ""}]
      if {$post ne ""} { eval $post }

      return $tokens
    }

    # Encode a HogFileObj into a single list-file line.
    proc Encode {hog_file root_path list_ext {default_lib ""} {tool ""}} {
      set path [tdict getval $hog_file path]
      set rel  [Relative $root_path $path]
      set tokens [list $rel]

      # lib= token: emit when the stored library differs from the default.
      set lib_tlist [tdict get $hog_file libraries]
      if {[tlist length lib_tlist] > 0 && $default_lib ne ""} {
        set lib_name [tlist getval $lib_tlist 0]
        if {$lib_name ne "${default_lib}${list_ext}"} {
          set lib_base [string range $lib_name 0 end-[string length $list_ext]]
          if {$lib_base ne ""} { lappend tokens "lib=${lib_base}" }
        }
      }

      set tokens [concat $tokens [EncodeProps $hog_file $tool]]
      return [join $tokens " "]
    }

    ############################################################################
    # Built in Codecs
    ############################################################################

    RegisterCodec {\.vhdl?$} {
      library_rule {${file_lib}${list_ext}}
      decoder {
        post {
          set props [tdict get $hog_file props]
          set std "2008"
          foreach year {93 1987 1993 2008 2019} {
            if {[tdict exists $props $year]} {
              set std $year 
              set props [tdict remove $props $year]
              break
            }
          }
          tdict set props std [tstr $std]
          tdict set hog_file props $props
        }
      }
      encoder {
        pre {
          tdict for {k v} [tdict get $hog_file props] {
            if {$k eq "std"} {
              lappend tokens [tobj value $v]
            } else {
              lappend tokens [EncodeProp $k $v]
            }
          }
          set _done 1
        }
      }
    }

    RegisterCodec {\.v$}                 {library_rule {${file_lib}${list_ext}}}
    RegisterCodec {\.svp?$}              {library_rule {${file_lib}${list_ext}}}
    RegisterCodec {\.xcix?$|\.ip$|\.bd$} {library_rule ips.src}

    RegisterCodec {\.xml$} {
      library_rule xml.ipb
      decoder {
        post {
          set props [tdict get $hog_file props]
          if {[llength $raw_tokens] > 0} {
            tdict set props generated_vhd [tstr [lindex $raw_tokens 0]]
            set bare [lindex $raw_tokens 0]
            if {[tdict exists $props $bare]} { 
              set props [tdict remove $props $bare]
              }
          }
          tdict set hog_file props $props
        }
      }
      encoder {
        pre {
          set props [tdict get $hog_file props]
          if {[tdict exists $props generated_vhd]} {
            lappend tokens [tdict getval $props generated_vhd]
          }
          tdict for {k v} $props {
            if {$k eq "generated_vhd"} { continue }
            lappend tokens [EncodeProp $k $v]
          }
          set _done 1
        }
      }
    }

    RegisterCodec {\.xdc$} {library_rule {[expr {$list_ext eq ".con" ? "sources.con" : "others.src"}]}}
    RegisterCodec {\.sdc$} {library_rule {[expr {$list_ext eq ".con" ? "sources.con" : "others.src"}]}}
    RegisterCodec {\.tcl$} {library_rule {[expr {$list_ext eq ".con" ? "sources.con" : $list_ext eq ".sim" ? "others.sim" : "others.src"}]}}
    RegisterCodec {\.udo?$}             {library_rule others.sim}
    RegisterCodec {\.c$|\.cpp$|\.hpp?$} {library_rule {${file_lib}${list_ext}}}
    RegisterCodec {\.cfg$}              {library_rule {${file_lib}${list_ext}}}
  }
}
