namespace eval Tools::Quartus {
  Tools::RegisterTool [namespace current] {
    name        "Quartus"
    vendor      "Altera"
    description "Altera Quartus Prime Pro and Standard Edition"
    ref_name    {quartus quartus_pro quartus_std}
  }

  RegisterFlow CREATE {
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

  RegisterFlow SYNTHESIS {
    aliases {synth synthesize}
    description "Run synthesis only, create the project if not existing."
    stages  {@CREATE Synthesize}
    options {
      {recreate        "If set, the project will be re-created if it already exists."}
      {njobs.arg 4     "Number of jobs."}
      {check_syntax    "If set, the HDL syntax will be checked before synthesis."}
    }
  }

  RegisterFlow IMPLEMENTATION {
    aliases {i impl implement}
    description "Run implementation (fit + timing), creating and synthesising first if needed."
    stages  {@SYNTHESIS Implement}
    options {
      {no_bitstream    "If set, the bitstream file will not be produced."}
    }
  }

  RegisterFlow WORKFLOW {
    aliases {w work cw}
    description "Run the full workflow, creates the project if not existing."
    stages  {@IMPLEMENTATION GenerateBitstream}
  }

  RegisterStage CreateProject     { description "Create the Quartus project from the Top/ description." }
  RegisterStage AddProjectFiles   { description "Add the list-file sources to the Quartus project." }
  RegisterStage CheckSyntax       { description "Analyse every HDL source with quartus_map." }
  RegisterStage Synthesize        { description "Run IP generation and Analysis & Synthesis." }
  RegisterStage Implement         { description "Run Partition Merge (if incremental), Fitter and Timing Analyzer." }
  RegisterStage GenerateBitstream { description "Run the Assembler." }

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

  ## @brief True on Quartus Prime Pro (the version string ends in "Pro Edition").
  proc IsPro {} {
    return [expr {[info exists ::quartus(version)] && [string match "*Pro Edition*" $::quartus(version)]}]
  }

  proc Launch {} {
    set script [Launcher::Get script]
    Msg Info "Launching quartus: \n    quartus_sh -t $script {*}$::argv"
    # TODO: Use standard Hog Exec
    exec -ignorestderr quartus_sh -t $script {*}$::argv >@ stdout
  }

  proc Initialize {} {
    # The flow/report packages are only loadable inside quartus_sh.
    if {[IsActive]} {
      package require ::quartus::project
      load_package flow
      load_package report
    }

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
      OpenProject [CurrentProject::Get project_file] [Repo::Get repo_path]
      FlowControl::Produce PROJECT_OPEN
      return
    }

    if {[CurrentProject::Exists config main FAMILY] == 0} {
      Msg Error "You must specify a device Family for Quartus in your hog.conf file."
      return
    }

    set FAMILY [CurrentProject::Get config main FAMILY]
    set PART   [CurrentProject::Get config main PART]
    Msg Info "Creating Quartus project with part: $PART at [CurrentProject::Get project_file]"

    if {[is_project_open]} { project_close }
    file delete -force [CurrentProject::Get build_dir]
    file mkdir [CurrentProject::Get build_dir]
    cd [CurrentProject::Get build_dir]
    project_new -family $FAMILY -part $PART -overwrite [file tail [CurrentProject::Get design]]
    set_global_assignment -name PROJECT_OUTPUT_DIRECTORY output_files
    FlowControl::Produce PROJECT_OPEN
    FlowControl::Produce PROJECT_CREATED
    ConfigureProperties
    ConfigureScripts
    # Assignments only reach the .qsf on export/close; the process may exit first.
    export_assignments
  }

  ## @brief Hook the Hog pre/post scripts into the Quartus flow.
  #
  # Quartus has no per-step Tcl hooks: a PRE_FLOW script runs before the whole
  # flow and one POST_MODULE script runs after every module, which
  # quartus-post-module.tcl dispatches on the module name.
  proc ConfigureScripts {} {
    set_global_assignment -name PRE_FLOW_SCRIPT_FILE    quartus_sh:[Repo::Get pre_synth]
    set_global_assignment -name POST_MODULE_SCRIPT_FILE quartus_sh:[Repo::Get quartus_post_module]
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
    # A re-opened project (no recreate) already has its sources: nothing to do.
    FlowControl::RequireOr PROJECT_CREATED { return }

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
          _GenerateQsysSystem $path [_QsysOpts $fobj]
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

    set_global_assignment -name TOP_LEVEL_ENTITY [CurrentProject::Get synth_top_module]
    export_assignments

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
    if {[catch {exec -ignorestderr $cmd --script=$script_file >& $log_file} ret opt]} {
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
      _GenerateQsysSystem $qsys_file [_QsysOpts $fobj]
    }
  }

  ## @brief Generate a qsys system from a .qsys file and add its IPs to the project.
  #
  #  @param[in] qsysFile    the Platform Designer file (.qsys) to generate
  #  @param[in] commandOpts extra qsys-generate options
  proc _GenerateQsysSystem {qsysFile commandOpts} {
    if {![file exists $qsysFile]} {
      Msg Error "Error while generating ip variations from qsys: $qsysFile not found!"
      return
    }
    set qsysPath    [file dirname $qsysFile]
    set qsysName    [file rootname [file tail $qsysFile]]
    set qsysIPDir   "$qsysPath/$qsysName"
    set qsysLogFile "$qsysPath/$qsysName.qsys-generate.log"

    set cmd [file join [_QsysRootDir] qsys-generate]
    Msg Info "Executing: $cmd $qsysFile --output-directory=$qsysIPDir $commandOpts"
    Msg Info "Saving logfile in: $qsysLogFile"
    if {[catch {exec -ignorestderr $cmd $qsysFile --output-directory=$qsysIPDir {*}$commandOpts >& $qsysLogFile} ret opt]} {
      if {[lindex [dict get $opt -errorcode] 0] eq "CHILDSTATUS"} {
        Msg CriticalWarning "$cmd returned with [lindex [dict get $opt -errorcode] end]"
      } else {
        Msg Error "Could not execute command $cmd: $ret"
        return
      }
    }

    # Add the generated IPs to the project and record their checksums.
    set ipFiles [concat \
      [glob -nocomplain -directory $qsysIPDir -types f *.ip *.qip] \
      [glob -nocomplain -directory "$qsysIPDir/synthesis" -types f *.ip *.qip *.vhd *.vhdl]]
    set tmp_dir [file normalize "./hogTmp"]
    file mkdir $tmp_dir
    set fh [open "$tmp_dir/.hogQsys.md5" a]
    foreach ipFile $ipFiles {
      set_global_assignment -name [FindFileType $ipFile] $ipFile
      puts $fh "$ipFile\t[Md5Sum $ipFile]"
    }
    close $fh
  }

  ################################################################################
  # Flow stages (ported from the legacy LaunchSynthesis / LaunchImplementation /
  # GenerateBitstream / CheckSyntax Quartus branches in Tcl/hog.tcl)
  ################################################################################

  ## @brief Run one quartus module, reporting failure as a Msg Error.
  proc _RunModule {tool args what} {
    set revision [get_current_revision]
    if {[catch {execute_module -tool $tool {*}$args} result]} {
      Msg Error "Result: $result\n$what failed. See the report file.\n"
      return 0
    }
    Msg Info "$what was successful for revision $revision.\n"
    return 1
  }

  ## @brief Make sure the project is open (stage run on its own, e.g. 'quartus stage Synthesize').
  proc _EnsureOpen {} {
    FlowControl::RequireOr PROJECT_OPEN {
      if {![file exists [CurrentProject::Get project_file]]} {
        return -code error "Quartus project not found at [CurrentProject::Get project_file], run the CREATE flow first."
      }
      OpenProject [CurrentProject::Get project_file] [Repo::Get repo_path]
      FlowControl::Produce PROJECT_OPEN
    }
  }

  proc CheckSyntax {} {
    _EnsureOpen
    set project_name [CurrentProject::Get project_name]
    lassign [GetHogFiles -list_files "*.src" "[Repo::Get repo_path]/Top/$project_name/list/" [Repo::Get repo_path]] src_files dummy
    dict for {lib files} $src_files {
      foreach f $files {
        if {[file extension $f] in {.vhd .vhdl .v .sv}} {
          if {[catch {execute_module -tool map -args "--analyze_file=$f"} result]} {
            Msg Error "\nResult: $result\nCheck syntax failed.\n"
          } elseif {$result eq ""} {
            Msg Info "Check syntax was successful for $f.\n"
          } else {
            Msg Warning "Found syntax error in file $f:\n $result\n"
          }
        }
      }
    }
  }

  proc Synthesize {} {
    _EnsureOpen
    if {[Launcher::GetOr options check_syntax 0]} { CheckSyntax }

    set njobs        [Launcher::GetOr options njobs 4]
    set project_name [CurrentProject::Get project_name]
    set project      [file tail [file rootname $project_name]]
    set repo_path    [Repo::Get repo_path]
    set_global_assignment -name NUM_PARALLEL_PROCESSORS $njobs
    Msg Info "Number of jobs set to $njobs."

    # Quartus doesn't run PRE_FLOW scripts for execute_module, so run it by hand.
    # The project must be closed meanwhile or the script's own project_open conflicts.
    set revision        [get_current_revision]
    set tool            quartus_sh
    set pre_flow_script [Repo::Get pre_synth]
    set project_file    [CurrentProject::Get project_file]
    project_close

    lassign [ExecuteRet $tool -t $pre_flow_script quartus_map $project $revision] ret log
    if {$ret != 0} {
      Msg Warning "Can not execute $tool -t $pre_flow_script quartus_map $project $revision"
      Msg Warning "LOG: $log"
    } else {
      Msg Info "Pre flow script executed!"
      Msg Info "Pre flow script log: \n$log"
    }

    OpenProject $project_file $repo_path

    _RunModule ipg   {-args --clean}    "IP Generation"
    if {[_RunModule map {-args --parallel} "Analysis & Synthesis"]} {
      FlowControl::Produce SYNTHESIS_DONE
    }
  }

  proc Implement {} {
    FlowControl::Require SYNTHESIS_DONE
    _EnsureOpen
    Msg Info "Starting implementation flow..."

    # Partition Merge is Standard-only; Pro rejects the INCREMENTAL_COMPILATION assignment.
    set ic [expr {[IsPro] ? "" : [get_global_assignment -name INCREMENTAL_COMPILATION]}]
    if {$ic ne "" && [string toupper $ic] ne "OFF"} {
      Msg Info "Incremental compilation enabled ($ic), running Partition Merge..."
      _RunModule cdb {-args --merge=on} "Partition Merge"
    }

    if {![_RunModule fit {} "Place & Route"]} { return }

    if {[_RunModule sta {-args --do_report_timing} "Time Quest"]} {
      # Purely informational: panel/row names differ between editions, never fail on them.
      if {[catch {
        load_package report
        load_report
        set panel "Timing Analyzer||Timing Analyzer Summary"
        Msg Info "*******************************************************************"
        foreach row {{Device Name} {Timing Models} {Delay Model}} {
          Msg Info "$row: [get_report_panel_data -name $panel -col 1 -row_name $row]"
        }
        Msg Info "*******************************************************************"
      } err]} {
        Msg Debug "Timing summary not available on this edition: $err"
      }
    }
    FlowControl::Produce IMPLEMENTATION_DONE
  }

  proc GenerateBitstream {} {
    FlowControl::Require IMPLEMENTATION_DONE
    _EnsureOpen
    Msg Info "Starting write bitstream flow..."
    if {[_RunModule asm {} "Generate bitstream"]} {
      FlowControl::Produce BITSTREAM_DONE
    }
  }

}
