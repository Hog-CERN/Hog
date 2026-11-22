#   Copyright 2018-2026 The University of Birmingham
#   Copyright 2018-2026 Max-Planck-Institute for Physics
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

## @file cheby.tcl
# Cheby register-map tool.
#
# The `Tools::Cheby` namespace holds everything needed to turn the lines of a
# `.chb` list file into `cheby` invocations, and to either regenerate or verify
# the artefacts (HDL, C headers, documentation, ...) those lines declare.
# The commands are registered in commands.tcl, sourced at the end of this file.
#
# `Process` does no list-file handling of its own: it consumes a plain list of
# *entries*, built from the loaded project by `EntriesFromProject`.
#
# An entry is a dict with the keys:
#   input      absolute path to the cheby description file
#   input_rel  repository-relative path, used in messages
#   outputs    declared artefacts, relative to the repository root
#   props      key/value properties parsed from the same line
#   origin     human readable location, e.g. "cheby.chb:12"

namespace eval Tools::Cheby {

  Tools::RegisterTool [namespace current] {
    name        "Cheby"
    vendor      "CERN"
    ref_name    {chb}
    description "Cheby register-map generator: check or regenerate the artefacts declared in the .chb list files."
  }

  # List-file codec for the cheby descriptions. A .chb line is
  #   <input.cheby> [<output> ...] [key=value ...]
  # so the bare tokens are the declared artefacts, not flags: collect them
  # into an ordered `outputs` prop, which pairs up with `gen=` positionally.
  # The descriptions go to the `cheby.chb` library, which the IDE tools skip.
  # The scripts run inside ListFile::Codec::Decode and Encode, see RegisterCodec.
  ListFile::Codec::RegisterCodec {\.cheby$|\.ya?ml$} {
    library_rule {[expr {$list_ext eq ".chb" ? "cheby.chb" : "others.src"}]}
    decoder {
      post {
        if {$list_ext eq ".chb"} {
          set props   [tdict get $hog_file props]
          set outputs [list]
          foreach tok $raw_tokens {
            if {[string first "=" $tok] >= 0} { continue }
            lappend outputs [tstr $tok]
            if {[tdict exists $props $tok]} { set props [tdict remove $props $tok] }
          }
          tdict set props outputs [tlist create {*}$outputs]
          tdict set hog_file props $props
        }
      }
    }
    encoder {
      pre {
        set props [tdict get $hog_file props]
        if {[tdict exists $props outputs]} {
          tlist foreachval out [tdict get $props outputs] { lappend tokens $out }
        }
        tdict for {k v} $props {
          if {$k eq "outputs"} { continue }
          lappend tokens [EncodeProp $k $v]
        }
        set _done 1
      }
    }
  }

  # Short generator aliases used in `gen=` and the cheby flag they map to.
  variable GenFlags [dict create \
    hdl          "--gen-hdl" \
    consts       "--gen-consts" \
    c            "--gen-c" \
    c_check      "--gen-c-check-layout" \
    doc          "--gen-doc" \
    memmap       "--print-memmap" \
    memmap_v     "--print-memmap-verbose" \
    pretty       "--print-pretty" \
    devicetree   "--gen-devicetree" \
    edge         "--gen-edge" \
    silecs       "--gen-silecs" \
    wbgen        "--gen-wbgen-hdl" \
    custom       "--gen-custom" \
    install      "--gen-install-script" \
    gena_memmap  "--gen-gena-memmap" \
    gena_regctrl "--gen-gena-regctrl" \
  ]

  # Properties taking a value, and the cheby flag they map to.
  variable OptionFlags [dict create \
    hdl           "--hdl" \
    header        "--header" \
    c_style       "--c-style" \
    consts_style  "--consts-style" \
    doc           "--doc" \
    address_space "--address-space" \
    out_prefix    "--out-prefix" \
    ff_reset      "--ff-reset" \
    word_endian   "--word-endian" \
    wb_lib_name   "--wb-lib-name" \
    axil_lib_name "--axil-lib-name" \
    rest_headers  "--rest-headers" \
    custom        "--custom" \
  ]

  # Properties emitted as a bare flag when set to a true-ish value.
  variable BoolFlags [dict create \
    hdl_preload        "--hdl-preload" \
    doc_hide_comments  "--doc-hide-comments" \
    doc_no_reg_drawing "--doc-no-reg-drawing" \
    doc_include_js_dep "--doc-include-js-dep" \
    gena_common_visual "--gena-common-visual" \
    gen_c_bit_struct   "--gen-c-bit-struct" \
    gen_gena_dsp       "--gen-gena-dsp" \
  ]

  # Properties handled by Hog itself, never forwarded to cheby.
  variable HogProps {gen profile outputs}


  ## @brief Return the cheby command-line flag for a short generator alias.
  #
  # @param[in] gen  Short alias, e.g. "hdl", "consts", "c", "doc".
  #
  # @return         The corresponding flag, or "" if the alias is unknown.
  proc GenFlag {gen} {
    variable GenFlags
    if {![dict exists $GenFlags $gen]} {
      return ""
    }
    return [dict get $GenFlags $gen]
  }


  ## @brief Guess the generator to use from the extension of a declared output.
  #
  # Only used when a .chb line declares exactly one output and no `gen=`.
  #
  # @param[in] output  The declared output file.
  #
  # @return            A generator alias, or "" when the extension is ambiguous.
  proc InferGen {output} {
    switch -- [string tolower [file extension $output]] {
      ".vhd" -
      ".vhdl" -
      ".v" -
      ".sv"   { return "hdl" }
      ".h" -
      ".hpp"  { return "c" }
      ".html" -
      ".md" -
      ".rst" -
      ".tex"  { return "doc" }
    }
    return ""
  }


  ## @brief Pair every declared output with its generator and collect cheby flags.
  #
  # The `gen=` property holds a comma-separated list of generator aliases whose
  # length must match the number of declared outputs. When it is absent, a
  # single generator is inferred from the extension of the single output.
  #
  # Recognised value properties are mapped to their flag (`hdl=vhdl` becomes
  # `--hdl vhdl`), boolean ones are emitted bare, and any key already starting
  # with `--` is passed through verbatim.
  #
  # @param[in] props    Properties parsed from the .chb line.
  # @param[in] outputs  Expected output files declared on the same line.
  #
  # @return             A 3-element list { ok gen_map opt_flags }: `ok` is 0 on
  #                     success, in which case `gen_map` is a flat
  #                     { gen output gen output ... } list and `opt_flags` the
  #                     cheby flags. On failure `ok` is 1 and `gen_map` holds
  #                     the error message.
  proc BuildCmdArgs {props outputs} {
    variable OptionFlags
    variable BoolFlags
    variable HogProps

    set gens [list]
    if {[dict exists $props "gen"]} {
      set gens [split [dict get $props "gen"] ","]
    }

    if {[llength $gens] == 0} {
      if {[llength $outputs] != 1} {
        return [list 1 "Cannot map [llength $outputs] outputs without a `gen=...`\
                        property listing the generators." [list]]
      }
      set inferred [InferGen [lindex $outputs 0]]
      if {$inferred eq ""} {
        return [list 1 "Cannot infer generator from output extension\
                        '[file extension [lindex $outputs 0]]'.\
                        Please add a `gen=...` property to the line." [list]]
      }
      set gens [list $inferred]
    }

    if {[llength $outputs] != [llength $gens]} {
      return [list 1 "Number of declared outputs ([llength $outputs]) does not match\
                      number of generators ([llength $gens], gen=[join $gens ,])." [list]]
    }

    set gen_map [list]
    foreach g $gens o $outputs {
      lappend gen_map $g $o
    }

    set opt_flags [list]
    dict for {k v} $props {
      if {$k in $HogProps} {
        continue
      }
      if {[dict exists $OptionFlags $k]} {
        lappend opt_flags [dict get $OptionFlags $k] $v
      } elseif {[dict exists $BoolFlags $k]} {
        if {[string tolower $v] in {1 true yes}} {
          lappend opt_flags [dict get $BoolFlags $k]
        }
      } elseif {[string range $k 0 1] eq "--"} {
        lappend opt_flags $k $v
      } else {
        Msg Warning "Unknown cheby property '$k=$v', ignoring."
      }
    }

    return [list 0 $gen_map $opt_flags]
  }


  ## @brief Express @a abs relatively to @a base for cheby argv/header display.
  #
  # Cheby records sys.argv verbatim in the header of every file it generates.
  # Running it from the description's own directory with relative paths keeps
  # those headers identical to what a manual invocation would produce.
  #
  # @param[in] base  Reference directory, normally the description's directory.
  # @param[in] abs   Absolute path to express relatively.
  #
  # @return          A relative path, or @a abs when no relative form exists.
  proc RelPath {base abs} {
    set base [file normalize $base]
    set abs  [file normalize $abs]
    if {$base eq [file dirname $abs]} {
      return [file tail $abs]
    }
    set rel [Relative $base $abs 1]
    if {$rel eq ""} {
      return $abs
    }
    return $rel
  }


  ## @brief Drop the auto-generated cheby comment header from a list of lines.
  #
  # The header (see cheby/gen_header.py) is metadata only and always sits at the
  # top of the file: a banner line, the argv line, and — with `header=full` — a
  # "Generated on <date> by <user>" line. None of them should make a check fail.
  #
  # @param[in] lines  Non-blank, right-trimmed lines read from a generated file.
  #
  # @return           The same lines without the cheby banner block.
  proc StripGeneratedHeader {lines} {
    set idx [lsearch -regexp $lines {Do not edit\.\s+Generated by cheby}]
    if {$idx < 0} {
      return $lines
    }
    # The banner is always followed by the argv line.
    set last [expr {$idx + 1}]
    # The timestamp line is only there with header=full. Match anywhere in the
    # line, as the comment prefix depends on the generated language.
    set ts_line [lindex $lines [expr {$idx + 2}]]
    if {$ts_line ne "" && [string first "Generated on " $ts_line] >= 0} {
      incr last
    }
    return [lreplace $lines $idx $last]
  }


  ## @brief Read a file, dropping trailing whitespace and blank lines.
  proc _ReadSignificantLines {file} {
    set lines [list]
    set fp [open $file r]
    while {[gets $fp line] != -1} {
      set line [string trimright $line]
      if {$line eq ""} { continue }
      lappend lines $line
    }
    close $fp
    return $lines
  }


  ## @brief Compare two text files ignoring trailing whitespace and blank lines.
  #
  # @param[in] file1        Path to the first file.
  # @param[in] file2        Path to the second file.
  # @param[in] skip_header  If 1, ignore the cheby auto-generated header.
  #
  # @return                 1 if the files are equivalent, 0 otherwise.
  proc FilesEqual {file1 file2 {skip_header 0}} {
    if {![file exists $file1] || ![file exists $file2]} {
      return 0
    }
    set la [_ReadSignificantLines $file1]
    set lb [_ReadSignificantLines $file2]
    if {$skip_header} {
      set la [StripGeneratedHeader $la]
      set lb [StripGeneratedHeader $lb]
    }
    if {[llength $la] != [llength $lb]} {
      return 0
    }
    foreach x $la y $lb {
      if {$x ne $y} { return 0 }
    }
    return 1
  }


  ## @brief Quote a string as a POSIX shell single-quoted literal.
  proc _ShellQuote {s} {
    return "'[string map {' '\\''} $s]'"
  }


  ## @brief Return the value of a key in a dict, or a default if it is missing.
  #
  # Private copy of the DictGet in hog.tcl, so this file does not depend on it.
  #
  # @param[in] d        The dictionary.
  # @param[in] key      The key to look up.
  # @param[in] default  Value returned when @a key is not in @a d.
  proc _DictGet {d key {default ""}} {
    if {[dict exists $d $key]} {
      return [dict get $d $key]
    }
    return $default
  }


  ## @brief Run an external command using the user's shell environment.
  #
  # Inside Vivado, `exec` routes Python scripts through Vivado's own bundled
  # interpreter, which lacks the packages cheby needs (PyYAML in particular).
  # Re-run through bash with Vivado's Python variables cleared and the system
  # binaries first in PATH. Set HOG_PYTHON to force a specific interpreter.
  #
  # @param[in] args  The command and its arguments.
  #
  # @return          A list { return_code output }.
  proc ExecRet {args} {
    global env
    if {![IsVivado]} {
      return [ExecuteRet {*}$args]
    }

    set run_args $args
    if {[regexp {\.py$} [lindex $args 0]]} {
      if {[info exists env(HOG_PYTHON)] && $env(HOG_PYTHON) ne ""} {
        set py $env(HOG_PYTHON)
      } else {
        set py /usr/bin/python3
      }
      set run_args [linsert $args 0 $py]
    }

    set quoted [list]
    foreach a $run_args {
      lappend quoted [_ShellQuote $a]
    }
    set inner [join $quoted " "]

    if {[OS] eq "windows"} {
      return [ExecuteRet cmd /c $inner]
    }

    # The bash script must stay a single Tcl list element, otherwise Tcl word
    # splits it and bash only ever runs the first token.
    set cmd "env -u PYTHONHOME -u PYTHONPATH -u PYTHON \
PATH=/usr/local/bin:/usr/bin:/bin:\$PATH $inner"
    return [ExecuteRet /bin/bash -c $cmd]
  }


  ## @brief Return the cheby executable to use.
  #
  # @param[in] tool  Explicit executable, wins over everything else.
  #
  # @return          @a tool, else $HOG_CHEBY_TOOL, else "cheby".
  proc GetTool {{tool ""}} {
    global env
    if {$tool ne ""} {
      return $tool
    }
    if {[info exists env(HOG_CHEBY_TOOL)] && $env(HOG_CHEBY_TOOL) ne ""} {
      return $env(HOG_CHEBY_TOOL)
    }
    return "cheby"
  }


  ## @brief Parse a `.chb` list file into entries.
  #
  # Each non-empty, non-comment line has the form:
  #   <input.cheby> [<output1> <output2> ...] [key=value ...]
  # Tokens containing `=` are properties, the others are expected outputs.
  #
  # @param[in] chb_file   Path to the .chb list file.
  # @param[in] repo_path  Repository root, used to resolve the paths.
  #
  # @return               A list of entries, see the file header for the shape.
  proc ParseListFile {chb_file repo_path} {
    set fp [open $chb_file r]
    set lines [split [read $fp] "\n"]
    close $fp

    set entries [list]
    set line_num 0
    foreach line $lines {
      incr line_num
      set trimmed [string trim $line]
      if {$trimmed eq "" || [string index $trimmed 0] eq "#"} {
        continue
      }

      set tokens [regexp -all -inline {\S+} $line]
      set outputs [list]
      set props   [dict create]
      foreach tok [lrange $tokens 1 end] {
        set eq_pos [string first "=" $tok]
        if {$eq_pos == -1} {
          lappend outputs $tok
        } else {
          dict set props [string range $tok 0 [expr {$eq_pos - 1}]] \
                         [string range $tok [expr {$eq_pos + 1}] end]
        }
      }

      set input_rel [lindex $tokens 0]
      set input     [file normalize [file join $repo_path $input_rel]]
      set origin    [file tail $chb_file]:$line_num
      lappend entries [dict create input $input input_rel $input_rel \
                         outputs $outputs props $props origin $origin]
    }
    return $entries
  }


  ## @brief Build the entries from an already loaded HogProjectObj.
  #
  # The project object tells us which `.chb` list files belong to the project;
  # the lines themselves are read from those files. A single description is
  # routinely declared on several lines — one per profile, say HDL, software
  # header and documentation — and the project object keys its files by path,
  # so it cannot carry more than one set of outputs per description.
  #
  # @param[in] hog_project  A HogProjectObj with its list files loaded.
  #
  # @return                 A list of entries.
  proc EntriesFromProject {hog_project} {
    set repo_path [Repo::Get repo_path]
    set entries [list]
    tlist foreachval list_file [tdict get $hog_project list_files] {
      if {[file extension $list_file] ne ".chb"} { continue }
      Msg Debug "Reading cheby list file: $list_file"
      lappend entries {*}[ParseListFile $list_file $repo_path]
    }
    return $entries
  }


  ## @brief Run cheby for every entry and either regenerate or check its outputs.
  #
  # In check mode (the default) the artefacts are generated into a temporary
  # directory and compared with the ones on disk, reporting every difference.
  # In generate mode the files on disk are overwritten in place.
  #
  # A copy of the resolved descriptions and of the existing artefacts is left
  # under @a dst for traceability.
  #
  # @param[in] entries    Entries to process, see the file header.
  # @param[in] repo_path  Repository root, the entry paths are resolved against it.
  # @param[in] dst        Directory receiving the traceability copies.
  # @param[in] args       Any of:
  #                         -generate <0|1>  overwrite the artefacts on disk
  #                         -profile <name>  only process the lines whose
  #                                          `profile=` matches (default "all")
  #                         -tool <path>     cheby executable to invoke
  #                         -strict <0|1>    report mismatches as errors
  #                         -verbose <0|1>   print the expanded command lines
  #                         -version <ver>   cheby list-set version, for the log
  #                         -sha <sha>       cheby list-set SHA, for the log
  #
  # @return               The number of errors encountered, 0 on success.
  proc Process {entries repo_path dst args} {
    set generate [_DictGet $args -generate 0]
    set profile  [_DictGet $args -profile "all"]
    set tool     [GetTool [_DictGet $args -tool ""]]
    set strict   [_DictGet $args -strict 0]
    set verbose  [_DictGet $args -verbose 0]
    set version  [_DictGet $args -version ""]
    set sha      [_DictGet $args -sha ""]

    if {[llength $entries] == 0} {
      Msg CriticalWarning "No cheby register map declared, nothing to do."
      return 1
    }

    lassign [ExecRet $tool --version] ret tool_msg
    if {$ret != 0} {
      if {$generate} {
        Msg Error "Cannot run cheby: '$tool' not found or not working: $tool_msg"
        return 1
      }
      Msg Warning "Cheby executable '$tool' not found or not working ($tool_msg).\
                   Will not verify cheby outputs."
      return 0
    }
    Msg Info "Using cheby tool: $tool ([string trim $tool_msg])"
    if {$version ne "" && $sha ne ""} {
      Msg Info "Cheby list set version: $version, SHA: $sha"
    }

    set dst [file normalize $dst]
    set tmp_dir    [file join $dst _check]
    set inputs_dir [file join $dst inputs]
    file mkdir $dst $tmp_dir $inputs_dir

    set severity [expr {$strict ? "Error" : "CriticalWarning"}]
    set n_entries   0
    set n_processed 0
    set n_changed   0
    set n_errors    0

    foreach entry $entries {
      incr n_entries
      set input   [dict get $entry input]
      set in_rel  [dict get $entry input_rel]
      set outputs [dict get $entry outputs]
      set props   [dict get $entry props]
      set origin  [dict get $entry origin]

      set line_profile [_DictGet $props "profile" "all"]
      if {$profile ne "all" && $line_profile ne "all" && $line_profile ne $profile} {
        if {$verbose} {
          Msg Info "  Skipping $origin (profile='$line_profile')"
        }
        continue
      }

      if {![file exists $input]} {
        Msg $severity "Cheby input not found ($origin): $input"
        incr n_errors
        continue
      }

      lassign [BuildCmdArgs $props $outputs] ok gen_map opt_flags
      if {$ok != 0} {
        Msg $severity "$origin: $gen_map"
        incr n_errors
        continue
      }

      # Run cheby from the description's directory with relative argv paths, so
      # the generated headers match those of a manual invocation.
      set cheby_cwd [file dirname $input]
      set cmd [list $tool -i [file tail $input]]
      lappend cmd {*}$opt_flags

      set out_targets [list]
      set bad_gen 0
      foreach {gen out_rel} $gen_map {
        set gen_flag [GenFlag $gen]
        if {$gen_flag eq ""} {
          Msg $severity "$origin: unknown generator '$gen'"
          incr n_errors
          set bad_gen 1
          break
        }
        set target [file normalize [file join $repo_path $out_rel]]
        if {$generate} {
          set out_path $target
        } else {
          set out_path [file join $tmp_dir \
            "[file rootname [file tail $target]]_${n_entries}_${gen}[file extension $target]"]
        }
        lappend cmd $gen_flag [RelPath $cheby_cwd $out_path]
        lappend out_targets [list $out_rel $target $out_path]
      }
      if {$bad_gen} { continue }

      foreach target $out_targets {
        file mkdir [file dirname [lindex $target 1]] [file dirname [lindex $target 2]]
      }

      if {$verbose} {
        Msg Info "  Running (cwd=$cheby_cwd): [join $cmd { }]"
      }

      set saved_pwd [pwd]
      cd $cheby_cwd
      lassign [ExecRet {*}$cmd] cret cmsg
      cd $saved_pwd
      if {$cret != 0} {
        Msg $severity "Cheby failed for $in_rel ($origin): $cmsg"
        incr n_errors
        continue
      }
      incr n_processed

      foreach target $out_targets {
        lassign $target out_rel abs_target out_path
        if {$generate} {
          Msg Info "  Generated: $out_rel"
          incr n_changed
          continue
        }
        if {![file exists $abs_target]} {
          Msg $severity "Expected cheby output missing: $out_rel ($origin)"
          incr n_errors
          continue
        }
        if {[FilesEqual $out_path $abs_target 1]} {
          Msg Info "  OK: $out_rel matches generator output."
          continue
        }
        Msg $severity "Cheby output mismatch: $out_rel does not match what cheby\
                       would generate from $in_rel ($origin).\
                       Run `Hog/Do CHEBY <project> -generate` to refresh."
        catch { file copy -force $out_path [file join $dst "diff_[file tail $abs_target]"] }
        incr n_changed
        incr n_errors
      }

      catch { file copy -force $input [file join $inputs_dir [file tail $input]] }
      foreach target $out_targets {
        set abs_target [lindex $target 1]
        if {[file exists $abs_target]} {
          catch { file copy -force $abs_target [file join $dst [file tail $abs_target]] }
        }
      }
    }

    catch { file delete -force $tmp_dir }

    set summary "Cheby summary: parsed $n_entries line(s), ran $n_processed cheby invocation(s),\
                 $n_changed change(s), $n_errors error(s)."
    if {$n_errors > 0} {
      Msg CriticalWarning $summary
    } else {
      Msg Info $summary
    }
    return $n_errors
  }


  # Cheby commands
  source [file join [file dirname [info script]] commands.tcl]
}
