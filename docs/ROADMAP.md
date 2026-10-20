# Roadmap

## Completed

- Version 0.41.0 delivers portable Omarchy controls: 100 panel settings with
  manual apply actions, managed-block structured editors (`shortcut`,
  `compose`, `bar-layout`), profile-aware workspace and display editors
  (`workspace`, `display`), and software reconciliation (`reconcile`) inside
  Restore. Published as one squashed commit, verified by the full matrix,
  green CI, and the active 0.41.0 installation.

- Version 0.13.0 delivered the single-format repository, transactional saves, bulk operations, and the current panel.
- Version 0.14.0 makes the CLI fail closed for help, locks, core load errors, undo, and unknown states.

## Current

- Version 0.41.1 reviews the portable controls release. It preserves the
  selected package source, opens installs visibly, keeps file modes, improves
  rollback, and makes new command parsers fail closed. Decimal settings use
  a text field with a unit label. Qualified color references restore the theme.
- Complete live installation and placement verification for the usability patch.
- Record the remaining shell restart and interaction evidence in `TASKS.md`.

## Next

- Improve restore evidence without expanding the public repository format or scope CLI.
- Complete disposable-session verification for the Settings hardening release.

## Portable controls expansion (0.41.0)

- Work happens on `feature/portable-controls-0.41` (I0 through I7 local, I8 squashes to `main`).
- I0 establishes the baseline; I1 defers Settings data until requested.
- I2 adds Settings navigation and manual apply actions.
- I3 expands window and effect settings; I4 completes portable scalar settings (95 to 105).
- I5 adds portable structured editors; I6 adds profile-aware workspace and display editors.
- I7 reconciles portable software inventories; I8 audits, releases 0.41.0, publishes, and installs.
- The repository format stays unchanged; new mutating CLI commands preview by default and require `--apply`.
- Status: I0 through I8 complete. Deferred Settings loading reduces the initial
  median from 7.84 seconds to 2.28 seconds. The Settings tab covers five
  domains and 100 settings. Structured editors use managed blocks and
  preview-first changes. Workspace and display editors separate shared app
  rules from monitor mappings for each profile. Software reconciliation
  installs selected missing packages from one saved machine inside Restore.

## Settings hardening (0.40.0)

- Lua writes preserve scalar types, reject damaged managed blocks, and restore
  the exact backup when reload validation fails.
- Defaults only come from Omarchy files or registry fallbacks. Current
  compositor values do not create reset actions.
- Refreshes parse each Lua settings file once. Float controls accept exact
  decimal input.

## Settings expansion (0.39.0)

- Settings grow from 24 to 47: Keyboard, Mouse & pointer, Touchpad and Windows
  join the existing groups, with the seven existing identifiers unchanged.
- Hyprland values live in a managed block at the end of `hypr/input.lua` and
  `hypr/looknfeel.lua`. Writes validate with `hyprctl reload` and
  `configerrors`, roll back on any new error, and save only the owning file.
