#!/bin/bash
# Measure the settings payload against an initialized repository fixture.
# The fixture includes both managed Lua files, saved copies, and all registry
# paths. It never reads the machine configuration or a user repository.
set -euo pipefail

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd -- "$HERE/.." && pwd)"
CORE="$ROOT/bin/replicant-core.sh"

RUNS="${REPLICANT_SETTINGS_RUNS:-5}"
# Calibrated for the 100-setting catalog (I4): the payload builds one row per
# setting, so its cost scales with the catalog, not with the machine. The
# 8000 ms budget fit 76 settings; 100 need proportionally more.
MAX_MEDIAN_MS=11000
[[ "$RUNS" =~ ^[1-9][0-9]*$ ]] || { echo "RUNS must be a positive integer" >&2; exit 2; }

BENCH_TMP="$(mktemp -d "${TMPDIR:-/tmp}/replicant-settings-bench-XXXXXX")"
trap 'rm -rf "$BENCH_TMP"' EXIT
export HOME="$BENCH_TMP/home"
export XDG_CONFIG_HOME="$BENCH_TMP/config"
export XDG_DATA_HOME="$BENCH_TMP/data"
export XDG_STATE_HOME="$BENCH_TMP/state"
export XDG_CACHE_HOME="$BENCH_TMP/cache"
export OMARCHY_REPLICANT_HOME="$BENCH_TMP/replicant"
export GIT_CONFIG_GLOBAL="$BENCH_TMP/gitconfig"
export REPLICANT_LOGIND_DROPIN="$BENCH_TMP/logind.conf"
mkdir -p "$HOME/.config/omarchy" "$HOME/.config/hypr" "$HOME/.local/state/omarchy/defaults" \
  "$XDG_STATE_HOME" "$OMARCHY_REPLICANT_HOME" "$BENCH_TMP/bin"
printf '[user]\n\tname = Bench\n\temail = bench@example.com\n' > "$GIT_CONFIG_GLOBAL"
printf '#!/bin/sh\nexit 1\n' > "$BENCH_TMP/bin/hyprctl"
chmod +x "$BENCH_TMP/bin/hyprctl"
export PATH="$BENCH_TMP/bin:$PATH"

cat > "$HOME/.config/omarchy/shell.json" <<'JSON'
{"idle":{"screensaver":300,"lock":600,"lazyDpms":120,"lazySuspendAc":0,"lazySuspendBatt":300},"bar":{"position":"top","transparent":false}}
JSON
printf '[font]\nbase-size = 14\n\n[spacing]\nscale = 1.0\n\n[bar]\nsize-horizontal = 26\nsize-vertical = 28\nicon-font = 13\n' > "$HOME/.config/omarchy/shell.toml"
printf 'nvim\n' > "$HOME/.local/state/omarchy/defaults/editor"
cat > "$HOME/.config/hypr/input.lua" <<'LUA'
hl.config({
  input = {
    repeat_rate = 40, repeat_delay = 250, kb_layout = "us", numlock_by_default = true,
    sensitivity = 0, accel_profile = "adaptive", natural_scroll = false,
    scroll_factor = 1, left_handed = false,
    touchpad = { natural_scroll = false, tap_to_click = true,
      disable_while_typing = true, scroll_factor = 0.4,
      clickfinger_behavior = true, tap_and_drag = true, middle_button_emulation = false },
  },
})
LUA
cat > "$HOME/.config/hypr/looknfeel.lua" <<'LUA'
hl.config({
  general = { gaps_in = 5, gaps_out = 10, border_size = 2, resize_on_border = false, layout = "dwindle" },
  animations = { enabled = true },
  decoration = { rounding = 0, dim_inactive = false, dim_strength = 0.5,
    inactive_opacity = 1, blur = { enabled = false, special = false }, shadow = { enabled = false } },
  scrolling = { column_width = 0.5 },
})
LUA

source "$CORE"
set +e +u
core_backup >/dev/null 2>&1
set -euo pipefail

measure_ms() {
  local start stop
  start=$(date +%s%N)
  build_settings_json >/dev/null
  stop=$(date +%s%N)
  printf '%s\n' "$(( (stop - start) / 1000000 ))"
}

samples=()
for ((i = 0; i < RUNS; i++)); do samples+=("$(measure_ms)"); done
median=$(printf '%s\n' "${samples[@]}" | sort -n | awk -v n="$RUNS" 'NR == int((n + 1) / 2) { print; exit }')
echo "settings payload median ${median} ms across ${RUNS} initialized samples"
if (( median > MAX_MEDIAN_MS )); then
  echo "settings payload exceeds ${MAX_MEDIAN_MS} ms budget" >&2
  exit 1
fi
