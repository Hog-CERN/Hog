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
import re
import zipfile
import xml.etree.ElementTree as ET


def app_list_dict(workspace_path):
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

def app_config(workspace_path, app_name, config_dict):
    """Configure app settings
    Args:
        workspace_path: Path to the workspace
        app_name: Name of the app
        config_dict: Dictionary with app configurations
    """
    workspace = vitis.Workspace(workspace_path)
    app = workspace.get_app(app_name)
    for key, value in config_dict.items():
        if key == 'build-config':
            app.set_build_config(value)
        # Add other config options as needed
    app.save()

def app_build(workspace_path, app_name):
    """Build an app
    Args:
        workspace_path: Path to the workspace
        app_name: Name of the app
    """
    workspace = vitis.Workspace(workspace_path)
    app = workspace.get_app(app_name)
    app.build()

def extract_soft_procs_from_xsa(xsa_path, output_file):
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

        if len(processors) == 0:
          print("Note: No soft processors found via XSA XML parsing", file=sys.stderr)

        # Write to output file
        if output_file:
            with open(output_file, 'w') as f:
                for proc in processors:
                    if proc['address_tag']:
                        f.write(f"{proc['hier_name']} {proc['address_tag']}\n")
                    else:
                        print("Warning: Processor %s has no address tag" % proc['name'], file=sys.stderr)
        return {'processors': processors}

    except zipfile.BadZipFile:
        print("ERROR: %s is not a valid ZIP file (XSA format)" % xsa_path, file=sys.stderr)
        return {'processors': [], 'error': 'Invalid XSA file format'}
    except Exception as e:
        print("ERROR: Failed to extract soft processors from XSA: %s" % str(e), file=sys.stderr)
        import traceback
        traceback.print_exc(file=sys.stderr)
        return {'processors': [], 'error': str(e)}


if __name__ == "__main__":
    command = sys.argv[1]
    if command == "app_list":
        workspace_path = sys.argv[2]
        apps = app_list_dict(workspace_path)
        print(json.dumps(apps))
    elif command == "app_config":
        workspace_path = sys.argv[2]
        app_name = sys.argv[3]
        config_json = sys.argv[4]
        config_dict = json.loads(config_json)
        app_config(workspace_path, app_name, config_dict)
    elif command == "app_build":
        workspace_path = sys.argv[2]
        app_name = sys.argv[3]
        app_build(workspace_path, app_name)
    elif command == "extract_soft_procs":
        xsa_path = sys.argv[2]
        output_file = sys.argv[3] if len(sys.argv) > 3 else None
        result = extract_soft_procs_from_xsa(xsa_path, output_file)
        print(json.dumps(result))
    else:
        print("ERROR: Unknown command: %s" % command, file=sys.stderr)
        sys.exit(1)