# Settings hardening plan

Status: implemented for automated release checks. Disposable-session verification remains pending.

Baseline: version 0.39.0, commit `7bbabcb`.

## Objective

Make settings edits preserve existing values, detect validation failures, and report defaults accurately.
Then reduce refresh cost and support precise decimal input.

Keep the 47 setting identifiers, repository format, scopes, and selective save behavior unchanged.
Use temporary fixtures and local remotes for automated verification.
Keep private data and machine configuration outside those fixtures untouched.

## Review evidence

The review reproduced four defects in temporary fixtures:

| Defect | Trigger | Observed result |
| --- | --- | --- |
| Lost string types | Set a Lua enum, then change another setting in that file. | The writer removes quotes from the earlier enum. |
| Missed configuration errors | Preserve an existing error while introducing another error. | The operation succeeds and retains the changed file. |
| Incorrect defaults | Query a setting without a known default. | The reader treats the active session value as its default. |
| Inconsistent marker recognition | Indent both managed block markers, then write a setting. | The writer appends a second block. |

The review also found that the Lua reader treats multiline comments as configuration.
Include this existing limitation in parser regression coverage.

Existing checks passed: Settings 296, settings save 35, and QML 68.
Plugin validation and QML lint also passed.
These results do not cover the reproduced defects or validate a live Hyprland reload.

## Phase 1: Establish regression coverage

Primary files: `tests/test-settings.sh`, `tests/test-settings-save.sh`, and dedicated Lua fixtures under `tests/fixtures/`.

- [x] Add consecutive edits for keyboard layout, acceleration profile, and window layout.
- [x] Check both the generated literals and their types through a Lua interpreter with a fake `hl.config` callback.
- [x] Execute only generated test fixtures through that interpreter, never arbitrary user configuration.
- [x] Declare the interpreter as a test dependency in `tests/Dockerfile`.
- [x] Cover clean errors, unchanged errors, new errors, mixed old and new errors, and failed error queries.
- [x] Cover canonical, indented, duplicated, reversed, and incomplete markers.
- [x] Cover multiline comments and quoted content that contains comment delimiters or braces.
- [x] Cover known defaults and unknown defaults independently from active session values.
- [x] Assert that rejected edits preserve file bytes and leave the repository commit unchanged.

Acceptance: each reproduced defect has a regression test that fails on the baseline for the expected reason.
Use unique temporary paths for every new fixture.

## Phase 2: Correct Lua writes and rollback

Primary files: `bin/lib/settings.sh` and, if needed, `bin/lib/backups.sh`.

- [x] Preserve string, boolean, and numeric types when the writer reconstructs a managed block.
- [x] Use the settings registry as the authority for supported routes and their types.
- [x] Reject unsupported managed content instead of silently discarding it.
- [x] Use one marker recognition rule for validation, extraction, and replacement.
- [x] Reject noncanonical or damaged markers before any write.
- [x] Preserve manual content and add only the separator required before a new block.
- [x] Handle comments and strings without evaluating source Lua.
- [x] Compare every error after reload against the complete set captured before the write.
- [x] Treat failed validation queries as failures, not empty error lists.
- [x] Bound reload and validation commands with explicit timeouts.
- [x] Require a successful backup before replacement and retain its exact path for rollback.
- [x] Report rollback failures explicitly instead of claiming that restoration succeeded.
- [x] Prevent save or push when application or validation fails.

Acceptance: consecutive edits preserve earlier values and types.
Any new configuration error causes failure and restores the exact prior file.
Unchanged pre-existing errors remain permissible.
Rejected blocks remain byte-identical, and repeated valid writes remain idempotent.

## Phase 3: Separate defaults from active values

Primary files: `bin/lib/settings.sh` and the existing reset controls in `components/SettingRow.qml`, if presentation needs adjustment.

- [x] Resolve defaults from installed default files or an explicit registry fallback.
- [x] Remove active session values as a fallback for default resolution.
- [x] Keep active session values available for current-value display and override notices.
- [x] Normalize known default values to the registry type before comparison or reset.
- [x] Represent an unknown default with an empty `default_value` and `can_revert_default: false`.
- [x] Keep the setting editable when its default is unknown.
- [x] Make a CLI reset to an unknown default fail clearly before any write.
- [x] Preserve reset from the saved repository value.

Acceptance: changing the active value cannot change its reported default.
Known defaults reset correctly; unknown defaults never create a false reset action.

Release checkpoint: ship phases 1 through 3 as a corrective release before the performance and control improvements.

## Phase 4: Measure and reduce refresh cost

Primary files: `bin/lib/settings.sh`, `tests/bench-status.sh`, and benchmark fixtures.

The review measured approximately 0.8 seconds for 24 settings and 3.8 seconds for 47 settings in a synthetic fixture.
These measurements used simulated dependencies and do not represent complete panel latency.
The existing budget check exits through the uninitialized repository path, so it does not exercise settings construction.

- [x] Add an initialized repository fixture with all 47 settings, managed blocks, defaults, and saved copies.
- [x] Measure settings construction, full status, and brief status separately.
- [x] Record a baseline after the corrective release, using the same fixture and environment as the optimized candidate.
- [x] Parse each Lua file once per refresh, including its managed block and manual content.
- [x] Reuse each option query within that refresh and preserve cache invalidation after writes and rollback.
- [x] Keep the cache local to a refresh; add no persistent store or polling loop.
- [x] Assert unchanged JSON values, notices, defaults, and scope behavior after the optimization.
- [x] Report sample count and median latency rather than relying only on the fastest sample.

Acceptance: output parity passes, and settings construction improves by at least 50 percent against the corrected baseline.
Treat this reduction as a target to verify, not an achieved result.
Set an absolute CI budget from the initialized fixture measurements and record its environment.

## Phase 5: Add precise decimal controls

Primary files: `components/SettingRow.qml` and QML interaction tests.

- [x] Add decimal text input beside the existing slider.
- [x] Use registry bounds and steps for validation and adjustment.
- [x] Preserve the CLI's accepted decimal precision; do not add an undocumented step restriction.
- [x] Submit a changed value on Enter or focus loss, through the existing controller queue.
- [x] Submit no command for invalid input, unchanged values, or Escape cancellation.
- [x] Prevent duplicate submissions when Enter is followed by focus loss.
- [x] Apply the same busy, unavailable, and dependency rules to both controls.
- [x] Verify focus order, keyboard input, value labels, and layout at supported interface scales.

Acceptance: users can enter values such as `0.4`, `1.25`, and `-0.5` where permitted by the setting.
The control preserves that value and emits one operation per accepted edit.

## Release verification

- [ ] Run the relevant regression suites after each phase.
- [ ] Run `./tests/run-all.sh` for each release candidate.
- [ ] Run `omarchy plugin validate .` and lint every changed QML file.
- [ ] Run `tests/check-version-bump.sh --base <release-base>` against the actual release base.
- [ ] Exercise CLI set and reset with shared, profile, and off scopes in isolated repositories.
- [ ] Verify save failure and rejected push reporting without losing the applied local state.
- [ ] Test installation, disable, enable, shell restart, and removal in a disposable Omarchy session.
- [ ] Validate real reloads, configuration errors, dependent controls, and decimal input in that session.
- [ ] Record exact commands, results, unresolved failures, and benchmark samples before release.
- [ ] Update task completion and the roadmap with that evidence.

The corrective release targets `0.39.1`; the performance and control release targets `0.40.0`.
If another release lands first, choose higher versions according to `CONTRIBUTING.md`.
Keep every shipped change and its version bump in the same pull request.

Do not run the installation lifecycle against the user's active plugin as part of automated tests.
If a disposable session is unavailable, keep live verification explicitly pending.
Do not replace screenshot baselines solely to make an unexplained comparison failure pass.

## Implementation record, 2026-10-19

Automated checks cover the Lua parser, rollback, defaults, decimal control
contract, controller QML, version bump, plugin validation, and QML lint.
`tests/bench-settings.sh` uses five initialized samples and enforces an
8,000 ms median budget. The local sample measured 3,965 ms.

The local G7 screenshot runner reports eight fixture mismatches in its
offscreen Omarchy session. The same failure affects every view and does not
identify a Settings-specific change. The release container does not include
Omarchy, so it skips that machine-only runner. Do not update those fixtures
until a disposable Omarchy session explains the renderer difference.

The remaining required check is the install, enable, restart, and removal
lifecycle in a disposable Omarchy session. Do not run it against the active
user plugin.
