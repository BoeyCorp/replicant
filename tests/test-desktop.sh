#!/bin/bash
# Desktop editors: profile-aware workspace and display changes in managed
# blocks, with preview-first mutations and saves through the owning entry.
#
# Two simulated machines share one repo: studio (docked, two monitors) and
# den (one internal panel with different modes). Physical identifiers in the
# fixtures are fake, and none may reach the output.
set -uo pipefail

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CLI="$HERE/../bin/replicant"
# shellcheck source=tests/lib.sh
source "$HERE/lib.sh"

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
export HOME="$TMP/home"
export OMARCHY_PATH="$TMP/omarchy"
export OMARCHY_REPLICANT_HOME="$TMP/replicant"
export REPLICANT_PROFILE="studio"
REPO="$OMARCHY_REPLICANT_HOME/repo"
mkdir -p "$HOME/.config/hypr" "$HOME/.config/omarchy" "$OMARCHY_PATH/config"

cat > "$HOME/.config/hypr/hyprland.lua" <<'LUA'
-- Personal Hyprland overrides.
require("hypr.monitors")
o.window("kitty", { workspace = "1" })
LUA

cat > "$HOME/.config/hypr/monitors.lua" <<'LUA'
-- Personal monitor entries.
hl.monitor({ output = "desc:FAKE MAKE MODEL SERIAL-XYZ", mode = "3840x2160@240", position = "0x0", scale = 1.6 })
hl.monitor({ output = "eDP-9", mode = "3072x1920@120", position = "2400x390", scale = 1.6 })
LUA

printf '{"bar":{"layout":{"left":[],"center":[],"right":[]}}}\n' > "$HOME/.config/omarchy/shell.json"

# Two machines: studio is docked (internal plus external), den keeps only
# the internal panel with fewer modes.
cat > "$TMP/monitors-studio.json" <<'JSON'
[
  {"name": "eDP-9", "description": "Fake Internal Panel SERIAL-INT", "width": 3072, "height": 1920,
   "refreshRate": 120.0, "scale": 1.6, "transform": 0, "focused": true, "vrr": false, "mirrorOf": "none",
   "availableModes": ["3072x1920@120.00Hz", "3072x1920@60.00Hz"]},
  {"name": "DP-9", "description": "Fake External SERIAL-EXT", "width": 3840, "height": 2160,
   "refreshRate": 240.0, "scale": 1.6, "transform": 0, "focused": false, "vrr": true, "mirrorOf": "none",
   "availableModes": ["3840x2160@240.00Hz", "3840x2160@120.00Hz", "2560x1440@144.00Hz"]}
]
JSON
cat > "$TMP/monitors-den.json" <<'JSON'
[
  {"name": "eDP-9", "description": "Fake Internal Panel SERIAL-INT", "width": 3072, "height": 1920,
   "refreshRate": 60.0, "scale": 1.6, "transform": 0, "focused": true, "vrr": false, "mirrorOf": "none",
   "availableModes": ["3072x1920@60.00Hz"]}
]
JSON
export HYPRCTL_MONITORS="$TMP/monitors-studio.json"
mkdir -p "$TMP/fakebin"
cat > "$TMP/fakebin/hyprctl" <<'EOF'
#!/bin/bash
if [[ "$1" == reload ]]; then
  [[ "${HYPRCTL_FAIL_RELOAD:-0}" == 1 ]] && { echo "reload failed" >&2; exit 1; }
  exit 0
fi
if [[ "$1" == configerrors ]]; then
  if [[ -n "${HYPRCTL_CONFIGERRORS:-}" && -f "$HYPRCTL_CONFIGERRORS" ]]; then cat "$HYPRCTL_CONFIGERRORS"; exit 0; fi
  echo "no errors"
  exit 0
fi
if [[ "$1" == monitors ]]; then
  cat "$HYPRCTL_MONITORS"
  exit 0
fi
exit 1
EOF
chmod +x "$TMP/fakebin/hyprctl"
export PATH="$TMP/fakebin:$PATH"

run() { "$CLI" "$@" 2>&1; }

check_true "initial repository setup succeeds" "$CLI" init

section "workspace list starts empty and stays private"
out=$(run workspace list --json)
check "workspace list is valid JSON" "0" "$(printf '%s' "$out" | jq empty >/dev/null 2>&1; echo $?)"
check "no workspaces defined" "0" "$(printf '%s' "$out" | jq '.workspaces | length')"
check "serials never print" "0" "$(printf '%s' "$out" | grep -c 'SERIAL' || true)"
check_contains "plain list explains itself" "define one" "$(run workspace list)"

section "workspace define, rename and undefine"
cp "$HOME/.config/hypr/hyprland.lua" "$TMP/hyprland.orig"
prev=$(run workspace define 1 --name web --layout dwindle --persistent on)
check_contains "define preview shows the rule" 'workspace = "1"' "$prev"
check_contains "define preview names the file" "hyprland.lua" "$prev"
check_true "define preview changes nothing" cmp -s "$HOME/.config/hypr/hyprland.lua" "$TMP/hyprland.orig"
run workspace define 1 --name web --layout dwindle --persistent on --apply >/dev/null 2>&1; rc=$?
check "define succeeds" "0" "$rc"
check_contains "managed block opens" "replicant:workspaces:start" "$(cat "$HOME/.config/hypr/hyprland.lua")"
check_contains "rule lands" 'default_name = "web"' "$(cat "$HOME/.config/hypr/hyprland.lua")"
check_contains "unmanaged require survives" 'require("hypr.monitors")' "$(cat "$HOME/.config/hypr/hyprland.lua")"
check "backup left behind" "1" "$(ls "$HOME/.config/hypr"/hyprland.lua.bak.* 2>/dev/null | wc -l)"
check "save commits the shared owner" "workspaces: define 1" "$(git -C "$REPO" log -1 --format=%s)"
out=$(run workspace list --json)
check "list sees the workspace" "web" "$(printf '%s' "$out" | jq -r '.workspaces[0].name')"
check "list sees keep-empty" "true" "$(printf '%s' "$out" | jq -r '.workspaces[0].persistent')"
check "list marks it managed" "true" "$(printf '%s' "$out" | jq -r '.workspaces[0].managed')"
check "define merges on re-run" "dwindle" "$(run workspace define 1 --name www --apply >/dev/null 2>&1; run workspace list --json | jq -r '.workspaces[0].layout')"
check "…and keeps one rule" "1" "$(grep -c 'hl.workspace_rule({ workspace = "1"' "$HOME/.config/hypr/hyprland.lua")"
check_false "bad workspace refused" run workspace define 0 --name x --apply
check_false "bad workspace refused" run workspace define 21 --name x --apply
check_false "bad name refused" run workspace define 2 --name 'a b!' --apply
check_false "bad layout refused" run workspace define 2 --layout floating --apply
check_false "bad persistent refused" run workspace define 2 --persistent maybe --apply
check_false "empty define refused" run workspace define 2 --apply
run workspace define 1 --name www --apply >/dev/null 2>&1
check "rename keeps the layout" "dwindle" "$(run workspace list --json | jq -r '.workspaces[0].layout')"
check "rename keeps keep-empty" "true" "$(run workspace list --json | jq -r '.workspaces[0].persistent')"
run workspace undefine 1 --apply >/dev/null 2>&1; rc=$?
check "undefine succeeds" "0" "$rc"
check "undefine removes the rule" "0" "$(grep -c 'hl.workspace_rule({ workspace = "1"' "$HOME/.config/hypr/hyprland.lua" || true)"
check_false "undefining it again refused" run workspace undefine 1 --apply

section "workspace count keeps 1..N alive"
run workspace count 3 --apply >/dev/null 2>&1; rc=$?
check "count succeeds" "0" "$rc"
check "three persistents" "3" "$(grep -c 'persistent = true' "$HOME/.config/hypr/hyprland.lua")"
check "save commits the count" "workspaces: keep 3" "$(git -C "$REPO" log -1 --format=%s)"
run workspace define 5 --name mail --apply >/dev/null 2>&1
run workspace count 3 --apply >/dev/null 2>&1
check "above N loses keep-empty" "0" "$(grep -c 'workspace = "5".*persistent' "$HOME/.config/hypr/hyprland.lua" || true)"
check "above N keeps its name" "mail" "$(run workspace list --json | jq -r '[.workspaces[] | select(.workspace=="5")][0].name')"
check "repo copy carries the persistents" "3" "$(grep -c 'persistent = true' "$REPO/config/hypr/hyprland.lua" 2>/dev/null || true)"

section "application rules travel as shared state"
run workspace app-add "firefox" 2 --apply >/dev/null 2>&1; rc=$?
check "app-add succeeds" "0" "$rc"
check_contains "app rule lands" 'o.window("firefox", { workspace = "2" })' "$(cat "$HOME/.config/hypr/hyprland.lua")"
out=$(run workspace list --json)
check "apps list the rule" "firefox" "$(printf '%s' "$out" | jq -r '[.apps[] | select(.class=="firefox")][0].class')"
check "apps list is managed" "true" "$(printf '%s' "$out" | jq -r '[.apps[] | select(.class=="firefox")][0].managed')"
check_false "managed duplicate refused" run workspace app-add "firefox" 3 --apply
check_false "unmanaged duplicate refused" run workspace app-add "kitty" 3 --apply
check "…and kitty is untouched" "1" "$(grep -c 'o.window("kitty"' "$HOME/.config/hypr/hyprland.lua")"
check_false "empty class refused" run workspace app-add "" 3 --apply
run workspace app-add "Code|.*" 4 --apply >/dev/null 2>&1
check "regex class round-trips" "Code|.*" "$(run workspace list --json | jq -r '[.apps[] | select(.class=="Code|.*")][0].class')"
prev=$(run workspace app-add "newapp" 9)
check_contains "undefined workspace warns" "opens it on demand" "$prev"
run workspace app-remove "firefox" --apply >/dev/null 2>&1
check "app-remove deletes the rule" "0" "$(grep -c 'o.window("firefox"' "$HOME/.config/hypr/hyprland.lua" || true)"
check_false "removing an unmanaged rule refused" run workspace app-remove "kitty" --apply
check "…and kitty stays" "1" "$(grep -c 'o.window("kitty"' "$HOME/.config/hypr/hyprland.lua")"
check_false "removing an absent rule refused" run workspace app-remove "nope" --apply

section "assignments live in the machine profile"
cp "$HOME/.config/hypr/monitors.lua" "$TMP/monitors.orig"
prev=$(run workspace assign 1 DP-9 --default)
check_contains "assign preview shows the rule" 'monitor = "DP-9"' "$prev"
check_contains "assign preview names the profile file" "monitors.lua" "$prev"
check_true "assign preview changes nothing" cmp -s "$HOME/.config/hypr/monitors.lua" "$TMP/monitors.orig"
run workspace assign 1 DP-9 --default --apply >/dev/null 2>&1; rc=$?
check "assign succeeds" "0" "$rc"
check_contains "assignment lands in the profile block" "replicant:assignments:start" "$(cat "$HOME/.config/hypr/monitors.lua")"
check_contains "default flag lands" 'default = true' "$(cat "$HOME/.config/hypr/monitors.lua")"
check "profile copy carries the assignment" "1" "$(grep -c 'monitor = "DP-9"' "$REPO/profiles/studio/config/hypr/monitors.lua" 2>/dev/null || true)"
check "shared copy has no assignments" "0" "$(grep -c 'monitor = "DP-9"' "$REPO/config/hypr/monitors.lua" 2>/dev/null || echo 0)"
run workspace assign 2 eDP-9 --apply >/dev/null 2>&1
run workspace assign 3 DP-9 --default --apply >/dev/null 2>&1
check "default moves to workspace 3" "3" "$(run workspace list --json | jq -r '[.workspaces[] | select(.default=="true")][0].workspace')"
check "old default cleared" "0" "$(grep -c 'workspace = "1", monitor = "DP-9", default = true' "$HOME/.config/hypr/monitors.lua" || true)"
prev=$(run workspace assign 4 GHOST-9 --apply)
check_contains "disconnected assignment warns" "not connected" "$prev"
check "…but still stores it" "1" "$(grep -c 'monitor = "GHOST-9"' "$HOME/.config/hypr/monitors.lua")"
run workspace unassign 4 --apply >/dev/null 2>&1
check "unassign removes it" "0" "$(grep -c 'GHOST-9' "$HOME/.config/hypr/monitors.lua" || true)"
check_false "unassigning an absent workspace refused" run workspace unassign 9 --apply
check_false "assign refuses a bad workspace" run workspace assign 0 DP-9 --apply
check_false "assign refuses an empty monitor" run workspace assign 1 "" --apply

section "private identifiers never reach the output"
out=$(run workspace list --json)
check "no serials in JSON" "0" "$(printf '%s' "$out" | grep -c 'SERIAL' || true)"
check "no descs in JSON" "0" "$(printf '%s' "$out" | grep -c 'desc:' || true)"
prev=$(run workspace assign 5 eDP-9 --apply)
check "no serials in previews" "0" "$(printf '%s' "$prev" | grep -c 'SERIAL' || true)"
run workspace unassign 5 --apply >/dev/null 2>&1 || true

section "display list shows entries, connection and modes"
out=$(run display list --json)
check "display list is valid JSON" "0" "$(printf '%s' "$out" | jq empty >/dev/null 2>&1; echo $?)"
check "display list finds two entries" "2" "$(printf '%s' "$out" | jq 'length')"
check "unmanaged desc is redacted nowhere here" "0" "$(printf '%s' "$out" | grep -c 'SERIAL-XYZ' || true)"
plain=$(run display list)
check "plain list redacts the serial" "1" "$(printf '%s' "$plain" | grep -c 'desc:<redacted>' || true)"
check_contains "connected monitor shows its modes" "DP-9" "$plain"

section "display set merges, validates and previews capability"
cp "$HOME/.config/hypr/monitors.lua" "$TMP/monitors.disp"
prev=$(run display set DP-9 --mode 2560x1440@144 --scale 1.5)
check_contains "capability names the monitor" "DP-9 is connected" "$prev"
check_contains "capability confirms the mode" "mode 2560x1440@144 is offered" "$prev"
check_contains "set preview shows the mode" 'mode = "2560x1440@144"' "$prev"
check "no serials in set preview" "0" "$(printf '%s' "$prev" | grep -c 'SERIAL' || true)"
check_true "set preview changes nothing" cmp -s "$HOME/.config/hypr/monitors.lua" "$TMP/monitors.disp"
run display set DP-9 --mode 2560x1440@144 --scale 1.5 --apply >/dev/null 2>&1; rc=$?
check "set succeeds" "0" "$rc"
check_contains "mode lands in the managed block" 'mode = "2560x1440@144"' "$(cat "$HOME/.config/hypr/monitors.lua")"
check "save commits the profile owner" "display: set DP-9" "$(git -C "$REPO" log -1 --format=%s)"
check_false "unknown mode refused" run display set DP-9 --mode 9999x9999@999 --apply
check_contains "refusal lists what is offered" "2560x1440@144" "$(run display set DP-9 --mode 9999x9999@999 2>&1 || true)"
check_false "bad scale refused" run display set DP-9 --scale 9 --apply
check_false "bad rotation refused" run display set DP-9 --rotation 9 --apply
check_false "bad position refused" run display set DP-9 --position here --apply
check_false "bad vrr refused" run display set DP-9 --vrr 9 --apply
check_false "self mirror refused" run display set DP-9 --mirror DP-9 --apply
check_false "absent mirror refused" run display set DP-9 --mirror NOPE-0 --apply
check_false "set with no options refused" run display set DP-9 --apply
check_false "unknown monitor refused" run display set NOPE-0 --mode preferred --apply
run display set DP-9 --hdr --rotation 1 --position 3840x0 --vrr 1 --apply >/dev/null 2>&1
check "hdr lands as bitdepth 10" "1" "$(grep -c 'bitdepth = 10' "$HOME/.config/hypr/monitors.lua")"
check "rotation lands" "1" "$(grep -c 'transform = 1' "$HOME/.config/hypr/monitors.lua")"
run display set DP-9 --no-hdr --apply >/dev/null 2>&1
check "no-hdr lands as bitdepth 8" "1" "$(grep -c 'bitdepth = 8' "$HOME/.config/hypr/monitors.lua")"
run display set eDP-9 --mirror DP-9 --apply >/dev/null 2>&1; rc=$?
check "mirror lands" "0" "$rc"
check_contains "mirror names the target" 'mirror = "DP-9"' "$(cat "$HOME/.config/hypr/monitors.lua")"

section "a second machine keeps its own profile"
# Den is another machine: its own live files, its own profile, its own
# capabilities. Shared state (hyprland.lua) travels; the profile does not.
mkdir -p "$TMP/den/.config/hypr" "$TMP/den/.config/omarchy"
cp "$HOME/.config/hypr/hyprland.lua" "$TMP/den/.config/hypr/hyprland.lua"
cat > "$TMP/den/.config/hypr/monitors.lua" <<'LUA'
-- Den monitor entries.
hl.monitor({ output = "eDP-9", mode = "3072x1920@60", position = "0x0", scale = 1 })
LUA
cp "$HOME/.config/omarchy/shell.json" "$TMP/den/.config/omarchy/shell.json"
export HOME="$TMP/den"
export HYPRCTL_MONITORS="$TMP/monitors-den.json"
export REPLICANT_PROFILE="den"
run workspace assign 1 eDP-9 --default --apply >/dev/null 2>&1
run display set eDP-9 --mode 3072x1920@60 --apply >/dev/null 2>&1
check "den profile carries its assignment" "1" "$(grep -c 'monitor = "eDP-9"' "$REPO/profiles/den/config/hypr/monitors.lua" 2>/dev/null || true)"
check "den mode fits its capabilities" "1" "$(awk '/replicant:monitors:start/,/replicant:monitors:end/' "$REPO/profiles/den/config/hypr/monitors.lua" 2>/dev/null | grep -c '3072x1920@60' || echo 0)"
check "studio keeps its own assignments" "2" "$(grep -c 'monitor = "DP-9"' "$REPO/profiles/studio/config/hypr/monitors.lua" 2>/dev/null || echo 0)"
check_false "den refuses what it cannot do" run display set eDP-9 --mode 3840x2160@240 --apply
export HOME="$TMP/home"
export REPLICANT_PROFILE="studio"
export HYPRCTL_MONITORS="$TMP/monitors-studio.json"

section "scope off warns and commits nothing"
run scope hypr/monitors.lua off >/dev/null 2>&1
head_before=$(git -C "$REPO" rev-parse HEAD)
out=$(run workspace assign 2 eDP-9 --apply 2>&1); rc=$?
check "scope-off still applies locally" "0" "$rc"
check "scope-off commits nothing" "$head_before" "$(git -C "$REPO" rev-parse HEAD)"
check_contains "scope-off warns" "switched off" "$out"
run scope hypr/monitors.lua profile >/dev/null 2>&1

section "damaged markers refuse without touching the file"
cp "$HOME/.config/hypr/monitors.lua" "$TMP/monitors.good"
printf '%s\n' '-- replicant:monitors:start' >> "$HOME/.config/hypr/monitors.lua"
cp "$HOME/.config/hypr/monitors.lua" "$TMP/monitors.dup"
check_false "duplicated markers refuse a set" run display set eDP-9 --scale 2 --apply
check_true "duplicated markers leave the file alone" cmp -s "$HOME/.config/hypr/monitors.lua" "$TMP/monitors.dup"
cp "$TMP/monitors.good" "$HOME/.config/hypr/monitors.lua"
printf -- '-- replicant:assignments:end\n-- replicant:assignments:start\n' >> "$HOME/.config/hypr/monitors.lua"
check_false "markers out of order refuse an assign" run workspace assign 2 eDP-9 --apply
cp "$TMP/monitors.good" "$HOME/.config/hypr/monitors.lua"

section "a failed reload restores the file and commits nothing"
head_before=$(git -C "$REPO" rev-parse HEAD)
HYPRCTL_FAIL_RELOAD=1 run display set eDP-9 --scale 2 --apply >/dev/null 2>&1; rc=$?
check "reload failure reports failure" "1" "$rc"
check "reload failure restores the file" "0" "$(grep -c 'scale = 2, transform' "$HOME/.config/hypr/monitors.lua" || true)"
check "reload failure commits nothing" "$head_before" "$(git -C "$REPO" rev-parse HEAD)"
unset HYPRCTL_FAIL_RELOAD

section "removed monitors clean up from the profile"
run display disable GHOST-9 --apply >/dev/null 2>&1; rc=$?
check "disabling a gone monitor succeeds" "0" "$rc"
check "gone monitor stored disabled" "1" "$(grep -c 'disabled = true' "$HOME/.config/hypr/monitors.lua")"
run display remove GHOST-9 --apply >/dev/null 2>&1; rc=$?
check "removal succeeds" "0" "$rc"
check "gone monitor is gone" "0" "$(grep -c 'GHOST-9' "$HOME/.config/hypr/monitors.lua" || true)"
check_false "removing it again refused" run display remove GHOST-9 --apply
check_false "enabling without an entry refused" run display enable GHOST-9 --apply

section "display default marks workspace 1 in the profile"
run display default eDP-9 --apply >/dev/null 2>&1; rc=$?
check "default succeeds" "0" "$rc"
check "workspace 1 prefers it" "eDP-9" "$(run workspace list --json | jq -r '[.workspaces[] | select(.workspace=="1" and .default=="true")][0].monitor')"
check "save commits the default" "display: default eDP-9" "$(git -C "$REPO" log -1 --format=%s)"

section "restore-file brings back both structures"
run workspace define 7 --name tmp --apply >/dev/null 2>&1
printf '\n-- a local edit after the save\n' >> "$HOME/.config/hypr/hyprland.lua"
run restore-file hypr/hyprland.lua >/dev/null 2>&1; rc=$?
check "restore succeeds" "0" "$rc"
check "defined workspace is back" "1" "$(grep -c 'workspace = "7"' "$HOME/.config/hypr/hyprland.lua")"
check "local edit is gone" "0" "$(grep -c 'a local edit after the save' "$HOME/.config/hypr/hyprland.lua" || true)"
printf '\n-- a local monitor edit\n' >> "$HOME/.config/hypr/monitors.lua"
run restore-file hypr/monitors.lua >/dev/null 2>&1; rc=$?
check "profile restore succeeds" "0" "$rc"
check "local monitor edit is gone" "0" "$(grep -c 'a local monitor edit' "$HOME/.config/hypr/monitors.lua" || true)"

section "help names every operation"
check_contains "workspace help lists define" "workspace define" "$(run workspace --help)"
check_contains "workspace help lists assign" "workspace assign" "$(run workspace --help)"
check_contains "display help lists set" "display set" "$(run display --help)"
check_contains "display help lists default" "display default" "$(run display --help)"
check_contains "usage lists the editors" "display set" "$(run --help)"

summary
