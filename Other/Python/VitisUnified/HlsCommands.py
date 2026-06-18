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

import sys
import os
import subprocess
import shutil
import json

# Import functions from SharedCommands
_shared_commands_path = os.path.join(os.path.dirname(__file__), "SharedCommands.py")
if os.path.exists(_shared_commands_path):
  import importlib.util
  spec = importlib.util.spec_from_file_location("shared_commands", _shared_commands_path)
  shared_commands = importlib.util.module_from_spec(spec)
  spec.loader.exec_module(shared_commands)
  PrintInfo = shared_commands.PrintInfo
  PrintError = shared_commands.PrintError
  PrintWarning = shared_commands.PrintWarning
  PrintDebug = shared_commands.PrintDebug
  InitVitisWorkspace = shared_commands.InitVitisWorkspace
else:
  print("ERROR: [Hog:Python:HlsCommands.py] Failed to import SharedCommands, file not found: %s" % _shared_commands_path)


def ValidateHlsConfig(cfg_file):
  """Validate that an hls_config.cfg file exists and has required fields.

  Args:
    cfg_file: Path to the hls_config.cfg file
  Returns:
    bool: True if valid, False otherwise
  """
  if not os.path.exists(cfg_file):
    PrintError("HLS config file not found: %s" % cfg_file)
    return False

  has_part = False
  has_top = False
  has_syn_file = False

  with open(cfg_file, 'r') as f:
    for line in f:
      line = line.strip()
      if line.startswith('part='):
        has_part = True
      elif line.startswith('syn.top='):
        has_top = True
      elif line.startswith('syn.file='):
        has_syn_file = True

  if not has_part:
    PrintError("HLS config file missing 'part=' line: %s" % cfg_file)
    return False
  if not has_top:
    PrintError("HLS config file missing 'syn.top=' line: %s" % cfg_file)
    return False
  if not has_syn_file:
    PrintError("HLS config file missing 'syn.file=' line(s): %s" % cfg_file)
    return False

  PrintInfo("HLS config file validated: %s" % cfg_file)
  return True


def GenerateMinimalConfig(cfg_file, part, top_function):
  """Generate a minimal hls_config.cfg file with defaults.

  Called when no hls_config.cfg exists and the user wants Hog to create one.

  Args:
    cfg_file: Path where the config file will be written
    part: FPGA part string
    top_function: Top-level function name
  Returns:
    bool: True if successful, False otherwise
  """
  try:
    PrintInfo("Generating minimal HLS config: %s" % cfg_file)
    output_dir = os.path.dirname(cfg_file)
    if output_dir and not os.path.exists(output_dir):
      os.makedirs(output_dir, exist_ok=True)

    with open(cfg_file, 'w') as f:
      f.write("part=%s\n\n" % part)
      f.write("[hls]\n")
      f.write("flow_target=vivado\n")
      f.write("package.output.format=ip_catalog\n")
      f.write("package.output.syn=false\n")
      f.write("clock=10\n")
      f.write("syn.top=%s\n" % top_function)
      f.write("# Add your source files below:\n")
      f.write("# syn.file=path/to/source.cpp\n")
      f.write("# tb.file=path/to/testbench.cpp\n")

    PrintInfo("Minimal HLS config generated at: %s" % cfg_file)
    PrintWarning("Please edit %s to add your source and testbench files" % cfg_file)
    return True

  except Exception as e:
    PrintError("Failed to generate minimal HLS config: %s" % e)
    return False


def RunHlsCsim(component_name, cfg_file, work_dir):
  """Run C simulation for an HLS component.

  Args:
    component_name: Name of the HLS component
    cfg_file: Absolute path to the hls_config.cfg file
    work_dir: Working directory for the build
  Returns:
    bool: True if successful, False otherwise
  """
  try:
    PrintInfo("Running C simulation for HLS component '%s'" % component_name)
    cfg_dir = os.path.dirname(os.path.abspath(cfg_file))
    cmd = ["vitis-run", "--mode", "hls", "--csim",
           "--config", os.path.abspath(cfg_file),
           "--work_dir", os.path.abspath(work_dir)]

    PrintInfo("Command: %s" % " ".join(cmd))
    PrintInfo("Running from directory: %s" % cfg_dir)
    result = subprocess.run(cmd, capture_output=False, cwd=cfg_dir)

    if result.returncode != 0:
      PrintError("C simulation failed for '%s' (exit code: %d)" % (component_name, result.returncode))
      issues = _check_config_issues(cfg_file)
      if issues:
        PrintError("Possible configuration issues detected:")
        for issue in issues:
          PrintError("  - %s" % issue)
      return False

    PrintInfo("C simulation completed successfully for '%s'" % component_name)
    return True

  except FileNotFoundError:
    PrintError("'vitis-run' not found in PATH. Please source Vitis settings first.")
    return False
  except Exception as e:
    PrintError("Failed to run C simulation: %s" % e)
    import traceback
    traceback.print_exc()
    sys.stdout.flush()
    return False


def RunHlsSynthesis(component_name, cfg_file, work_dir):
  """Run C synthesis for an HLS component.

  Args:
    component_name: Name of the HLS component
    cfg_file: Absolute path to the hls_config.cfg file
    work_dir: Working directory for the build
  Returns:
    bool: True if successful, False otherwise
  """
  try:
    PrintInfo("Running C synthesis for HLS component '%s'" % component_name)
    cfg_dir = os.path.dirname(os.path.abspath(cfg_file))
    cmd = ["v++", "--compile", "--mode", "hls",
           "--config", os.path.abspath(cfg_file),
           "--work_dir", os.path.abspath(work_dir)]

    PrintInfo("Command: %s" % " ".join(cmd))
    PrintInfo("Running from directory: %s" % cfg_dir)
    result = subprocess.run(cmd, capture_output=False, cwd=cfg_dir)

    if result.returncode != 0:
      PrintError("C synthesis failed for '%s' (exit code: %d)" % (component_name, result.returncode))
      issues = _check_config_issues(cfg_file, check_syn=True, check_tb=False)
      if issues:
        PrintError("Possible configuration issues detected:")
        for issue in issues:
          PrintError("  - %s" % issue)
      return False

    PrintInfo("C synthesis completed successfully for '%s'" % component_name)
    return True

  except FileNotFoundError:
    PrintError("'v++' not found in PATH. Please source Vitis settings first.")
    return False
  except Exception as e:
    PrintError("Failed to run C synthesis: %s" % e)
    import traceback
    traceback.print_exc()
    sys.stdout.flush()
    return False


def RunHlsCosim(component_name, cfg_file, work_dir):
  """Run co-simulation for an HLS component.

  Args:
    component_name: Name of the HLS component
    cfg_file: Absolute path to the hls_config.cfg file
    work_dir: Working directory for the build
  Returns:
    bool: True if successful, False otherwise
  """
  try:
    PrintInfo("Running co-simulation for HLS component '%s'" % component_name)
    cfg_dir = os.path.dirname(os.path.abspath(cfg_file))
    cmd = ["vitis-run", "--mode", "hls", "--cosim",
           "--config", os.path.abspath(cfg_file),
           "--work_dir", os.path.abspath(work_dir)]

    PrintInfo("Command: %s" % " ".join(cmd))
    PrintInfo("Running from directory: %s" % cfg_dir)
    result = subprocess.run(cmd, capture_output=False, cwd=cfg_dir)

    if result.returncode != 0:
      PrintError("C/RTL co-simulation failed for '%s' (exit code: %d)" % (component_name, result.returncode))
      issues = _check_config_issues(cfg_file)
      syn_dir = os.path.join(os.path.abspath(work_dir), "hls", "syn")
      if not os.path.isdir(syn_dir):
        issues.append("C synthesis output not found at %s — synthesis must complete successfully before co-simulation" % syn_dir)
      if issues:
        PrintError("Possible configuration issues detected:")
        for issue in issues:
          PrintError("  - %s" % issue)
      return False

    PrintInfo("Co-simulation completed successfully for '%s'" % component_name)
    return True

  except FileNotFoundError:
    PrintError("'vitis-run' not found in PATH. Please source Vitis settings first.")
    return False
  except Exception as e:
    PrintError("Failed to run co-simulation: %s" % e)
    import traceback
    traceback.print_exc()
    sys.stdout.flush()
    return False


def RunHlsImpl(component_name, cfg_file, work_dir):
  """Run implementation (place & route) for an HLS component.

  Args:
    component_name: Name of the HLS component
    cfg_file: Absolute path to the hls_config.cfg file
    work_dir: Working directory for the build
  Returns:
    bool: True if successful, False otherwise
  """
  try:
    PrintInfo("Running implementation for HLS component '%s'" % component_name)
    cfg_dir = os.path.dirname(os.path.abspath(cfg_file))
    cmd = ["vitis-run", "--mode", "hls", "--impl",
           "--config", os.path.abspath(cfg_file),
           "--work_dir", os.path.abspath(work_dir)]

    PrintInfo("Command: %s" % " ".join(cmd))
    PrintInfo("Running from directory: %s" % cfg_dir)
    result = subprocess.run(cmd, capture_output=False, cwd=cfg_dir)

    if result.returncode != 0:
      PrintError("Implementation failed for '%s' (exit code: %d)" % (component_name, result.returncode))
      PrintError("Check the log above for details. Common causes:")
      PrintError("  - C synthesis must complete successfully before implementation")
      PrintError("  - Timing constraints not met: review clock period in hls_config.cfg")
      return False

    PrintInfo("Implementation completed successfully for '%s'" % component_name)
    return True

  except FileNotFoundError:
    PrintError("'vitis-run' not found in PATH. Please source Vitis settings first.")
    return False
  except Exception as e:
    PrintError("Failed to run implementation: %s" % e)
    import traceback
    traceback.print_exc()
    sys.stdout.flush()
    return False


def ExportHlsRtl(component_name, work_dir, output_dir, language):
  """Copy generated VHDL or Verilog files from the HLS build to a source-tree directory.

  After C synthesis, generated RTL files reside under work_dir/hls/syn/vhdl/
  and work_dir/hls/syn/verilog/. This function copies the requested language
  to output_dir so they can be version-controlled and instantiated in other designs.

  Args:
    component_name: Name of the HLS component
    work_dir: HLS build working directory (contains hls/syn/)
    output_dir: Destination directory (e.g. example_hls/outputs/)
    language: "vhdl" or "verilog"
  Returns:
    bool: True if files were exported, False otherwise
  """
  try:
    lang = language.lower()
    if lang not in ("vhdl", "verilog"):
      PrintError("Invalid language '%s'. Must be 'vhdl' or 'verilog'." % language)
      return False

    PrintInfo("Exporting %s for HLS component '%s' to %s" % (lang.upper(), component_name, output_dir))

    if lang == "vhdl":
      extensions = (".vhd", ".vhdl")
    else:
      extensions = (".v", ".sv")

    search_dirs = [
      os.path.join(work_dir, "hls", "syn", lang),
      os.path.join(work_dir, component_name, "syn", lang),
    ]

    found_files = []
    for rtl_dir in search_dirs:
      if not os.path.isdir(rtl_dir):
        continue
      for f in os.listdir(rtl_dir):
        if any(f.endswith(ext) for ext in extensions):
          found_files.append(os.path.join(rtl_dir, f))

    if not found_files:
      PrintWarning("No %s files found for '%s'. Run C synthesis first." % (lang.upper(), component_name))
      PrintWarning("Searched: %s" % ", ".join(search_dirs))
      return False

    os.makedirs(output_dir, exist_ok=True)

    for src_file in found_files:
      dst = os.path.join(output_dir, os.path.basename(src_file))
      PrintInfo("Exporting: %s -> %s" % (os.path.basename(src_file), dst))
      shutil.copy2(src_file, dst)

    PrintInfo("Exported %d %s file(s) for '%s'" % (len(found_files), lang.upper(), component_name))
    return True

  except Exception as e:
    PrintError("Failed to export RTL: %s" % e)
    import traceback
    traceback.print_exc()
    sys.stdout.flush()
    return False


def ExportHlsIp(component_name, work_dir, output_dir):
  """Copy the IP catalog ZIP from the HLS build to a source-tree directory.

  Requires package.output.format=ip_catalog in hls_config.cfg.
  The ZIP file is generated during C synthesis and contains the packaged IP
  (component.xml, RTL sources, synthesis scripts) ready for Vivado IP catalog.

  Args:
    component_name: Name of the HLS component
    work_dir: HLS build working directory
    output_dir: Destination directory for the IP ZIP
  Returns:
    bool: True if IP was exported, False otherwise
  """
  try:
    PrintInfo("Exporting IP catalog for HLS component '%s' to %s" % (component_name, output_dir))

    search_dirs = [
      work_dir,
      os.path.join(work_dir, "hls"),
      os.path.join(work_dir, "hls", "syn"),
      os.path.join(work_dir, component_name),
    ]

    found_files = []
    for search_dir in search_dirs:
      if not os.path.isdir(search_dir):
        continue
      for f in os.listdir(search_dir):
        if f.endswith(".zip"):
          found_files.append(os.path.join(search_dir, f))

    if not found_files:
      PrintError("No IP catalog ZIP found for '%s'. Make sure package.output.format=ip_catalog is set in hls_config.cfg." % component_name)
      PrintError("Searched: %s" % ", ".join(search_dirs))
      return False

    os.makedirs(output_dir, exist_ok=True)

    for src_file in found_files:
      dst = os.path.join(output_dir, os.path.basename(src_file))
      PrintInfo("Exporting: %s -> %s" % (os.path.basename(src_file), dst))
      shutil.copy2(src_file, dst)

    PrintInfo("Exported %d IP file(s) for '%s'" % (len(found_files), component_name))
    return True

  except Exception as e:
    PrintError("Failed to export IP: %s" % e)
    import traceback
    traceback.print_exc()
    sys.stdout.flush()
    return False


def CollectHlsReports(component_name, work_dir, output_dir):
  """Collect HLS synthesis, implementation and simulation reports into output_dir.

  Reports are typically located under:
    - work_dir/hls/syn/report/  (C synthesis: timing, resource estimates)
    - work_dir/hls/impl/report/ (implementation: RTL synthesis, place & route, final timing)
    - work_dir/hls/sim/report/  (co-simulation)

  RTL and IP outputs are NOT collected here — their location is
  controlled by hls_config.cfg and they are version-controlled in place.

  Args:
    component_name: Name of the HLS component
    work_dir: Working directory where the build was done
    output_dir: Directory where reports should be copied (typically bin/)
  Returns:
    bool: True if any reports were found, False otherwise
  """
  try:
    PrintInfo("Collecting HLS reports for component '%s'" % component_name)

    report_extensions = (".rpt", ".xml", ".log")
    report_roots = [
      os.path.join(work_dir, "hls", "syn", "report"),
      os.path.join(work_dir, "hls", "impl", "report"),
      os.path.join(work_dir, "hls", "sim", "report"),
      os.path.join(work_dir, component_name, "syn", "report"),
      os.path.join(work_dir, component_name, "impl", "report"),
      os.path.join(work_dir, component_name, "sim", "report"),
    ]

    found_reports = []
    for report_dir in report_roots:
      if not os.path.isdir(report_dir):
        continue
      for root, dirs, files in os.walk(report_dir):
        for f in files:
          if any(f.endswith(ext) for ext in report_extensions):
            found_reports.append(os.path.join(root, f))

    if not found_reports:
      PrintWarning("No reports found for '%s' in %s" % (component_name, work_dir))
      return False

    hls_report_dir = os.path.join(output_dir, component_name, "reports")
    os.makedirs(hls_report_dir, exist_ok=True)

    for report in found_reports:
      dst = os.path.join(hls_report_dir, os.path.basename(report))
      PrintInfo("Copying report: %s -> %s" % (report, dst))
      shutil.copy2(report, dst)

    PrintInfo("Collected %d report(s) for '%s'" % (len(found_reports), component_name))
    return True

  except Exception as e:
    PrintError("Failed to collect HLS reports: %s" % e)
    import traceback
    traceback.print_exc()
    sys.stdout.flush()
    return False


def _check_config_issues(cfg_file, check_syn=True, check_tb=True):
  """Parse hls_config.cfg and return a list of detected configuration issues.

  Checks whether syn.file / tb.file paths and -I include directories
  referenced in syn.cflags / tb.cflags actually exist on disk.

  Args:
    cfg_file: Absolute path to the hls_config.cfg file
    check_syn: If True, check syn.file and syn.cflags entries
    check_tb:  If True, check tb.file and tb.cflags entries
  Returns:
    list of str: human-readable issue descriptions (empty if everything looks fine)
  """
  issues = []
  cfg_dir = os.path.dirname(os.path.abspath(cfg_file))

  syn_files = []
  tb_files = []
  syn_cflags_raw = []
  tb_cflags_raw = []

  try:
    with open(cfg_file, 'r') as f:
      for line in f:
        line = line.strip()
        if line.startswith('#') or '=' not in line:
          continue
        key, _, value = line.partition('=')
        key = key.strip()
        value = value.strip()
        if key == 'syn.file':
          syn_files.append(value)
        elif key == 'tb.file':
          tb_files.append(value)
        elif key == 'syn.cflags':
          syn_cflags_raw = value.split()
        elif key == 'tb.cflags':
          tb_cflags_raw = value.split()
  except Exception:
    return issues

  if check_syn:
    for rel in syn_files:
      abs_path = os.path.normpath(os.path.join(cfg_dir, rel))
      if not os.path.exists(abs_path):
        issues.append("Source file not found: %s (resolved to %s)" % (rel, abs_path))
    for flag in _resolve_cflags(syn_cflags_raw, cfg_dir):
      if flag.startswith("-I"):
        inc_dir = flag[2:]
        if not os.path.isdir(inc_dir):
          issues.append("syn.cflags include directory not found: %s" % inc_dir)

  if check_tb:
    for rel in tb_files:
      abs_path = os.path.normpath(os.path.join(cfg_dir, rel))
      if not os.path.exists(abs_path):
        issues.append("Testbench file not found: %s (resolved to %s)" % (rel, abs_path))
    for flag in _resolve_cflags(tb_cflags_raw, cfg_dir):
      if flag.startswith("-I"):
        inc_dir = flag[2:]
        if not os.path.isdir(inc_dir):
          issues.append("tb.cflags include directory not found: %s" % inc_dir)

  return issues


def _find_first_file(roots, filename):
  """Search each root (recursively) for the given filename, return the first match."""
  for root in roots:
    if not os.path.isdir(root):
      continue
    for dirpath, _, files in os.walk(root):
      if filename in files:
        return os.path.join(dirpath, filename)
  return None


def _fmt_util_pct(used, avail):
  """Format a utilisation percentage as 'XX.XX' or '-' when unknown."""
  try:
    used_i = int(used)
    avail_i = int(avail)
    if avail_i <= 0:
      return "-"
    return "{:.2f}".format(100.0 * used_i / avail_i)
  except (ValueError, TypeError):
    return "-"


def _write_hls_util_section(f, component_name, stage, rows):
  """Write one utilisation section (markdown table) to file handle f.

  rows is a list of tuples (site_type, used, available).
  """
  f.write("## %s HLS %s Utilization report\n\n\n" % (component_name, stage))
  f.write("| **Site Type** | **Used** | **Available** | **Util%** |\n")
  f.write("| --- | --- | --- | --- |\n")
  for site, used, avail in rows:
    pct = _fmt_util_pct(used, avail)
    used_s = used if used not in (None, "") else "-"
    avail_s = avail if avail not in (None, "") else "-"
    f.write("| %s | %s | %s | %s |\n" % (site, used_s, avail_s, pct))
  f.write("\n\n")


def _write_hls_timing_section(f, component_name, stage, rows, met):
  """Write one timing section (markdown table) to file handle f.

  rows is a list of tuples (parameter, value_str).
  met is True/False/None.
  """
  f.write("## %s HLS %s Timing summary\n\n" % (component_name, stage))
  f.write("| **Parameter** | **value (ns)** |\n")
  f.write("| --- | --- |\n")
  for name, value in rows:
    f.write("| %s | %s |\n" % (name, value))
  f.write("\n")
  if met is True:
    f.write("Time requirements are met.\n")
  elif met is False:
    f.write("Time requirements are **NOT** met.\n")
  f.write("\n\n")


def _parse_hls_syn_xml(xml_path):
  """Parse an HLS C-synthesis csynth.xml file.

  Returns a dict with keys: target_clk, estimated_clk, clock_uncertainty,
  lut, ff, dsp, bram, uram, avail_lut, avail_ff, avail_dsp, avail_bram, avail_uram.
  Missing fields are None.
  """
  import xml.etree.ElementTree as ET
  data = {
    "target_clk": None, "estimated_clk": None, "clock_uncertainty": None,
    "lut": None, "ff": None, "dsp": None, "bram": None, "uram": None,
    "avail_lut": None, "avail_ff": None, "avail_dsp": None,
    "avail_bram": None, "avail_uram": None,
  }
  tree = ET.parse(xml_path)
  root = tree.getroot()

  ua = root.find("UserAssignments")
  if ua is not None:
    t = ua.findtext("TargetClockPeriod")
    if t is not None:
      data["target_clk"] = t.strip()
    u = ua.findtext("ClockUncertainty")
    if u is not None:
      data["clock_uncertainty"] = u.strip()

  perf = root.find("PerformanceEstimates/SummaryOfTimingAnalysis")
  if perf is not None:
    e = perf.findtext("EstimatedClockPeriod")
    if e is not None:
      data["estimated_clk"] = e.strip()

  area = root.find("AreaEstimates")
  if area is not None:
    res = area.find("Resources")
    if res is not None:
      data["lut"] = (res.findtext("LUT") or "").strip() or None
      data["ff"] = (res.findtext("FF") or "").strip() or None
      data["dsp"] = (res.findtext("DSP") or "").strip() or None
      data["bram"] = (res.findtext("BRAM_18K") or "").strip() or None
      data["uram"] = (res.findtext("URAM") or "").strip() or None
    avail = area.find("AvailableResources")
    if avail is not None:
      data["avail_lut"] = (avail.findtext("LUT") or "").strip() or None
      data["avail_ff"] = (avail.findtext("FF") or "").strip() or None
      data["avail_dsp"] = (avail.findtext("DSP") or "").strip() or None
      data["avail_bram"] = (avail.findtext("BRAM_18K") or "").strip() or None
      data["avail_uram"] = (avail.findtext("URAM") or "").strip() or None

  return data


def _parse_hls_impl_xml(xml_path):
  """Parse an HLS implementation export_impl.xml file.

  Returns a dict with keys: target_clk, achieved_clk, wns, tns, timing_met,
  lut, ff, dsp, bram, uram, clb, srl,
  avail_lut, avail_ff, avail_dsp, avail_bram, avail_uram, avail_clb.
  Missing fields are None. timing_met is True/False/None.
  """
  import xml.etree.ElementTree as ET
  data = {
    "target_clk": None, "achieved_clk": None, "wns": None, "tns": None,
    "timing_met": None,
    "lut": None, "ff": None, "dsp": None, "bram": None, "uram": None,
    "clb": None, "srl": None,
    "avail_lut": None, "avail_ff": None, "avail_dsp": None,
    "avail_bram": None, "avail_uram": None, "avail_clb": None,
  }
  tree = ET.parse(xml_path)
  root = tree.getroot()

  tr = root.find("TimingReport")
  if tr is not None:
    data["target_clk"] = (tr.findtext("TargetClockPeriod") or "").strip() or None
    data["achieved_clk"] = (tr.findtext("AchievedClockPeriod") or "").strip() or None
    data["wns"] = (tr.findtext("WNS_FINAL") or "").strip() or None
    data["tns"] = (tr.findtext("TNS_FINAL") or "").strip() or None
    met = (tr.findtext("TIMING_MET") or "").strip().upper()
    if met == "TRUE":
      data["timing_met"] = True
    elif met == "FALSE":
      data["timing_met"] = False

  ar = root.find("AreaReport")
  if ar is not None:
    res = ar.find("Resources")
    if res is not None:
      data["lut"] = (res.findtext("LUT") or "").strip() or None
      data["ff"] = (res.findtext("FF") or "").strip() or None
      data["dsp"] = (res.findtext("DSP") or "").strip() or None
      data["bram"] = (res.findtext("BRAM") or "").strip() or None
      data["uram"] = (res.findtext("URAM") or "").strip() or None
      data["clb"] = (res.findtext("CLB") or "").strip() or None
      data["srl"] = (res.findtext("SRL") or "").strip() or None
    avail = ar.find("AvailableResources")
    if avail is not None:
      data["avail_lut"] = (avail.findtext("LUT") or "").strip() or None
      data["avail_ff"] = (avail.findtext("FF") or "").strip() or None
      data["avail_dsp"] = (avail.findtext("DSP") or "").strip() or None
      data["avail_bram"] = (avail.findtext("BRAM") or "").strip() or None
      data["avail_uram"] = (avail.findtext("URAM") or "").strip() or None
      data["avail_clb"] = (avail.findtext("CLB") or "").strip() or None

  return data


def GenerateHlsSummary(component_name, work_dir, output_dir):
  """Generate markdown summary files for an HLS component.

  Parses C-synthesis (csynth.xml) and implementation (export_impl.xml) reports
  and writes two files into output_dir/<component_name>/:
    - utilization.txt
    - timing_ok.txt        (if timing is met)
    - timing_error.txt     (if timing is NOT met)

  File names mirror the Vivado convention so the existing CI logic (release
  notes assembly and timing_error.txt failure detection) works for HLS too.

  The caller decides the output_dir: for mixed (vivado_vitis_unified) projects
  it should already include a 'vitis_hls/' prefix to keep HLS files visually
  separate from Vivado's top-level outputs; for pure vitis_unified projects it
  is just the bin/<project>/ directory.

  Args:
    component_name: Name of the HLS component
    work_dir: HLS build working directory (contains hls/syn/, hls/impl/)
    output_dir: Directory where the <component_name>/ folder will be created.
  Returns:
    bool: True if at least one summary was generated, False otherwise
  """
  try:
    syn_roots = [
      os.path.join(work_dir, "hls", "syn", "report"),
      os.path.join(work_dir, component_name, "syn", "report"),
    ]
    impl_roots = [
      os.path.join(work_dir, "hls", "impl", "report"),
      os.path.join(work_dir, component_name, "impl", "report"),
    ]

    syn_xml = _find_first_file(syn_roots, "csynth.xml")
    impl_xml = _find_first_file(impl_roots, "export_impl.xml")

    if syn_xml is None and impl_xml is None:
      PrintWarning("No HLS XML reports found for '%s'; skipping summary generation." % component_name)
      return False

    comp_out_dir = os.path.join(output_dir, component_name)
    os.makedirs(comp_out_dir, exist_ok=True)

    # Parse what is available
    syn = _parse_hls_syn_xml(syn_xml) if syn_xml else None
    impl = _parse_hls_impl_xml(impl_xml) if impl_xml else None

    # Utilization file
    util_path = os.path.join(comp_out_dir, "utilization.txt")
    with open(util_path, "w") as f:
      if syn is not None:
        rows = [
          ("LUT",      syn["lut"],  syn["avail_lut"]),
          ("FF",       syn["ff"],   syn["avail_ff"]),
          ("DSP",      syn["dsp"],  syn["avail_dsp"]),
          ("BRAM_18K", syn["bram"], syn["avail_bram"]),
          ("URAM",     syn["uram"], syn["avail_uram"]),
        ]
        _write_hls_util_section(f, component_name, "Synthesis", rows)
      if impl is not None:
        rows = [
          ("LUT",  impl["lut"],  impl["avail_lut"]),
          ("FF",   impl["ff"],   impl["avail_ff"]),
          ("DSP",  impl["dsp"],  impl["avail_dsp"]),
          ("BRAM", impl["bram"], impl["avail_bram"]),
          ("URAM", impl["uram"], impl["avail_uram"]),
          ("CLB",  impl["clb"],  impl["avail_clb"]),
          ("SRL",  impl["srl"],  None),
        ]
        _write_hls_util_section(f, component_name, "Implementation", rows)

    # Timing summary — compute section data + per-stage met status
    syn_rows = []
    syn_met = None
    if syn is not None:
      if syn["target_clk"] is not None:
        syn_rows.append(("Target Clock Period", syn["target_clk"]))
      if syn["estimated_clk"] is not None:
        syn_rows.append(("Estimated Clock Period", syn["estimated_clk"]))
      if syn["clock_uncertainty"] is not None:
        syn_rows.append(("Clock Uncertainty", syn["clock_uncertainty"]))
      try:
        if syn["estimated_clk"] and syn["target_clk"]:
          t = float(syn["target_clk"])
          u = float(syn["clock_uncertainty"]) if syn["clock_uncertainty"] else 0.0
          e = float(syn["estimated_clk"])
          syn_met = e <= (t - u)
      except ValueError:
        syn_met = None

    impl_rows = []
    impl_met = None
    if impl is not None:
      if impl["target_clk"] is not None:
        impl_rows.append(("Target Clock Period", impl["target_clk"]))
      if impl["achieved_clk"] is not None:
        impl_rows.append(("Achieved Clock Period", impl["achieved_clk"]))
      if impl["wns"] is not None:
        impl_rows.append(("WNS", impl["wns"]))
      if impl["tns"] is not None:
        impl_rows.append(("TNS", impl["tns"]))
      impl_met = impl["timing_met"]

    # Overall timing status — prefer implementation; fall back to synthesis
    if impl_met is not None:
      overall_met = impl_met
    else:
      overall_met = syn_met

    # Remove any stale timing_ok.txt / timing_error.txt from previous runs,
    # so the surviving file unambiguously reflects the current status.
    for stale in ("timing_ok.txt", "timing_error.txt"):
      stale_path = os.path.join(comp_out_dir, stale)
      if os.path.exists(stale_path):
        try:
          os.remove(stale_path)
        except OSError:
          pass

    if overall_met is False:
      timing_name = "timing_error.txt"
    else:
      timing_name = "timing_ok.txt"
    timing_path = os.path.join(comp_out_dir, timing_name)

    with open(timing_path, "w") as f:
      if syn is not None:
        _write_hls_timing_section(f, component_name, "Synthesis", syn_rows, syn_met)
      if impl is not None:
        _write_hls_timing_section(f, component_name, "Implementation", impl_rows, impl_met)

    PrintInfo("Generated HLS utilization summary: %s" % util_path)
    PrintInfo("Generated HLS timing summary:      %s" % timing_path)
    return True

  except Exception as e:
    PrintError("Failed to generate HLS summary for '%s': %s" % (component_name, e))
    import traceback
    traceback.print_exc()
    sys.stdout.flush()
    return False


def _resolve_cflags(raw_flags, cfg_dir):
  """Resolve a list of raw cflags tokens, making -I paths absolute relative to cfg_dir.

  Handles both '-Ipath' (merged) and '-I path' (space-separated) forms.
  Non-absolute -I paths are resolved relative to cfg_dir.

  Returns:
    list of resolved flag strings
  """
  resolved = []
  i = 0
  while i < len(raw_flags):
    flag = raw_flags[i]
    if flag == "-I" and i + 1 < len(raw_flags):
      inc_dir = raw_flags[i + 1]
      if not os.path.isabs(inc_dir):
        inc_dir = os.path.normpath(os.path.join(cfg_dir, inc_dir))
      resolved.append("-I%s" % inc_dir)
      i += 2
    elif flag.startswith("-I") and len(flag) > 2:
      inc_dir = flag[2:]
      if not os.path.isabs(inc_dir):
        inc_dir = os.path.normpath(os.path.join(cfg_dir, inc_dir))
      resolved.append("-I%s" % inc_dir)
      i += 1
    else:
      resolved.append(flag)
      i += 1
  return resolved


def GenerateCompileCommands(cfg_file, comp_dir):
  """Generate compile_commands.json for IDE linting support.

  Parses hls_config.cfg to extract source files, include flags, and top function,
  then writes a compile_commands.json that the Vitis IDE clang linter can use.

  Args:
    cfg_file: Absolute path to hls_config.cfg
    comp_dir: Directory where compile_commands.json will be written
  """
  try:
    cfg_dir = os.path.dirname(os.path.realpath(cfg_file))

    syn_files = []
    tb_files = []
    syn_top = ""
    syn_cflags = []
    tb_cflags = []

    with open(cfg_file, 'r') as f:
      for line in f:
        line = line.strip()
        if line.startswith('#') or '=' not in line:
          continue
        key, _, value = line.partition('=')
        key = key.strip()
        value = value.strip()

        if key == 'syn.file':
          abs_path = os.path.normpath(os.path.join(cfg_dir, value))
          if abs_path.endswith(('.c', '.cpp', '.cc', '.cxx')):
            syn_files.append(abs_path)
        elif key == 'tb.file':
          abs_path = os.path.normpath(os.path.join(cfg_dir, value))
          if abs_path.endswith(('.c', '.cpp', '.cc', '.cxx')):
            tb_files.append(abs_path)
        elif key == 'syn.top':
          syn_top = value
        elif key == 'syn.cflags':
          syn_cflags = value.split()
        elif key == 'tb.cflags':
          tb_cflags = value.split()

    vitis_path = ""
    vpp = shutil.which("v++")
    if vpp:
      vitis_path = os.path.normpath(os.path.join(os.path.dirname(os.path.realpath(vpp)), ".."))

    syn_headers = os.path.join(vitis_path, "common", "technology", "autopilot") if vitis_path else ""
    sim_headers = os.path.join(vitis_path, "include") if vitis_path else ""
    clang_path = os.path.join(vitis_path, "vcxx", "libexec", "clang++") if vitis_path else "clang++"
    gcc_toolchain = os.path.join(vitis_path, "tps", "lnx64", "gcc-8.3.0") if vitis_path else ""

    resolved_syn_cflags = _resolve_cflags(syn_cflags, cfg_dir)
    resolved_tb_cflags = _resolve_cflags(tb_cflags, cfg_dir)

    entries = []
    for src in syn_files:
      args = [clang_path]
      if gcc_toolchain:
        args.append("--gcc-toolchain=%s" % gcc_toolchain)
      args.append("-fhls")
      if syn_headers:
        args.append("-hls-syn-headers-dir=%s" % syn_headers)
      if syn_top:
        args.append("-fhlstoplevel=%s" % syn_top)
      args.extend(resolved_syn_cflags)
      args.extend(["-c", src])
      entries.append({
        "directory": cfg_dir,
        "arguments": args,
        "file": src
      })

    for src in tb_files:
      args = [clang_path]
      if gcc_toolchain:
        args.append("--gcc-toolchain=%s" % gcc_toolchain)
      args.append("-fhls-tb")
      if sim_headers:
        args.append("-hls-sim-headers-dir=%s" % sim_headers)
      args.extend(resolved_tb_cflags)
      args.extend(["-c", src])
      entries.append({
        "directory": cfg_dir,
        "arguments": args,
        "file": src
      })

    if entries:
      cc_path = os.path.join(comp_dir, "compile_commands.json")
      with open(cc_path, 'w') as f:
        json.dump(entries, f, indent=2)
        f.write("\n")
      PrintInfo("Generated compile_commands.json with %d entries at %s" % (len(entries), cc_path))

  except Exception as e:
    PrintWarning("Could not generate compile_commands.json: %s" % e)


def CreateHlsWorkspace(workspace_path, component_name, cfg_file, work_dir):
  """Create a Vitis-compatible HLS workspace so the project can be opened in the GUI.

  Uses InitVitisWorkspace (SharedCommands) to properly initialize the
  workspace metadata (_ide folder), then creates a component directory
  with a vitis-comp.json descriptor that points directly to the committed
  hls_config.cfg in the source tree.

  Args:
    workspace_path: Path to the Vitis workspace (e.g. Projects/<proj>/vitis_unified/)
    component_name: Name of the HLS component
    cfg_file:       Absolute path to the committed hls_config.cfg in the source tree
    work_dir:       Absolute path to the HLS build work directory
  Returns:
    bool: True if successful, False otherwise
  """
  try:
    import vitis

    os.makedirs(workspace_path, exist_ok=True)

    client = InitVitisWorkspace(workspace_path)
    if client is None:
      PrintError("Could not initialize Vitis workspace")
      return False

    comp_dir = os.path.join(workspace_path, component_name)
    cfg_file = os.path.abspath(cfg_file)
    rel_cfg = os.path.relpath(cfg_file, comp_dir)
    rel_work_dir = os.path.relpath(os.path.abspath(work_dir), comp_dir)

    # create_hls_component(name, platform=None, part=None, cfg_file=None, template=None)
    api_created = False
    try:
      client.create_hls_component(
        name=component_name,
        cfg_file=cfg_file
      )
      PrintInfo("HLS component '%s' created via Vitis API" % component_name)
      api_created = True
    except AttributeError:
      PrintInfo("client.create_hls_component() not available, generating vitis-comp.json manually")
    except Exception as e:
      PrintWarning("Vitis API create_hls_component failed: %s. Falling back to manual generation." % e)

    if not api_created:
      os.makedirs(comp_dir, exist_ok=True)

      vitis_comp = {
        "name": component_name,
        "type": "HLS",
        "configuration": {
          "componentType": "HLS",
          "configFiles": [rel_cfg.replace("\\", "/")],
          "work_dir": rel_work_dir.replace("\\", "/")
        },
        "template": "empty_hls_component"
      }

      vitis_comp_path = os.path.join(comp_dir, "vitis-comp.json")
      with open(vitis_comp_path, 'w') as f:
        json.dump(vitis_comp, f, indent=2)
        f.write("\n")

    vitis.dispose()

    GenerateCompileCommands(cfg_file, comp_dir)

    PrintInfo("Created Vitis workspace component: %s" % comp_dir)
    PrintInfo("  configFiles -> %s" % rel_cfg)
    PrintInfo("  work_dir    -> %s" % rel_work_dir)
    return True

  except Exception as e:
    PrintError("Failed to create HLS workspace: %s" % e)
    import traceback
    traceback.print_exc()
    sys.stdout.flush()
    try:
      import vitis
      vitis.dispose()
    except:
      pass
    return False


if __name__ == "__main__":
  if len(sys.argv) < 2:
    PrintError("Command is required")
    print("Usage: vitis -s HlsCommands.py <command> [arguments...]", flush=True)
    print("\nAvailable commands:", flush=True)
    print("  validate <cfg_file>", flush=True)
    print("  generate_minimal <cfg_file> <part> <top_function>", flush=True)
    print("  csim <component_name> <cfg_file> <work_dir>", flush=True)
    print("  synthesis <component_name> <cfg_file> <work_dir>", flush=True)
    print("  cosim <component_name> <cfg_file> <work_dir>", flush=True)
    print("  collect_reports <component_name> <work_dir> <output_dir>", flush=True)
    print("  release_notes <component_name> <work_dir> <output_dir>", flush=True)
    print("  create_workspace <workspace_path> <component_name> <cfg_file> <work_dir>", flush=True)
    sys.exit(1)

  command = sys.argv[1]

  if command == "validate":
    if len(sys.argv) < 3:
      PrintError("validate requires: cfg_file")
      sys.exit(1)
    result = ValidateHlsConfig(cfg_file=sys.argv[2])
    sys.exit(0 if result else 1)

  elif command == "generate_minimal":
    if len(sys.argv) < 5:
      PrintError("generate_minimal requires: cfg_file part top_function")
      sys.exit(1)
    result = GenerateMinimalConfig(
      cfg_file=sys.argv[2],
      part=sys.argv[3],
      top_function=sys.argv[4]
    )
    sys.exit(0 if result else 1)

  elif command == "csim":
    if len(sys.argv) < 5:
      PrintError("csim requires: component_name cfg_file work_dir")
      sys.exit(1)
    result = RunHlsCsim(
      component_name=sys.argv[2],
      cfg_file=sys.argv[3],
      work_dir=sys.argv[4]
    )
    sys.exit(0 if result else 1)

  elif command == "synthesis":
    if len(sys.argv) < 5:
      PrintError("synthesis requires: component_name cfg_file work_dir")
      sys.exit(1)
    result = RunHlsSynthesis(
      component_name=sys.argv[2],
      cfg_file=sys.argv[3],
      work_dir=sys.argv[4]
    )
    sys.exit(0 if result else 1)

  elif command == "cosim":
    if len(sys.argv) < 5:
      PrintError("cosim requires: component_name cfg_file work_dir")
      sys.exit(1)
    result = RunHlsCosim(
      component_name=sys.argv[2],
      cfg_file=sys.argv[3],
      work_dir=sys.argv[4]
    )
    sys.exit(0 if result else 1)

  elif command == "impl":
    if len(sys.argv) < 5:
      PrintError("impl requires: component_name cfg_file work_dir")
      sys.exit(1)
    result = RunHlsImpl(
      component_name=sys.argv[2],
      cfg_file=sys.argv[3],
      work_dir=sys.argv[4]
    )
    sys.exit(0 if result else 1)

  elif command == "export_rtl":
    if len(sys.argv) < 6:
      PrintError("export_rtl requires: component_name work_dir output_dir language")
      sys.exit(1)
    result = ExportHlsRtl(
      component_name=sys.argv[2],
      work_dir=sys.argv[3],
      output_dir=sys.argv[4],
      language=sys.argv[5]
    )
    sys.exit(0 if result else 1)

  elif command == "export_ip":
    if len(sys.argv) < 5:
      PrintError("export_ip requires: component_name work_dir output_dir")
      sys.exit(1)
    result = ExportHlsIp(
      component_name=sys.argv[2],
      work_dir=sys.argv[3],
      output_dir=sys.argv[4]
    )
    sys.exit(0 if result else 1)

  elif command == "collect_reports":
    if len(sys.argv) < 5:
      PrintError("collect_reports requires: component_name work_dir output_dir")
      sys.exit(1)
    # Always exit 0 — missing reports is non-critical
    CollectHlsReports(
      component_name=sys.argv[2],
      work_dir=sys.argv[3],
      output_dir=sys.argv[4]
    )
    sys.exit(0)

  elif command == "release_notes":
    if len(sys.argv) < 5:
      PrintError("release_notes requires: component_name work_dir output_dir")
      sys.exit(1)
    # Non-critical if it fails — do not block the build
    GenerateHlsSummary(
      component_name=sys.argv[2],
      work_dir=sys.argv[3],
      output_dir=sys.argv[4]
    )
    sys.exit(0)

  elif command == "create_workspace":
    if len(sys.argv) < 6:
      PrintError("create_workspace requires: workspace_path component_name cfg_file work_dir")
      sys.exit(1)
    result = CreateHlsWorkspace(
      workspace_path=sys.argv[2],
      component_name=sys.argv[3],
      cfg_file=sys.argv[4],
      work_dir=sys.argv[5]
    )
    sys.exit(0 if result else 1)

  else:
    PrintError("Unknown command: %s" % command)
    print("Available commands: validate, generate_minimal, csim, synthesis, cosim, impl, export_rtl, export_ip, collect_reports, release_notes, create_workspace", file=sys.stderr, flush=True)
    sys.exit(1)
