namespace eval Tools::Quartus {
  variable Manifest {
    name        "Quartus"
    vendor      "Altera"
    description "Altera Quartus Prime Pro and Standard Edition"
    aliases     "quartus quartus_pro quartus_std"
    Flows {
      CREATE {
        aliases {C}
        description "Create the project, replace it if already existing."
        options {
          {ext_path.arg   "" "Sets the absolute path for the external libraries."}
          {verbose           "If set, launch the script in verbose mode"}
        }
        stages  {
          CreateProject
          AddProjectFiles
        }
      }
    }
  }

  ## @brief Returns true, if IDE is Quartus
  proc IsActive {} {
    if {[catch {package require ::quartus::flow} result]} {
      # not available
      return 0
    } else {
      # available (we are inside quartus)
      return 1
    }
  }

  proc Launch {} {
    set script [Launcher::Get script]
    Msg Info "Launching quartus: \n    quartus_sh -t $script {*}$::argv"
    # TODO: Use standard Hog Exec
    exec -ignorestderr quartus_sh -t $script {*}$::argv >@ stdout
  }

  proc Initialize {} {
    # Tool-specific setup — DataStores are already populated by _ConfigureEnvironment
    set repo_path    [Repo::Get repo_path]
    set top_path     [Repo::Get top_path]

    if {[CurrentProject::Exists project_name] == 0} {
      FlowControl::Produce QUARTUS_INITIALIZED
      return
    }

    set project_name [CurrentProject::Get project_name]
    CurrentProject::Set project_file [file normalize [file join [CurrentProject::Get build_dir] [CurrentProject::Get project].qpf]]
    set proj_dir [file normalize "${repo_path}/Top/${project_name}"]

    FlowControl::Produce QUARTUS_INITIALIZED
  }

  proc CreateProject {} {
    FlowControl::Require QUARTUS_INITIALIZED
    CurrentProject::SaveJsonToFile [Repo::Get repo_path]/last_run.json 1
    if {[file exists [CurrentProject::Get project_file]] && [Launcher::GetOr options recreate 1] == 0} {
      Msg Info "Project file found at [CurrentProject::Get project_file], opening project..."
      #file mkdir "[CurrentProject::Get project_file]/[CurrentProject::Get project_name].gen/sources_1"
      OpenProject [CurrentProject::Get project_file] [Repo::Get repo_path]
      FlowControl::Produce PROJECT_CREATED
      return
    }

    Msg Info "Creating Quartus project with part: [CurrentProject::Get config main PART] at [CurrentProject::Get project_file]"
    if {[CurrentProject::Exists config main FAMILY] == 0} {
      Msg Error "You must specify a device Family for Quartus in your hog.conf file."
      return
    }

    set FAMILY [CurrentProject::Get config main FAMILY]
    set PART [CurrentProject::Get config main PART]
    file mkdir [CurrentProject::Get build_dir]
    cd [CurrentProject::Get build_dir]
    project_new -family $FAMILY -part $PART -overwrite [file tail [CurrentProject::Get design]]
    set_global_assignment -name PROJECT_OUTPUT_DIRECTORY output_files
    FlowControl::Produce PROJECT_CREATED
    ConfigureProperties
  }

  proc ConfigureProperties {} {
    # TODO
    set_global_assignment -name VHDL_INPUT_VERSION VHDL_2008
  }

  ## @brief Add every source file of the project to the Quartus project.
  #
  # Quartus has no filesets: every file becomes a global assignment and the only
  # grouping that survives is the VHDL library. So the project files are walked
  # as one flat dictionary rather than per fileset. Simulation libraries are
  # skipped, Quartus Prime cannot run them.
  proc AddProjectFiles {} {
    FlowControl::Require PROJECT_CREATED

    if {![is_project_open]} {
      Msg Error "Project is closed"
      return
    }

    set all_files   [Projects::GetProjectFiles [CurrentProject::GetProjectObj] -as tdict]
    set skipped_sim [dict create]

    tdict for {path fobj} $all_files {
      set lib      [tlist getval [tdict get $fobj libraries] 0]
      set rootlib  [file rootname [file tail $lib]]
      set list_ext [file extension $lib]
      set props    [tdict get $fobj props]

      if {$list_ext eq ".sim"} {
        dict set skipped_sim $rootlib 1
        continue
      }

      set file_type [FindFileType $path]

      # Top synthesis module
      if {[tdict exists $props top]} {
        set top [tdict getval $props top]
        Msg Info "Setting $top as top module..."
        CurrentProject::Set synth_top_module $top
      }

      # SYSTEMVERILOG_FILE contains VERILOG, so it must be tested first.
      if {[string first "VHDL" $file_type] != -1} {
        # The VHDL codec normalises 93/1987/1993/2008/2019 into a single std
        # prop that is always present (see Tcl/core/listfile.tcl).
        set_global_assignment -name $file_type $path \
          -hdl_version [_VhdlVersion [tdict getval $props std]] -library $rootlib
      } elseif {[string first "SYSTEMVERILOG" $file_type] != -1} {
        # Verilog codecs have no decode hook, so the year stays a bare flag.
        if {[tdict exists $props 2005]} {
          set_global_assignment -name $file_type $path -hdl_version systemverilog_2005
        } elseif {[tdict exists $props 2009]} {
          set_global_assignment -name $file_type $path -hdl_version systemverilog_2009
        } else {
          set_global_assignment -name $file_type $path
        }
      } elseif {[string first "VERILOG" $file_type] != -1} {
        if {[tdict exists $props 1995]} {
          set_global_assignment -name $file_type $path -hdl_version verilog_1995
        } elseif {[tdict exists $props 2001]} {
          set_global_assignment -name $file_type $path -hdl_version verilog_2001
        } else {
          set_global_assignment -name $file_type $path
        }
      } elseif {[string first "QSYS" $file_type] != -1} {
        if {![tdict exists $props noadd]} {
          set_global_assignment -name $file_type $path
        }
        if {![tdict exists $props nogenerate]} {
          GenerateQsysSystem $path [_QsysOpts $fobj]
        }
      } elseif {[string first "SOURCE" $file_type] != -1 || [string first "COMMAND_MACRO" $file_type] != -1} {
        set_global_assignment -name $file_type $path
        if {$list_ext eq ".con"} {
          source $path
        } elseif {$list_ext eq ".src" && [tdict exists $props qsys]} {
          # A Platform Designer script: run it and register the system it emits.
          _RunQsysScript $path $fobj
        }
      } else {
        set_global_assignment -name $file_type $path -library $rootlib
      }
    }

    if {[dict size $skipped_sim] > 0} {
      Msg Warning "Simulation files are not supported in Quartus Prime mode.\
        Skipped: [join [dict keys $skipped_sim] {, }]."
    }
  }

  ## @brief Map the codec's normalised std prop onto a Quartus -hdl_version.
  proc _VhdlVersion {std} {
    switch -- $std {
      1987      { return VHDL_1987 }
      93 - 1993 { return VHDL_1993 }
      2008      { return VHDL_2008 }
      default {
        Msg CriticalWarning "VHDL standard '$std' is not supported by Quartus, using VHDL_2008."
        return VHDL_2008
      }
    }
  }

  ## @brief Re-encode a file's props as the raw token list GenerateQsysSystem wants.
  #
  # The codec's encoder gives back the tokens the legacy parser used to carry
  # around; the ones Hog consumes itself are dropped before forwarding.
  proc _QsysOpts {fobj} {
    set opts {}
    foreach tok [ListFile::Codec::EncodeProps $fobj quartus] {
      if {$tok in {qsys noadd nogenerate}} { continue }
      lappend opts $tok
    }
    return $opts
  }

  ## @brief Locate the Platform Designer executables.
  proc _QsysRootDir {} {
    if {[info exists ::env(QSYS_ROOTDIR)]} {
      return $::env(QSYS_ROOTDIR)
    }
    if {[info exists ::env(QUARTUS_ROOTDIR)]} {
      set dir "$::env(QUARTUS_ROOTDIR)/sopc_builder/bin"
      Msg Warning "The QSYS_ROOTDIR environment variable is not set! I will use $dir"
      return $dir
    }
    Msg CriticalWarning "The QUARTUS_ROOTDIR environment variable is not set!\
      Assuming all quartus executables are contained in your PATH!"
    return ""
  }

  ## @brief Run a Platform Designer tcl script and register the .qsys it produces.
  #
  # Ported from the Quartus branch of AddHogFiles (Tcl/hog.tcl:388-455).
  proc _RunQsysScript {script_file fobj} {
    set props     [tdict get $fobj props]
    set root      [file rootname [file tail $script_file]]
    set qsys_path [file dirname $script_file]
    set qsys_name "$root.qsys"
    set qsys_file "$qsys_path/$qsys_name"
    set log_file  "$qsys_path/$root.qsys-script.log"

    set cmd [file join [_QsysRootDir] qsys-script]
    Msg Info "Executing: $cmd --script=$script_file"
    Msg Info "Saving logfile in: $log_file"
    if {[catch {exec -ignorestderr $cmd --script=$script_file >>& $log_file} ret opt]} {
      Msg CriticalWarning "$cmd returned with [lindex [dict get $opt -errorcode] end]"
    }

    # qsys-script writes into the current directory, move it next to its script.
    if {![file exists $qsys_name]} {
      Msg Error "Error while moving the generated qsys file to final location: $qsys_name not found!"
      return
    }
    file rename -force $qsys_name $qsys_file

    # Record the checksum, the CI uses it to tell whether the system is stale.
    set tmp_dir [file normalize "./hogTmp"]
    file mkdir $tmp_dir
    set fh [open "$tmp_dir/.hogQsys.md5" a]
    puts $fh "$qsys_file\t[Md5Sum $qsys_file]"
    close $fh

    if {![tdict exists $props noadd]} {
      set_global_assignment -name [FindFileType $qsys_file] $qsys_file
    }
    if {![tdict exists $props nogenerate]} {
      GenerateQsysSystem $qsys_file [_QsysOpts $fobj]
    }
  }
}
