# VHDL-LS Command

## Overview

The `VHDLLS` command generates a [VHDL-LS](https://github.com/VHDL-LS/rust_hdl) configuration file for a Hog project. VHDL-LS is a language server that provides IDE features (go-to-definition, diagnostics, auto-completion) for VHDL files in editors such as VS Code.

The generated TOML file maps each Hog library to the VHDL source files it contains, using paths relative to the repository root. It can be merged into (or used as) the `vhdl_ls.toml` configuration file consumed by the language server.

## Usage

```bash
./Hog/Do VHDLLS <project_name> [options]
```

`<project_name>` is the name of an existing Hog project (as listed by `./Hog/Do LIST`).

The command can also be invoked with the short alias `VHDL`:

```bash
./Hog/Do VHDL <project_name>
```

## Options

| Option | Description |
|---|---|
| `-verbose` | Enable verbose/debug output. |

## What It Does

1. Reads the project's `.src` Hog list files via `GetHogFiles`.
2. Creates a TOML file named `vhdl_ls_<project>.toml` in the repository root.
3. Writes a `[libraries]` section. For each Hog library, a `<libname>.files` entry is added listing the relative paths of all `.vhd` and `.vhdl` source files that belong to it.

Non-VHDL files (Verilog, SystemVerilog, IP, constraint files, etc.) are silently skipped — VHDL-LS only handles VHDL sources.

## Output

A single TOML file is created at:

```
<repo_root>/vhdl_ls_<project>.toml
```

### Example output structure

```toml
[libraries]

work.files = [
  'path/to/source_a.vhd',
  'path/to/source_b.vhdl',
]

my_lib.files = [
  'path/to/pkg.vhd',
]
```

## Using the Generated File

Copy the content into your project's `vhdl_ls.toml` (or use it directly as the configuration file):

```bash
cp vhdl_ls_<project>.toml vhdl_ls.toml
```

VS Code users with the [VHDL LS extension](https://marketplace.visualstudio.com/items?itemName=haakonesbjornsen.vhdl-ls) will pick up `vhdl_ls.toml` automatically when it is placed at the repository root.

## Example

```bash
# Generate the VHDL-LS configuration for project MyFirmware
./Hog/Do VHDLLS MyFirmware

# Use the short alias
./Hog/Do VHDL MyFirmware
```

## Notes

- The command runs entirely in `tclsh` without launching any IDE.
- Only `.vhd` and `.vhdl` files are included in the output; all other source types are ignored.
- File paths in the TOML are relative to the repository root, so the file is portable across machines as long as the repository is checked out at the same relative structure.
- The command does not modify any existing `vhdl_ls.toml`; it writes a standalone file that you merge manually.

## Implementation

| File | Role |
|---|---|
| `Tcl/commands.tcl` | Declares the `VHDLLS` / `VHDL` directive and its options. |
| `Tcl/launch.tcl` | Dispatches to the TOML generation logic when `do_vhdl_ls == 1`. |
