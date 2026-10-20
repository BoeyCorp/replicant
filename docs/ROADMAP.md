# Roadmap

## Completed

- Version 0.13.0 delivered the single-format repository, transactional saves, bulk operations, and the current panel.
- Version 0.14.0 makes the CLI fail closed for help, locks, core load errors, undo, and unknown states.

## Current

- Version 0.15.0 makes recovery reinsert entries, makes the CLI fail
  closed for undo and track options, and makes the panel honest about pending
  scope, locked rows, keyboard reach and result history.
- Complete live installation and placement verification for the usability patch.
- Record the remaining shell restart and interaction evidence in `TASKS.md`.
- Complete deferred panel loading. Security cleanup and documentation alignment
  are complete.

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
- Status: I0 through I7 complete, I8 in progress. Deferred Settings loading ships on the branch; initial load median 7.84s to 2.28s (71 percent faster, budget 2.5s). Settings tab navigates five domains with manual apply actions. Window and effect catalog at 76 settings; border-inside and animation speed excluded with compositor evidence. Scalar catalog at 100 settings: dwindle, master, group bar, focus policy, XKB variant and options, monospace font, and bar anchor; scrolling fullscreen-one-column and group colors excluded with compositor evidence. Structured editors (`shortcut`, `compose`, `bar-layout`) write managed blocks with preview-first mutations and save through the owning entry. Workspace and display editors (`workspace`, `display`) keep shared app rules apart from per-profile monitor mappings; desc: serials never print. Software reconciliation (`reconcile`) installs only selected missing packages from the newest-saved machine, inside Restore.

## Settings hardening (0.40.0)

- Lua writes preserve scalar types, reject damaged managed blocks, and restore
  the exact backup when reload validation fails.
- Defaults only come from Omarchy files or registry fallbacks. Current
  compositor values do not create reset actions.
- Refreshes parse each Lua settings file once. Float controls accept exact
  decimal input beside their sliders.

## Settings expansion (0.39.0)

- Settings grow from 24 to 47: Keyboard, Mouse & pointer, Touchpad and Windows
  join the existing groups, with the seven existing identifiers unchanged.
- Hyprland values live in a managed block at the end of `hypr/input.lua` and
  `hypr/looknfeel.lua`. Writes validate with `hyprctl reload` and
  `configerrors`, roll back on any new error, and save only the owning file.
