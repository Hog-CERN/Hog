namespace eval Tools::Vivado {

  variable Manifest {
    name      "Vivado"
    vendor    "AMD/Xilinx"
    ref_names {vivado vivado_vitis_classic planahead}
    Flows {
      CREATE {
        aliases {create_project c}
        stages  {CreateProject}
      }
      SYNTH {
        aliases {s synthesize}
        stages  {@CREATE Synthesize}
        options {{no_bitstream "Skip bitstream generation"}}
      }
      IMPL {
        aliases {i}
        stages  {@SYNTH Implement}
        options {{no_bitstream "Skip bitstream generation"}}
      }
    }
  }

  proc IsActive {} {
    if {[info commands version] eq ""} { return 0 }
    set v [version]
    return [expr {
      [string first "Vivado"    $v] == 0 ||
      [string first "PlanAhead" $v] == 0
    }]
  }


  proc Launch {} {
    # Each tool should define how it passes context from tclsh to itself
    # I think most can just pass the entire context dict as a tclarg, but
    # something like vitis_unified will probably need to manpulate it to
    # pass to python env. 

    set script [Context::Get launch_script]
    set before_tcl_script " -nojournal -nolog -mode batch -notrace -source "
    exec -ignorestderr vivado -nojournal -nolog -mode batch -notrace -source $script -tclargs "-context"  "[Context::GetFullContext]" >@ stdout
  }

  proc Initialize {args} {
    # Again, each tool will need to define how it processes the context passed from tclsh.
    if {[llength $args] < 1} {
      puts "Vivado::InitializeTool requires at least 1 argument (the context dict)"
      return
    } else {
      if {[lindex $args 0] eq "-context"} {
        set context_dict [lindex $args 1]
        Context::Load $context_dict
      } else {
        puts "Vivado::InitializeTool requires -context argument"
        return
      }
    }
  }

  proc CreateProject {} {
    set project_name [Context::Get launch_settings project_name]
    set top_path     [Context::Get launch_settings top_path]
    Msg Info "Creating Vivado project \"$project_name\" from $top_path"
  }

  proc Synthesize {} {
    Msg Info "Running synthesis..."
    return "Done"
  }

  proc Implement {} {
    Msg Info "Running implementation..."
  }

  proc GenerateBitstream {} {
    Msg Info "Generating bitstream..."
  }

  proc Simulate {} {
    Msg Info "Running simulation..."
  }

  proc CheckSyntax {} {
    Msg Info "Checking syntax..."
  }

  proc RtlAnalysis {} {
    Msg Info "Running RTL analysis..."
  }

}
