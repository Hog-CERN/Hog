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
  print("ERROR: [Hog:Python:AppCommands.py] Failed to import SharedCommands, file not found: %s" % _shared_commands_path)


def AppListDict(workspace_path):
  """Get list of apps as dictionary
  Args:
    workspace_path: Path to the workspace
  Returns:
    Dictionary with app names as keys (empty dicts as values)
  """
  try:
    PrintInfo("Getting app list from workspace: %s" % workspace_path)
    # Use client-based approach
    client = vitis.create_client()

    # Set workspace
    try:
      client.set_workspace(path=workspace_path)
    except Exception as e:
      PrintError("Failed to set workspace '%s': %s" % (workspace_path, e))
      vitis.dispose()
      return {}

    # Get all components from the workspace
    try:
      components = client.list_components()
      if components is None:
        components = []
      PrintInfo("Found %d component(s) in workspace" % len(components))
    except Exception as e:
      PrintError("Failed to list components: %s" % e)
      import traceback
      traceback.print_exc()
      sys.stdout.flush()
      vitis.dispose()
      return {}

    # Filter for application components (component_type == "APPLICATION")
    app_dict = {}
    if components:
      for comp in components:
        # Get component name first
        comp_name = None
        
        # Check if component is a dictionary or an object
        if isinstance(comp, dict):
          comp_name = comp.get('component_name', comp.get('name', ''))
        else:
          # It's an object, check attributes
          comp_name = getattr(comp, 'component_name', None)
          if comp_name is None:
            comp_name = getattr(comp, 'name', None)
        
        if not comp_name:
          PrintDebug("Skipping component with no name: %s" % str(comp))
          continue
        
        PrintDebug("Checking component: name='%s'" % comp_name)
        
        # Try to get the component object to check its type
        try:
          comp_obj = client.get_component(name=comp_name)
          
          # Check if it's an application by checking the component type
          comp_type = None
          if hasattr(comp_obj, 'component_type'):
            comp_type = comp_obj.component_type
          elif hasattr(comp_obj, 'type'):
            comp_type = comp_obj.type
          
          comp_type_str = str(comp_type).upper() if comp_type else ""
          PrintDebug("Component '%s' has type: '%s'" % (comp_name, comp_type_str))
          
          # Check if this is an application component
          # component_type can be "APPLICATION" or "HOST" (which maps to APPLICATION)
          if comp_type_str == "APPLICATION" or comp_type_str == "HOST":
            # Add app name to dictionary (empty dict as value to match expected format)
            app_dict[comp_name] = {}
            PrintInfo("Added app '%s' to list" % comp_name)
          else:
            PrintDebug("Skipping non-application component '%s' (type='%s')" % (comp_name, comp_type_str))
        except Exception as e:
          # If we can't get the component, it might not exist or might be a different type
          # Try to determine if it's an application by checking if we can access it as an app
          PrintDebug("Could not get component '%s' as object: %s" % (comp_name, e))
          # Skip components we can't retrieve
          continue
    
    PrintInfo("Total apps found: %d" % len(app_dict))

    # Closes all client connections and terminates the connection to the server
    vitis.dispose()
    return app_dict

  except Exception as e:
    PrintError("Unexpected error in AppListDict: %s" % e)
    import traceback
    traceback.print_exc()
    sys.stdout.flush()
    try:
      vitis.dispose()
    except:
      pass
    return {}

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

def AddAppFiles(app_name, file_paths, ws_dir, target_path=None):
  """
  Add source files to a Vitis Unified application
  Args:
    app_name: Name of the application
    file_paths: List of file paths to add (can be JSON string or list)
    ws_dir: Workspace directory path
    target_path: Optional target path within the app (relative to app directory)
  Returns:
    bool: True if successful, False otherwise
  """
  try:
    PrintInfo("Adding files to app '%s'" % app_name)
    # Parse file_paths if it's a JSON string
    if isinstance(file_paths, str):
      try:
        file_list = json.loads(file_paths)
      except json.JSONDecodeError:
        # If not JSON, treat as single file path
        file_list = [file_paths]
    elif isinstance(file_paths, list):
      file_list = file_paths
    else:
      PrintError("file_paths must be a string or list")
      return False

    if len(file_list) == 0:
      PrintWarning("No files provided to add to app '%s'" % app_name)
      return True

    # Use client-based approach
    client = vitis.create_client()

    # Set workspace
    try:
      client.set_workspace(path=ws_dir)
    except Exception as e:
      PrintError("Failed to set workspace '%s': %s" % (ws_dir, e))
      vitis.dispose()
      return False

    # Get the app component
    try:
      app = client.get_component(name=app_name)
    except Exception as e:
      PrintError("Failed to get application '%s': %s" % (app_name, e))
      vitis.dispose()
      return False

    # Group files by their source directory for efficient import
    # The import_files API expects from_loc to be a directory and files to be a list of filenames
    files_by_dir = {}
    valid_files = 0
    for file_path in file_list:
      if not os.path.exists(file_path):
        PrintWarning("File '%s' does not exist, skipping" % file_path)
        continue

      file_path = os.path.abspath(file_path)
      file_dir = os.path.dirname(file_path)
      file_name = os.path.basename(file_path)

      if file_dir not in files_by_dir:
        files_by_dir[file_dir] = []
      files_by_dir[file_dir].append(file_name)
      valid_files += 1

    if len(files_by_dir) == 0:
      PrintWarning("No valid files to add to app '%s'" % app_name)
      vitis.dispose()
      return True

    # Add files to the app using the correct API
    # Group by directory and import all files from each directory at once
    try:
      total_imported = 0
      for from_dir, file_names in files_by_dir.items():
        PrintInfo("Importing %d file(s) from '%s' to app '%s'" % (len(file_names), from_dir, app_name))

        # Use Component.import_files API
        # from_loc: source directory
        # files: list of filenames within that directory
        # dest_dir_in_cmp: destination directory within the component (optional)
        app.import_files(from_loc=from_dir, files=file_names, dest_dir_in_cmp=target_path)
        total_imported += len(file_names)

      PrintInfo("Successfully added %d file(s) to app '%s'" % (total_imported, app_name))
    except Exception as e:
      PrintError("Failed to add files to app '%s': %s" % (app_name, e))
      import traceback
      traceback.print_exc()
      sys.stdout.flush()
      vitis.dispose()
      return False

    # Closes all client connections and terminates the connection to the server
    vitis.dispose()
    return True

  except Exception as e:
    PrintError("Unexpected error in AddAppFiles: %s" % e)
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
    print("  add_app_files <app_name> <file_paths_json> <workspace_path> [target_path]", flush=True)
    print("\nExamples:", flush=True)
    print("  vitis -s AppCommands.py configure_app TestApp1 '{ PLATFORM TestPlatform1 PROC psu_cortexa53_0 OS standalone }' my_workspace_path", flush=True)
    print("  vitis -s AppCommands.py app_list my_workspace_path", flush=True)
    print("  vitis -s AppCommands.py add_app_files TestApp1 '[\"/path/to/file1.c\", \"/path/to/file2.c\"]' my_workspace_path src", flush=True)
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

  elif command == "add_app_files":
    if len(sys.argv) < 5:
      PrintError("App name, file paths, and workspace directory are required for add_app_files")
      print("Usage: vitis -s AppCommands.py add_app_files <app_name> '<file_paths_json>' <workspace_path> [target_path]", flush=True)
      print("\nExample:", flush=True)
      print("  vitis -s AppCommands.py add_app_files TestApp1 '[\"/path/to/file1.c\", \"/path/to/file2.c\"]' my_workspace_path src", flush=True)
      sys.exit(1)
    app_name = sys.argv[2]
    file_paths_json = sys.argv[3]
    ws_dir = sys.argv[4]
    target_path = sys.argv[5] if len(sys.argv) > 5 else None
    result = AddAppFiles(app_name=app_name, file_paths=file_paths_json, ws_dir=ws_dir, target_path=target_path)
    sys.exit(0 if result else 1)

  else:
    PrintError("Unknown command: %s" % command)
    print("Available commands: configure_app, app_list, add_app_files", file=sys.stderr, flush=True)
    sys.exit(1)