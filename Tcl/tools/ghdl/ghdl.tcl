# GHDL is not an IDE: it is a command line simulator. This tool deliberately does
# not define a Launch proc, so the injected default in Tcl/core/tools.tcl returns
# "no_ide" and the flow runs in the same tclsh process. This matches the legacy
# launcher, which ran GHDL simulations before ever spawning an IDE.

namespace eval Tools::Ghdl {
  variable Manifest {
    name        "GHDL"
    vendor      "GHDL"
    description "GHDL open source VHDL simulator."
    aliases     {ghdl}
    Flows {
      SIMULATION {
        aliases {s sim simulate}
        description "Simulate the project with GHDL."
        stages  {ImportGhdl RunGhdl}
        options {
          {simset.arg   "" "Simulation sets to run. If not set, all the GHDL simulation sets are run."}
          {ext_path.arg "" "Sets the absolute path for the external libraries."}
        }
      }
    }
  }

  # Cache of the GHDL simulation sets of the current project, filled by
  # _GhdlSimsets so that ImportGhdl and RunGhdl agree on what to run.
  variable _simsets ""

  proc Initialize {} {
    if {[catch {exec which ghdl}]} {
      Msg Error "ghdl was not found in your system. Make sure to add ghdl to your PATH environment variable."
      return
    }
    FlowControl::Produce GHDL_INITIALIZED
  }

  ## @brief Return the GHDL simulation sets of the current project.
  #
  # HLS simsets (csim:/cosim:) are filtered out of the -simset option, as GHDL
  # only deals with HDL ones. Mirrors Tcl/launch.tcl:499-510.
  proc _GhdlSimsets {} {
    variable _simsets
    if {$_simsets ne ""} {
      return $_simsets
    }

    set hdl_simsets [list]
    foreach s [Launcher::GetOr options simset ""] {
      if {![regexp {^(csim|cosim):} $s]} {
        lappend hdl_simsets $s
      }
    }

    set _simsets [GetSimSets [CurrentProject::Get project_name] [Repo::Get repo_path] $hdl_simsets 1]
    if {$_simsets eq ""} {
      set _simsets [dict create]
    }
    return $_simsets
  }

  proc _ExtPath {} {
    return [Launcher::GetOr options ext_path ""]
  }

  ## @brief Import the project sources into the GHDL work directory.
  #
  # The legacy launcher imported once, using the first GHDL simset, and then ran
  # every simset against that work directory (Tcl/launch.tcl:511-518).
  proc ImportGhdl {} {
    FlowControl::Require GHDL_INITIALIZED

    set simsets [_GhdlSimsets]
    if {[dict size $simsets] == 0} {
      FlowControl::ExitFlow "No GHDL simulation set found for [CurrentProject::Get project_name]."
      return
    }

    set project_name [CurrentProject::Get project_name]
    set repo_path    [Repo::Get repo_path]

    set simset_name [lindex [dict keys $simsets] 0]
    Msg Info "Importing GHDL files for $project_name using simulation set $simset_name..."
    ImportGHDL $project_name $repo_path $simset_name [dict get $simsets $simset_name] [_ExtPath]

    FlowControl::Produce GHDL_IMPORTED
  }

  ## @brief Elaborate and run every GHDL simulation set.
  proc RunGhdl {} {
    FlowControl::Require GHDL_IMPORTED

    set project_name [CurrentProject::Get project_name]
    set repo_path    [Repo::Get repo_path]
    set ext_path     [_ExtPath]

    dict for {simset_name simset_dict} [_GhdlSimsets] {
      Msg Info "Running GHDL simulation set $simset_name..."
      LaunchGHDL $project_name $repo_path $simset_name $simset_dict $ext_path
    }

    FlowControl::Produce SIMULATION_DONE
  }
}
