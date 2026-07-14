# Note: This is mostly for the benefit of CI/CD pipelines as if using a code editor
# with Sigasi integration then code quality and formatting are easy to access

# The CLI functionality requires a paid license.

# These proceedures should be available regardless of which synthesis tool is used.

set ::hog_commands {

  sigasi-export {
    aliases {sigasi sigasi-e}
    description " exports a CSV file for sigasi project creation "
    script  {sigasi-export}
  }
  sigasi-format {
    aliases {sigasi-f}
    description " sigasi-cli wrapper "
    script  {sigasi-format}
  }
  sigasi-document {
    aliases {sigasi-d sigasi-doc sigasi-docs}
    description " sigasi-cli wrapper "
    script  {sigasi-document}
  }
  sigasi-lint {
    aliases {sigasi-l}
    description " sigasi-cli wrapper "
    script  {sigasi-lint}
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
  # check that the rest of Hog is existing as expected
  if { ![namespace exists ::Repo] } {
    Msg Error " sigasi has been called before Repo namespace has been created "
  }
}

# create a default dict. Then we can merge in the repo.conf dict (overwriting) followed by the project dict (overwriting)
proc _create_sigasi_default_dict {} {
  dict set sigasi_defaults DIAGRAMS "LINKED"
  dict set sigasi_defaults DESIGN_UNITS_PER_PAGE 25
  dict set sigasi_defaults DIAGRAM_NODE_LIMIT 2500
  dict set sigasi_defaults DOC_DIR "./sigasi-docs"
  dict set sigasi_defaults REPORT_FORMAT "plain"
  dict set sigasi_defaults REPORT_OUTFILE "./sigasi_report.txt"
  dict set sigasi_defaults VHDL_VERSION 2008
  dict set sigasi_defaults KEYWORDS "lowercase"
  dict set sigasi_defaults TAB_WIDTH 4

  return $sigasi_defaults
}

# create default and merge with repo and project dicts from config files
proc get_sigasi_conf {} {
  set default_dict [_create_sigasi_default_dict]
  set out_dict $default_dict

  Msg Info " retrieving the sigasi configuration settings "
  if { [ ::tdict::exists [ CurrentProject::Get repo_config ] sigasi ] } {
    set sigasi_dict [ ::tobj::native [ CurrentProject::Get repo_config sigasi ]]
    Msg Debug "debug merge 1 $sigasi_dict "
    set out_dict [dict merge $default_dict $sigasi_dict]
  }

  set config [ CurrentProject::Get config ]
  if { [ ::tdict::exists [ CurrentProject::Get config ] sigasi ] } {
    set sigasi_dict [ ::tobj::native [ CurrentProject::Get config sigasi ]]
    Msg Debug "debug merge 2 $sigasi_dict "
    set out_dict [dict merge $out_dict $sigasi_dict]
  }

  return $out_dict
}

proc sigasi-export {} {
  _test_sigasi

  set repo_path [Repo::Get repo_path]
  set project_name [Launcher::Get project_name]
  Msg Info "Creating Sigasi CSV files for project $project_name..."

  set project_files [ ::tobj::native [ CurrentProject::Get project_files ] ]
  # puts " debug project_files $project_files"

  set csv_file [open "$repo_path/sigasi_$project_name.csv" w]

  foreach source_file $project_files {
    if {
      [file extension $source_file] eq ".vhd"
      || [file extension $source_file] eq ".vhdl"
      || [file extension $source_file] eq ".sv"
      || [file extension $source_file] eq ".v"
    } {
      set file_dict [dict get $project_files $source_file]
      puts $csv_file [concat [file rootname [dict get $file_dict libraries]] "," $source_file]
    }
  }

  close $csv_file
  Msg Info "Sigasi CSV file created: sigasi_$project_name.csv"
  Msg Info "You can use the python script provided by Sigasi to convert the generated csv file into a Sigasi project."
  Msg Info \
    "More info at: \
    https://www.sigasi.com/knowledge/how_tos/generating-sigasi-project-vivado-project/#2-generate-the-sigasi-project-files-from-the-csv-file"
  exit 0
}


proc sigasi-lint {} {
  _test_sigasi

  set repo_path [Repo::Get repo_path]
  set project_name [Launcher::Get project_name]
  Msg Info "Generating a code quality report for project $project_name..."

  file mkdir $repo_path/sigasi_lint
  set outfile "$repo_path/sigasi_lint/$project_name"

  set options_list ""

  set sigasi_conf [get_sigasi_conf]
  Msg Info "sigasi config dict: $sigasi_conf"

  if {[dict exists $sigasi_conf LIBRARY_DATABASE]} {
    set libraries [dict get $sigasi_conf LIBRARY_DATABASE]
    foreach lib [split $libraries ,] {
      lappend options_list "--library-database=[string trim $lib]"
    }
  }

  set report_format [dict get $sigasi_conf REPORT_FORMAT]
  lappend options_list "--$report_format"

  if { $report_format == "json" || $report_format == "sonarqube" } {
    set filetype ".json"
  } elseif { $report_format == "warnings-ng" } {
    set filetype ".xml"
  } else {
    set filetype ".txt"
  }

  if {[dict exists $sigasi_conf REPORT_ABSOLUTE]} {
    lappend options_list "--absolute"
  }
  if {[dict exists $sigasi_conf REPORT_SUPPRESSED]} {
    lappend options_list "--include-suppressed"
  }
  if {[dict exists $sigasi_conf FAIL]} {
    lappend options_list "--fail-on-[dict get $sigasi_conf FAIL]"
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

  set repo_path [Repo::Get repo_path]
  set project_name [Launcher::Get project_name]
  Msg Info "Formatting VHDL files for project $project_name ..."

  set options_list ""
  set ignore_list ""

  set sigasi_conf [get_sigasi_conf]
  Msg Info "sigasi config dict: $sigasi_conf"

  if {[dict exists $sigasi_conf TABS]} {
    lappend options_list ""
  } else {
    lappend options_list "--spaces-for-tabs"
  }
  if {[dict exists $sigasi_conf PRESERVE_NEWLINES]} {
    lappend options_list "--preserve-newlines"
  }
  if {[dict exists $sigasi_conf NO_ALIGN]} {
    lappend options_list "--no-align"
  }

  lappend options_list "--vhdl-version=[dict get $sigasi_conf VHDL_VERSION]"
  set tab_width [dict get $sigasi_conf TAB_WIDTH]
  set keywords [dict get $sigasi_conf KEYWORDS]

  if {[dict exists $sigasi_conf IGNORE_DIR]} {
    set ignore [dict get $sigasi_conf IGNORE_DIR]
    foreach dir [split $ignore ,] {
      lappend ignore_list "$repo_path/[string trim $dir]"
    }
  }

  set project_files [ ::tobj::native [ CurrentProject::Get project_files ] ]
  # Msg Debug " debug project_files $project_files"

  foreach source_file $project_files {
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
  exit 0
}

proc sigasi-document {} {
  _test_sigasi

  set repo_path [Repo::Get repo_path]
  set project_name [Launcher::Get project_name]
  Msg Info "Generating project documentation for $project_name..."

  set options_list ""

  set sigasi_conf [get_sigasi_conf]
  Msg Info "sigasi config dict: $sigasi_conf"

  if {[dict exists $sigasi_conf LIBRARY_DATABASE]} {
    set libraries [dict get $sigasi_conf LIBRARY_DATABASE]
    foreach lib [split $libraries ,] {
      lappend options_list "--library-database=[string trim $lib]"
    }
  }

  lappend options_list "--diagram-node-limit=[dict get $sigasi_conf DIAGRAM_NODE_LIMIT]"
  lappend options_list "--design-units-per-page=[dict get $sigasi_conf DESIGN_UNITS_PER_PAGE]"
  lappend options_list "--diagrams=[dict get $sigasi_conf DIAGRAMS]"
  if {[dict exists $sigasi_conf TOP_LEVEL]} {
    lappend options_list "--top-level=[dict get $sigasi_conf TOP_LEVEL]"
  }
  set outdir "$repo_path/sigasi_doc/$project_name"
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
