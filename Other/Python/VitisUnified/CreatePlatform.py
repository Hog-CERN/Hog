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


def parse_platform_options(platform_options_str):
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

def str_to_bool(value):
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

def parse_advanced_options(value):
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
      print("Warning: Could not parse advanced_options as JSON: %s" % value)
      return None
  return None

def validate_required_options(options):
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

def create_platform(platform_options=None, ws_dir=None):
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
      options = parse_platform_options(platform_options)
    elif isinstance(platform_options, dict):
      options = platform_options
    else:
      print("Error: platform_options must be a string or dictionary")
      return False

    # Validate required options
    is_valid, error_msg = validate_required_options(options)
    if not is_valid:
      print("Error: %s" % error_msg)
      return False

    # Extract options - map input keys to API parameter names
    # Required arguments
    name = options.get("name")
    hw_design = options.get("hw_design") or options.get("hw") or ''  # Support both "hw" and "hw_design", default to ''
    emu_design = options.get("emu_design") or ''
    platform_xpfm_path = options.get("platform_xpfm_path") or ''

    # Optional arguments (only include if explicitly provided)
    desc = options.get("desc")
    os_type = options.get("os")
    cpu = options.get("cpu") or options.get("proc")  # Support both "cpu" and "proc"
    domain_name = options.get("domain_name")
    template = options.get("template")

    # Boolean options - convert from string if provided
    no_boot_bsp = str_to_bool(options.get("no_boot_bsp")) if "no_boot_bsp" in options else None
    is_pmufw_req = str_to_bool(options.get("is_pmufw_req")) if "is_pmufw_req" in options else None
    generate_dtb = str_to_bool(options.get("generate_dtb")) if "generate_dtb" in options else None

    # Path options
    fsbl_target = options.get("fsbl_target")
    fsbl_path = options.get("fsbl_path")
    pmufw_Elf = options.get("pmufw_Elf")

    # Advanced options - parse from string if needed
    advanced_options = parse_advanced_options(options.get("advanced_options"))

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

    client = vitis.create_client()

    # Set workspace - initialize if it doesn't exist
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
            print("Error: Failed to set workspace after initialization: %s" % e2)
            vitis.dispose()
            return False
        except Exception as init_err:
          print("Error: Failed to initialize workspace '%s': %s" % (ws_dir, init_err))
          vitis.dispose()
          return False
      else:
        print("Error: Failed to set workspace '%s': %s" % (ws_dir, e))
        vitis.dispose()
        return False

    # Create platform component
    try:
      print("Creating platform '%s'..." % name)
      print("  Options: %s" % ', '.join(['%s=%s' % (k, v) for k, v in platform_kwargs.items() if v]))
      platform = client.create_platform_component(**platform_kwargs)
      print("Platform component '%s' created successfully" % name)
    except Exception as e:
      print("Error: Failed to create platform component: %s" % e)
      vitis.dispose()
      return False

    # # Get platform component
    # try:
    #   platform = client.get_component(name=name)
    # except Exception as e:
    #   print("Error: Failed to get platform component '%s': %s" % (name, e))
    #   vitis.dispose()
    #   return False

    # # Build platform
    # try:
    #   print("Building platform '%s'..." % name)
    #   status = platform.build()
    #   if status:
    #     print("Warning: Platform build returned status: %s" % status)
    #   else:
    #     print("Platform '%s' built successfully" % name)
    # except Exception as e:
    #   print("Error: Failed to build platform: %s" % e)
    #   vitis.dispose()
    #   return False

    # Closes all client connections and terminates the connection to the server
    vitis.dispose()
    return True

  except Exception as e:
    print("Error: Unexpected error in create_platform: %s" % e)
    try:
      vitis.dispose()
    except:
      pass
    return False


if __name__ == "__main__":
  if len(sys.argv) < 3:
    print("Error: Both platform options and workspace directory are required")
    print("Usage: vitis -s create_platform.py '{ -name <platform_name> -hw_design <xsa_file_path> -os <os_type> -cpu <cpu_type> }' <workspace_directory_path>")
    print("\nExample:")
    print("  vitis -s create_platform.py '{ -name TestPlatform1 -hw_design my_project.xsa -cpu psu_cortexa53_0 -os standalone -domain_name standalone_a53 }' my_project_workspace")
    sys.exit(1)

  platform_options = sys.argv[1]
  ws_dir = sys.argv[2]

  # Create platform
  result = create_platform(platform_options=platform_options, ws_dir=ws_dir)

  # Exit with appropriate code
  sys.exit(0 if result else 1)