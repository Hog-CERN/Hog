
# Note: This is mostly for the benefit of CI/CD pipelines as if using a code editor
# with Sigasi integration then code quality and formatting are easy to access

# The CLI functionality requires a paid license.

# These proceedures should be available regardless of which synthesis tool is used.

variable SigasiManifest {
    name      "sigasi-cli"
    vendor    "Sigasi"
    ref_names {sigasi sigasi-cli}
    Flows {
      sigasi-export {
        aliases {sigasi sigasi-e}
        stages  {sigasi-export}
      }
      sigasi-format {
        aliases {sigasi-f}
        stages  {sigasi-format}
      }
      sigasi-document {
        aliases {sigasi-d sigasi-doc sigasi-docs}
        stages  {sigasi-document}
      }
      sigasi-lint {
        aliases {sigasi-l}
        stages  {sigasi-lint}
      }
    }
  }

proc _test_sigasi {} {
  if { [catch {exec which sigasi-cli} ] } {
    puts "sigasi-cli not available -- check sigasi-cli is in PATH"
    exit 1
  } else {
    if { [catch {exec -- sigasi-cli --license } ] } {
      puts "check SIGASI_LM_LICENSE_FILE is set"
      exit 1
    }
  }
}

proc sigasi-export {} {
  # if using new experimental hog then get key info from Context. Else access the TCL globals
  if { [namespace exists ::Repo] } {
    set repo_path [Repo::Get repo_path]
    set project_name [HogProject::Get project_name]
  } else {
    global repo_path
    global project_name
  }

  cd $repo_path
  Msg Info "Creating Sigasi CSV files for project $project_name..."
  set proj_dir $repo_path/Top/$project_name
  set proj_list_dir $repo_path/Top/$project_name/list
  set project [file tail $project_name]
  lassign [GetHogFiles -list_files {.src} $proj_list_dir $repo_path] libraries
  set csv_file [open "sigasi_$project.csv" w]
  foreach lib $libraries {
    set source_files [DictGet $libraries $lib]
    foreach source_file $source_files {
      if {
        [file extension $source_file] eq ".vhd"
        || [file extension $source_file] eq ".vhdl"
        || [file extension $source_file] eq ".sv"
        || [file extension $source_file] eq ".v"
      } {
        puts $csv_file [concat [file rootname $lib] "," $source_file]
      }
    }
  }
  lassign [GetHogFiles -list_files ".sim" $proj_list_dir $repo_path] \
    listSimLibraries
  foreach lib $listSimLibraries {
    set source_files [DictGet $listSimLibraries $lib]
    foreach source_file $source_files {
      if {
        [file extension $source_file] eq ".vhd"
        || [file extension $source_file] eq ".vhdl"
        || [file extension $source_file] eq ".sv"
        || [file extension $source_file] eq ".v"
      } {
        puts $csv_file [concat [file rootname $lib] "," $source_file]
      }
    }
  }
  close $csv_file
  Msg Info "Sigasi CSV file created: sigasi_$project.csv"
  Msg Info "You can use the python script provided by Sigasi to convert the generated csv file into a Sigasi project."
  Msg Info \
    "More info at: \
    https://www.sigasi.com/knowledge/how_tos/generating-sigasi-project-vivado-project/#2-generate-the-sigasi-project-files-from-the-csv-file"
  exit 0
}


proc sigasi-lint {} {
  _test_sigasi
  if { [namespace exists ::Repo] } {
    set repo_path [Repo::Get repo_path]
    set project_name [HogProject::Get project_name]
  } else {
    global repo_path
    global project_name
  }

  cd $repo_path
  Msg Info "Generating a code quality report for project $project_name..."

  # set default values then parse repo.conf for any custom set properties
  set filetype ".txt"
  file mkdir $repo_path/sigasi_lint
  set outfile "$repo_path/sigasi_lint/$project_name"
  set repo_conf $repo_path/Top/repo.conf
  set options_list ""

  if {[file exists $repo_conf]} {
    set PROPERTIES [ReadConf $repo_conf]
    if {[dict exists $PROPERTIES sigasi]} {
      set sigasiDict [dict get $PROPERTIES sigasi]
      if {[dict exists $sigasiDict LIBRARY_DATABASE]} {
        set libraries [dict get $sigasiDict LIBRARY_DATABASE]
        foreach lib [split $libraries ,] {
          lappend options_list "--library-database=[string trim $lib]"
        }
      }
      if {[dict exists $sigasiDict REPORT_FORMAT]} {
        set report_format [dict get $sigasiDict REPORT_FORMAT]
        lappend options_list "--$report_format"

        if { $report_format == "json" || $report_format == "sonarqube" } {
          set filetype ".json"
        } elseif { $report_format == "warnings-ng" } {
          set filetype ".xml"
        }
      }
      # if {[dict exists $sigasiDict REPORT_OUTFILE]} {
      #   set outdir [dict get $sigasiDict REPORT_OUTFILE]
      #   set outdir [file rootname [file normalize $outdir]]
      #   if { [file writable $outdir] } {
      #     set outfile $outdir
      #   }
      # }
      if {[dict exists $sigasiDict REPORT_ABSOLUTE]} {
        lappend options_list "--absolute"
      }
      if {[dict exists $sigasiDict REPORT_SUPPRESSED]} {
        lappend options_list "--include-suppressed"
      }
      if {[dict exists $sigasiDict FAIL]} {
        lappend options_list "--fail-on-[dict get $sigasiDict FAIL]"
      }
    }
  }

  lappend options_list "--out=$outfile$filetype"

  puts "sigasi-cli verify $repo_path $options_list "
  if { [catch { exec -- sigasi-cli verify $repo_path {*}$options_list } ] } {
    Msg Error "sigasi-cli verify failed - please review $outfile$filetype for issues"
    exit 1
  }

  Msg Info "Despite passing there maybe minor code violations caught. See $outfile$filetype"
  exit 0
}

proc sigasi-format {} {
  _test_sigasi
  if { [namespace exists ::Repo] } {
    set repo_path [Repo::Get repo_path]
    set project_name [HogProject::Get project_name]
  } else {
    global repo_path
    global project_name
    puts "global $repo_path $project_name"
  }

  cd $repo_path
  Msg Info "Formatting VHDL files for project $project_name ..."

  # set default values then parse repo.conf for any custom set properties
  set tab_width 4
  set keywords "lowercase"
  set repo_conf $repo_path/Top/repo.conf
  set options_list ""
  set ignore_list ""

  if {[file exists $repo_conf]} {
    set PROPERTIES [ReadConf $repo_conf]
    if {[dict exists $PROPERTIES sigasi]} {
      set sigasiDict [dict get $PROPERTIES sigasi]
      if {[dict exists $sigasiDict TABS]} {
        lappend options_list ""
      } else {
        lappend options_list "--spaces-for-tabs"
      }
      if {[dict exists $sigasiDict PRESERVE_NEWLINES]} {
        lappend options_list "--preserve-newlines"
      }
      if {[dict exists $sigasiDict NO_ALIGN]} {
        lappend options_list "--no-align"
      }
      if {[dict exists $sigasiDict VHDL_VERSION]} {
        lappend options_list "--vhdl-version=[dict get $sigasiDict VHDL_VERSION]"
      }
      if {[dict exists $sigasiDict TAB_WIDTH]} {
        set tab_width [dict get $sigasiDict TAB_WIDTH]
      }
      if {[dict exists $sigasiDict KEYWORDS]} {
        set keywords [dict get $sigasiDict KEYWORDS]
      }
      if {[dict exists $sigasiDict IGNORE_DIR]} {
        set ignore [dict get $sigasiDict IGNORE_DIR]
        foreach dir [split $ignore ,] {
          lappend ignore_list "$repo_path/[string trim $dir]"
        }
      }
    }
  }

  set proj_dir $repo_path/Top/$project_name
  set proj_list_dir $repo_path/Top/$project_name/list
  set project [file tail $project_name]

  lassign [GetHogFiles -list_files {.src} $proj_list_dir $repo_path] libraries
  lappend [GetHogFiles -list_files ".sim" $proj_list_dir $repo_path] libraries

  foreach lib $libraries {
    set source_files [DictGet $libraries $lib]

    foreach source_file $source_files {
      set skip 0
      foreach dir $ignore_list {
        if { [string match $dir* $source_file] } {
          set skip 1
        }
      }
      if { $skip == 1 } {
        puts "skipping $source_file due to IGNORE_DIR setting"
      } else {
        if {[file extension $source_file] == ".vhd" ||
            [file extension $source_file] == ".vhdl" } {
          puts "sigasi-cli format $options_list --keywords=$keywords --tab-width=$tab_width $source_file"
          exec -- sigasi-cli format {*}$options_list --keywords=$keywords --tab-width=$tab_width $source_file
        }
      }
    }
  }
  exit 0
}

proc sigasi-document {} {
  _test_sigasi
  if { [namespace exists ::Repo] } {
    set repo_path [Repo::Get repo_path]
    set project_name [HogProject::Get project_name]
  } else {
    global repo_path
    global project_name
  }

  cd $repo_path
  Msg Info "Generating project documentation for $project_name..."

  set options_list ""
  set outdir "$repo_path/sigasi_doc/$project_name"
  set repo_conf $repo_path/Top/repo.conf
  set project_conf $repo_path/Top/$project_name/hog.conf
  set proj_top 0

  if {[file exists $project_conf]} {
    set PROJ_PROPS [ReadConf $project_conf]
    if {[dict exists $PROJ_PROPS sigasi]} {
      set sigasiDict [dict get $PROJ_PROPS sigasi]
      if {[dict exists $sigasiDict TOP_LEVEL]} {
        lappend options_list "--top-level=[dict get $sigasiDict TOP_LEVEL]"
        set proj_top 1
      }
    }
  }

  if {[file exists $repo_conf]} {
    set PROPERTIES [ReadConf $repo_conf]
    if {[dict exists $PROPERTIES sigasi]} {
      set sigasiDict [dict get $PROPERTIES sigasi]
      if {[dict exists $sigasiDict LIBRARY_DATABASE]} {
        set libraries [dict get $sigasiDict LIBRARY_DATABASE]
        foreach lib [split $libraries ,] {
          lappend options_list "--library-database=[string trim $lib]"
        }
      }
      # if {[dict exists $sigasiDict DOC_DIR]} {
      #   set outdir [dict get $sigasiDict DOC_DIR]
      #   set outdir [file normalize $outdir]
      # }
      if {[dict exists $sigasiDict DIAGRAM_NODE_LIMIT]} {
        lappend options_list "--diagram-node-limit=[dict get $sigasiDict DIAGRAM_NODE_LIMIT]"
      }
      if {[dict exists $sigasiDict DESIGN_UNITS_PER_PAGE]} {
        lappend options_list "--design-units-per-page=[dict get $sigasiDict DESIGN_UNITS_PER_PAGE]"
      }
      if {[dict exists $sigasiDict DIAGRAMS]} {
        lappend options_list "--diagrams=[dict get $sigasiDict DIAGRAMS]"
      }
      if { $proj_top == 0} {
        if {[dict exists $sigasiDict TOP_LEVEL]} {
          lappend options_list "--top-level=[dict get $sigasiDict TOP_LEVEL]"
        }
      }
    }
  }
  lappend options_list "--output-directory=$outdir"

  puts "sigasi-cli document $repo_path $options_list "
  try {
    set results [exec -- sigasi-cli document $repo_path {*}$options_list 2>@1  ]
    set status 0
  } trap CHILDSTATUS {results} {
    Msg Error "Generation of documentation has failed. Please debug sigasi command outside of HOG"
    exit 1
  }
  Msg Info "Documentation successfully saved to $outdir"
  exit 0
}



