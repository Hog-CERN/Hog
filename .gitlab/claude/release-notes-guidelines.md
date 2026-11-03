# Hog release notes guidelines

Hog uses a `HogYYYY.N` scheme: `YYYY.1` and `YYYY.2` are feature releases (develop merged
into master), and `-N` suffixes are patch releases cut from master with hotfix MRs.

The notes are read by firmware engineers deciding whether to update the Hog submodule in
their repository. They want to know: what is new, what changed behaviour, what they must
do when updating, and which bugs are fixed.

## Style

- Write for users, not for Hog developers: describe the effect, not the implementation.
  Name commands (`./Hog/Do ...`), options, `hog.conf` properties, list-file properties,
  CI variables and templates exactly as the user types them, in backticks.
- Start with one sentence that characterises the release (e.g. "The Vitis Unified and
  Vitis HLS release." or "Bugfix release: ...").
- For patch releases with few changes, one short paragraph is enough.
- For feature releases use a bullet list grouped by theme with a bold lead-in
  (`- **Vitis HLS**: ...`), most important first, and end with a `- **Fixes**: ...` bullet.
- Actions users must take when updating (renamed/removed options, new required CI
  variables, docker image changes, changed defaults) go in the separate `upgrade_notes`
  output field, never in the notes themselves: the job renders them as an
  `### Upgrade notes` section.
- Merge commit noise, CI-of-Hog-itself changes, linting, typo fixes and reverted work
  should be left out unless they matter to users.
- Do not invent features: every statement must be backed by the commits, the MR
  descriptions or the diff. Do not include MR numbers, commit hashes or author names.
- Do not add a title, a compare link or a diffstat: the job adds them.

## Example (feature release)

The Vitis Unified and Vitis HLS release.

- **Vitis Unified**: new `Other/Python/VitisUnified` package driving platform and
  application creation. `-vitis_only` / `-vivado_only` split the flow; standalone Vitis
  projects skip the Vivado setup entirely.
- **Vitis HLS**: components are declared as `[hls:<component>]` sections in `hog.conf`
  and configured from `hls_config.cfg`; csim, synthesis, cosim and impl steps are
  individually selectable.
- **New commands**: `cocotb` generates a Python cocotb skeleton compiling all project
  sources with the chosen simulator.
- **Fixes**: lowercase VHDL booleans for Vivado generic overrides, ELF properties
  reapplied after block-design generation.

## Example (patch release)

Bugfix release: fall back to plain `tar` when an IP archive file name exceeds 254
characters, revert a post-synthesis change, and raise the message limit.
