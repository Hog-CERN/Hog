
proc Create_sigasi_CSV {project_name repo_path ext_path IsQuartus IsVivado recreate} {
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
        if {[file extension $source_file] == ".vhd" ||
            [file extension $source_file] == ".vhdl" ||
            [file extension $source_file] == ".sv" ||
            [file extension $source_file] == ".v" } {
          puts $csv_file [ concat  [file rootname $lib] "," $source_file ]
        }
      }
    }
    close $csv_file
    Msg Info "Sigasi CSV file created: sigasi_$project.csv"
    Msg Info "You can use the python script provided by Sigasi to convert the generated csv file into a Sigasi project."
    Msg Info "More info at: https://www.sigasi.com/knowledge/how_tos/generating-sigasi-project-vivado-project/#2-generate-the-sigasi-project-files-from-the-csv-file"
    exit 0
  }

  