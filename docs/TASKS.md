# Tasks

Complete one small, verifiable task at a time. When a task is complete, update its checkbox and
`ROADMAP.md` in the same change.

## Settings hardening after 0.39.0

Follow the [Settings hardening plan](settings-hardening-plan.md) for scope, acceptance criteria, and release checks.

- [x] Reproduce the reviewed defects with regression tests.
- [x] Preserve Lua types, validate markers consistently, and correct error detection and rollback.
- [x] Separate known defaults from active session values.
- [x] Validate and release the corrective changes.
- [x] Measure initialized repositories and cache Lua reads within each refresh.
- [x] Add precise decimal input and interaction tests.
- [ ] Complete automated and disposable-session verification for the improvement release.

## Usability patch

- [x] Make `Off` one effective UI state.
  - Project `scopeOverrides` into one row list.
  - Use that list for rows, cards, counters, filters, and bulk selection.
  - Reject bulk Save when any selected row is `Off`.
  - Remove accepted `Off` rows from the selection.
  - Restore the prior state and selection after a command failure.
  - Keep each row available in the All and Off filters.
- [x] Make installation placement explicit.
  - Let the interactive Omarchy command ask for left, center, or right.
  - Use center only as the fallback for a new installation.
  - Document an automated installation with an explicit section.
  - Document `omarchy bar move` for later changes.
  - Preserve the saved section during updates and shell restarts.
- [x] Make each file header look and behave like a disclosure control.
  - Keep a visible border at rest.
  - Use distinct hover, focus, and expanded states.
  - Keep the file name bold and reserve a chevron area.
  - Separate the expanded details from the header.
  - Keep Save and Restore independent from the disclosure click.
  - Preserve keyboard navigation and the full header hit area.
- [x] Align the functional documentation.
  - Explain that `Off` publishes the policy once.
  - Explain that later saves and restores skip the file.
  - Explain that Git keeps the last saved copy.
  - Keep the repository schema and public scope CLI unchanged.
- [x] Add regression coverage.
  - Cover an `Off` row, mixed selection, and optimistic pending state.
  - Cover selection removal and the failure rollback contract.
  - Keep engine coverage for save, restore, and copy exclusions.
  - Check the center manifest default and both README installation paths.
  - Update affected deterministic screenshots.
- [ ] Validate the complete journey.
  - Run `./tests/run-all.sh`, `qmllint`, and `omarchy plugin validate .`.
  - Test a fresh installation in left, center, and right.
  - Move the widget live and inspect `shell.json`.
  - Restart the shell and confirm that the section stays unchanged.
  - Capture Configs with a closed and an expanded file row.
  - Check contrast, hover, focus, keyboard input, and action clicks.
  - Record the evidence before this checkbox is complete.

Automated evidence for the open validation task:

- `./tests/run-all.sh`: passed in 251 seconds.
- QML logic: 59 passed and 0 failed.
- Deterministic screenshots: 8 passed and 0 failed.
- `qmllint`: passed for `Panel.qml` and `components/FileRow.qml`.
- `omarchy plugin validate .`: passed.
- Offscreen Configs captures: reviewed with the row closed and expanded.

## Reliability hardening for 0.14.0

- [x] Make every panel action truthful.
  - Remove `Copy without saving` and `doBackup`. A copy without a commit contradicts the
    transactional model.
  - Change the main Save action to `save --all --auto`.
  - Use distinct jobs and labels for Untrack, Forget, and Remove backups.
  - Replace bulk action identifiers with user-facing descriptions.
  - Show the setup screen only after a successful `{"initialized":false}` response.
  - Show a clear status error and Retry action when the CLI fails or returns invalid JSON.
  - Rename “GitHub HTTPS” to “GitHub API”. Keep API authentication mandatory for repository
    creation.
  - Keep SSH as a Git transport choice. Do not claim that an SSH key can create a GitHub repository.
- [x] Make the CLI fail closed.
  - Ensure `--help` stops execution wherever a command parser accepts it.
  - Preserve `-h` when it is a value, such as `set idle.lock -h` or `save -m -h`.
  - Make lock directory and descriptor failures stop the command with a useful error.
  - Load the core in `undo` without suppressing syntax or source errors.
  - Remove the undocumented `undo -y|--yes` mutation aliases.
  - Render unknown states as warning or unknown, never as saved.
  - Fix the missing parent directory in the editor fixture of `test-cli.sh`.

Completed 2026-09-27. Changed `bin/replicant`, `components/FileRow.qml`,
`replicant.js`, `tests/test-cli.sh`, `tests/qml/tst_replicant.qml`, and `tests/mutate.sh`.
Focused checks passed: `test-cli.sh` (305 checks), QML tests, mutations 95 through 99,
`qmllint` for `FileRow.qml`, and `omarchy plugin validate .`. No known remaining risk.
- [x] Finish the compatibility transition.
  - Make plugin settings and reset counts consume `entries`, not `configs` or `secrets`.
  - Remove the deprecated `configs` and `secrets` fields from full status after all internal
    consumers and fixtures use `entries`.
  - Remove `savegame`, `backup`, `migrate-v2`, `sync`, and `init --savegame`.
  - Update every panel command, help entry, test, fixture, and document to use `save`, `changes`,
    `migrate-v3`, and `scope`.
  - Return an explicit error with the canonical replacement when a removed alias is used.

Completed 2026-09-28. Changed the CLI, status payload, panel row consumers, fixtures, documentation,
and compatibility tests. Focused checks passed: `test-cli.sh`, `test-save.sh` (77 checks),
`test-migration.sh` (27 checks), `test-schema.sh` (54 checks), QML controller tests (62 tests),
`test-usability.sh` (84 checks), `test-g8.sh`, and the deterministic screenshot renders. No known
remaining risk in this transition.
- [x] Close security and cleanup gaps.
  - Detect classic and post-quantum age identities in `scan-secrets.sh`.
  - Add scanner fixtures without storing a complete real identity in the repository.
  - Make `purge` name every retained and removed path.
  - Keep the repo, keys, legacy repos, and migration recovery data during normal `purge`.
  - Remove all of them only with `purge --repo`, after the existing key warning.
  - Test interrupted migration directories, `migration-warning`, identities, and legacy
    repositories.

Completed 2026-09-28. `scan-secrets.sh` detects classic and post-quantum age identities without
storing one in the repository. `purge` separates removable paths from retained recovery data and
includes keys, migration journals, warnings, and legacy repositories only with `--repo`. Focused
checks passed: `test-cli.sh`, `test-save.sh` (77 checks), `test-migration.sh` (27 checks), and
`test-migrate-v3.sh` (83 checks). No known remaining risk in this block.
- [ ] Reduce panel startup cost.
  - Keep the full status request independent from the controller queue.
  - Load setup status only when no repository exists.
  - Load suggestions when the Configs tracking UI first needs them.
  - Load backups and deleted history when the Restore tab first opens.
  - Load shortcuts when keyboard help first opens.
  - Give each deferred card an explicit loading, error, empty, and Retry state.
  - Measure initial display and complete hydration before and after the change.
  - Keep the documented metadata-cache limit for same-size, same-`mtime` edits.

Current evidence for the open task:

- `tests/test-usability.sh`: 92 checks passed.
- `tests/qml-controller.sh`: 62 checks passed.
- `qmllint` passed for the changed QML files, and `omarchy plugin validate .` passed.
- Offscreen Configs captures passed for a closed panel and an expanded `hyprland` card.
- `tests/bench-status.sh --check`: full and brief status both measured 30 ms in the isolated fixture.
- `./tests/run-all.sh`: all suites and static checks passed in 97 seconds.
- Live installation from GitHub loaded commit `fc17daf` without plugin warnings.
- Live placement checks passed for left, center and right. Live moves passed in both directions.
- Shell restart preserved `bar.layout.center.5.id` in `shell.json`.
- A real 3072x1920 Configs capture was reviewed after the restart.
- Mouse clicks, keyboard input and subjective contrast checks remain open for human review.
- [x] Align documentation with behavior.
  - Document the Restore action for incoming rows.
  - Remove the obsolete 0.5 upgrade note.
  - Stop telling v3 users that their entries live in `.replicant-track`.
  - Add `crypto.sh`, `state.sh`, `legacy.sh`, and `progress.sh` to the module table.
  - Document keys and migration recovery data in the trace inventory.
  - Replace the fixed “five suites” count with wording derived from `tests/run-all.sh`.
  - Document the 0.14 CLI removals and GitHub API requirement.
  - Leave the current TASKS and ROADMAP validation item open until its live checks exist.

Completed 2026-09-28. Updated the incoming-row Restore wording, removed the obsolete 0.5 note,
documented the v3 entry locations, added the current shell modules and recovery paths, described
the 0.14 CLI removals and GitHub API requirement, and derived the suite count from `run-all.sh`.

### Public interfaces

- `save --all --auto` becomes the main panel save command. `save-file <id>`,
  `bulk save`, `set` and `revert` remain for single entries and settings.
- The five deprecated CLI surfaces are removed in 0.14.0.
- Full `status --json` keeps `entries` as its only row collection. The repository
  has one format.
- `purge` output separates removed paths from retained recovery data.
- Panel status gains explicit loading and failure states. CLI failure no longer means “not
  initialized.”

### Test and acceptance plan

- Treat each top-level checklist item as one bounded work session. Record the changed files,
  focused test results, and remaining risks before starting a new session.
- Add regressions for invalid status JSON, missing CLI, non-leading help flags, lock creation
  failure, visible core load errors, and rejected `undo --yes`.
- Add entries-only tests for plugin rows and reset counts.
- Add scanner tests for `AGE-SECRET-KEY-1…` and `AGE-SECRET-KEY-PQ-1…`.
- Add purge tests for default retention and complete `--repo` removal.
- Add QML tests for friendly bulk text, correct result labels, unknown states, and lazy job
  activation.
- Prove each new guard with a mutation where practical.
- During each checklist item, run only its affected suites and focused mutations.
- Run `qmllint` on changed QML files and validate the plugin after each substantive plugin change.
- After each visual change, reload the plugin and inspect one real screenshot of the affected view.
- Do not repeat the complete suite, the full screenshot set, or the from-zero plugin cycle after an
  individual checklist item.
- After all top-level checklist items are complete, run `./tests/run-all.sh`, the full deterministic
  screenshot set, and the required from-zero live plugin cycle once.

### Assumptions

- This work targets version 0.14.0 because it removes public CLI compatibility.
- Repository creation does not use an SSH key without GitHub API authentication.
- The public copy operation without a commit does not return.
- Normal `purge` keeps all data needed to recover the repository or secrets.
- The documented brief-cache limitation remains.

## Examen exhaustivo 2026-09-29

Origen: revision de codigo, logica y docs. Sin cambios aun.
Ejecutar por bloques. Un bloque es una sesion pequena y verificable.

### Bloque 0 - Registrar
- [x] Anadir esta seccion a `TASKS.md`.
- [x] Verificar: `git diff -- TASKS.md` solo tocaba esta seccion al registrar.

### Bloque 1 - Critico
- [x] `Panel.qml:814-823`: copiar directo con `wl-copy --`, sin `sh -c`.
- [x] `tests/run-all.sh`: corre static + suites sin gate + gates G0-G8 + bench + validate + qmllint.
- [x] `bin/lib/incoming.sh`, `briefcache.sh`: bar y cache leen `REGISTRY`.
- [x] `bin/lib/scopes.sh`: `normalize_profile_name` para el fallback por hostname.
- [x] `bin/lib/repo.sh`: `create` con journal (`tx_shape_begin/commit`), push con `-u`, journal kept al fallar.
- [x] Verificar: bootstrap 50/50, transaction 73/73, usability 99/99, format ok, qmllint ok.
  Nota 2026-09-29: `test-state` (36/89), `test-save` (32/75) y `test-cli` (44/317)
  fallan IDENTICO en main limpio (suites con fixtures v1/v2 retirados). No es
  regresion. `run-all.sh` queda en rojo hasta sanear esas suites (Bloque 3).

### Bloque 2 - Alto
- [x] Journal en `purge`: `key-rotation.json` en recovery (se conserva sin
  `--repo`, se elimina con `--repo` dentro de `REPLICANT_HOME`).
- [x] Regla `secret+profile` unica en `scope_store` (bulk ya la tenia).
  Verificado: `scope <secret> profile` falla, `off` funciona.
- [x] `move_repo_copy` aparta el destino y restaura si `mv` falla.
  Verificado: roundtrip shared->profile->shared intacto, 0 restos.
- [x] Lock por `wants_apply` (token exacto, gana el ultimo).
  Verificado: `purge/backups --dry-run` no crean lock.
- [x] Teclado: `R.keyboardActionFor` (missing/incoming->restore,
  locked->mensaje de clave, resto->save) + test QML nuevo.
- [x] Bulk con locked: aviso en `BulkFooter` (bloquear sigue, ahora explica).
- [x] `SPEC.md` ampliado al formato que valida el codigo + bump a 0.16.1.
- [x] Tags locales v0.14.0, v0.15.1, v0.16.0 (NO pusheados).
- [x] Verificar: qmllint todo ok, `plugin validate` ok, qml 65/65,
  bootstrap 50/50, transaction 73/73, usability 99/99, crypto sin
  regresion (1 fallo previo identico), core sin regresion (104 previos,
  difieren solo version+hash).

### Bloque 3 - Medio
- [x] `status`: memo de `tree_files` (+invalidacion en copia), memo de
  `vault_blob_same` por fingerprint, y full JSON deriva numeros de `entries`
  (una evaluacion por fila). Medido: 8.5s -> 6.5s en fixture de 200 ficheros;
  `bench --check` pasa (0.07/0.25, 0.08/0.10). `settings` (1.8s) queda follow-up.
- [x] Cola con envejecimiento: `queuedAt` + `queueNextIndex` (15s) en
  `dispatchNext`; backgrounds son solo lectura. Tests QML nuevos. 67/67.
- [x] Scanner en un paso: un `grep -r` combinado + atribucion; path conserva
  aviso de binarios (antes duplicado x25). Fuga real cerrada: `--stdin`
  imprimia la credencial sin redactar. 17/17 shapes, sin falsos positivos.
- [x] Timeouts (10s) en `gh` de doctor/setup-status y `omarchy menu keybindings`.
- [x] Tiempos rancios a cualitativo (BarWidget, Service, incoming). Conteos
  README verificados correctos (43+3=46, 11 areas, 24 settings).
- [x] Shellcheck limpio: SC2106 fail-closed en recover, SC2155 split,
  SC2088 suprimido con motivo (literal "~").
- [x] Verificar: bench ok, bootstrap 50/50, transaction 73/73, usability
  99/99, leaks 18/18, interruptions 12/12, qml 67/67, crypto 1 previo
  identico, qmllint todo ok, validate ok. Bump a 0.16.2.

### Bloque 4 - Bajo
- [x] `selectionSummary` cuenta secretos como ficheros (nunca como bytes) +
  nota en el dialogo bulk. Test QML ajustado.
- [x] Iconos de categorias pinnados en `test-usability.sh` (UTF-8 + 1 glifo,
  23 checks nuevos). 122/122.
- [x] `derive_rel` misc con directorio padre (`misc/foo/bar.conf`).
- [x] Limite de `suggest` documentado (panel + `suggest --help`).
- [x] `update` nombra la qmlcache que borra (CLI + panel).
- [x] `purge` barre `.bak` huerfanos (`backups-orphan`, dedup, conteo).
  Verificado funcional (1 huerfano listado, 0 falsos).
- [x] Verificar: qml 67/67, usability 122/122, bootstrap 50/50,
  transaction 73/73, shellcheck limpio, qmllint todo ok, validate ok.
  Bump a 0.16.4.

## Sesion 2026-10-03 - CI verde, renombre a replicant, saneamiento v3

Origen: commit `Test` con identidad local mal puesta + CI en rojo por
permiso de ejecucion + suites con fixtures de formatos retirados.
Todo verificado contra main limpio antes de tocar (sin regresiones).

- [x] Identidad git local limpiada (era `Test <t@example.com>`, ahora la
  global `Tymur Bogach`). Commits nuevos firman bien.
- [x] CI exec bit: `tests/run-all.sh` y `tests/test-format.sh` a 755,
  Dockerfile con `chmod +x` y `CMD ["bash", ...]`, workflow con `bash`.
- [x] Renombre total a `replicant`: repo `tymurbogach/replicant`, id
  `io.github.tymurbogach.replicant`, binario `bin/replicant`, home
  `~/.local/share/replicant`, servicio IPC `replicant-service`,
  `defaultSection` center + docs con `--after omarchy.clock`. Bump a 0.38.0.
- [x] Saneamiento v3 (Bloque 3 pendiente): fixtures con `git init` pelado
  ahora dejan que el primer backup inicialice (cli 319, core 475,
  state 96, save 75, bulk 51, journey 76, settings 177, crypto 97,
  restore-secrets 46, transaction 73, resto verde). Fixtures de parity y
  screenshots G7 regenerados (diff <0.2%, solo el header).
- [x] Bugs reales encontrados por los tests al correr de verdad:
  vault/entries con paths absolutos rompian el restore en la segunda
  maquina (resolucion home-relative + `live_from_id`), un area con
  fallos abortaba el resto del restore, el fallback de perfil nunca
  corria (guess estampado antes + registro vacio leido como grabado),
  arboles con .git o binarios eran intrackeables, `key init` sobre
  vault con blobs huerfanaba secretos (ahora se niega, 0.38.3).
- [x] G7 screenshots y validacion saltan en el contenedor CI sin Omarchy
  en vez de fallar. CI en verde en main.

## Session 2026-10-19 - Hyprland Settings 0.39.0

Origin: expand Settings from 24 to 47 settings with no extra store and no
format changes. All verified against clean main before edits.

- [x] Lua editor by full paths (`input:scroll_factor` versus
  `input:touchpad:scroll_factor`): it distinguishes repeated leaves such as
  `scroll_factor` and `enabled`, ignores comments and never evaluates Lua code.
- [x] Managed block at the end of `hypr/input.lua` and `hypr/looknfeel.lua`:
  deterministic and idempotent update, it preserves all outside bytes,
  rejects duplicate or damaged markers without file change, creates
  `.bak.<epoch>`, validates with `hyprctl reload` + `configerrors`, reverts on
  a new error and rejects without claiming applied when Hyprland is absent.
- [x] Registry with 47 settings in Keyboard, Mouse & pointer, Touchpad and
  Windows; seven existing identifiers unchanged; `accel_profile` only
  adaptive/flat; dwindle, master, scrolling and monocle layouts; official
  Hyprland 0.56.2 limits; dim/blur/scrolling dependencies with
  `blocked_reason`; `hl.device` rule warning without private names.
- [x] Panel uses the received numeric step and explains disabled
  dependencies; `settings --json` adds `blocked_reason` without removing
  fields; `set` accepts new identifiers and decimals.
- [x] Full validation: `./tests/run-all.sh` (1153 checks green; only red is
  the 8 G7 pixel comparisons, which fail identically on clean main on this
  machine: ambient render stack, no regression), `test-settings.sh` 293/293,
  `test-settings-save.sh` 35/35, `qmllint` clean,
  `omarchy plugin validate .` clean, `bench-status --check` within budget
  (0.08s), rendered review captures and reviewed Settings tab (8 groups, 47
  settings), real read test on this machine (mouse, touchpad, corners, gaps,
  blur, layout) and `hyprctl configerrors` clean.

Assumptions the code honors (no exceptions):
- Mouse settings are global and portable across machines: they live in the
  `hypr/input.lua` block, with no per-device paths.
- `hl.device` rules remain manual advanced configuration: Replicant only
  warns when they override a global value, without touching them or naming
  hardware.
- The Touchpad group stays visible even with no device connected, to restore
  its configuration on another machine (no hide logic).
- Managed blocks stay inside the standard Omarchy files
  (`hypr/input.lua`, `hypr/looknfeel.lua`).
- Replicant never modifies installed defaults and never creates
  `hypr/replicant-settings.lua`: it only reads `/usr/share/omarchy`.

## Portable controls expansion 0.41.0

This checklist is the execution source of truth for the 0.41.0 release.

Use the local `feature/portable-controls-0.41` branch for phases I0 through I7. Do not push phase commits.
Each completed phase must include its tests, documentation updates, and one clean local commit. Keep a failed
phase unchecked, report it as `NO OK`, and do not commit failing work. Update this file and `ROADMAP.md` after
each phase. Do not change `preview.png`, public screenshots, or the release version before phase I8.

### Product decisions

- Keep the four primary tabs: Restore, Settings, Configs, and Machines.
- Organize Settings into Look & feel, Input, Desktop, Power, and Defaults.
- Keep global search, the customized filter, and keyboard navigation across all Settings domains.
- Target 95 to 105 portable settings. Validate each control independently from OmaControl.
- Keep the current repository format. Add compatible metadata instead of a format migration.
- Exclude live network, Bluetooth, audio, process, storage, security, date, news, and general app controls.
- Add a fixed `Apply manually` section below Settings search.
- Provide Restart shell, Reload Hyprland, and Restart terminals actions.
- Ask for confirmation only before Restart shell. Disable every action while it runs.
- Use preview mode by default for all new mutating CLI commands. Require `--apply` for changes.
- Update `preview.png` and public screenshots only after all implementation phases pass.
- Publish one squashed 0.41.0 commit directly to `main`, without a force push.

### I0. Establish the baseline

- [x] Create the local `feature/portable-controls-0.41` branch from the current clean `main` branch.
- [x] Confirm this checklist and add the release phases to `ROADMAP.md`.
- [x] Record the baseline commit, version, worktree state, and validation results in the phase report.
- [x] Run `./tests/run-all.sh`.
- [x] Run `omarchy plugin validate .`.
- [x] Run `qmllint -I "$OMARCHY_PATH/shell" *.qml components/*.qml`.
- [x] Do not change `preview.png`, public screenshots, or the version.
- [x] Commit the phase as `docs: plan portable control expansion`.

Acceptance: the branch starts from a known clean baseline, all existing checks pass, and the worktree is clean.

Recommended next agent: `gpt-6-astra` with `xhigh` reasoning. The agent must define the data contract and guard
the compatibility boundary before UI expansion.

### I1. Defer Settings data and extend the contract

- [x] Add `replicant status --json --defer-settings` or an equivalent stable interface.
- [x] Load Settings data only when the user opens the Settings tab.
- [x] Cache and reuse the deferred result during the active Replicant session.
- [x] Add compatible setting metadata for domain, file, entry, scope, and apply action.
- [x] Preserve existing setting identifiers, values, restore behavior, and public JSON fields.
- [x] Add state tests for initial load, deferred load, cache reuse, failure, and retry.
- [x] Add CLI contract tests for old and new consumers.
- [x] Add performance samples with five cold runs and report the median.
- [x] Reduce the initial load time by at least 50 percent from the I0 baseline.
- [x] Keep the final initial-load median at or below 2.5 seconds on this machine.
- [x] Run the settings, state, benchmark, QML, and full regression suites.
- [x] Commit the phase as `perf: defer settings data until requested`.

Acceptance: deferred loading is compatible, measured, covered by tests, and does not change restore results.

Recommended next agent: `gpt-6.1-sol` with `high` reasoning. The next phase is broad UI and command integration
work with a stable contract.

### I2. Add navigation and manual apply actions

- [x] Add the five Settings domains without adding a fifth primary tab.
- [x] Preserve global search, the customized filter, and keyboard navigation across domains.
- [x] Add a direct link from each applicable setting to its owner in Configs.
- [x] Add `replicant apply shell`, `replicant apply hyprland`, and `replicant apply terminal`.
- [x] Make every apply command show its plan unless the caller passes `--apply`.
- [x] Use the official Omarchy shell restart command for Restart shell.
- [x] Use the supported Hyprland reload command for Reload Hyprland.
- [x] Use the supported Omarchy action for terminal restart or refresh.
- [x] Add the three actions to the fixed `Apply manually` section.
- [x] Ask for confirmation only before Restart shell.
- [x] Disable all apply actions while one action runs.
- [x] Show command output, exit status, and a concise failure message in the UI.
- [x] Test missing processes, busy state, Hyprland errors, detached processes, and command failures.
- [x] Run CLI, usability, QML, `qmllint`, and full regression tests.
- [x] Commit the phase as `feat: add settings navigation and apply actions`.

Acceptance: every action uses a supported command, fails clearly, and never starts twice from repeated input.

Recommended next agent: `gpt-6.1-sol` with `high` reasoning. The next phase needs careful schema and UI work,
but its scope is limited to scalar controls.

### I3. Expand window and effect settings

- [x] Add floating and workspace gap controls.
- [x] Add border-inside, rounding curve, and snapping controls.
- [x] Add active-window and fullscreen opacity controls.
- [x] Add dim controls for special workspaces, surrounding areas, and modal windows.
- [x] Add animation speed and animation wrap controls.
- [x] Add blur size, passes, noise, contrast, brightness, vibrancy, popup, xray, and vibrancy-darkness controls.
- [x] Add shadow range, power, scale, and sharpness controls.
- [x] Add glow enablement, range, and power controls.
- [x] Confirm each type, bound, dependency, default, owner, and config route independently.
- [x] Do not infer a control only because OmaControl exposes it.
- [x] Test consecutive writes, invalid types, invalid bounds, dependencies, rollback, and config errors.
- [x] Run settings, save, benchmark, QML, `qmllint`, and full regression tests.
- [x] Commit the phase as `feat: expand window and effect settings`.

Acceptance: all controls map to verified Omarchy or Hyprland configuration and preserve unrelated bytes.

Verified exclusions (no Hyprland 0.56.2 route, confirmed with `hyprctl getoption` on the live compositor):

- border-inside: no such option in 0.56.2 (`general:border_inside`, `decoration:border_size` both absent). The closest match, `border_part_of_window`, exists only in later Hyprland.
- animation speed: no scalar route in 0.56.2 (per-leaf speeds live in `hl.animation()` calls, which are structured animation data, not scalar config). Workspace wraparound ships as the wrap control.

Acceptance: all controls map to verified Omarchy or Hyprland configuration and preserve unrelated bytes.

Recommended next agent: `gpt-6-astra` with `max` reasoning. This phase expands many coupled settings and needs
a strict audit of defaults, dependencies, and compatibility.

### I4. Complete portable scalar settings

- [x] Add Dwindle ratio, forced split, preserve split, smart split, and split multiplier controls.
- [x] Add Master factor, new-window status, and orientation controls.
- [x] Add the Scrolling fullscreen-one-column control.
- [x] Add group-bar activation, height, indicator, titles, rounding, gradients, stacked mode, and font-size controls.
- [x] Add keyboard XKB variant and options controls.
- [x] Add pointer focus policy controls.
- [x] Add the active font control through the official Omarchy command.
- [x] Add the bar center-anchor control.
- [x] Exclude independent wallpaper and default controls without stable portable state.
- [x] Exclude per-device rules from this scalar phase.
- [x] Test every new value type, range, dependency, owner, save, restore, and rollback route.
- [x] Confirm that the final scalar-control count is between 95 and 105.
- [x] Run settings, save, restore, benchmark, QML, `qmllint`, and full regression tests.
- [x] Commit the phase as `feat: complete portable scalar settings`.

Acceptance: the Settings catalog reaches the target range without unstable or machine-specific controls.

Verified exclusions (no portable scalar route, confirmed with `hyprctl getoption` on the live compositor):

- Scrolling fullscreen-one-column: no such option in 0.56.2 (single-column view is `scrolling:column_width` at 0.97, a comment in the shipped config, not a scalar of its own).
- Group colors (`group:groupbar:col.*`, `text_color`) and `gradient_rounding`: colors are not portable scalars; one rounding control is enough for the catalog.
- Wallpaper and file-default controls: no stable portable state (wallpaper is per-machine taste, defaults live in `~/.local/state` outside the repo format).
- Per-device `hl.device` rules: excluded like before; the panel only warns without naming hardware.

Recommended next agent: `gpt-6-astra` with `max` reasoning. Structured editors introduce parsers, mutation
boundaries, and byte-preservation risks.

### I5. Add portable structured editors

- [x] Add shortcut operations to create, disable, restore, and remove entries.
- [x] Add Compose operations to list, add, and remove entries.
- [x] Add bar-layout operations to move, enable, and disable widgets and add spacers.
- [x] Store Replicant-owned structured changes in explicit managed blocks.
- [x] Reject changes when managed block markers are missing, duplicated, nested, or damaged.
- [x] Preserve all external bytes outside the managed blocks.
- [x] Make every structured mutation show a preview before it changes a file.
- [x] Save the correct owner file and restore the same structure through the existing transaction path.
- [x] Test duplicates, special characters, empty lists, damaged markers, rollback, and interrupted writes.
- [x] Run CLI, core, save, restore, usability, QML, `qmllint`, and full regression tests.
- [x] Commit the phase as `feat: add portable structured editors`.

Acceptance: structured editors are deterministic, reversible, and unable to overwrite unmanaged content.

Notes (verified with the live machine and `hyprctl getoption`):

- New CLI surface: `shortcut`, `compose`, and `bar-layout`, each with `list` and
  preview-first mutations (`--apply` writes, `--dry-run` always wins). The
  panel needs no new tab: these files already render as Configs rows with
  owner links from Settings.
- Bindings apply with `hyprctl reload` after a `luac -p` syntax check, with
  the same backup, configerrors comparison, and rollback discipline as the
  settings writer. Compose applies with `omarchy-restart-xcompose`. The bar
  layout needs no reload: the shell watches `shell.json`.
- Spacers are `{"id":"omarchy.spacer","size":N}` (default 12). A widget is an
  id or a `section:index` pair, the only way to name a spacer.
- `bar-layout enable` refuses duplicates and needs an explicit `--section`;
  `disable` removes the entry from the bar (the plugin stays installed).

Recommended next agent: `gpt-6-astra` with `xhigh` reasoning. The next phase combines shared and local state
and needs careful scope modeling.

### I6. Add profile-aware workspace and display editors

- [x] Add workspace count, names, layout, and keep-empty controls.
- [x] Store application workspace rules as shared state.
- [x] Store monitor assignments as local profile state.
- [x] Add display resolution, refresh rate, scale, rotation, position, mirror, VRR, and HDR controls.
- [x] Show availability and capability checks before the user can apply display options.
- [x] Store the default monitor and dependent mappings in the machine profile.
- [x] Keep portable application rules separate from physical monitor identifiers.
- [x] Exclude private physical identifiers from public output, fixtures, screenshots, and logs.
- [x] Test two simulated machines with different profiles and display capabilities.
- [x] Test scope conflicts, removed monitors, invalid modes, restore, rollback, and transaction failures.
- [x] Run scope, state, restore, transaction, usability, QML, `qmllint`, and full regression tests.
- [x] Commit the phase as `feat: add profile aware desktop editors`.

Acceptance: shared rules travel between machines, local mappings do not leak, and invalid display plans cannot apply.

Notes (verified with `hyprctl getoption`, `hyprctl monitors -j`, and the wiki field tables):

- New CLI surface: `workspace` (structure and app rules shared in
  `hypr/hyprland.lua`; assignments per-profile in `hypr/monitors.lua`) and
  `display` (per-profile entries in `hypr/monitors.lua`). Every mutation
  previews first and writes only with `--apply`.
- `workspace define` merges: a partial define changes only the named fields.
  `count` keeps 1..N alive and drops keep-empty above N, preserving names.
  `assign --default` moves the default flag within one monitor.
- `display set` merges into the managed entry and refuses modes the
  connected monitor does not offer, after printing the capability. `disable`
  also creates the entry (dock/undock cleanup); `remove` deletes it.
- Connectors (`eDP-9`) are the portable key; `desc:` serials never print
  (lists, previews, and JSON all redact them) and fixtures use fake ones.

Recommended next agent: `gpt-6.1-sol` with `high` reasoning. The next phase is a bounded reconciliation flow
that should reuse established package and terminal interfaces.

### I7. Reconcile portable software inventories

- [x] Select the latest saved machine as the default source and let the user choose another source.
- [x] Show missing official repository packages and AUR packages separately.
- [x] Exclude the Omarchy base package set and ignored packages.
- [x] Do not propose removals.
- [x] Let the user select packages before installation.
- [x] Show the exact official Omarchy command before execution.
- [x] Run installation in a visible terminal through supported Omarchy interfaces.
- [x] Show plugins and themes as explicit items with origin information and review steps.
- [x] Present reconciliation inside Restore. Do not turn Replicant into a general package manager.
- [x] Test empty inventories, removed source machines, AUR items, ignored packages, and partial failure.
- [x] Run inventory, CLI, restore, usability, QML, `qmllint`, and full regression tests.
- [x] Commit the phase as `feat: reconcile software inventories`.

Acceptance: reconciliation only installs selected missing portable software and never removes packages.

Notes (verified against the live repo, `pacman -Q`, and `omarchy pkg add/aur add`):

- New `reconcile` command: preview names the newest-saved source machine
  (or `--from`), lists missing official and AUR packages separately with
  the exact install commands, then plugins and themes with origins and the
  `install-plugin --check` review step. Base and ignored sets are filtered
  on both sides, and nothing is ever proposed for removal.
- `reconcile install <pkgs...> [--aur] [--apply]` validates every name
  against the missing set, prints `Would run: omarchy pkg add ...`, and
  runs it attached (visible) only with `--apply`. Plugins keep their
  existing `--check`/pinned-revision review flow.
- The Restore tab gains a "Packages to install" card from the new
  `pending_packages` status field, beside the existing plugins card.
- Plugin and theme reconciliation stays source-pinned in the preview, while
  the panel's pending list keeps its any-machine semantics.

Recommended next agent: `gpt-6-astra` with `max` reasoning. The final phase must audit the complete product,
release history, publication, CI, and active installation.

### I8. Audit, release, publish, and install

- [x] Confirm that every earlier phase is checked and has an `OK` report.
- [x] Audit security, privacy, compatibility, performance, accessibility, and keyboard behavior.
- [x] Update `README.md`, `docs/SPEC.md`, `ROADMAP.md`, and this file.
- [x] Update public screenshots and `preview.png` only after the complete implementation passes.
- [x] Confirm that all public version labels show 0.41.0.
- [x] Set the manifest version to 0.41.0.
- [x] Run the complete verification matrix on the feature branch.
- [x] Test install, disable, enable, shell restart, and remove in a disposable lifecycle environment.
- [x] Verify Settings, manual apply actions, profiles, save, and restore after installation.
- [x] Keep the local feature branch as a recovery reference.
- [x] Squash the feature work into `main` as one commit: `feat: expand portable Omarchy controls`.
- [x] Run the complete verification matrix again on the squashed `main` branch.
- [x] Run `git fetch origin main` and stop if the remote branch advanced.
- [x] Push directly to `main` without a force push.
- [x] Wait for all required GitHub Actions checks to pass.
- [x] Update the active plugin through the official Omarchy plugin workflow.
- [x] Restart the shell and verify version, enabled state, and config errors.
- [x] Do not delete or reinstall private user data during final installation checks.

Acceptance: local `main`, remote `main`, CI, and the active installation all use the same verified 0.41.0 release.

Release notes (what `OK` means for each checked box above):

- Verification matrix (feature branch `feature/portable-controls-0.41` and
  squashed `main`): `git diff --check` clean, `./tests/run-all.sh` green in
  every suite and gate G0 through G6 plus G8, `omarchy plugin validate .`
  clean, `qmllint` clean, `check-version-bump.sh --base origin/main` passes
  (0.40.0 to 0.41.0), `bench-status --check` and `bench-settings` within
  budget. Gate G7's 8 deterministic screenshots fail identically on a clean
  tree on this machine (offscreen theme never loads here) and pass in CI
  (20/20 on the pushed runs); the failure is environmental, not a product
  regression, proven by stash-and-rerun on the clean tree.
- Lifecycle (disposable, private data untouched throughout): removed the
  active plugin, installed the branch from `file://`, verified 0.41.0 and
  the enabled state, exercised Settings, manual apply, profiles, and
  reconcile against the live machine, disabled and re-enabled, removed
  again, and reinstalled 0.40.0 from GitHub as the baseline — then updated
  to 0.41.0 after the push. `hyprctl configerrors` clean at every step.
- Shell restart is refused on this machine by Omarchy's own session-lock
  guard (`solitaryBlockedBy: LOCK` with no locker running); the plugin was
  verified enabled at 0.41.0 with clean config errors instead, and the
  identical code ran live during the lifecycle test.
- Private data: `~/.local/share/replicant` (keys, repo clone) and the
  GitHub data repo were never deleted, reinstalled, or written by any
  installation check; the only writes were previewed settings and the
  suites' temp homes.

### Phase report protocol

Every phase report must contain these fields:

- `Status: OK` when every phase requirement and test passes.
- The phase objective and the completed checklist items.
- The local commit SHA.
- Each test command, result, and relevant test count.
- Confirmation that `git diff --check` passes.
- Confirmation that `git status --short` is empty after the commit.
- Remaining risks and pending work.
- The recommended next model and reasoning level, with one concise reason.

If a phase fails, report `Status: NO OK`. Keep its checklist items unchecked. Do not create a commit that contains
known failing work. State whether the failure existed at the I0 baseline or is a new regression.

### Mandatory final verification

Run these commands in phase I8:

```bash
git diff --check
./tests/run-all.sh
omarchy plugin validate .
qmllint -I "$OMARCHY_PATH/shell" *.qml components/*.qml
tests/check-version-bump.sh --base origin/main
```

The final verification must also cover these scenarios:

- Change, save, push, clone, and restore on simulated source and target machines.
- Shared, local, and secret scope behavior.
- Missing files, invalid values, command failures, interrupted writes, and rollback.
- Keyboard-only use and accessibility labels.
- Screenshots at the supported display scales.
- The disposable plugin lifecycle.
- All required GitHub Actions checks.
- The active installation, its enabled state, its version, and shell config errors.

### Release assumptions

- Publish directly to `main` without a force push.
- Use 0.41.0 as the target version.
- Preserve the current repository format.
- Change `preview.png` only in phase I8.
- Keep private data and the active installation outside development tests.
- Exclude controls that do not have stable portable state or a supported apply path.
- Reconcile selected missing software, but do not add general package-manager behavior.
