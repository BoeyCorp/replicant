#!/bin/bash
# Benchmark status on a representative INITIALIZED repository.
#
# bench-status.sh --check only measures an empty fixture (harness overhead:
# ~90 ms full) and the fastest of three samples. That gate cannot see real
# status work and never substitutes for it (R14). This script builds a
# realistic repo — shared configs, a directory tree, an encrypted vault with
# secrets, machine state, and pending work — asserts the status is correct on
# it, then measures cold/warm full/deferred/brief over repeated samples and
# compares medians against justified budgets.
#
# Budgets are env-overridable and deliberately generous: they must catch a
# real regression (verified by a controlled failure run with a 1 ms budget),
# not flake on a noisy shared runner. Reference medians on the 2026-10-22
# dev machine (42 rows: 30 shared configs, 10 vault secrets, 1 dir tree of 10
# files, 2 unsaved, 1 missing): full ~9.7 s, deferred ~6.9 s, brief ~4.5 s
# warm. Defaults below roughly double those, so host noise cannot fail the
# gate while a 2x slowdown still does.
set -uo pipefail

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd -- "$HERE/.." && pwd)"
CLI="$ROOT/bin/replicant"
CORE="$ROOT/bin/replicant-core.sh"
# shellcheck source=tests/lib.sh
source "$HERE/lib.sh"

RUNS="${REPLICANT_BENCH_RUNS:-3}"
FULL_BUDGET_MS="${INIT_FULL_BUDGET_MS:-20000}"
DEFERRED_BUDGET_MS="${INIT_DEFERRED_BUDGET_MS:-15000}"
BRIEF_BUDGET_MS="${INIT_BRIEF_BUDGET_MS:-12000}"
[[ "$RUNS" =~ ^[1-9][0-9]*$ ]] || { echo "RUNS must be a positive integer" >&2; exit 2; }

TMP=$(mktemp -d "${TMPDIR:-/tmp}/replicant-bench-init-XXXXXX")
trap 'rm -rf "$TMP"' EXIT
export HOME="$TMP/home" OMARCHY_PATH="$TMP/omarchy" OMARCHY_REPLICANT_HOME="$TMP/replicant"
export XDG_STATE_HOME="$TMP/xstate" XDG_CACHE_HOME="$TMP/xcache" XDG_CONFIG_HOME="$TMP/xcfg"
export GIT_CONFIG_GLOBAL="$TMP/gitconfig"
mkdir -p "$HOME/.config/hypr" "$HOME/.config/environment.d" "$HOME/.config/nvim/lua" \
  "$HOME/.local/bin" "$OMARCHY_PATH/config/hypr" "$XDG_STATE_HOME" "$OMARCHY_REPLICANT_HOME"
printf '[user]\n\tname = Bench\n\temail = bench@example.com\n' > "$GIT_CONFIG_GLOBAL"
printf 'default input\n' > "$OMARCHY_PATH/config/hypr/input.lua"

# Representative content: 30 shared configs, 10 secret env files, a 10-file
# directory tree, one executable script.
for i in $(seq 1 30); do printf 'content %d\n' "$i" > "$HOME/.config/hypr/conf-$i.conf"; done
for i in $(seq 1 10); do printf 'VAR%d=fixture-secret-%d\n' "$i" "$i" > "$HOME/.config/environment.d/s-$i.conf"; done
for i in $(seq 1 10); do printf 'plug %d\n' "$i" > "$HOME/.config/nvim/lua/p-$i.lua"; done
printf '#!/bin/bash\necho hi\n' > "$HOME/.local/bin/tool"; chmod +x "$HOME/.local/bin/tool"

# shellcheck source=/dev/null
source "$CORE" 2>/dev/null
set +e +u
core_backup >/dev/null 2>&1
key_init >/dev/null 2>&1
for f in "$HOME"/.config/environment.d/s-*.conf; do core_track "$f" --secret >/dev/null 2>&1; done
for f in "$HOME"/.config/hypr/conf-*.conf "$HOME"/.config/nvim/lua/p-*.lua "$HOME/.local/bin/tool"; do
  core_track "$f" >/dev/null 2>&1
done
core_track "$HOME/.config/nvim/lua" >/dev/null 2>&1 || true
core_backup >/dev/null 2>&1
git -C "$REPO_DIR" add -A >/dev/null 2>&1
git -C "$REPO_DIR" commit -qm "initialized benchmark fixture" >/dev/null 2>&1 || true

# Pending work the gate must actually evaluate: unsaved config + secret edits
# and one tracked file gone from this machine.
printf 'edited\n' >> "$HOME/.config/hypr/conf-1.conf"
printf 'VAR1=changed-secret\n' > "$HOME/.config/environment.d/s-1.conf"
rm -f "$HOME/.config/hypr/conf-2.conf"
set -euo pipefail

section "fixture status assertions (real work, not an empty repo)"
out=$(core_status --json --no-fetch 2>/dev/null)
check "the fixture tracks shared, secret and tree rows" "42" "$(jq '.entries | length' <<<"$out")"
check "…with unsaved work pending" "2" "$(jq -r '.unsaved' <<<"$out")"
check "…and a missing file" "1" "$(jq -r '.missing' <<<"$out")"
check "…with the vault ready, not locked" "ready" "$(jq -r '.encryption.state' <<<"$out")"
check "…and no secret value in status output" "0" "$(grep -c 'fixture-secret' <<<"$out" || true)"
blob_bytes=$(du -sb "$REPO_DIR/vault/blobs" 2>/dev/null | cut -f1)
echo "  fixture: 42 rows (30 shared, 10 vault secrets, 1 dir of 10, 1 script), vault blobs ${blob_bytes} bytes"

ms_now() { date +%s%N; }
measure_ms() {
  local s e
  s=$(ms_now)
  "$@" >/dev/null 2>&1
  e=$(ms_now)
  printf '%s\n' "$(( (e - s) / 1000000 ))"
}
median_of() { printf '%s\n' "$@" | sort -n | awk -v n="$#" 'NR == int((n + 1) / 2) { print; exit }'; }
max_of() { printf '%s\n' "$@" | sort -n | tail -n 1; }

section "cold and warm status over $RUNS samples per mode"
briefcache_invalidate >/dev/null 2>&1 || true
rm -rf "$REPLICANT_HOME/cache" 2>/dev/null || true
cold_full=$(measure_ms "$CLI" status --json --no-fetch)
echo "  cold full: ${cold_full} ms (caches cleared)"
full=(); for ((i = 0; i < RUNS; i++)); do full+=("$(measure_ms "$CLI" status --json --no-fetch)"); done
deferred=(); for ((i = 0; i < RUNS; i++)); do deferred+=("$(measure_ms "$CLI" status --json --no-fetch --defer-settings)"); done
brief=(); for ((i = 0; i < RUNS; i++)); do brief+=("$(measure_ms "$CLI" status --json --brief --no-fetch)"); done
echo "  warm full samples: ${full[*]}"
echo "  warm deferred samples: ${deferred[*]}"
echo "  warm brief samples: ${brief[*]}"
med_full=$(median_of "${full[@]}"); max_full=$(max_of "${full[@]}")
med_def=$(median_of "${deferred[@]}"); max_def=$(max_of "${deferred[@]}")
med_brief=$(median_of "${brief[@]}"); max_brief=$(max_of "${brief[@]}")
echo "  median/max full: ${med_full}/${max_full} ms (budget ${FULL_BUDGET_MS} ms)"
echo "  median/max deferred: ${med_def}/${max_def} ms (budget ${DEFERRED_BUDGET_MS} ms)"
echo "  median/max brief: ${med_brief}/${max_brief} ms (budget ${BRIEF_BUDGET_MS} ms)"
echo "  runtime: git $(git --version | awk '{print $3}'), jq $(jq --version), age $(age --version 2>&1 | head -n1), bash ${BASH_VERSION%%.*}"

section "budget verdict"
check "full median within budget" "0" "$(( med_full > FULL_BUDGET_MS ? 1 : 0 ))"
check "deferred median within budget" "0" "$(( med_def > DEFERRED_BUDGET_MS ? 1 : 0 ))"
check "brief median within budget" "0" "$(( med_brief > BRIEF_BUDGET_MS ? 1 : 0 ))"
# A gate that cannot fail cannot detect a slowdown: the medians above are
# seconds on real work, so a 1 ms budget must fail. The inner run skips its
# own self-check via REPLICANT_BENCH_SELFCHECK=0, so this is one level only.
if [[ "${REPLICANT_BENCH_SELFCHECK:-1}" == "1" ]]; then
  if INIT_FULL_BUDGET_MS=1 INIT_DEFERRED_BUDGET_MS=1 INIT_BRIEF_BUDGET_MS=1 \
      REPLICANT_BENCH_RUNS=1 REPLICANT_BENCH_SELFCHECK=0 \
      bash "$HERE/bench-status-initialized.sh" >/dev/null 2>&1; then
    t_bad "a 1 ms budget still passes — the gate cannot detect a slowdown"
  else
    t_ok "a 1 ms budget fails — the gate detects a deliberate slowdown"
  fi
fi

summary
