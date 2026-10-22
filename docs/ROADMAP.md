# Roadmap

The executable plan, dependencies, acceptance criteria, and evidence are in [TASKS.md](TASKS.md).
F06–F10 are implemented in this checkout; F11 is next.

## Completed

- F10 detects vault changes across pulls and resolves them to secret IDs, with
  a tracked-secrets fallback when metadata is unreadable. Covered in
  `tests/test-crypto.sh` (122 checks), `tests/test-state.sh` (111 checks),
  and `tests/test-journey.sh` (76 checks). Shipped as 0.42.6.
- F09 merges incoming markers across pulls and prunes only resolved rows:
  inventory-only pulls preserve pending work, second config pulls add to it,
  and other-profile paths stay filtered. Covered in `tests/test-state.sh`
  (111 checks), `tests/test-save.sh` (75 checks), and `tests/test-journey.sh`
  (76 checks). Shipped as 0.42.5.
- F08 keeps the vault index scope authoritative: Off stays Off with unchanged
  ciphertext through ordinary saves, shared still saves, profile stays
  rejected, and single Off saves refuse. Covered in `tests/test-crypto.sh`
  (109 checks), `tests/test-bulk-vault.sh` (13 checks), and
  `tests/test-state.sh` (103 checks). Shipped as 0.42.4.
- F07 enforces mode 600 on identical restores and every new secret backup in
  both HOME and privileged paths, and fails closed when protection fails.
  Covered in `tests/test-restore-secrets.sh` (60 checks),
  `tests/test-crypto.sh` (97 checks), `tests/test-leaks.sh` (18 checks),
  and `tests/gate.sh G6`. Shipped as 0.42.3.
- F06 requires explicit PRIVATE visibility before activation or push: unknown,
  empty, malformed, or failing results stop with an actionable message and no
  local mutation, and a transient failure retries as PRIVATE. Covered in
  `tests/test-bootstrap.sh` (89 checks), `tests/test-cli.sh` (361 checks),
  and `tests/gate.sh G2`. Shipped as 0.42.2.
- F01 reconciles the open interaction and lifecycle evidence without claiming
  that human review or the blocked shell restart passed. F03 confirms that the
  reviewed Restore previews show their source, destination, differences,
  exclusions, and secret redaction. F04 separates active tasks from the
  preserved release history. F05 proposes direct navigation between visible
  Restore cards. F03 did not establish secret-history recovery or apply-error
  propagation. F05 completed a proposal, not an interface change.

- Version 0.41.0 delivers portable Omarchy controls: 100 panel settings with
  manual apply actions, managed-block structured editors (`shortcut`,
  `compose`, `bar-layout`), profile-aware workspace and display editors
  (`workspace`, `display`), and software reconciliation (`reconcile`) inside
  Restore. Published as one squashed commit, verified by the full matrix,
  green CI, and the active 0.41.0 installation.

- Version 0.13.0 delivered the single-format repository, transactional saves, bulk operations, and the current panel.
- Version 0.14.0 makes the CLI fail closed for help, locks, core load errors, undo, and unknown states.

## Current (2026-10-22)

- The local baseline is version 0.42.1 on `main`, commit `bda9422`.
  Recent changes refresh update state when the panel opens and reduce Settings source lookups.
- The panel has Overview, Configs, Settings, and Restore tabs. Machines is a section inside Overview.
- The integral audit reproduced seven high-severity defects and nine medium-severity defects.
  One further medium-severity modal keyboard finding requires real-key-event verification.
- The audit passed the existing full suite, plugin validation, QML lint, and eight offscreen screenshots.
  Additional probes exposed gaps in incoming-change protection, secret scope and permissions,
  repository readiness, recovery, Settings edits, controller startup, and restore feedback.
- Initialized-repository status probes were much slower than the empty-repository benchmark.
  New performance budgets must follow representative measurements.
- F02 remains blocked on a disposable graphical Omarchy session. Previous live placement evidence
  and offscreen passes do not establish the current install/enable/restart/removal lifecycle.

## Next

1. **Urgent, F06–F14:** verify repository privacy explicitly; protect secret permissions and scope;
   preserve incoming configs and encrypted changes; enforce readiness; recover secret-only deletions.
2. **Important, F15–F22:** retain independent Settings edits; recover failed process startup;
   report restore/apply results; align filters, owning-file navigation, key guidance, and documentation.
   Verify the modal keyboard route before deciding whether it requires a correction.
3. **Optimization, F23–F25:** make skipped validation visible, execute real runtime checks,
   benchmark initialized repositories, and improve one measured bottleneck when justified.
4. **Evolution, F26:** optionally add direct Restore section navigation from the F05 proposal.
   Keep the existing four tabs; do not treat this proposal as a required defect correction.

Start with **F11**. F02 can resume independently when its disposable environment is available.
Production readiness still requires F02 and the real-runtime evidence in F23.
No phase authorizes remote publication or changes to the active installation through this plan.

## Previous release and verification context

- Version 0.41.2 reports the actual update source and divergent history.
  Manual refresh invalidates cached settings and reloads the active view.
- Version 0.41.1 reviews the portable controls release. It preserves the
  selected package source, opens installs visibly, keeps file modes, improves
  rollback, and makes new command parsers fail closed. Decimal settings use
  a text field with a unit label. Qualified color references restore the theme.
- Live install and placement checks passed for left, center, and right. A shell
  restart preserved the saved layout. Human input review remains open.
- The release lifecycle restart remains blocked by Omarchy's session lock.
  See `docs/settings-hardening-plan.md` for its scope.
- Disposable-session verification for Settings hardening remains open as F02.
  Dated evidence is preserved in [TASKS-HISTORY.md](TASKS-HISTORY.md).

## Portable controls expansion (0.41.0)

- Work used `feature/portable-controls-0.41` (I0 through I7 local, I8 squashed to `main`).
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
