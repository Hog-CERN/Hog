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

import vitis
import sys
import inspect
import os
import hashlib

# Range used to derive the Vitis server port from the workspace path. It is kept
# below the usual ephemeral range so that it does not clash with the ports the
# operating system hands out for outgoing connections.
VITIS_PORT_BASE = 42000
VITIS_PORT_RANGE = 6000

# Windows refuses to open a path longer than this
WINDOWS_MAX_PATH = 260

# Longest path Vitis appends below <workspace>/<platform>/<proc>/<platform> when
# it builds the BSP of a processor domain, measured with Vitis 2025.2:
#   bsp/libsrc/build_configs/gen_bsp/libsrc/standalone/src/CMakeFiles/xilstandalone.dir/
#   743a002251c87983b35effde48ecde8c/translation_table.S.obj.d
# plus the four separators between the workspace, platform and processor names
VITIS_BSP_PATH_OVERHEAD = 146


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


def DisposeVitisClient():
  """Close all client connections and terminate the Vitis server, ignoring errors"""
  try:
    vitis.dispose()
  except:
    pass


def CheckBspPathLength(workspace_path, platform_name, proc_name):
  """Warn when the BSP object paths of a platform will not fit in MAX_PATH.

  Only checked on Windows. Vitis builds a BSP deep under
  <workspace>/<platform>/<proc>/<platform>/bsp/libsrc/build_configs/gen_bsp/...
  and the GNU cross compilers it drives are not long-path aware, so once the
  deepest object file crosses MAX_PATH the build dies on a misleading
  "No such file or directory" for a dependency file. Estimating the depth up
  front turns that into an actionable message, because the real failure shows up
  minutes later and thousands of log lines away from its cause.

  This is an estimate: the overhead is Vitis own directory layout, so it may
  drift between versions. Hence a warning and never a hard error.
  See AMD support article 000039167.

  Args:
    workspace_path: Path to the Vitis workspace
    platform_name: Name of the platform component
    proc_name: Name of the processor the domain is built for
  Returns:
    True if the projected paths fit, False if they are expected to be too long
  """
  if os.name != "nt":
    return True

  projected = len(workspace_path) + 2 * len(platform_name) + len(proc_name or "") \
      + VITIS_BSP_PATH_OVERHEAD
  if projected <= WINDOWS_MAX_PATH:
    return True

  PrintWarning("The BSP build path of platform '%s' is about %d characters long, over the Windows"
               " limit of %d, so building it will probably fail on a long object file name"
               % (platform_name, projected, WINDOWS_MAX_PATH))
  PrintWarning("Shorten the workspace path by at least %d characters, for example by mapping the"
               " repository to a virtual drive with 'subst', or use shorter platform names"
               % (projected - WINDOWS_MAX_PATH))
  return False


def VitisWorkspacePort(workspace_path):
  """Return the TCP port of the Vitis server to use for a workspace.

  Always asking for the same port makes the next "vitis -s" call reconnect to a
  server that is already running, instead of starting another one that would then
  fail to lock a workspace the first server still holds. The port is derived from
  the workspace path so that unrelated Hog jobs on the same machine do not end up
  sharing a server. Set HOG_VITIS_PORT to override it.

  Args:
    workspace_path: Path to the workspace directory
  Returns:
    Port number as an int
  """
  override = os.environ.get("HOG_VITIS_PORT")
  if override:
    return int(override)

  workspace_id = os.path.normcase(os.path.abspath(workspace_path)).encode("utf-8")
  digest = hashlib.md5(workspace_id).hexdigest()
  return VITIS_PORT_BASE + int(digest, 16) % VITIS_PORT_RANGE


def WorkspaceIsSet(client):
  """Return True if the client already has its workspace set.

  check_workspace() is not available in every Vitis version: when it is missing,
  assume the workspace still has to be set.
  """
  try:
    return bool(client.check_workspace())
  except Exception:
    return False


def InitVitisWorkspace(workspace_path):
  """Initialize a Vitis workspace and return the client.

  Connects to (or starts) the Vitis server of this workspace, sets the workspace
  if it is not set already (which creates the _ide metadata directory), and
  handles the common "cannot recognize the workspace version" error by calling
  update_workspace first.

  Args:
    workspace_path: Absolute path to the workspace directory
  Returns:
    vitis client object on success, None on failure.
    Caller is responsible for calling vitis.dispose() when done.
  """
  port = VitisWorkspacePort(workspace_path)
  PrintInfo("Setting Vitis workspace: %s (Vitis server port %d)" % (workspace_path, port))

  try:
    client = vitis.create_client(port=port)
  except Exception as e:
    PrintWarning("Could not use the Vitis server port %d (%s), letting Vitis pick one" % (port, e))
    try:
      client = vitis.create_client()
    except Exception as e2:
      PrintError("Failed to create the Vitis client: %s" % e2)
      return None

  try:
    if WorkspaceIsSet(client):
      PrintDebug("The Vitis server already has a workspace set")
    else:
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
  elif "already in use" in error_msg:
    PrintError("Vitis workspace '%s' is already in use: %s" % (workspace_path, error_msg))
    PrintError("Close any Vitis GUI or 'vitis -s' process using this workspace and try again")
  else:
    PrintError("Failed to set workspace '%s': %s" % (workspace_path, error_msg))

  DisposeVitisClient()
  return None


if __name__ == "__main__":
  print("SharedCommands.py is a library module providing shared functions:", flush=True)
  print("  - PrintInfo(message)", flush=True)
  print("  - PrintError(message)", flush=True)
  print("  - PrintWarning(message)", flush=True)
  print("  - PrintDebug(message)", flush=True)
  print("  - InitVitisWorkspace(workspace_path)", flush=True)
  print("  - DisposeVitisClient()", flush=True)
  print("  - VitisWorkspacePort(workspace_path)", flush=True)
  print("  - WorkspaceIsSet(client)", flush=True)
  print("  - CheckBspPathLength(workspace_path, platform_name, proc_name)", flush=True)
  print("\nThis module is imported by PlatformCommands.py, AppCommands.py, and HlsCommands.py", flush=True)
  sys.exit(0)