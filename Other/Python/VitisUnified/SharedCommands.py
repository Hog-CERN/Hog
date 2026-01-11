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
import inspect
import os


def PrintInfo(message):
  """
  Print an INFO message with function name prefix
  Args:
    message: The message to print
  """
  # Get the calling function name (skip this function and its caller)
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
  # Get the calling function name (skip this function and its caller)
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
  # Get the calling function name (skip this function and its caller)
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
  # Check if debug mode is enabled via environment variable
  debug_mode = os.environ.get('HOG_DEBUG_MODE', '0')
  if debug_mode != '1':
    return 

  # Get the calling function name (skip this function and its caller)
  frame = inspect.currentframe()
  try:
    caller_frame = frame.f_back
    function_name = caller_frame.f_code.co_name
  except:
    function_name = "unknown"
  finally:
    del frame
  print("DEBUG: [Hog:Python:%s] %s" % (function_name, message), flush=True)


if __name__ == "__main__":
  # This is a library module providing logging functions
  # It is typically imported by other Vitis Unified command modules
  print("SharedCommands.py is a library module providing logging functions:", flush=True)
  print("  - PrintInfo(message)", flush=True)
  print("  - PrintError(message)", flush=True)
  print("  - PrintWarning(message)", flush=True)
  print("  - PrintDebug(message)", flush=True)
  print("\nThis module is typically imported by PlatformCommands.py and AppCommands.py", flush=True)
  sys.exit(0)