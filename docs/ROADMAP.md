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

## Settings expansion (0.39.0)

- Settings grow from 24 to 47: Keyboard, Mouse & pointer, Touchpad and Windows
  join the existing groups, with the seven existing identifiers unchanged.
- Hyprland values live in a managed block at the end of `hypr/input.lua` and
  `hypr/looknfeel.lua`. Writes validate with `hyprctl reload` and
  `configerrors`, roll back on any new error, and save only the owning file.
