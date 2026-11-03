# Helpers for recording the signal paths selected in the active XSim WCFG.
# Copy this file into a project's simulation inputs and source it from the
# project-owned custom-Do script.
namespace eval WcfgVcd {
  proc selected_objects {} {
    set wave_config [current_wave_config]
    if {$wave_config eq ""} {
      error "No waveform configuration is loaded. Start XSim with -view <file.wcfg>."
    }

    set wcfg_file [get_property FILE_PATH $wave_config]
    set file_id [open $wcfg_file r]
    set wcfg_xml [read $file_id]
    close $file_id

    set objects {}
    foreach tag [regexp -all -inline {<wvobject[[:space:]][^>]*>} $wcfg_xml] {
      if {![regexp {fp_name="([^"]+)"} $tag -> signal_path]} {
        continue
      }
      if {[string index $signal_path 0] ne "/"} {
        continue
      }

      set matched [get_objects -quiet $signal_path]
      if {[llength $matched] == 0} {
        puts "WARNING: WCFG signal is not present in this simulation: $signal_path"
        continue
      }
      foreach object $matched {
        lappend objects $object
      }
    }

    set objects [lsort -unique $objects]
    if {[llength $objects] == 0} {
      error "The active WCFG did not select any simulation objects."
    }
    return $objects
  }

  proc start {vcd_file} {
    set objects [selected_objects]
    puts "Recording [llength $objects] WCFG-selected objects to $vcd_file"
    open_vcd $vcd_file
    log_vcd $objects
  }

  proc stop {} {
    close_vcd
  }
}
