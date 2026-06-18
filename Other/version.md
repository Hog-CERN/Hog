# VERSION Command

Prints the version of a Hog project. With `-describe`, prints the Hog describe string instead.

## Usage

```bash
./Hog/Do VERSION <project_name> [options]
./Hog/Do VER <project_name> [options]
```

## Options

| Option | Description |
|---|---|
| `-describe` | Print the Hog describe string instead of the plain version number. |
| `-ext_path <path>` | Absolute path for external IP libraries. |
| `-verbose` | Enable verbose/debug output. |

## Output

Default:

```
v1.2.3
```

With `-describe`:

```
MyFirmware-v1.2.3-5-gabcdef01
```

## Example

```bash
./Hog/Do VER MyFirmware
./Hog/Do VERSION MyFirmware -describe
```

## Implementation

Defined in `Tcl/commands.tcl`. Dispatched in `Tcl/launch.tcl` via `GetRepoVersions` (plain version) and `GetHogDescribe` (describe string). Runs in `tclsh` without launching any IDE.
