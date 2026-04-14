#   Copyright 2018-2026 The University of Birmingham
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
      PrintError("Co-simulation failed for '%s' (exit code: %d)" % (component_name, result.returncode))
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


def CollectHlsReports(component_name, work_dir, output_dir):
  """Collect HLS synthesis and simulation reports into output_dir.

  After synthesis, reports are typically located under
  work_dir/<component>/syn/report/ (.rpt, .xml).
  After co-simulation, reports may also be under
  work_dir/<component>/sim/report/.

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
    report_dirs = [
      os.path.join(work_dir, "hls", "syn", "report"),
      os.path.join(work_dir, "hls", "sim", "report"),
      os.path.join(work_dir, component_name, "syn", "report"),
      os.path.join(work_dir, component_name, "sim", "report"),
    ]

    found_reports = []
    for report_dir in report_dirs:
      if not os.path.isdir(report_dir):
        continue
      for root, dirs, files in os.walk(report_dir):
        for f in files:
          if any(f.endswith(ext) for ext in report_extensions):
            found_reports.append(os.path.join(root, f))

    if not found_reports:
      PrintWarning("No reports found for '%s' in %s" % (component_name, work_dir))
      return False

    hls_report_dir = os.path.join(output_dir, "hls_%s_reports" % component_name)
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


def CreateHlsWorkspace(workspace_path, component_name, cfg_file, work_dir):
  """Create a Vitis-compatible HLS workspace so the project can be opened in the GUI.

  The workspace is a directory containing one subdirectory per HLS component.
  Each component directory holds a vitis-comp.json descriptor and a link
  (or copy) of the committed hls_config.cfg.

  Args:
    workspace_path: Path to the Vitis workspace (e.g. Projects/<proj>/vitis_unified/)
    component_name: Name of the HLS component
    cfg_file:       Absolute path to the committed hls_config.cfg in the source tree
    work_dir:       Absolute path to the HLS build work directory
  Returns:
    bool: True if successful, False otherwise
  """
  try:
    comp_dir = os.path.join(workspace_path, component_name)
    os.makedirs(comp_dir, exist_ok=True)

    ws_cfg = os.path.join(comp_dir, "hls_config.cfg")
    cfg_file = os.path.abspath(cfg_file)

    if os.path.exists(ws_cfg) or os.path.islink(ws_cfg):
      os.remove(ws_cfg)

    linked = False
    try:
      os.symlink(cfg_file, ws_cfg)
      linked = True
      PrintInfo("Symlinked hls_config.cfg -> %s" % cfg_file)
    except (OSError, NotImplementedError):
      shutil.copy2(cfg_file, ws_cfg)
      PrintWarning("Symlink not supported, copied hls_config.cfg to workspace. "
                    "GUI edits will NOT propagate back to the source tree.")

    rel_work_dir = os.path.relpath(os.path.abspath(work_dir), comp_dir)
    vitis_comp = {
      "name": component_name,
      "type": "HLS",
      "configuration": {
        "componentType": "HLS",
        "configFiles": ["hls_config.cfg"],
        "work_dir": rel_work_dir
      },
      "template": "empty_hls_component"
    }

    vitis_comp_path = os.path.join(comp_dir, "vitis-comp.json")
    with open(vitis_comp_path, 'w') as f:
      json.dump(vitis_comp, f, indent=2)
      f.write("\n")

    PrintInfo("Created Vitis workspace component: %s" % comp_dir)
    PrintInfo("  vitis-comp.json -> work_dir=%s" % rel_work_dir)
    if linked:
      PrintInfo("  hls_config.cfg is a symlink to the source tree (single source of truth)")
    return True

  except Exception as e:
    PrintError("Failed to create HLS workspace: %s" % e)
    import traceback
    traceback.print_exc()
    sys.stdout.flush()
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
    print("Available commands: validate, generate_minimal, csim, synthesis, cosim, collect_reports, create_workspace", file=sys.stderr, flush=True)
    sys.exit(1)
