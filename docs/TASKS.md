# Tasks

Complete one small, verifiable task at a time. When a task is complete, update its checkbox and
`ROADMAP.md` in the same change.

## Functional and organization improvements (2026-10-20)

The plan started from version 0.41.2 on `main` at `fc49856`, with a clean worktree. Replicant
manages Omarchy configuration and software across machines, with a
Quickshell panel and a Bash CLI. The panel has Restore, Settings, Configs, and Machines tabs. The
CLI uses a single repository format and transaction journals.

The current product has 100 Settings controls, structured editors, profile-aware workspace and
display controls, and software reconciliation. The roadmap called for better Restore evidence.
The records also identify disposable-session checks and human interaction review. The old task file
mixed release history with active work. This plan addresses those verified gaps first.

### F01. Reconcile current verification records

- Objective: make the remaining release and usability evidence accurate and easy to resume.
- Tasks:
  - [x] Compare the open usability checklist with the recorded live placement, restart, and input evidence.
  - [x] Record which mouse, keyboard, focus, contrast, and shell-restart checks remain possible.
  - [x] Update `TASKS.md` and `ROADMAP.md` from the resulting evidence.
- Dependencies: none.
- Acceptance: every remaining item has a status, exact evidence or a stated environment blocker, and one next action.
- Required checks: compare every claim with the existing task records and Git state; run `git diff --check`.
- Risks: the active session lock may still prevent a shell restart. Do not treat a blocked restart as a pass.
- State: Completed.
- Evidence: placement and moves passed in all three bar sections. A shell restart preserved the
  saved layout, and a real panel capture was reviewed. Mouse, keyboard, focus, and subjective
  contrast checks remain open for human review. The later release lifecycle could not restart the
  shell because Omarchy reported `solitaryBlockedBy: LOCK`. This phase reconciled records only; it
  did not repeat those live checks.
- Commit: this commit (`docs: reconcile verification records`).

### F02. Verify Settings in a disposable session

- Objective: close the live verification gap for Settings hardening and release behavior.
- Tasks:
  - [x] Run the Settings, save, and QML controller suites in an isolated test container against this checkout.
  - [ ] Use a disposable graphical Omarchy session, separate from the active user plugin and private data.
  - [ ] Exercise the documented install, enable, shell restart, and removal lifecycle.
  - [ ] Verify real setting reads, edits, resets, reload errors, rollback, and decimal input.
  - [ ] Record commands, results, and any environment limitation in the task records.
- Dependencies: F01 records the current evidence and environment limits.
- Acceptance: every lifecycle and Settings scenario has a result; failures retain exact evidence and remain open.
- Required checks: the lifecycle and Settings scenarios listed in `docs/settings-hardening-plan.md`.
- Risks: a disposable Omarchy session may not be available. Keep this phase open until the environment exists.
- State: BLOCKED (2026-10-21).
- Evidence: `omarchy plugin list --json` reports that `omarchy-shell` is not running, and
  `hyprctl instances -j` returns no active instance. The local Docker inventory has no Omarchy or
  Replicant test target. The active user installation is not a safe substitute for a disposable
  session. The Settings suite passed 497 checks, the Settings save suite passed 35 checks, and the
  QML controller suite passed 71 checks in a disposable container with this checkout mounted
  read-only. A headless Hyprland start exited with `CBackend::create() failed`. An offscreen
  Quickshell start exited because it had no display or session bus. These automated checks do not
  verify the live install, enable, restart, and removal lifecycle.
- Next action: resume F02 when a disposable Omarchy session is available.
- Commit: this commit (`docs: record Settings verification limits`).

### F03. Verify Restore decision evidence

- Objective: make sure users can review what Restore reads, changes, and skips.
- Tasks:
  - [x] Confirm the Restore tab names the repository as the source and this machine as the target.
  - [x] Confirm the dry-run preview groups by area and shows destination paths and file differences.
  - [x] Confirm the preview reports skipped items and never prints secret values.
  - [x] Run the restore, secret-redaction, and panel usability suites.
- Dependencies: F01 establishes the current evidence and verification limits.
- Acceptance: the preview identifies the repository source, local destination, planned differences, skipped items, and secret redaction.
- Required checks: restore, scope, secret-redaction, and QML interaction suites; plugin validation and QML lint for changed QML.
- Risks: none found in this audit. The preview uses the restore plan that the apply path consumes.
- State: Completed. Existing behavior met the acceptance criteria, so no product code changed.
- Evidence: `tests/test-journey.sh` passed 76 checks, `tests/test-restore-secrets.sh` passed 46 checks, and `tests/test-usability.sh` passed 143 checks in the isolated test container.
- Commit: this commit (`docs: verify Restore decision evidence`).

### F04. Separate active work from project history

- Objective: make the task record and roadmap clear for the next contributor.
- Tasks:
  - [x] Keep current phases, open risks, and the next action in `docs/TASKS.md`.
  - [x] Move completed dated session reports and closed release checklists into a linked history document.
  - [x] Align `docs/ROADMAP.md` with the active and completed records.
  - [x] Keep repository instructions and the private data repository boundary intact.
- Dependencies: F01 resolves which current items remain open.
- Acceptance: `TASKS.md` names only active work and its next action; archived material remains linked and unchanged in meaning; roadmap status matches both.
- Required checks: compare every moved checklist and evidence block against Git history; run `git diff --check`.
- Risks: moving records can lose release evidence or make old phase references stale. Preserve phase names, commits, and links.
- State: Completed.
- Evidence: moved the prior task history to `docs/TASKS-HISTORY.md`. The active plan is 114 lines; the linked archive preserves the former release and session records. F02 retains the live verification blocker.
- Commit: this commit (`docs: separate active tasks from history`).

### F05. Select the next product organization improvement

- Objective: choose one measurable panel improvement after the current Restore work is reviewed.
- Tasks:
  - [x] Review how users find pending work across Restore, Settings, Configs, and Machines.
  - [x] Use existing test journeys and panel structure to identify one repeated navigation or status problem.
  - [x] Write a bounded proposal with a before-and-after journey and acceptance checks.
- Dependencies: F03 and F04.
- Acceptance: the proposal names one observed problem, one affected panel path, one outcome metric, and focused checks. Do not add a feature from speculation alone.
- Required checks: inspect the affected panel journey and existing QML tests; no product changes in this phase.
- Risks: broad redesign can increase panel complexity. Keep the proposal to one user journey.
- State: Completed.
- Evidence: Restore uses a vertical stack of six action cards, and `RestoreTab.navigationItem()` returns no anchor. Other tabs expose card or row anchors. Existing usability checks cover tab access but no jump between Restore cards.
- Proposal: add a compact, keyboard-accessible section picker for the visible Restore cards. Before, a person who opens Restore to undo a backup must scroll or tab past earlier cards. After, the person picks “Undo a restore” and reaches that card directly. Target: reach any visible Restore section with one navigation action, then activate its control with one action. Test each visible card, hidden-card changes, keyboard focus, and return from a preview.
- Commit: this commit (`docs: propose Restore section navigation`).

## Final verification (2026-10-21)

- `tests/run-all.sh` passed gates G0 through G8, then exited 1 because `status.brief` measured 120 ms against its 100 ms budget. The isolated `tests/bench-status.sh --check` rerun passed at 100 ms. Treat the performance result as borderline, not as a clean full-suite pass.
- `omarchy plugin validate .`, QML lint, `git diff --check`, and `tests/check-version-bump.sh --base origin/main` passed. No version bump is required because shipped code did not change.
- G7 skipped the Tokyo Night screenshot check because `/usr/share/omarchy/themes/tokyo-night` is unavailable. Fixed offscreen screenshots passed. F02 remains blocked on live lifecycle and graphical Settings checks.

## Next action

F01, F03, F04, and F05 are complete. F02 remains blocked until a disposable graphical Omarchy session is available.

## Previous records

Completed release checklists and dated session evidence are in [TASKS-HISTORY.md](TASKS-HISTORY.md). Open Settings lifecycle work is tracked in [settings-hardening-plan.md](settings-hardening-plan.md) and F02 above.
