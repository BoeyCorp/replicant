# Tasks

Complete one small, verifiable phase at a time. Update this file and [ROADMAP.md](ROADMAP.md)
together. Planning does not authorize implementation, installation, commits, or publication.

## Objective and current state

Replicant saves, restores, and shares an Omarchy setup through a private Git repository.
Its users manage their own desktop or several machines. Profiles control configuration scope,
not user permissions. This plan addresses the integral audit of 2026-10-22.

- Baseline: public plugin repository, branch `main`, commit `bda9422`, manifest version `0.42.1`.
- The worktree was clean before this documentation update. HEAD has no version tag.
  `git describe --tags --always` returns `v0.16.4-28-gbda9422`; this is not the manifest version.
- Recent changes refresh update state when the panel opens and reduce Settings source lookups.
- The panel has **Overview, Configs, Settings, and Restore** tabs. Machines appear inside Overview.
- Existing functionality includes scoped saves, encrypted secrets, restores and undo, live Settings,
  structured editors, workspace/display profiles, software reconciliation, and transaction recovery.
- F01, F03, F04, and F05 are complete within their recorded scope. Their evidence remains in
  [TASKS-HISTORY.md](TASKS-HISTORY.md#functional-and-organization-plan-2026-10-20-to-2026-10-21).
  F05 completed a proposal, not its implementation.
- F02 remains blocked on a disposable graphical Omarchy session. Offscreen tests do not close it.
- The audit reproduced seven high-severity defects and nine medium-severity defects.
  A further medium-severity keyboard finding requires real-event verification.
- No audit correction has been implemented. Passing existing tests does not resolve these findings.

## Architecture and boundaries

| Area | Implementation and responsibility |
| --- | --- |
| Desktop entry points | `BarWidget.qml` and `Service.qml`: status, panel entry, and IPC integration. |
| Panel | `Panel.qml`, `components/`, and `replicant.js`: navigation, presentation, Settings, and UI state. |
| Command execution | `ReplicantController.qml`: one process queue with progress, cancellation, and completion. |
| CLI and domain logic | Bash entry points in `bin/`; repository, scopes, vault, history, restore, and status modules in `bin/lib/`. |
| Persistence | One format from [SPEC.md](SPEC.md): shared and profile configs, machine inventories, encrypted vault, and Git history. |
| Local state | Keys, incoming markers, caches, and transaction journals stay outside the shared data repository. |
| Integrations | Git, GitHub CLI, age, jq, Omarchy, Hyprland, Qt/QML, and Quickshell. Tests also use Docker and ShellCheck. |

There is no application server, database service, or role-based permission system.
The desktop plugin runs with the local user's authority. Do not use the private data repository,
active plugin, or real secrets as fixtures. Do not add a second repository format or compatibility layer.

## Audit evidence and verification limits

The audit at this baseline ran `./tests/run-all.sh` successfully, including G0 through G8.
Eight offscreen screenshots matched. Plugin validation and QML lint passed in that environment.
This is prior audit evidence, not a claim that implementation phases below are complete.

Additional synthetic fixtures reproduced the data, scope, permissions, and recovery defects below.
Real offscreen Quickshell probes reproduced lost Settings edits and the failed-start process stall.
The keyboard probe changed background selection through a navigation signal while a dialog was open.
It did not establish the full physical-key route; F21 must check that route.

An additional ShellCheck run found SC2193 in `bin/replicant`.
A 52-entry initialized fixture took about 5.2–5.4 seconds for deferred status and 3.3–3.6 seconds
for warm brief status. The existing empty-repository benchmark reported about 90 ms.
These are diagnostic samples, not portable performance budgets or statistically robust percentiles.

The audit did not verify real GitHub writes, marketplace publication, or the disposable desktop
install/enable/restart/removal lifecycle. Synthetic probes must become maintained regressions
before their corresponding implementation phase can close.

| Finding | Severity and evidence | Affected source | Planned phase |
| --- | --- | --- | --- |
| R01 | High, confirmed: encrypted incoming changes can be overwritten by a stale local save. | `bin/lib/incoming.sh`, `bin/lib/crypto.sh` | F10, F11 |
| R02 | High, confirmed: a later pull clears unresolved incoming config markers. | `bin/lib/incoming.sh` | F09 |
| R03 | High, confirmed: saving a changed secret can replace its Off scope with Shared. | `bin/lib/scopes.sh`, `bin/lib/crypto.sh` | F08 |
| R04 | High, confirmed: repository setup accepts an unknown GitHub visibility result. | `bin/lib/repo.sh` | F06 |
| R05 | High, confirmed: unchanged secrets and plaintext backups can retain mode 644. | `bin/lib/crypto.sh` | F07 |
| R06 | High, confirmed: a secret-only deletion is absent from recovery discovery and exits recovery early. | `bin/lib/history.sh` | F13, F14 |
| R07 | High, confirmed: readiness omits required vault files; status reports invalid data as initialized. | `bin/lib/schema.sh`, `bin/lib/status.sh` | F12 |
| R08 | Medium, confirmed: one Settings debounce slot drops an earlier edit to another setting. | `Panel.qml` | F15 |
| R09 | Medium, confirmed: failed process startup leaves the controller queue blocked. | `ReplicantController.qml` | F16 |
| R10 | Medium, probable end-to-end: modal navigation can reach the background; signal routing was reproduced. | `Panel.qml`, Omarchy confirmation dialog integration | F21 |
| R11 | Medium, confirmed: Show owning file can select a row hidden by filters or a closed category. | `Panel.qml`, Configs components | F19 |
| R12 | Medium, confirmed: programmatic search changes leave stale text in the visible field. | `components/FilterBar.qml`, `Panel.qml` | F18 |
| R13 | Medium, confirmed: a locked existing vault offers key creation, which the CLI rejects. | `components/StatusCard.qml`, `bin/lib/crypto.sh` | F20 |
| R14 | Medium, confirmed: status performance gates measure an uninitialized repository and the fastest sample. | `tests/bench-status.sh`, status pipeline | F24, F25 |
| R15 | Medium, confirmed: CI omits real desktop validation and ShellCheck; some gates only inspect source text. | `.github/workflows/tests.yml`, `tests/run-all.sh`, QML test harness | F23 |
| R16 | Medium, confirmed: dry-run, write-boundary, CLI setup, and key instructions contradict behavior. | `README.md`, `docs/getting-started.md` | F22 |
| R17 | Medium, confirmed: restore-file suppresses apply failures and reports success after copying. | `bin/lib/restore.sh`, CLI and panel result handling | F17 |

## Execution and verification rules

Each phase is scoped to one work session. Split a phase before implementation if its investigation
reveals a larger change. Preserve these IDs and record additional dependencies instead of expanding scope silently.

- Reproduce the named failure with synthetic data before changing its behavior.
- Reuse existing modules and test harnesses. Add focused assertions for observable behavior.
- Update affected setup, CLI, UI, and technical documentation in the same implementation phase.
- Follow [CONTRIBUTING.md](../CONTRIBUTING.md), including the version increase for every shipped code change.
  This planning update needs no version change.
- After a code phase, run its focused checks and the required full suite.
  Run plugin validation and QML lint as required by the repository instructions.
- A skipped real-runtime check remains skipped. Record blockers and commands instead of claiming a pass.
- Record test evidence, changed files, and the phase commit when execution is authorized.
  All new phases below currently have no implementation evidence and no commit.
- Do not install, remove, restart, publish, or modify an active desktop to satisfy a test.
  F02 uses a separate disposable session with the required authorization.
- Conditional or optional phases require their stated evidence or selection before implementation.

Useful commands from the repository root:

```sh
./bin/replicant --help
bash tests/test-schema.sh
bash tests/test-crypto.sh
bash tests/test-save.sh
bash tests/qml-controller.sh
./tests/run-all.sh
omarchy plugin validate .
qmllint -I /usr/share/omarchy/shell ./*.qml ./components/*.qml
bash tests/check-version-bump.sh --base <phase-base>
git diff --check
```

Replace `<phase-base>` with the recorded commit immediately before the phase.
These commands do not authorize missing dependency installation or a live shell restart.

## Phase order

Order within each priority band follows the table, subject to dependencies.
F02 can resume whenever its disposable environment exists; repeat affected scenarios after later fixes.

| Priority | Phase | Outcome | Dependencies | State |
| --- | --- | --- | --- | --- |
| Existing verification | F02 | Real Settings and desktop lifecycle evidence | F01; disposable session | BLOCKED |
| Urgent | F06 | Explicit private-repository verification | None | Completed |
| Urgent | F07 | Restrictive secret and backup permissions | None | Completed |
| Urgent | F08 | One effective secret scope | None | Completed |
| Urgent | F09 | Durable incoming config markers | None | Completed |
| Urgent | F10 | Encrypted incoming-change discovery | F08, F09 | Completed |
| Urgent | F11 | Save protection for incoming secrets | F10 | Completed |
| Urgent | F12 | Consistent repository readiness and status | None | Completed |
| Urgent | F13 | Secret deletion discovery | None | Pending |
| Urgent | F14 | Secret-only recovery | F12, F13 | Pending |
| Important | F15 | Independent pending Settings edits | None | Pending |
| Important | F16 | Controller recovery after startup failure | None | Pending |
| Important | F17 | Accurate restore and apply outcomes | None | Pending |
| Important | F18 | Synchronized search state | None | Pending |
| Important | F19 | Visible owning-file navigation | F18 | Pending |
| Important | F20 | Correct key action for an existing vault | F12 | Pending |
| Important | F21 | Verified modal keyboard routing | None | Verification first |
| Important | F22 | Accurate setup and command documentation | F06–F20; F21 outcome | Pending |
| Optimization | F23 | Honest, executable validation gates | F15, F16, F21 outcome | Pending |
| Optimization | F24 | Representative status benchmark | F08–F12 | Pending |
| Optimization | F25 | One measured status bottleneck improvement | F24 profiling | Conditional |
| Evolution | F26 | Direct Restore section navigation | F05, F18–F21; selection | Optional proposal |

### F02. Verify Settings in a disposable session

- Objective: close the live Settings and desktop lifecycle gap from the previous plan.
- Tasks:
  - [x] Run Settings, save, and QML controller suites in an isolated container against the earlier checkout.
  - [ ] Prepare a disposable graphical Omarchy session, separate from the active plugin and private data.
  - [ ] Exercise install, enable, shell restart, and removal with the required authorization.
  - [ ] Verify reads, rapid edits, resets, decimal input, reload errors, rollback, and focus.
  - [ ] Record the tested commit, exact commands, results, screenshots, and remaining limitations.
- Dependencies: F01; a disposable graphical session. Include F15–F21 changes in the final live check.
- Acceptance: every scenario in [settings-hardening-plan.md](settings-hardening-plan.md) has a real result.
  A failed or unavailable scenario stays open.
- Required checks: that plan's lifecycle and Settings scenarios, plus real mouse and keyboard interaction.
- Scope and risk: one verification session after provisioning; never substitute the active installation.
- State: BLOCKED. The 2026-10-21 record found no usable disposable session; provisioning remains unverified.
- Prior evidence: Settings 497, Settings save 35, and QML controller 71 checks passed in the earlier container.
  Headless Hyprland and Quickshell attempts failed in that session. Later offscreen audit probes succeeded,
  but did not test a complete desktop lifecycle. Full earlier evidence remains in the history document.
- Next action: resume when a disposable graphical session is available.

## Urgent: protect data and repository boundaries

### F06. Require explicit private-repository verification

- Finding and scope: R04; repository setup in `bin/lib/repo.sh`.
- Tasks:
  - [x] Reproduce failed, empty, malformed, public, and explicit PRIVATE visibility responses through a fake GitHub CLI.
  - [x] Require explicit private visibility before activating a data repository or allowing subsequent publication.
  - [x] Provide an actionable verification error and cover retry after a transient failure.
- Dependencies: none.
- Acceptance: unknown or non-private visibility cannot activate the repository or reach a push.
  A verified private repository still completes setup.
- Required checks: `tests/test-bootstrap.sh`, `tests/test-cli.sh`; assert command calls and unchanged local setup on failure.
- Estimate and risk: 2–4 hours; authentication and network failures must remain distinguishable from public visibility.
- State: Completed.
- Evidence: `bin/lib/repo.sh` adds `repo_verify_private` and fails closed on
  command failure, empty output, or any non-PRIVATE value; existing-public,
  empty, malformed, and failing visibility leave remote, HEAD, and tree
  untouched and log no push. New-remote post-create verification leaves no
  repo directory on failure; a transient failure retries as PRIVATE and
  activates. `tests/test-bootstrap.sh` grows from 50 to 89 checks with
  existing, new-remote, and retry coverage. `tests/test-cli.sh` passes 361
  checks. `tests/gate.sh G2` passes 12 checks. `docs/getting-started.md`
  states the explicit PRIVATE requirement and retry. `manifest.json` 0.42.1
  -> 0.42.2.
- Changed files: `bin/lib/repo.sh`, `tests/test-bootstrap.sh`,
  `docs/getting-started.md`, `manifest.json`, `docs/TASKS.md`,
  `docs/ROADMAP.md`.
- Commit: this commit.

### F07. Enforce secret and backup permissions

- Finding and scope: R05; regular and privileged secret restore paths in `bin/lib/crypto.sh`.
- Tasks:
  - [x] Cover identical-content and changed-content restores from a mode-644 live secret.
  - [x] Enforce mode 600 for the resulting secret and every newly created plaintext backup.
  - [x] Preserve intended ownership and handle permission failures explicitly.
- Dependencies: none.
- Acceptance: both restore paths leave protected files at mode 600; failed protection cannot report successful restoration.
- Required checks: `tests/test-crypto.sh`, `tests/test-restore-secrets.sh`, `tests/test-leaks.sh`;
  exercise privileged operations through an isolated stub or container.
- Estimate and risk: 2–4 hours; preserve rollback behavior and avoid disclosing plaintext in diagnostics.
- State: Completed.
- Evidence: `vault_restore_entry` and `vault_restore_entry_privileged` now
  chmod 600 an identical-content live file and every new `.bak.<epoch>`
  backup, verify mode 600, and fail closed when chmod, chown, or verification
  fails. `tests/test-restore-secrets.sh` grows to 60 checks with HOME and
  privileged identical/backup cases plus a chmod-failure case.
  `tests/test-crypto.sh` passes 97 checks. `tests/test-leaks.sh` passes 18
  checks. `tests/gate.sh G6` passes 16 checks. `README.md` states restored
  secrets and backups stay at mode 600. `manifest.json` 0.42.2 -> 0.42.3.
- Changed files: `bin/lib/crypto.sh`, `tests/test-restore-secrets.sh`,
  `README.md`, `manifest.json`, `docs/TASKS.md`, `docs/ROADMAP.md`.
- Commit: this commit.

### F08. Preserve the effective scope of encrypted secrets

- Finding and scope: R03; scope lookup, vault save, and registry projection.
- Tasks:
  - [x] Reproduce Off becoming Shared after a changed secret is saved.
  - [x] Resolve secret scope from its authoritative vault metadata throughout save and status.
  - [x] Preserve Off across single, bulk, and automatic saves and restores.
- Dependencies: none.
- Acceptance: an Off secret remains Off and its stored content does not change during ordinary saves.
  Shared secrets remain saveable; unsupported profile scope stays rejected.
- Required checks: `tests/test-crypto.sh`, `tests/test-bulk-vault.sh`, `tests/test-state.sh`;
  assert scope, ciphertext preservation, and matching CLI/panel counts.
- Estimate and risk: 3–5 hours; update the existing contract without a new metadata format.
- State: Completed.
- Evidence: `vault_save_entry` keeps the existing vault index scope for saved
  secrets and rejects profile; `vault_save_all` skips Off from the vault index
  so ciphertext stays unchanged; `core_scope` reads the old scope from the
  vault index for secrets. `tests/test-crypto.sh` passes 109 checks with Off
  preservation, ciphertext, registry/status agreement, single-save refusal,
  shared save, and profile rejection. `tests/test-bulk-vault.sh` passes 13
  checks. `tests/test-state.sh` passes 103 checks. `manifest.json` 0.42.3
  -> 0.42.4.
- Changed files: `bin/lib/crypto.sh`, `bin/lib/scopes.sh`,
  `tests/test-crypto.sh`, `manifest.json`, `docs/TASKS.md`,
  `docs/ROADMAP.md`.
- Commit: this commit.

### F09. Preserve unresolved incoming config changes

- Finding and scope: R02; incoming state in `bin/lib/incoming.sh` and its consumers.
- Tasks:
  - [x] Reproduce a config pull followed by an inventory-only or unchanged pull.
  - [x] Merge new incoming entries with unresolved entries instead of replacing the entire pending set.
  - [x] Remove markers only after a verified resolution, including existing explicit replacement actions.
- Dependencies: none.
- Acceptance: repeated pulls cannot make stale local content eligible for an ordinary overwrite.
  Resolved entries clear correctly; unrelated profiles do not acquire incoming markers.
- Required checks: `tests/test-save.sh`, `tests/test-state.sh`, `tests/test-journey.sh`;
  exercise two synthetic machines and interrupted or failed resolution.
- Estimate and risk: 4–6 hours; avoid permanent false conflicts when files already match.
- State: Completed.
- Evidence: `core_incoming` merges new rows with the existing file and prunes
  only rows whose copies now match (verified via registry and status verdict);
  inventory-only pulls preserve pending work and second config pulls add to it.
  Other-profile paths stay filtered. `tests/test-state.sh` passes 111 checks
  with merge, preserve, prune, and profile cases. `tests/test-save.sh`
  passes 75 checks. `tests/test-journey.sh` passes 76 checks with two machines.
  `manifest.json` 0.42.4 -> 0.42.5.
- Changed files: `bin/lib/incoming.sh`, `tests/test-state.sh`,
  `manifest.json`, `docs/TASKS.md`, `docs/ROADMAP.md`.
- Commit: this commit.

### F10. Detect incoming encrypted changes

- Finding and scope: discovery portion of R01; incoming and vault metadata.
- Tasks:
  - [x] Detect relevant vault changes across the before/after revisions of a pull.
  - [x] Identify changed secret IDs when the required metadata can be decrypted.
  - [x] Preserve an unresolved state when keys are unavailable or metadata cannot be read.
- Dependencies: F08 and F09.
- Acceptance: ciphertext changes cannot disappear from pending state.
  Keyless detection fails safely without revealing secret values or falsely marking the vault synchronized.
- Required checks: `tests/test-crypto.sh`, `tests/test-state.sh`, `tests/test-journey.sh`;
  include keyless pulls, metadata-only changes, blob changes, and consecutive pulls.
- Estimate and risk: 4–6 hours; encryption can change bytes without changing plaintext.
  Use existing local state and keep private metadata out of public logs.
- State: Completed.
- Evidence: `core_incoming` now resolves vault diffs to secret IDs via
  decrypted before/after indexes plus blob-to-ID mapping, and falls back to
  every tracked secret when metadata is unreadable. Merge/prune from F09 keeps
  unresolved rows across consecutive pulls and clears resolved ones.
  `tests/test-crypto.sh` passes 122 checks with blob, keyless, metadata-only,
  and consecutive cases. `tests/test-state.sh` passes 111 checks.
  `tests/test-journey.sh` passes 76 checks. `manifest.json` 0.42.5 -> 0.42.6.
- Changed files: `bin/lib/incoming.sh`, `tests/test-crypto.sh`,
  `manifest.json`, `docs/TASKS.md`, `docs/ROADMAP.md`.
- Commit: this commit.

### F11. Protect incoming secrets during save

- Finding and scope: mutation portion of R01; single, bulk, automatic, and transactional vault saves.
- Tasks:
  - [x] Reproduce stale local content overwriting a newer encrypted incoming copy.
  - [x] Apply the pending-state guard from F10 to every save entry point.
  - [x] Keep any explicit replacement action distinct and clear pending state only after success.
- Dependencies: F10.
- Acceptance: ordinary saves preserve incoming ciphertext and leave a useful unresolved result.
  A successful restore or explicit authorized replacement resolves the marker.
- Required checks: `tests/test-save.sh`, `tests/test-bulk-vault.sh`, `tests/test-transaction.sh`,
  and `tests/test-interruptions.sh`; assert content, markers, and transaction recovery.
- Estimate and risk: 4–6 hours; protect concurrent and interrupted operations without bypassing journals.
- State: Completed.
- Evidence: `vault_save_all` holds back incoming secrets whose copies differ,
  preserving ciphertext and reporting restore/save-file; explicit `snapshot_one`
  still overrules and resolves via copies-match plus next-pull prune.
  `tests/test-crypto.sh` passes 129 checks with hold-back, explicit, and
  resolution cases. `tests/test-save.sh` passes 75 checks.
  `tests/test-bulk-vault.sh` passes 13 checks. `tests/test-transaction.sh`
  passes 73 checks. `tests/test-interruptions.sh` passes 12 checks.
  `manifest.json` 0.42.6 -> 0.42.7.
- Changed files: `bin/lib/crypto.sh`, `tests/test-crypto.sh`,
  `manifest.json`, `docs/TASKS.md`, `docs/ROADMAP.md`.
- Commit: this commit.

### F12. Enforce repository readiness consistently

- Finding and scope: R07; schema validation, clone activation, and status.
- Tasks:
  - [x] Define the distinction between local setup in progress and a ready repository using the existing format.
  - [x] Validate every required readiness artifact before clone activation or normal data reads.
  - [x] Make status expose invalid or incomplete setup without synthesizing valid entries.
- Dependencies: none.
- Acceptance: missing recipient/index, corrupt schema, and incomplete staged clones cannot appear ready.
  Fresh setup still follows its valid initialization sequence. Invalid data remains unchanged.
- Required checks: `tests/test-schema.sh`, `tests/test-format.sh`, `tests/test-bootstrap.sh`,
  `tests/test-state.sh`; compare text, full JSON, brief status, and mutation gates.
- Estimate and risk: 4–6 hours; preserve the documented single format and intentional bootstrap sequence.
- State: Completed.
- Evidence: `require_ready_schema` now requires index/recipient when blobs
  exist (fresh and config-only repos stay valid); `core_status` returns
  `initialized:false` for invalid repos in text, full JSON, and brief without
  synthesized entries and without mutating data; clone rejects staged vaults
  without an index. `vault_save_entry` caches readiness before writing the
  blob so the transient blob-without-index state cannot misclassify a valid
  save. `tests/test-schema.sh` passes 38 checks, `tests/test-format.sh`
  passes, `tests/test-bootstrap.sh` passes 93 checks, `tests/test-state.sh`
  passes 119 checks, `tests/test-crypto.sh` passes 129 checks.
  `manifest.json` 0.42.7 -> 0.42.8.
- Changed files: `bin/lib/schema.sh`, `bin/lib/status.sh`, `bin/lib/crypto.sh`,
  `tests/test-schema.sh`, `tests/test-bootstrap.sh`, `tests/test-state.sh`,
  `manifest.json`, `docs/TASKS.md`, `docs/ROADMAP.md`.
- Commit: this commit.

### F13. Discover deleted secrets in history

- Finding and scope: discovery portion of R06; history path selection and deleted-entry listing.
- Tasks:
  - [ ] Include vault-only commits in relevant history queries.
  - [ ] Identify deleted secret entries from the appropriate historical index.
  - [ ] Report locked or unreadable history explicitly without exposing plaintext.
- Dependencies: none.
- Acceptance: a secret-only deletion appears as recoverable when decryptable.
  Missing keys produce an actionable limitation instead of an empty success result.
- Required checks: `tests/test-crypto.sh`, `tests/test-journey.sh`, `tests/test-leaks.sh`;
  cover mixed config/secret deletion, vault-only deletion, and unavailable historical keys.
- Estimate and risk: 3–5 hours; key rotation and Git history may limit recoverability.
- State: Pending.

### F14. Recover a secret-only deletion

- Finding and scope: mutation portion of R06; `core_recover`, vault recovery, and transactions.
- Tasks:
  - [ ] Route a vault-only recovery through the existing transaction even when no config path is selected.
  - [ ] Restore the relevant index entry and blob without replacing unrelated current vault entries.
  - [ ] Preserve preview, retry, and failed-push recovery behavior.
- Dependencies: F12 and F13.
- Acceptance: recovery of one deleted secret succeeds and preserves unrelated current data.
  Key or blob failures leave the repository unchanged and keep an actionable error.
- Required checks: `tests/test-crypto.sh`, `tests/test-journey.sh`, `tests/test-transaction.sh`,
  and `tests/test-interruptions.sh`; verify mixed and secret-only histories.
- Estimate and risk: 4–6 hours; do not imply that missing historical keys can be reconstructed.
- State: Pending.

## Important: complete and explain user operations

### F15. Retain independent Settings edits

- Finding and scope: R08; Settings debounce and save dispatch in `Panel.qml`.
- Tasks:
  - [ ] Reproduce two distinct setting edits inside the debounce interval in the real panel.
  - [ ] Coalesce repeated edits for one setting while retaining edits for other settings.
  - [ ] Define pending-edit behavior on tab changes, panel closure, and command failure.
- Dependencies: none.
- Acceptance: both distinct edits reach the controller once; repeated edits to one ID apply its final value.
  Navigation or failure cannot silently discard a pending edit.
- Required checks: `tests/qml-controller.sh`, `tests/test-settings-save.sh`, `tests/test-usability.sh`;
  add executable panel interaction coverage rather than source-text matching.
- Estimate and risk: 3–5 hours; preserve write ordering and avoid applying stale values after a reset.
- State: Pending.

### F16. Recover the controller after process startup failure

- Finding and scope: R09; process lifecycle in `ReplicantController.qml`.
- Tasks:
  - [ ] Reproduce a missing or non-executable CLI wrapper with a real Quickshell Process.
  - [ ] Settle a failed startup exactly once and advance or explicitly fail queued work.
  - [ ] Cover startup failure racing with cancellation and normal exit.
- Dependencies: none.
- Acceptance: no failed startup leaves a permanent current job or busy state.
  Each job gets one terminal result and a later valid command can run.
- Required checks: `tests/qml-controller.sh` plus a real-process integration probe;
  mocks alone cannot establish the runtime signal contract.
- Estimate and risk: 3–5 hours; verify the installed Process API before choosing the error hook.
- State: Pending.

### F17. Distinguish restored files from failed application

- Finding and scope: R17; restore results in `bin/lib/restore.sh`, CLI output, and panel feedback.
- Tasks:
  - [ ] Inject reload/apply failures after a successful file copy.
  - [ ] Report copied, applied, and failed states consistently for single-file and full restores.
  - [ ] Offer an apply retry that does not repeat the file overwrite or create misleading success feedback.
- Dependencies: none.
- Acceptance: apply failure is visible and actionable; backups remain available.
  Existing successful restores and dry runs preserve their contract.
- Required checks: `tests/test-journey.sh`, `tests/test-cli.sh`, `tests/test-settings.sh`,
  and `tests/test-usability.sh`; stub failing reload commands and verify returned results.
- Estimate and risk: 4–6 hours; coordinate exit status and JSON/UI handling without hiding partial success.
- State: Pending.

### F18. Keep visible search text synchronized

- Finding and scope: R12; `components/FilterBar.qml` and panel search state.
- Tasks:
  - [ ] Reproduce programmatic clear and replacement while a search field has visible text.
  - [ ] Use one search-state contract for keyboard input and programmatic navigation.
- Dependencies: none.
- Acceptance: field text and effective filter agree after typing, clear, tab switching, and chip navigation.
  Programmatic updates do not create feedback loops or erase active typing.
- Required checks: `tests/test-usability.sh`, executable QML interaction tests, and applicable G7 screenshots.
- Estimate and risk: 2–3 hours; check focus and cursor behavior for both Configs and Settings consumers.
- State: Pending.

### F19. Reveal the owning file in Configs

- Finding and scope: R11; Settings-to-Configs navigation in `Panel.qml`.
- Tasks:
  - [ ] Reproduce the jump with an incompatible search, collapsed category, and offscreen target.
  - [ ] Reveal the category and row, reconcile blocking filters, scroll, and transfer focus.
- Dependencies: F18.
- Acceptance: Show owning file exposes the intended row without manual filter clearing or extra searching.
  Missing ownership metadata gives an explicit result.
- Required checks: `tests/test-usability.sh` and executable QML interaction coverage for each blocking state.
- Estimate and risk: 2–4 hours; avoid clearing unrelated user state when it does not hide the target.
- State: Pending.

### F20. Offer the correct key action

- Finding and scope: R13; locked-vault guidance and `components/StatusCard.qml`.
- Tasks:
  - [ ] Distinguish a fresh setup from an existing encrypted vault without its identity.
  - [ ] Offer creation only for a valid initial setup; offer import guidance for an existing vault.
- Dependencies: F12.
- Acceptance: a second machine with existing blobs cannot be sent to an impossible key-creation flow.
  Locked and corrupt states remain distinct, and no secret key appears in panel output.
- Required checks: `tests/test-bootstrap.sh`, `tests/test-crypto.sh`, `tests/test-usability.sh`,
  and the locked G7 fixture.
- Estimate and risk: 2–4 hours; use existing encryption state instead of inferring state from a counter.
- State: Pending.

### F21. Verify and correct modal keyboard routing

- Finding and scope: R10; panel key routing and the installed confirmation dialog interface.
- Tasks:
  - [ ] Send real key events to a focused confirmation dialog and record the affected route.
  - [ ] If the defect reproduces, give the modal exclusive navigation and activation handling.
  - [ ] Verify cancel, confirm, background isolation, and focus restoration for relevant overlays.
- Dependencies: none.
- Acceptance: arrows, Enter, and Escape affect only the active dialog.
  If the full route is correct, record that result and narrow or close the hypothesis without speculative changes.
- Required checks: executable QML key-event tests with the actual dialog contract;
  retain a real desktop keyboard check in F02.
- Estimate and risk: 3–5 hours; the prior signal probe alone does not prove physical-key behavior.
- State: Verification first. Runtime availability can block the remaining evidence, not unrelated phases.

### F22. Align setup and command documentation

- Finding and scope: R16; README, getting-started instructions, CLI help, and affected technical docs.
- Tasks:
  - [ ] Document each important command's preview/apply behavior from verified code and tests.
  - [ ] Correct CLI path setup and distinguish key creation from key import on another machine.
  - [ ] State live-file, backup, journal, cache, and key write locations and existing retention/removal behavior.
  - [ ] Align pending-change, restore-apply, invalid-repository, and recovery explanations with completed phases.
- Dependencies: F06 through F20 and the recorded F21 outcome.
- Acceptance: setup examples work in a synthetic home; no blanket dry-run or write-boundary claim contradicts behavior.
  Unavailable live checks remain explicitly pending.
- Required checks: documentation/CLI cross-check, safe bootstrap examples, `tests/test-cli.sh`,
  secret scan, local link validation, and `git diff --check`.
- Estimate and risk: 3–5 hours; describe existing behavior, without inventing cleanup or retention capabilities.
- State: Pending. Correct changed-command documentation within each earlier phase as well.

## Optimization: make evidence representative

### F23. Make validation gates explicit and executable

- Finding and scope: R15; test runner, QML harness, Docker test image, and CI workflow.
- Tasks:
  - [ ] Separate passed, failed, and skipped checks in the test runner and CI summary.
  - [ ] Execute ShellCheck and resolve findings or justify narrowly scoped suppressions.
  - [ ] Require an actual Qt test run where QML behavior is claimed; retain source checks only as static checks.
  - [ ] Define a required real Omarchy validation job using a documented disposable runner contract.
- Dependencies: F15, F16, and the recorded F21 outcome establish the runtime cases to retain.
- Acceptance: missing runtimes cannot produce an unqualified full-validation pass.
  The real job must execute plugin validation, lint, and required runtime probes before being reported complete.
- Required checks: `tests/run-all.sh` with and without desktop dependencies, ShellCheck,
  QML runner absence/failure, and the real desktop job when its environment is available.
- Estimate and risk: 4–6 hours for gate changes; external runner provisioning is a separate dependency.
  If unavailable, retain a blocked integration result and F02, without pretending the container proves it.
- State: Pending.

### F24. Benchmark initialized repositories

- Finding and scope: measurement portion of R14; status benchmarks and synthetic fixtures.
- Tasks:
  - [ ] Add representative initialized fixtures with shared/profile configs, vault state, and pending work.
  - [ ] Measure cold and warm full/deferred/brief status over documented repeated samples.
  - [ ] Report median and tail latency with fixture size, runtime versions, and cache conditions.
  - [ ] Profile the dominant work and set justified budgets from the resulting baseline.
- Dependencies: F08 through F12, so the benchmark preserves the corrected state semantics.
- Acceptance: the gate exercises real status work and detects a deliberate slowdown.
  It reports all samples or sufficient artifacts and never substitutes the fastest empty-state result.
- Required checks: `tests/bench-status.sh --check`, `tests/bench-settings.sh`,
  fixture status assertions, and a controlled budget-failure run.
- Estimate and risk: 4–6 hours; isolate benchmark data and distinguish host noise from a product regression.
- State: Pending.

### F25. Improve one measured status bottleneck

- Finding and scope: optimization portion of R14; the dominant path identified by F24.
- Tasks:
  - [ ] Select one bounded repeated scan, subprocess cost, or cache invalidation issue from the profile.
  - [ ] Make the smallest change and compare the same fixtures before and after.
  - [ ] Verify invalidation after save, pull, scope change, key change, and profile change.
- Dependencies: F24 must identify a material bottleneck and a justified target.
- Acceptance: the selected budget improves without changing status correctness or hiding incoming/locked states.
  If no bounded improvement is justified, record the measurements and defer code changes.
- Required checks: F24 benchmark matrix, `tests/test-state.sh`, `tests/test-save.sh`,
  `tests/test-crypto.sh`, and the full suite.
- Estimate and risk: one 4–6 hour session after profiling; split larger work before implementation.
  Do not replace the architecture or add persistent caches without an invalidation contract.
- State: Conditional on F24 evidence.

## Evolution: optional product improvement

### F26. Add direct Restore section navigation

- Basis and scope: the completed F05 proposal; `components/RestoreTab.qml` and panel navigation.
- Tasks:
  - [ ] Confirm that the six-card scrolling journey still causes the observed navigation cost.
  - [ ] If selected, add a compact section picker using existing panel components.
  - [ ] Preserve contextual actions, hidden-card behavior, and return focus from previews.
- Dependencies: F05, F18 through F21, and explicit selection of this optional improvement.
- Acceptance: any visible Restore section is reachable with one section-selection action,
  followed by one activation action. No new top-level tab or duplicate business logic is required.
- Required checks: `tests/test-usability.sh`, QML keyboard interactions, G7 navigation/screenshots,
  and human review in a disposable session.
- Estimate and risk: 3–5 hours plus human review; this is a proposed UX improvement, not a proven data defect.
- State: Optional proposal. Do not include automatically when executing the confirmed correction plan.

## Product direction and completion criteria

Keep the four existing top-level tabs. Overview summarizes actionable state and machine context.
Configs owns saved files, scope, and file history. Settings owns live edits and links to visible owning files.
Restore owns preview, application, recovery, and software reconciliation from a chosen machine.

Required organization changes make existing destinations visible and state labels accurate.
A new Machines tab, broad component rewrite, or new service architecture has no demonstrated need.
F26 records the existing navigation proposal; its implementation remains optional and unselected.

The correction plan is complete only when each confirmed finding has a maintained regression,
the required checks pass on the tested commit, and documentation matches the resulting behavior.
Record F21's final conclusion separately. Production readiness also requires F02 and the real-runtime
evidence from F23; automated unit and offscreen passes alone do not establish that readiness.

## Planning verification (2026-10-22)

This update changes only `TASKS.md`, `TASKS-HISTORY.md`, and `ROADMAP.md`.

- Passed: 22 open or proposed phase IDs, including F02; all dependency references exist and have no cycles.
- Passed: all 17 audit findings map to phases; all 11 local document links and their anchors resolve.
- Passed: the archived prior plan preserves its text, with heading levels adjusted;
  the existing history body remains unchanged.
- Passed: `git diff --check` and `bash tests/check-version-bump.sh --base HEAD`.
  No shipped code changed, so no version increase is required.
- Application suites were not rerun for this documentation-only plan.
  Prior audit results are recorded above. No implementation phase or commit was completed.

## Next action

- Next phase: **F13**, secret deletion discovery.
- Resume command: `$taskflow run F13`.
- Recommended effort: **medium**.
- F02 remains blocked independently; do not wait for its environment before addressing confirmed data risks.
