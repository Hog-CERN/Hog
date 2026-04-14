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
    cmd = ["vitis-run", "--mode", "hls", "--csim",
           "--config", os.path.abspath(cfg_file),
           "--work_dir", os.path.abspath(work_dir)]

    PrintInfo("Command: %s" % " ".join(cmd))
    result = subprocess.run(cmd, capture_output=False)

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
    cmd = ["v++", "--compile", "--mode", "hls",
           "--config", os.path.abspath(cfg_file),
           "--work_dir", os.path.abspath(work_dir)]

    PrintInfo("Command: %s" % " ".join(cmd))
    result = subprocess.run(cmd, capture_output=False)

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
    cmd = ["vitis-run", "--mode", "hls", "--cosim",
           "--config", os.path.abspath(cfg_file),
           "--work_dir", os.path.abspath(work_dir)]

    PrintInfo("Command: %s" % " ".join(cmd))
    result = subprocess.run(cmd, capture_output=False)

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


def ExportHlsDesign(component_name, work_dir, output_dir=None):
  """Export the synthesized HLS design (IP or XO).

  After synthesis, the exported IP is typically located under
  work_dir/<component>/impl/ or work_dir/<component>/syn/.
  This function copies the export artifacts to the specified output directory.

  Args:
    component_name: Name of the HLS component
    work_dir: Working directory where the build was done
    output_dir: Directory where the exported IP should be copied
  Returns:
    bool: True if successful, False otherwise
  """
  try:
    PrintInfo("Exporting HLS design for component '%s'" % component_name)

    impl_dir = os.path.join(work_dir, component_name, "impl")
    export_dir_ip = os.path.join(impl_dir, "ip")
    export_dir_xo = os.path.join(impl_dir, "export.xo")

    found_artifacts = []

    if os.path.isdir(export_dir_ip):
      for f in os.listdir(export_dir_ip):
        if f.endswith(".zip"):
          found_artifacts.append(os.path.join(export_dir_ip, f))

    if os.path.exists(export_dir_xo):
      found_artifacts.append(export_dir_xo)

    syn_verilog = os.path.join(work_dir, component_name, "syn", "verilog")
    syn_vhdl = os.path.join(work_dir, component_name, "syn", "vhdl")
    if os.path.isdir(syn_verilog):
      found_artifacts.append(syn_verilog)
    if os.path.isdir(syn_vhdl):
      found_artifacts.append(syn_vhdl)

    if not found_artifacts:
      PrintWarning("No export artifacts found for '%s' in %s" % (component_name, work_dir))
      if os.path.isdir(impl_dir):
        for root, dirs, files in os.walk(impl_dir):
          for f in files:
            PrintInfo("  Found: %s" % os.path.join(root, f))
      return False

    if output_dir:
      os.makedirs(output_dir, exist_ok=True)
      for artifact in found_artifacts:
        dst = os.path.join(output_dir, os.path.basename(artifact))
        PrintInfo("Copying artifact: %s -> %s" % (artifact, dst))
        if os.path.isdir(artifact):
          if os.path.exists(dst):
            shutil.rmtree(dst)
          shutil.copytree(artifact, dst)
        else:
          shutil.copy2(artifact, dst)

    PrintInfo("Export completed for '%s'. Artifacts: %s" % (component_name, [os.path.basename(a) for a in found_artifacts]))
    return True

  except Exception as e:
    PrintError("Failed to export HLS design: %s" % e)
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
    print("  export <component_name> <work_dir> [output_dir]", flush=True)
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

  elif command == "export":
    if len(sys.argv) < 4:
      PrintError("export requires: component_name work_dir [output_dir]")
      sys.exit(1)
    output_dir = sys.argv[4] if len(sys.argv) > 4 else None
    result = ExportHlsDesign(
      component_name=sys.argv[2],
      work_dir=sys.argv[3],
      output_dir=output_dir
    )
    sys.exit(0 if result else 1)

  else:
    PrintError("Unknown command: %s" % command)
    print("Available commands: validate, generate_minimal, csim, synthesis, cosim, export", file=sys.stderr, flush=True)
    sys.exit(1)
