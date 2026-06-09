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

import vitis
import sys
import inspect
import os


def PrintInfo(message):
  """
  Print an INFO message with function name prefix
  Args:
    message: The message to print
  """
  frame = inspect.currentframe()
  try:
    caller_frame = frame.f_back
    function_name = caller_frame.f_code.co_name
  except:
    function_name = "unknown"
  finally:
    del frame
  print("INFO: [Hog:Python:%s] %s" % (function_name, message), flush=True)

def PrintError(message):
  """
  Print an ERROR message with function name prefix
  Args:
    message: The message to print
  """
  frame = inspect.currentframe()
  try:
    caller_frame = frame.f_back
    function_name = caller_frame.f_code.co_name
  except:
    function_name = "unknown"
  finally:
    del frame
  print("ERROR: [Hog:Python:%s] %s" % (function_name, message), flush=True)

def PrintWarning(message):
  """
  Print a WARNING message with function name prefix
  Args:
    message: The message to print
  """
  frame = inspect.currentframe()
  try:
    caller_frame = frame.f_back
    function_name = caller_frame.f_code.co_name
  except:
    function_name = "unknown"
  finally:
    del frame
  print("WARNING: [Hog:Python:%s] %s" % (function_name, message), flush=True)

def PrintDebug(message):
  """
  Print a DEBUG message with function name prefix
  Only prints if HOG_DEBUG_MODE environment variable is set to 1
  Args:
    message: The message to print
  """
  debug_mode = os.environ.get('HOG_DEBUG_MODE', '0')
  if debug_mode != '1':
    return 

  frame = inspect.currentframe()
  try:
    caller_frame = frame.f_back
    function_name = caller_frame.f_code.co_name
  except:
    function_name = "unknown"
  finally:
    del frame
  print("DEBUG: [Hog:Python:%s] %s" % (function_name, message), flush=True)


def InitVitisWorkspace(workspace_path):
  """Initialize a Vitis workspace and return the client.

  Creates a Vitis client, sets the workspace (which creates the _ide
  metadata directory), and handles the common "cannot recognize the
  workspace version" error by calling update_workspace first.

  Args:
    workspace_path: Absolute path to the workspace directory
  Returns:
    vitis client object on success, None on failure.
    Caller is responsible for calling vitis.dispose() when done.
  """
  PrintInfo("Setting Vitis workspace: %s" % workspace_path)
  client = vitis.create_client()

  try:
    client.set_workspace(path=workspace_path)
    return client
  except Exception as e:
    error_msg = str(e)
    if "cannot recognize the workspace version" in error_msg or "update_workspace" in error_msg:
      try:
        client.update_workspace(path=workspace_path)
        client.set_workspace(path=workspace_path)
        PrintInfo("Vitis workspace initialized after update")
        return client
      except Exception as e2:
        PrintError("Failed to set workspace after update: %s" % e2)
    else:
      PrintError("Failed to set workspace '%s': %s" % (workspace_path, e))

  try:
    vitis.dispose()
  except:
    pass
  return None


if __name__ == "__main__":
  print("SharedCommands.py is a library module providing shared functions:", flush=True)
  print("  - PrintInfo(message)", flush=True)
  print("  - PrintError(message)", flush=True)
  print("  - PrintWarning(message)", flush=True)
  print("  - PrintDebug(message)", flush=True)
  print("  - InitVitisWorkspace(workspace_path)", flush=True)
  print("\nThis module is imported by PlatformCommands.py, AppCommands.py, and HlsCommands.py", flush=True)
  sys.exit(0)