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
import sys
import json
import os

# Import logging functions from SharedCommands
# Get the directory of this file to find SharedCommands.py
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
  # Fallback if SharedCommands.py is not found
  def PrintInfo(msg): print("INFO: [Hog:Python:unknown] %s" % msg, flush=True)
  def PrintError(msg): print("ERROR: [Hog:Python:unknown] %s" % msg, flush=True)
  def PrintWarning(msg): print("WARNING: [Hog:Python:unknown] %s" % msg, flush=True)

def AppListDict(workspace_path):
  """Get list of apps as dictionary
  Args:
    workspace_path: Path to the workspace
  Returns:
    Dictionary with app names as keys and app configurations as values
  """
  workspace = vitis.Workspace(workspace_path)
  apps = workspace.get_apps()
  app_dict = {}
  for app in apps:
    app_dict[app.name] = {
      'name': app.name,
      'platform': app.platform.name if app.platform else '',
      'proc': app.proc if hasattr(app, 'proc') else ''
    }
  return app_dict

def ParseAppOptions(app_options_str):
  """
  Parse app options string into dictionary
  Args:
    app_options_str: String like "{ PLATFORM TestPlatform1 PROC psu_cortexa53_0 OS standalone }"
  Returns:
    Dictionary with extracted options
  """
  options_str = app_options_str.strip("{}").strip()
  tokens = options_str.split()

  opt_dict = {}
  i = 0
  while i < len(tokens):
    key = tokens[i].upper()
    if i + 1 < len(tokens):
      value = tokens[i + 1]
      # Remove quotes if present
      value = value.strip('"\'')
      opt_dict[key] = value
      i += 2
    else:
      i += 1

  return opt_dict

def ConfigureApp(app_name, app_conf, ws_dir):
  """
  Configure a Vitis Unified application
  Args:
    app_name: Name of the application
    app_conf: String or dict with app configuration options
    ws_dir: Workspace directory path
  Returns:
    bool: True if successful, False otherwise
  """
  try:
    # Parse app configuration
    if isinstance(app_conf, str):
      app_options = ParseAppOptions(app_conf)
    elif isinstance(app_conf, dict):
      app_options = app_conf
    else:
      PrintError("app_conf must be a string or dictionary")
      return False

    # Define create and config options
    create_options = {
      "platform", "domain", "sysproj", "hw", "proc", 
      "template", "os", "lang", "arch", "name"
    }

    conf_options = {
      "assembler-flags", "build-config", "compiler-misc", 
      "compiler-optimization", "define-compiler-symbols", 
      "include-path", "libraries", "library-search-path",
      "linker-misc", "linker-script", "undef-compiler-symbols"
    }

    # Separate create and config options
    app_create_options = {}
    app_conf_options = {}

    for key, value in app_options.items():
      key_lower = key.lower()
      if key_lower in create_options:
        app_create_options[key_lower] = value
      elif key_lower in conf_options:
        app_conf_options[key_lower] = value
      else:
        PrintWarning("Unknown app option: %s" % key_lower)

    # Use client-based approach (like CreatePlatform.py)
    client = vitis.create_client()

    # Set workspace
    try:
      client.set_workspace(path=ws_dir)
    except Exception as e:
      PrintError("Failed to set workspace '%s': %s" % (ws_dir, e))
      vitis.dispose()
      return False

    # Get platform path if specified
    platform_path = None
    if "platform" in app_create_options:
      platform_name = app_create_options["platform"]
      platform_path = "%s/%s/export/%s/%s.xpfm" % (ws_dir, platform_name, platform_name, platform_name)
      PrintInfo("Setting app platform to '%s'" % platform_path)

    # Prepare app creation parameters
    app_kwargs = {
      "name": app_name
    }

    # Add optional creation parameters
    if platform_path:
      app_kwargs["platform"] = platform_path

    if "domain" in app_create_options:
      app_kwargs["domain"] = app_create_options["domain"]

    # Use 'cpu' parameter (not 'proc') for create_app_component
    if "proc" in app_create_options:
      app_kwargs["cpu"] = app_create_options["proc"]
    elif "cpu" in app_create_options:
      app_kwargs["cpu"] = app_create_options["cpu"]

    if "os" in app_create_options:
      app_kwargs["os"] = app_create_options["os"]

    if "template" in app_create_options:
      app_kwargs["template"] = app_create_options["template"]

    if "hw" in app_create_options:
      app_kwargs["hw"] = app_create_options["hw"]

    if "arch" in app_create_options:
      app_kwargs["arch"] = app_create_options["arch"]

    # Create the app
    try:
      PrintInfo("Creating application '%s' with options: %s" % (app_name, app_kwargs))
      app = client.create_app_component(**app_kwargs)
      PrintInfo("Application '%s' created successfully" % app_name)
    except Exception as e:
      PrintError("Failed to create application: %s" % e)
      vitis.dispose()
      return False

    # Get the app again to configure it
    try:
      app = client.get_component(name=app_name)
    except Exception as e:
      PrintError("Failed to get application '%s': %s" % (app_name, e))
      vitis.dispose()
      return False

    # @nordin (2026-01-08): Pending to be validated...
    # Configure app options using set_app_config API
    key_mapping = {
      "build-config": "BUILD_CONFIG",
      "compiler-optimization": "USER_COMPILE_OPTIMIZATION_LEVEL",
      "define-compiler-symbols": "USER_COMPILE_DEFINITIONS",
      "undef-compiler-symbols": "USER_UNDEFINE_SYMBOLS",
      "include-path": "USER_INCLUDE_DIRECTORIES",
      "library-search-path": "USER_LINK_DIRECTORIES",  # May need verification
      "libraries": "USER_LINK_LIBRARIES",
      "linker-script": "USER_LINKER_SCRIPT",  # May need verification
      "assembler-flags": "USER_ASSEMBLER_FLAGS",  # May need verification
      "compiler-misc": "USER_COMPILE_MISC",  # May need verification
      "linker-misc": "USER_LINK_MISC"  # May need verification
    }

    for key, value in app_conf_options.items():
      try:
        PrintInfo("Configuring app option '%s' to '%s'" % (key, value))

        # Map TCL key to API key
        api_key = key_mapping.get(key)
        if not api_key:
          PrintWarning("Configuration option '%s' not mapped to API key" % key)
          continue

        # Convert value to list if it's a string (API expects list)
        if isinstance(value, str):
          if key in ["define-compiler-symbols", "undef-compiler-symbols", "include-path", "libraries"]:
            if ";" in value:
              values_list = [v.strip() for v in value.split(";") if v.strip()]
            else:
              values_list = [value]
          else:
            values_list = [value]
        elif isinstance(value, list):
          values_list = value
        else:
          values_list = [str(value)]

        # Use set_app_config with the mapped key
        app.set_app_config(key=api_key, values=values_list)
        PrintInfo("Successfully set %s to %s" % (api_key, values_list))
      except Exception as e:
        PrintWarning("Could not set app option '%s': %s" % (key, e))
        import traceback
        traceback.print_exc()
        sys.stdout.flush()

    PrintInfo("Application '%s' configured successfully" % app_name)

    # Closes all client connections and terminates the connection to the server
    vitis.dispose()
    return True

  except Exception as e:
    PrintError("Unexpected error in configure_app: %s" % e)
    import traceback
    traceback.print_exc()
    sys.stdout.flush()
    try:
      vitis.dispose()
    except:
      pass
    return False

if __name__ == "__main__":
  if len(sys.argv) < 2:
    PrintError("Command is required")
    print("Usage: vitis -s AppCommands.py <command> [arguments...]", flush=True)
    print("\nAvailable commands:", flush=True)
    print("  configure_app <app_name> <app_config> <workspace_path>", flush=True)
    print("  app_list <workspace_path>", flush=True)
    print("\nExamples:", flush=True)
    print("  vitis -s AppCommands.py configure_app TestApp1 '{ PLATFORM TestPlatform1 PROC psu_cortexa53_0 OS standalone }' my_workspace_path", flush=True)
    print("  vitis -s AppCommands.py app_list my_workspace_path", flush=True)
    sys.exit(1)

  command = sys.argv[1]

  if command == "configure_app":
    if len(sys.argv) < 5:
      PrintError("App name, app configuration, and workspace directory are required for configure_app")
      print("Usage: vitis -s AppCommands.py configure_app <app_name> '{ <app_options> }' <workspace_directory_path>", flush=True)
      print("\nExample:", flush=True)
      print("  vitis -s AppCommands.py configure_app TestApp1 '{ PLATFORM TestPlatform1 PROC psu_cortexa53_0 OS standalone }' my_workspace_path", flush=True)
      sys.exit(1)
    app_name = sys.argv[2]
    app_conf = sys.argv[3]
    ws_dir = sys.argv[4]
    result = ConfigureApp(app_name=app_name, app_conf=app_conf, ws_dir=ws_dir)
    sys.exit(0 if result else 1)

  elif command == "app_list":
    if len(sys.argv) < 3:
      PrintError("Workspace path is required for app_list")
      print("Usage: vitis -s AppCommands.py app_list <workspace_path>", flush=True)
      sys.exit(1)
    workspace_path = sys.argv[2]
    apps = AppListDict(workspace_path)
    print(json.dumps(apps), flush=True)

  else:
    PrintError("Unknown command: %s" % command)
    print("Available commands: configure_app, app_list", file=sys.stderr, flush=True)
    sys.exit(1)