dict set Manifest commands {
  PING {
    aliases     {p}
    description "Stub tool command — prints a hello from Vivado tool scope (tclsh-side)."
    ide         vivado
    script {
      puts "pong"
    }
  }
}

# Compiles the simulation libraries needed by the external simulators, i.e. the
# ones that Vivado drives through generated scripts (see GetSimulators). The
# resulting directory is what the -lib option of the SIMULATION flow points at.
#
# The simulator name is given as the positional argument, as in the legacy
# COMPSIMLIB directive: ./Hog/Do TOOL VIVADO COMPSIMLIB questa
dict set Manifest commands COMPSIMLIB {
  aliases       {compsim compsimlib}
  description   "Compile the simulation libraries for the given simulator. Usage: TOOL VIVADO COMPSIMLIB <simulator>"
  ide           vivado
  requires_proj false
  options {
    {dst_dir.arg "SimulationLib" "Output directory for the compiled simulation libraries,\
                                  relative to the repository root unless absolute."}
  }
  script {
    set simulator [Launcher::GetOr project ""]
    if {$simulator eq ""} {
      Msg Error "No simulator given. Usage: ./Hog/Do TOOL VIVADO COMPSIMLIB <simulator>.\
        Supported simulators: [join [GetSimulators] {, }]."
      return
    }
    if {[IsInList [string tolower $simulator] [GetSimulators] 1] == 0} {
      Msg Warning "'$simulator' is not one of the simulators Hog knows about:\
        [join [GetSimulators] {, }]. Trying anyway..."
    }

    set output_dir [Launcher::GetOr options dst_dir "SimulationLib"]
    if {[IsRelativePath $output_dir]} {
      set output_dir [file normalize [file join [Repo::Get repo_path] $output_dir]]
    }

    Msg Info "Compiling the $simulator simulation libraries into $output_dir..."
    compile_simlib -simulator $simulator -family all -language all -library all -dir $output_dir
    Msg Info "Simulation libraries compiled. Use them with './Hog/Do SIMULATION <project> -lib $output_dir'."
  }
}