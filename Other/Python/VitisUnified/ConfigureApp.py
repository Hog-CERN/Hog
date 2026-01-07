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


def parse_app_options(app_options_str):
  """
  Parse app options string into dictionary
  Args:
    app_options_str: String like "{ PLATFORM TestPlatform1 PROC psu_cortexa53_0 OS standalone }"
  Returns:
    Dictionary with extracted options
  """
  # Remove braces if present
  options_str = app_options_str.strip("{}").strip()
  
  # Split by whitespace, but handle quoted values
  # Simple approach: split on whitespace and pair up
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


def configure_app(app_name, app_conf, ws_dir):
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
      app_options = parse_app_options(app_conf)
    elif isinstance(app_conf, dict):
      app_options = app_conf
    else:
      print("Error: app_conf must be a string or dictionary")
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
        print(f"Warning: Unknown app option: {key_lower}")
    
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
            print(f"Error: Failed to set workspace after initialization: {e2}")
            vitis.dispose()
            return False
        except Exception as init_err:
          print(f"Error: Failed to initialize workspace '{ws_dir}': {init_err}")
          vitis.dispose()
          return False
      else:
        print(f"Error: Failed to set workspace '{ws_dir}': {e}")
        vitis.dispose()
        return False
    
    workspace = client.get_workspace()
    
    # Remove existing sysproj if it exists
    sysproj_name = app_options.get("sysproj") or f"{app_name}_system"
    try:
      sysprojs = workspace.get_sysprojs()
      for sysproj in sysprojs:
        if sysproj.name == sysproj_name:
          print(f"Removing existing sysproj '{sysproj_name}'...")
          sysproj.delete()
    except Exception as e:
      # Sysproj might not exist, which is fine
      pass
    
    # Remove existing app if it exists
    try:
      apps = workspace.get_apps()
      for app in apps:
        if app.name == app_name:
          print(f"Removing existing app '{app_name}'...")
          app.delete()
    except Exception as e:
      # App might not exist, which is fine
      pass
    
    # Get platform if specified
    platform = None
    if "platform" in app_create_options:
      platform_name = app_create_options["platform"]
      try:
        platform = workspace.get_component(name=platform_name)
        print(f"Setting app platform to '{platform_name}'")
      except Exception as e:
        print(f"Warning: Could not find platform '{platform_name}': {e}")
    
    # Prepare app creation parameters
    app_kwargs = {
      "name": app_name
    }
    
    # Add optional creation parameters
    if platform:
      app_kwargs["platform"] = platform
    
    if "domain" in app_create_options:
      app_kwargs["domain"] = app_create_options["domain"]
    
    if "proc" in app_create_options:
      app_kwargs["proc"] = app_create_options["proc"]
    
    if "os" in app_create_options:
      app_kwargs["os"] = app_create_options["os"]
    
    if "template" in app_create_options:
      app_kwargs["template"] = app_create_options["template"]
    else:
      # Default template based on lang
      if "lang" in app_create_options:
        lang = app_create_options["lang"].lower()
        if lang in ["c++", "cpp"]:
          app_kwargs["template"] = "Empty Application (C++)"
        else:
          app_kwargs["template"] = "Empty Application(C)"
      else:
        app_kwargs["template"] = "Empty Application"
    
    if "hw" in app_create_options:
      app_kwargs["hw"] = app_create_options["hw"]
    
    if "arch" in app_create_options:
      app_kwargs["arch"] = app_create_options["arch"]
    
    # Create the app
    try:
      print(f"Creating application '{app_name}' with options: {app_kwargs}")
      app = workspace.create_app(**app_kwargs)
      print(f"Application '{app_name}' created successfully")
    except Exception as e:
      print(f"Error: Failed to create application: {e}")
      vitis.dispose()
      return False
    
    # Get the app again to configure it
    try:
      app = workspace.get_app(app_name)
    except Exception as e:
      print(f"Error: Failed to get application '{app_name}': {e}")
      vitis.dispose()
      return False
    
    # Set build-config to Release by default
    try:
      app.set_build_config("Release")
      print(f"Set build-config to Release")
    except Exception as e:
      print(f"Warning: Could not set build-config: {e}")
    
    # Configure app options
    for key, value in app_conf_options.items():
      try:
        print(f"Configuring app option '{key}' to '{value}'")
        # Map configuration keys to app methods
        if key == "build-config":
          app.set_build_config(value)
        elif key == "compiler-optimization":
          app.set_compiler_optimization(value)
        elif key == "define-compiler-symbols":
          # This might need special handling for multiple symbols
          app.set_define_compiler_symbols(value)
        elif key == "undef-compiler-symbols":
          app.set_undef_compiler_symbols(value)
        elif key == "include-path":
          app.set_include_path(value)
        elif key == "library-search-path":
          app.set_library_search_path(value)
        elif key == "libraries":
          app.set_libraries(value)
        elif key == "linker-script":
          app.set_linker_script(value)
        elif key == "assembler-flags":
          app.set_assembler_flags(value)
        elif key == "compiler-misc":
          app.set_compiler_misc(value)
        elif key == "linker-misc":
          app.set_linker_misc(value)
        else:
          print(f"Warning: Configuration option '{key}' not yet implemented in Python API")
      except Exception as e:
        print(f"Warning: Could not set app option '{key}': {e}")
    
    # Save the app
    try:
      app.save()
      print(f"Application '{app_name}' configured and saved successfully")
    except Exception as e:
      print(f"Warning: Could not save application: {e}")
    
    # Closes all client connections and terminates the connection to the server
    vitis.dispose()
    return True
    
  except Exception as e:
    print(f"Error: Unexpected error in configure_app: {e}")
    import traceback
    traceback.print_exc()
    try:
      vitis.dispose()
    except:
      pass
    return False


if __name__ == "__main__":
  if len(sys.argv) < 4:
    print("Error: App name, app configuration, and workspace directory are required")
    print("Usage: vitis -s ConfigureApp.py <app_name> '{ <app_options> }' <workspace_directory_path>")
    print("\nExample:")
    print("  vitis -s ConfigureApp.py TestApp1 '{ PLATFORM TestPlatform1 PROC psu_cortexa53_0 OS standalone }' my_project_workspace")
    sys.exit(1)
  
  app_name = sys.argv[1]
  app_conf = sys.argv[2]
  ws_dir = sys.argv[3]
  
  # Configure app
  result = configure_app(app_name=app_name, app_conf=app_conf, ws_dir=ws_dir)
  
  # Exit with appropriate code
  sys.exit(0 if result else 1)