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


def parse_app_options(app_options_str):
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
        print("Warning: Unknown app option: %s" % key_lower)

    # Use client-based approach (like CreatePlatform.py)
    client = vitis.create_client()

    # Set workspace
    try:
      client.set_workspace(path=ws_dir)
    except Exception as e:
      print("Error: Failed to set workspace '%s': %s" % (ws_dir, e))
      vitis.dispose()
      return False

    # Remove existing app if it exists - use client
    try:
      sysprojs = workspace.get_sysprojs()
      for sysproj in sysprojs:
        if sysproj.name == sysproj_name:
          print("Removing existing sysproj '%s'..." % sysproj_name)
          sysproj.delete()
    except Exception as e:
      # Sysproj might not exist, which is fine
      pass

    # Remove existing app if it exists
    try:
      apps = workspace.get_apps()
      for app in apps:
        if app.name == app_name:
          print("Removing existing app '%s'..." % app_name)
          app.delete()
    except Exception as e:
      # App might not exist, which is fine
      pass

    # Get platform path if specified
    platform_path = None
    if "platform" in app_create_options:
      platform_name = app_create_options["platform"]
      # Construct platform path: {platform_name}/export/{platform_name}/{platform_name}.xpfm
      platform_path = f"{platform_name}/export/{platform_name}/{platform_name}.xpfm"
      print("Setting app platform to '%s'" % platform_path)

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
      print("Creating application '%s' with options: %s" % (app_name, app_kwargs))
      app = client.create_app_component(**app_kwargs)
      print("Application '%s' created successfully" % app_name)
    except Exception as e:
      print("Error: Failed to create application: %s" % e)
      vitis.dispose()
      return False

    # Get the app again to configure it
    try:
      app = client.get_component(name=app_name)
    except Exception as e:
      print("Error: Failed to get application '%s': %s" % (app_name, e))
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
        print("Configuring app option '%s' to '%s'" % (key, value))

        # Map TCL key to API key
        api_key = key_mapping.get(key)
        if not api_key:
          print("Warning: Configuration option '%s' not mapped to API key" % key)
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
        print("Successfully set %s to %s" % (api_key, values_list))
      except Exception as e:
        print("Warning: Could not set app option '%s': %s" % (key, e))
        import traceback
        traceback.print_exc()

    print("Application '%s' configured successfully" % app_name)

  except Exception as e:
    print("Error: Unexpected error in configure_app: %s" % e)
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
    print("  vitis -s ConfigureApp.py TestApp1 '{ PLATFORM TestPlatform1 PROC psu_cortexa53_0 OS standalone }' my_workspace_directory_path")
    sys.exit(1)

  app_name = sys.argv[1]
  app_conf = sys.argv[2]
  ws_dir = sys.argv[3]

  # Configure app
  result = configure_app(app_name=app_name, app_conf=app_conf, ws_dir=ws_dir)

  # Exit with appropriate code
  sys.exit(0 if result else 1)