# Hog review guidelines

Hog is a set of Tcl and shell scripts that manage HDL projects (Vivado, Quartus, Libero,
Diamond, ISE/PlanAhead, Vitis, GHDL) with git, plus CI templates for GitLab and GitHub.
It is used as a git submodule inside users' firmware repositories, so every change ships
to many projects that we cannot test: backward compatibility matters.

## Repository map

- `Do`: bash entry point that finds a suitable `tclsh` (from the IDE installations or the
  system) and calls `Tcl/launch.tcl`.
- `Tcl/hog.tcl`: core library (versioning `GetVer`/`GetSHA`, list-file parsing, `Msg`, ...).
  `Tcl/launch.tcl`, `Tcl/commands*`, `Tcl/create_project.tcl`: command dispatch and project
  creation. `Tcl/integrated/`: pre/post synthesis/implementation/bitstream hooks run inside
  the IDE. `Tcl/CI/`: scripts called by the CI templates. `Tcl/tools/`, `Tcl/utils/`, `Tcl/core/`.
- `Other/*.sh`: helper bash scripts (shared functions in `Other/CommonFunctions.sh`).
  `Other/Python/`: Vitis Unified support.
- `YAML/*.yml`, `hog.yml`, `hog-dynamic.yml`, `Templates/`: GitLab CI templates that users
  `include:`. `.github/workflows/Hog-*.yml`: reusable GitHub workflows.
- `.gitlab-ci.yml`, `.gitlab/`: CI of the Hog repository itself (not shipped to users).

## What to look for

- **Tcl portability**: code runs in several interpreters (Vivado's Tcl 8.5/8.6, Quartus,
  Libero `acttclsh`, plain `tclsh`). Flag Tcl 8.6/9-only features (`lmap`, `try`, `string cat`,
  `dict` subcommands newer than 8.5, `file tempfile`, ...) used outside code paths that are
  guaranteed to run on 8.6. Flag IDE-specific commands (e.g. `get_property`, `set_property`)
  used in code that may run outside that IDE without a guard.
- **Tcl correctness**: unbraced `expr`, missing `-nocomplain`/`catch` around `glob` or file
  operations that may legitimately fail, list vs string confusion, `exec` without handling
  non-zero exit or stderr output, paths with spaces, Windows path handling.
- **Messaging**: use `Msg Info|Warning|CriticalWarning|Error|Debug` instead of `puts` for
  user-facing messages; `Msg Error` should be followed by a proper exit/return where needed.
- **Versioning and git**: anything touching `GetVer`, `GetSHA`, tag parsing, list files or
  `git` invocations must keep working with shallow clones, detached HEAD, submodules and
  repositories with no tags.
- **Bash**: must pass `shellcheck -x -S error`. Quote variables, check `$?` right after the
  command it refers to, prefer POSIX-compatible constructs in files sourced by `sh`.
- **CI templates**: changes to `YAML/`, `hog*.yml` and `.github/workflows/` affect all users.
  Check variable names, `rules`/`only` logic, job `needs`, artifact paths and docker image
  tags (master must not use `hogcern/hog:develop`). YAML must pass yamllint.
- **Compatibility**: renamed/removed commands, options, `hog.conf` properties, list-file
  properties or environment variables need a deprecation path or a clear note.
- **Security**: no secrets echoed in CI logs, no unquoted user input passed to `eval`/`exec`.

## What not to report

- Pure style nits already enforced by `tclint` (`.tclint`), `shellcheck` or `yamllint`.
- Speculative issues you could not confirm by reading the surrounding code.
- Praise or restating what the change does, except in the summary.
