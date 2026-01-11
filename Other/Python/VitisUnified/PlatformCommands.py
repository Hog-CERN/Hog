#   Copyright 2018-2025 The University of Birmingham
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

import vitis
import os
import re
import sys
import json
import zipfile
import xml.etree.ElementTree as ET

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
else:
  print("ERROR: [Hog:Python:PlatformCommands.py] Failed to import SharedCommands, file not found: %s" % _shared_commands_path)


def ParsePlatformOptions(platform_options_str):
  """
  Parse platform options string into dictionary
  Args:
    platform_options_str: String like "{ -name TestPlatform1 -proc psu_cortexa53_0 ... }"
  Returns:
    Dictionary with extracted options
  """
  # Remove braces
  options_str = platform_options_str.strip("{}").strip()

  # Find all -key patterns and their values
  # Match: -key followed by whitespace, then capture everything until next -key or end
  pattern = r'-(\w+)\s+'
  matches = list(re.finditer(pattern, options_str))

  opt_dict = {}
  for i, match in enumerate(matches):
    key = match.group(1)
    # Find the start of the value (end of current match)
    value_start = match.end()
    # Find the end of the value (start of next match, or end of string)
    if i + 1 < len(matches):
      value_end = matches[i + 1].start()
    else:
      value_end = len(options_str)

    value = options_str[value_start:value_end].strip()
    opt_dict[key] = value

  return opt_dict

def StrToBool(value):
  """
  Convert string to boolean
  Args:
    value: String or boolean value
  Returns:
    bool: Converted boolean value, or None if value is None
  """
  if value is None:
    return None
  if isinstance(value, bool):
    return value
  if isinstance(value, str):
    return value.lower() in ('true', '1', 'yes', 'on')
  return False

def ParseAdvancedOptions(value):
  """
  Parse advanced_options from string to dictionary
  Args:
    value: String representation of dict or actual dict
  Returns:
    dict: Parsed dictionary or None
  """
  if value is None:
    return None
  if isinstance(value, dict):
    return value
  if isinstance(value, str):
    try:
      return json.loads(value)
    except json.JSONDecodeError:
      PrintWarning("Could not parse advanced_options as JSON: %s" % value)
      return None
  return None

def ValidateRequiredOptions(options):
  """
  Validate that required options are present
  Args:
    options: Dictionary of parsed options
  Returns:
    tuple: (is_valid, error_message)
  """
  # name is always required
  if not options.get("name"):
    return False, "Missing required option: name"

  # At least one of hw_design, emu_design, or platform_xpfm_path must be provided
  has_hw_design = options.get("hw_design") or options.get("hw")
  has_emu_design = options.get("emu_design")
  has_xpfm = options.get("platform_xpfm_path")

  if not has_hw_design and not has_emu_design and not has_xpfm:
    return False, "Missing required option: at least one of 'hw_design', 'emu_design', or 'platform_xpfm_path' must be specified"

  return True, None

# TODO: Pending to be validated for an XSA with embedded soft processors...
def ExtractProcsFromXsa(xsa_path, output_file):
  """Extract soft processors information from XSA file
  Args:
    xsa_path: Path to the XSA file
    output_file: Path to output PROC_MAP file
  Returns:
    Dictionary with soft processors information
  """
  processors = []
  try:
    # XSA files are ZIP archives
    with zipfile.ZipFile(xsa_path, 'r') as xsa_zip:
      xml_files = [f for f in xsa_zip.namelist() if f.endswith('.xml')]
      for xml_file in xml_files:
        try:
          xml_content = xsa_zip.read(xsa_zip.getinfo(xml_file))
          root = ET.fromstring(xml_content)
          for proc_elem in root.iter():
            tag_lower = proc_elem.tag.lower()
            if 'processor' in tag_lower or 'cpu' in tag_lower:
              proc_name = proc_elem.get('name', '')
              if not proc_name:
                proc_name = proc_elem.text if proc_elem.text else ''
              # Check if it's a soft processor
              if re.search(r'microblaze|risc', proc_name, re.IGNORECASE):
                proc_info = {
                  'name': proc_name,
                  'hier_name': proc_name,
                  'address_tag': ''
                }
                # Try to get hierarchical name
                hier_name = proc_elem.get('hier_name', '')
                if not hier_name:
                  hier_name = proc_elem.get('hierName', '')
                if hier_name:
                  proc_info['hier_name'] = hier_name
                # Try to get address tag
                addr_tag = proc_elem.get('address_tag', '')
                if not addr_tag:
                  addr_tag = proc_elem.get('addressTag', '')
                if not addr_tag:
                  addr_tag = proc_elem.get('addr_tag', '')
                if addr_tag:
                  proc_info['address_tag'] = addr_tag
                processors.append(proc_info)
        except Exception as e:
          continue

    if output_file:
      processors_with_tags = [proc for proc in processors if proc.get('address_tag')]
      if processors_with_tags:
        output_dir = os.path.dirname(output_file)
        if output_dir and not os.path.exists(output_dir):
          os.makedirs(output_dir, exist_ok=True)
        with open(output_file, 'w') as f:
          for proc in processors_with_tags:
            f.write("%s %s\n" % (proc['hier_name'], proc['address_tag']))
    return {'processors': processors}

  except zipfile.BadZipFile:
    PrintError("%s is not a valid ZIP file (XSA format)" % xsa_path)
    return {'processors': [], 'error': 'Invalid XSA file format'}
  except Exception as e:
    PrintError("Failed to extract soft processors from XSA: %s" % str(e))
    import traceback
    traceback.print_exc(file=sys.stderr)
    sys.stderr.flush()
    return {'processors': [], 'error': str(e)}

def CreatePlatform(platform_options=None, ws_dir=None):
  """
  Create a Vitis Unified platform component
  Args:
    platform_options: String or dict with platform options
    ws_dir: Workspace directory path
  Returns:
    bool: True if successful, False otherwise
  """
  try:
    # Parse platform options
    if isinstance(platform_options, str):
      options = ParsePlatformOptions(platform_options)
    elif isinstance(platform_options, dict):
      options = platform_options
    else:
      PrintError("platform_options must be a string or dictionary")
      return False

    # Validate required options
    is_valid, error_msg = ValidateRequiredOptions(options)
    if not is_valid:
      PrintError(error_msg)
      return False

    # Required arguments
    name = options.get("name")
    hw_design = options.get("hw_design") or options.get("hw") or ''
    emu_design = options.get("emu_design") or ''
    platform_xpfm_path = options.get("platform_xpfm_path") or ''

    # Determine XSA path for processor extraction
    # If hw_design is not provided, we can't extract soft processors
    xsa_path = hw_design if hw_design else None

    # Optional arguments (only include if explicitly provided)
    desc = options.get("desc")
    os_type = options.get("os")
    cpu = options.get("cpu") or options.get("proc")  # Support both "cpu" and "proc"
    domain_name = options.get("domain_name")
    template = options.get("template")

    # Boolean options - convert from string if provided
    no_boot_bsp = StrToBool(options.get("no_boot_bsp")) if "no_boot_bsp" in options else None
    is_pmufw_req = StrToBool(options.get("is_pmufw_req")) if "is_pmufw_req" in options else None
    generate_dtb = StrToBool(options.get("generate_dtb")) if "generate_dtb" in options else None

    # Path options
    fsbl_target = options.get("fsbl_target")
    fsbl_path = options.get("fsbl_path")
    pmufw_Elf = options.get("pmufw_Elf")

    # Advanced options, parse from string if needed
    advanced_options = ParseAdvancedOptions(options.get("advanced_options"))

    # Build kwargs dictionary for create_platform_component
    # Include all arguments, using API defaults for optional ones not provided
    platform_kwargs = {
      "name": name,
      "hw_design": hw_design,
      "emu_design": emu_design,
      "platform_xpfm_path": platform_xpfm_path
    }

    # Add optional arguments only if explicitly provided
    if desc is not None:
      platform_kwargs["desc"] = desc
    if os_type is not None:
      platform_kwargs["os"] = os_type
    if cpu is not None:
      platform_kwargs["cpu"] = cpu
    if domain_name is not None:
      platform_kwargs["domain_name"] = domain_name
    if template is not None:
      platform_kwargs["template"] = template
    if no_boot_bsp is not None:
      platform_kwargs["no_boot_bsp"] = no_boot_bsp
    if fsbl_target is not None:
      platform_kwargs["fsbl_target"] = fsbl_target
    if fsbl_path is not None:
      platform_kwargs["fsbl_path"] = fsbl_path
    if pmufw_Elf is not None:
      platform_kwargs["pmufw_Elf"] = pmufw_Elf
    if is_pmufw_req is not None:
      platform_kwargs["is_pmufw_req"] = is_pmufw_req
    if generate_dtb is not None:
      platform_kwargs["generate_dtb"] = generate_dtb
    if advanced_options is not None:
      platform_kwargs["advanced_options"] = advanced_options

    # Extract processor information from XSA if available
    if xsa_path and os.path.exists(xsa_path):
      PrintInfo("Opening hardware design to check if proc to cell mapping needs to be extracted for soft processors...")
      proc_map_file = os.path.join(ws_dir, "%s.PROC_MAP" % name)
      try:
        result = ExtractProcsFromXsa(xsa_path, proc_map_file)
        processors = result.get('processors', [])
        if len(processors) == 0:
          PrintInfo("No soft processors found in XSA (this is normal for hard processors like ARM)")
        else:
          PrintInfo("Extracted processor information for %d soft processor(s) to %s" % (len(processors), proc_map_file))
      except Exception as e:
        PrintError("Failed to extract processor information from XSA: %s" % str(e))
        vitis.dispose()
        return False

    PrintInfo("Creating client...")
    client = vitis.create_client()

    # Set workspace and initialize if it doesn't exist
    PrintInfo("Setting workspace...")
    try:
      client.set_workspace(path=ws_dir)
    except Exception as e:
      error_msg = str(e)
      if "cannot recognize the workspace version" in error_msg or "update_workspace" in error_msg:
        try:
          client.update_workspace(path=ws_dir)
          try:
            client.set_workspace(path=ws_dir)
          except Exception as e2:
            PrintError("Failed to set workspace after initialization: %s" % e2)
            vitis.dispose()
            return False
        except Exception as init_err:
          PrintError("Failed to initialize workspace '%s': %s" % (ws_dir, init_err))
          vitis.dispose()
          return False
      else:
        PrintError("Failed to set workspace '%s': %s" % (ws_dir, e))
        vitis.dispose()
        return False

    # Create platform component
    try:
      PrintInfo("Creating platform component '%s'..." % name)
      PrintInfo("  Options: %s" % ', '.join(['%s=%s' % (k, v) for k, v in platform_kwargs.items() if v]))
      platform = client.create_platform_component(**platform_kwargs)
      PrintInfo("Platform component '%s' created successfully" % name)
    except Exception as e:
      PrintError("Failed to create platform component: %s" % e)
      vitis.dispose()
      return False

    # # Get platform component
    # try:
    #   platform = client.get_component(name=name)
    # except Exception as e:
    #   print("Error: Failed to get platform component '%s': %s" % (name, e), flush=True)
    #   vitis.dispose()
    #   return False

    # # Build platform
    # try:
    #   print("Building platform '%s'..." % name, flush=True)
    #   status = platform.build()
    #   if status:
    #     print("Warning: Platform build returned status: %s" % status, flush=True)
    #   else:
    #     print("Platform '%s' built successfully" % name, flush=True)
    # except Exception as e:
    #   print("Error: Failed to build platform: %s" % e, flush=True)
    #   vitis.dispose()
    #   return False

    # Closes all client connections and terminates the connection to the server
    vitis.dispose()
    return True

  except Exception as e:
    PrintError("Unexpected error in create_platform: %s" % e)
    import traceback
    traceback.print_exc()
    sys.stdout.flush()
    try:
      vitis.dispose()
    except:
      pass
    return False


if __name__ == "__main__":
  if len(sys.argv) < 4:
    PrintError("Both platform options and workspace path are required")
    print("Usage: vitis -s PlatformCommands.py create_platform '{ -name <platform_name> -hw_design <xsa_file_path> -os <os_type> -cpu <cpu_type> }' <workspace_path>", flush=True)
    print("\nExample:", flush=True)
    print("  vitis -s PlatformCommands.py create_platform '{ -name TestPlatform1 -hw_design my_project.xsa -cpu psu_cortexa53_0 -os standalone -domain_name standalone_a53 }' my_workspace_path", flush=True)
    sys.exit(1)

  command = sys.argv[1]
  if command != "create_platform":
    PrintError("Unknown command: %s" % command)
    print("Available command: create_platform", file=sys.stderr, flush=True)
    sys.exit(1)

  platform_options = sys.argv[2]
  ws_dir = sys.argv[3]
  result = CreatePlatform(platform_options=platform_options, ws_dir=ws_dir)
  sys.exit(0 if result else 1)