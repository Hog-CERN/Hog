# COCOTB Command

## Overview

The `COCOTB` command generates a ready-to-use Python script that integrates a Hog project with the [cocotb](https://www.cocotb.org/) hardware verification framework.

It reads the project's Hog list files, resolves the full compile order (respecting library dependencies), and emits a self-contained Python file that calls `cocotb_tools.runner` to compile every HDL source and run a test against a chosen simulator.

## Usage

```bash
./Hog/Do COCOTB <project_name> [options]
```

`<project_name>` is the name of an existing Hog project (as listed by `./Hog/Do LIST`).

## Options

| Option | Description |
|---|---|
| `-lib <path>` | Path to a pre-compiled simulation library (e.g. `SimulationLib/`). When supplied, a `-modelsimini` flag pointing to `<path>/modelsim.ini` is added to every VHDL compilation unit. Can also be set via the `HOG_SIMULATION_LIB_PATH` environment variable. |
| `-ext_path <path>` | Absolute path for external IP libraries. |
| `-verbose` | Enable verbose/debug output. |

## What It Does

1. Parses the project's `.src` and `.ext` Hog list files to obtain the full source file set.
2. Resolves the compile order using the Hog `Hierarchy` utility.
3. Writes a Python script named `cocotb_<project>.py` in the repository root.

The generated script contains:

- **`test_placeholder`** – an empty `@cocotb.test()` coroutine to be replaced with actual test logic.
- **`build_libs(sim, build_dir)`** – iterates over every HDL source file in compile order and calls `runner.build()` for each one, setting:
  - `hdl_library` to the Hog library name for that file.
  - `build_args` to `["-2008"]` for VHDL files (plus `-modelsimini` when a sim-lib path is provided).
  - `build_args` with `+incdir+` entries for every directory containing `.svh`/`.vh` header files, for SystemVerilog/Verilog files.
- **`run_test(sim, build_dir, toplevel)`** – calls `runner.test()` against the generated test module.
- A **`__main__`** block with `argparse` for `--sim`, `--build-dir`, and `--toplevel`.

## Output

A single Python file is created at:

```
<repo_root>/cocotb_<project>.py
```

## Running the Generated Script

```bash
python cocotb_<project>.py --sim questa --toplevel <your_top_entity>
```

| Argument | Default | Description |
|---|---|---|
| `--sim` | `questa` | Simulator backend (e.g. `questa`, `ghdl`, `icarus`, `verilator`). |
| `--build-dir` | `sim_build` | Directory where build artefacts are written. |
| `--toplevel` | `<toplevel>` | Name of the HDL top-level entity/module to test. |

## Example

```bash
# Generate the cocotb script for project MyFirmware
./Hog/Do COCOTB MyFirmware

# Optionally, point to a pre-compiled simulation library
./Hog/Do COCOTB MyFirmware -lib SimulationLib/

# Run the generated script with GHDL
python cocotb_MyFirmware.py --sim ghdl --toplevel my_top
```

## Notes

- The generated script is a **template**: the placeholder test does nothing and must be replaced with meaningful verification logic.
- The compile order emitted by the script mirrors Hog's internal dependency resolution, so libraries are compiled before the design units that depend on them.
- The command runs entirely in `tclsh` without launching any IDE.
- Supported HDL file extensions: `.vhd`, `.vhdl`, `.v`, `.sv`, `.svh`, `.vh`.

## Implementation

| File | Role |
|---|---|
| `Tcl/commands.tcl` | Declares the `COCOTB` directive and its options. |
| `Tcl/launch.tcl` | Dispatches to `WriteCocoTbTemplate` when `do_cocotb == 1`. |
| `Tcl/utils/cocotb.tcl` | `WriteCocoTbTemplate` procedure — generates the Python file. |
| `Tcl/utils/hierarchy.tcl` | `Hierarchy` procedure — resolves the HDL compile order. |
