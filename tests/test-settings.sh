#!/bin/bash
# The SETTINGS layer in bin/replicant-core.sh: reading, writing, refusing, and
# the JSON the panel consumes.
#
# Runs entirely inside a temp $HOME — it never touches the real ~/.config.
set -uo pipefail

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CORE="$HERE/../bin/replicant-core.sh"
# shellcheck source=tests/lib.sh
source "$HERE/lib.sh"

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
export HOME="$TMP"
export OMARCHY_REPLICANT_HOME="$TMP/replicant"
mkdir -p "$TMP/.config/omarchy" "$TMP/.config/hypr" "$TMP/.local/state/omarchy/defaults"

cat > "$TMP/.config/omarchy/shell.json" <<'JSON'
{
  "idle": { "lock": 600, "screensaver": 300, "lazyDpms": 120, "lazySuspendAc": 0, "lazySuspendBatt": 300 },
  "bar": { "position": "top", "transparent": false }
}
JSON

printf '[font]\nbase-size = 14\n' > "$TMP/.config/omarchy/shell.toml"

cat > "$TMP/.config/hypr/input.lua" <<'LUA'
hl.config({
  input = {
    kb_layout = "es",
    repeat_rate = 40,
    repeat_delay = 250,
    touchpad = {
      natural_scroll = true,
      tap_to_click = true,  -- trailing comment must survive
      disable_while_typing = true,
    },
  },
})
-- commented out, must be ignored: repeat_rate = 99
LUA

printf 'code\n' > "$TMP/.local/state/omarchy/defaults/editor"

# Every write to a Lua setting runs `hyprctl reload`, and the real hyprctl talks
# to the real compositor whatever $HOME says: this suite used to reload the
# session of whoever ran it. The stub answers `getoption` from a file a test
# writes ("option<TAB>json" per line), and does nothing for anything else.
mkdir -p "$TMP/fakebin"
cat > "$TMP/fakebin/hyprctl" <<'EOF'
#!/bin/bash
if [[ "$1" == getoption ]]; then
  [[ -f "${HYPRCTL_OPTIONS:-}" ]] || exit 1
  awk -F'\t' -v o="$2" '$1 == o { print $2; found = 1 } END { exit !found }' "$HYPRCTL_OPTIONS"
  exit
fi
if [[ "$1" == reload ]]; then
  [[ "${HYPRCTL_FAIL_RELOAD:-0}" == 1 ]] && { echo "reload failed" >&2; exit 1; }
  exit 0
fi
if [[ "$1" == configerrors ]]; then
  if [[ -n "${HYPRCTL_CONFIGERRORS:-}" && -f "$HYPRCTL_CONFIGERRORS" ]]; then cat "$HYPRCTL_CONFIGERRORS"; exit 0; fi
  echo "no errors"
  exit 0
fi
exit 0
EOF
chmod +x "$TMP/fakebin/hyprctl"
export PATH="$TMP/fakebin:$PATH"
export HYPRCTL_OPTIONS="$TMP/hyprctl-options"

# shellcheck source=/dev/null
source "$CORE" 2>/dev/null
# replicant-core.sh sets -euo pipefail; these tests deliberately call failing
# commands, so relax that in this shell only.
set +e +u

# Writes commit to the repo, so the fixture needs a ready one. The first
# backup initializes the v3 layout; a bare git dir would be invalid.
core_backup >/dev/null 2>&1

section "reading — one per storage format"
check "JSON number"                  "300"   "$(get_setting_value idle.screensaver)"
check "JSON number that is zero"     "0"     "$(get_setting_value idle.lazySuspendAc)"
check "JSON enum"                    "top"   "$(get_setting_value bar.position)"
check "JSON bool that is false"      "false" "$(get_setting_value bar.transparent)"
check "TOML int"                     "14"    "$(get_setting_value font.baseSize)"
check "Lua int"                      "40"    "$(get_setting_value input.repeatRate)"
check "Lua quoted string"            "es"    "$(get_setting_value input.kbLayout)"
check "Lua bool, nested two levels"  "true"  "$(get_setting_value input.naturalScroll)"
check "single-line file"             "code"  "$(get_setting_value default.editor)"
check_false "absent TOML key reads as missing" get_setting_value spacing.scale
check_false "unknown id is rejected"           get_setting_value does.not.exist

section "writing — the value lands and the file stays valid"
set_setting_value idle.screensaver 240 >/dev/null 2>&1
check "JSON number written"          "240"    "$(get_setting_value idle.screensaver)"
set_setting_value bar.position bottom >/dev/null 2>&1
check "JSON enum written"            "bottom" "$(get_setting_value bar.position)"
set_setting_value bar.transparent true >/dev/null 2>&1
check "JSON bool written"            "true"   "$(get_setting_value bar.transparent)"
check "JSON still parses"            "0"      "$(jq empty "$TMP/.config/omarchy/shell.json" >/dev/null 2>&1; echo $?)"

set_setting_value font.baseSize 16 >/dev/null 2>&1
check "TOML int written"             "16"     "$(get_setting_value font.baseSize)"
check "TOML section header kept"     "[font]" "$(head -1 "$TMP/.config/omarchy/shell.toml")"

# shell.toml ships nearly empty, so "the key isn't there yet" is the normal
# first write for most appearance settings, not an error.
set_setting_value spacing.scale 1.25 >/dev/null 2>&1
check "TOML float created in a new section" "1.25" "$(get_setting_value spacing.scale)"
set_setting_value bar.sizeHorizontal 30 >/dev/null 2>&1
check "TOML key created in a new section"   "30"   "$(get_setting_value bar.sizeHorizontal)"
set_setting_value bar.sizeVertical 34 >/dev/null 2>&1
check "second key into the same section"    "34"   "$(get_setting_value bar.sizeVertical)"
check "earlier TOML value untouched"        "1.25" "$(get_setting_value spacing.scale)"
check "font section survived both writes"   "16"   "$(get_setting_value font.baseSize)"

set_setting_value input.repeatRate 55 >/dev/null 2>&1
check "Lua int written"              "55"     "$(get_setting_value input.repeatRate)"
set_setting_value input.tapToClick false >/dev/null 2>&1
check "Lua bool written"             "false"  "$(get_setting_value input.tapToClick)"
set_setting_value input.kbLayout us >/dev/null 2>&1
check "Lua string written"           "us"     "$(get_setting_value input.kbLayout)"
check_contains "Lua value is re-quoted in the managed block" 'kb_layout = "us"' "$(cat "$TMP/.config/hypr/input.lua")"
check_contains "managed block is present" '-- replicant:settings:start' "$(cat "$TMP/.config/hypr/input.lua")"
check_contains "managed value lands in the block" 'repeat_rate = 55' "$(cat "$TMP/.config/hypr/input.lua")"
check_contains "trailing comment preserved outside the block" 'tap_to_click = true,  -- trailing comment' "$(cat "$TMP/.config/hypr/input.lua")"
check_contains "block holds the new tap value" 'tap_to_click = false' "$(cat "$TMP/.config/hypr/input.lua")"
check "commented-out line untouched" "1" "$(grep -c 'repeat_rate = 99' "$TMP/.config/hypr/input.lua")"

set_setting_value default.editor nvim >/dev/null 2>&1
check "single-line file written"     "nvim"   "$(get_setting_value default.editor)"

section "refusing bad input — the value must not move"
check_false "non-numeric rejected"        set_setting_value idle.screensaver abc
check "…and the value is unchanged"  "240" "$(get_setting_value idle.screensaver)"
check_false "below minimum rejected"      set_setting_value idle.screensaver 1
check_false "above maximum rejected"      set_setting_value idle.screensaver 999999
check "…still unchanged"             "240" "$(get_setting_value idle.screensaver)"
check_false "value outside enum rejected" set_setting_value bar.position sideways
check "…still bottom"                "bottom" "$(get_setting_value bar.position)"
check_false "non-boolean rejected"        set_setting_value bar.transparent maybe
check_false "unknown setting rejected"    set_setting_value does.not.exist 1
check_false "float out of range rejected" set_setting_value spacing.scale 9
check_false "non-numeric float rejected"  set_setting_value spacing.scale wide
check "…float unchanged"             "1.25" "$(get_setting_value spacing.scale)"
check_false "int type rejects a float"    set_setting_value font.baseSize 12.5
check "…font size unchanged"         "16"   "$(get_setting_value font.baseSize)"

section "full routes distinguish shared leaves; only a repeated full route is ambiguous"
# input:scroll_factor and input:touchpad:scroll_factor share a leaf but live
# in different tables: both must read, and a device rule must not merge them.
cat > "$TMP/.config/hypr/input.lua" <<'LUA'
hl.config({
  input = {
    scroll_factor = 1.0,
    touchpad = {
      scroll_factor = 0.5,
    },
  },
})
LUA
check "mouse scroll_factor reads its own table" "1.0" "$(get_setting_value input.scrollFactor)"
check "touchpad scroll_factor reads its own table" "0.5" "$(get_setting_value input.touchScrollFactor)"
# The same full route twice is ambiguous and must read as missing/refuse.
cat > "$TMP/.config/hypr/input.lua" <<'LUA'
hl.config({
  input = {
    repeat_rate = 40,
    repeat_rate = 10,
  },
})
LUA
check_false "duplicate full route reads as missing" get_setting_value input.repeatRate
check_false "duplicate full route refuses a write"  set_setting_value input.repeatRate 60
check "…both lines still present" "2" "$(grep -c 'repeat_rate' "$TMP/.config/hypr/input.lua")"
check "…and neither value moved"  "1" "$(grep -c 'repeat_rate = 40' "$TMP/.config/hypr/input.lua")"

rm -f "$TMP/.config/hypr/input.lua"
check_false "missing file reads as missing"  get_setting_value input.repeatRate
check_false "missing file refuses a write"   set_setting_value input.repeatRate 60

section "safety"
backups=$(find "$TMP/.config" "$TMP/.local" -name '*.bak.*' 2>/dev/null | wc -l)
if [[ "$backups" -gt 0 ]]; then t_ok "every write left a .bak.<epoch> behind ($backups)"; else t_bad "no backups were made"; fi

# Backups are capped per file. Dragging a slider is a dozen writes, and one
# backup each buried the real config under near-identical copies.
for v in 100 110 120 130 140; do set_setting_value idle.lock "$v" >/dev/null 2>&1; done
# At most 3, not exactly 3: the name carries a whole-second timestamp, so
# writes inside the same second reuse one file rather than adding another.
n=$(find "$TMP/.config/omarchy" -name 'shell.json.bak.*' | wc -l)
if (( n >= 1 && n <= 3 )); then t_ok "backups are capped per file (kept $n)"; else t_bad "expected 1-3 backups, found $n"; fi
check "…and the newest survives"    "140" "$(get_setting_value idle.lock)"
check "…without touching other files' backups" "1" \
  "$(find "$TMP/.local" -name 'editor.bak.*' | wc -l)"
# A restore leaves its own <file>.bak.<epoch>, and that backup is the undo for
# the restore. The cap counted it with the setting's own backups, so a few
# edits to the setting after a restore deleted it. A cap of 1 makes the old
# behaviour fail every time instead of only sometimes.
restore_bak="$TMP/.config/omarchy/shell.json.bak.1000000000"
cp "$TMP/.config/omarchy/shell.json" "$restore_bak"
touch -d '2020-01-01' "$restore_bak"
# shellcheck disable=SC2034  # read by backup_before_write in the sourced core
BACKUPS_KEPT=1
for v in 150 160; do set_setting_value idle.lock "$v" >/dev/null 2>&1; done
# shellcheck disable=SC2034  # read by backup_before_write in the sourced core
BACKUPS_KEPT=3
check_true "a restore's backup survives later setting edits" test -f "$restore_bak"
n=$(find "$TMP/.config/omarchy" -name 'shell.json.bak.*' ! -name '*.1000000000' | wc -l)
check "…while the setting's own backups stay capped" "1" "$n"
rm -f "$restore_bak"
check "JSON is still parseable"       "0" "$(jq empty "$TMP/.config/omarchy/shell.json" >/dev/null 2>&1; echo $?)"
check "TOML has no duplicate sections" "1" "$(grep -c '^\[bar\]' "$TMP/.config/omarchy/shell.toml")"

section "the JSON the panel consumes"
# Every registry line is an entry only on a laptop: a desktop drops the Lid
# group (checked below). Pin the answer, so the count is the same on every machine.
is_laptop() { return 0; }
settings_json=$(build_settings_json)
check "valid JSON"                    "0"  "$(printf '%s' "$settings_json" | jq empty >/dev/null 2>&1; echo $?)"
check "one entry per registry line"   "${#SETTINGS[@]}" "$(printf '%s' "$settings_json" | jq 'length')"
check "every entry carries a group"   "0"  "$(printf '%s' "$settings_json" | jq '[.[] | select(.group == "" or .group == null)] | length')"
check "every entry carries a label"   "0"  "$(printf '%s' "$settings_json" | jq '[.[] | select(.label == "" or .label == null)] | length')"
check "numbers stay numbers"          "number" "$(printf '%s' "$settings_json" | jq -r '[.[] | select(.id=="idle.screensaver")][0].value | type')"
check "bools stay bools"              "boolean" "$(printf '%s' "$settings_json" | jq -r '[.[] | select(.id=="bar.transparent")][0].value | type')"
check "enums carry their options"     "4"  "$(printf '%s' "$settings_json" | jq '[.[] | select(.id=="bar.position")][0].options | length')"
check "a missing value is unavailable" "false" "$(printf '%s' "$settings_json" | jq -r '[.[] | select(.id=="input.repeatRate")][0].available')"
check "…and is reported as null"       "null"  "$(printf '%s' "$settings_json" | jq -r '[.[] | select(.id=="input.repeatRate")][0].value')"
check "every group is one of the declared ones" "0" \
  "$(printf '%s' "$settings_json" | jq --argjson g "$(printf '%s\n' "${SETTING_GROUPS[@]}" | cut -d'|' -f1 | jq -Rsc 'split("\n") | map(select(length>0))')" \
     '[.[] | select(.group as $x | $g | index($x) | not)] | length')"

section "values a person can read"
check "zero is never, not 0 s"       "never"        "$(human_duration 0)"
check "under a minute stays seconds" "45 s"         "$(human_duration 45)"
check "a round minute"               "10 min"       "$(human_duration 600)"
check "…and a ragged one keeps both" "2 min 30 s"   "$(human_duration 150)"
check "an hour"                      "1 h"          "$(human_duration 3600)"
check "…and change"                  "1 h 30 min"   "$(human_duration 5400)"
check "booleans read as on/off"      "on"           "$(human_value bool "" 1 "" true)"
check "…and off"                     "off"          "$(human_value lua-bool "" 1 "" false)"
check "a unit is spaced from its number" "26 px"    "$(human_value toml-int px 1 px 26)"
check "a multiplier is not"          "1.4×"         "$(human_value toml-float "×" 1 "×" 1.4)"
check "a rate is not"                "40/s"         "$(human_value lua-int "/s" 1 "/s" 40)"
check "an absent value is a dash"    "—"            "$(human_value number s 60 min "")"
# "1" and "1.0" are the same density; printing them differently made the panel
# offer a revert button that would have changed nothing.
check "trailing zeros are dropped"   "1"            "$(canon_number 1.0)"
check "…without eating real digits"  "1.4"          "$(canon_number 1.40)"
check "…and integers are left alone" "26"           "$(canon_number 26)"

section "the panel edits minutes, the CLI still speaks seconds"
# Earlier sections have been writing to these files; start from a known state.
cat > "$TMP/.config/omarchy/shell.json" <<'JSON'
{
  "idle": { "lock": 600, "screensaver": 150, "lazyDpms": 120, "lazySuspendAc": 0, "lazySuspendBatt": 300 },
  "bar": { "position": "top", "transparent": false }
}
JSON
sj=$(build_settings_json)
lock=$(printf '%s' "$sj" | jq '[.[] | select(.id=="idle.lock")][0]')
check "the stored value is seconds"        "600"    "$(printf '%s' "$lock" | jq -r '.value')"
check "the shown value is minutes"         "10"     "$(printf '%s' "$lock" | jq -r '.display_value')"
check "…labelled as such"                  "min"    "$(printf '%s' "$lock" | jq -r '.display_unit')"
check "…with the bounds converted too"     "1"      "$(printf '%s' "$lock" | jq -r '.display_min')"
check "…both of them"                      "120"    "$(printf '%s' "$lock" | jq -r '.display_max')"
check "a long range steps in fives"        "5"      "$(printf '%s' "$lock" | jq -r '.display_step')"
check "and the exact value is spelled out" "10 min" "$(printf '%s' "$lock" | jq -r '.value_text')"
# The rounding the stepper does must never be mistaken for the real value.
ss=$(printf '%s' "$sj" | jq '[.[] | select(.id=="idle.screensaver")][0]')
check "an odd number of seconds rounds in the stepper" "3" "$(printf '%s' "$ss" | jq -r '.display_value')"
check "…but the row still states the truth" "2 min 30 s" "$(printf '%s' "$ss" | jq -r '.value_text')"
check "zero reads as never, not 0 min"      "never" \
  "$(printf '%s' "$sj" | jq -r '[.[] | select(.id=="idle.lazySuspendAc")][0].value_text')"
check "an unscaled setting shows its stored value" "true" \
  "$(printf '%s' "$sj" | jq -r '[.[] | select(.id=="font.baseSize")][0] | .value == .display_value')"

section "the two ways back, per setting"
# Omarchy's own shipped file, so the "back to default" button has something to
# read rather than guessing.
export OMARCHY_PATH="$TMP/omarchy"
mkdir -p "$OMARCHY_PATH/config/omarchy"
# Earlier sections wrote appearance keys into shell.toml; start from the shape
# Omarchy actually ships, where most of them are simply absent.
printf '[font]\nbase-size = 14\n' > "$TMP/.config/omarchy/shell.toml"
printf '{"idle":{"lock":300},"bar":{"position":"top"}}\n' > "$OMARCHY_PATH/config/omarchy/shell.json"
check "the default comes from Omarchy's own file" "300" "$(setting_default_value idle.lock)"
sj=$(build_settings_json)
check "…and the panel is told so" "5 min" \
  "$(printf '%s' "$sj" | jq -r '[.[] | select(.id=="idle.lock")][0].default_text')"
check "a value that differs offers the button" "true" \
  "$(printf '%s' "$sj" | jq -r '[.[] | select(.id=="idle.lock")][0].can_revert_default')"
# A key Omarchy does not ship falls back to the registry's own fallback, which
# is the value the shell uses when the key is absent.
check "a key with no shipped default uses the fallback" "26" "$(setting_default_value bar.sizeHorizontal)"
check "…and offers no button while it matches" "false" \
  "$(printf '%s' "$sj" | jq -r '[.[] | select(.id=="bar.sizeHorizontal")][0].can_revert_default')"
check_false "a setting with neither has no default" setting_default_value input.repeatRate
printf '%s\t%s\n' input:repeat_rate '{"option":"input:repeat_rate","int":99,"set":true}' > "$HYPRCTL_OPTIONS"
check_false "an active Hyprland value is not a default" setting_default_value input.repeatRate
rm -f "$HYPRCTL_OPTIONS"

# What the repo has, read out of the saved copy.
mkdir -p "$CONFIG_DIR/omarchy"
printf '{"idle":{"lock":900,"screensaver":150}}\n' > "$CONFIG_DIR/omarchy/shell.json"
check "the repo value comes from the saved copy" "900" "$(setting_repo_value idle.lock)"
sj=$(build_settings_json)
check "…and the panel is told so"    "15 min" \
  "$(printf '%s' "$sj" | jq -r '[.[] | select(.id=="idle.lock")][0].repo_text')"
check "a value that differs offers the button" "true" \
  "$(printf '%s' "$sj" | jq -r '[.[] | select(.id=="idle.lock")][0].can_revert_repo')"
check "one that matches does not"              "false" \
  "$(printf '%s' "$sj" | jq -r '[.[] | select(.id=="idle.screensaver")][0].can_revert_repo')"

core_revert idle.lock default >/dev/null 2>&1
check "reverting to the default writes it" "300" "$(get_setting_value idle.lock)"
check "…and touches nothing else in the file" "top" "$(jq -r '.bar.position' "$HOME/.config/omarchy/shell.json")"
core_revert idle.lock repo >/dev/null 2>&1
check "reverting to the repo writes that"  "900" "$(get_setting_value idle.lock)"
check_false "an unknown target is refused"  core_revert idle.lock sideways
check_false "an unknown setting is refused" core_revert not.a.setting default

section "the lid, on a machine that has one"
# The drop-in is root-owned in real life, so point the registry at a writable
# fixture: what is under test is the reader, the writer and the gate, not sudo.
# REPLICANT_NO_RELOAD: the "after" side of a lid write is a REAL
# `systemctl reload systemd-logind` regardless of where $file points, and
# polkit pops a graphical auth prompt for it even from an unprivileged test
# fixture. Nothing here is testing that reload; it's testing the read, the
# write and the ambiguity gate.
export REPLICANT_LOGIND_DROPIN="$TMP/logind.d/99-lid.conf"
export REPLICANT_NO_RELOAD=1
mkdir -p "$TMP/logind.d"
printf '[Login]\nHandleLidSwitch=ignore\n' > "$REPLICANT_LOGIND_DROPIN"
# A fake systemctl on PATH, so this section fails loudly if REPLICANT_NO_RELOAD
# is ever removed or bypassed — real proof, not just "no prompt appeared".
mkdir -p "$TMP/fakebin"
cat > "$TMP/fakebin/systemctl" <<EOF
#!/bin/bash
echo "\$*" >> "$TMP/systemctl-calls.log"
EOF
chmod +x "$TMP/fakebin/systemctl"
export PATH="$TMP/fakebin:$PATH"
# shellcheck source=/dev/null
source "$CORE"
# The core sets -euo pipefail. Without this line, the first failing command
# after here ended the suite with no summary, instead of reporting a check.
set +e +u
is_laptop() { return 0; }

check "a drop-in value is read back"    "ignore" "$(get_setting_value lid.close)"
set_setting_value lid.close suspend >/dev/null 2>&1
check "…and written"                    "suspend" "$(get_setting_value lid.close)"
check "…without ever reloading the real systemd-logind" "" \
  "$(cat "$TMP/systemctl-calls.log" 2>/dev/null || true)"
check "…in systemd's own spelling, not TOML's" "1" \
  "$(grep -cx 'HandleLidSwitch=suspend' "$REPLICANT_LOGIND_DROPIN" || true)"
check "…keeping a backup like every other write" "1" \
  "$(ls "$REPLICANT_LOGIND_DROPIN".bak.* 2>/dev/null | wc -l)"
# A key the drop-in does not carry yet is logind's own built-in default, which
# is what the fallback field records — not "missing".
check "an absent key reports logind's default" "suspend" "$(get_setting_value lid.closeAc)"
set_setting_value lid.closeAc ignore >/dev/null 2>&1
check "…and writing it adds the key"    "ignore" "$(get_setting_value lid.closeAc)"
check "…without disturbing the other"   "suspend" "$(get_setting_value lid.close)"
check_false "a value logind does not know is refused" set_setting_value lid.close sideways
check "…and the file is untouched after a refusal" "suspend" "$(get_setting_value lid.close)"

check "the group is offered on a laptop" "1" \
  "$(build_setting_groups_json | jq -r '[.[] | select(.name=="Lid & sleep")] | length')"
is_laptop() { return 1; }
check "…and absent on a desktop"         "0" \
  "$(build_setting_groups_json | jq -r '[.[] | select(.name=="Lid & sleep")] | length')"
check "…along with its settings"         "0" \
  "$(build_settings_json | jq -r '[.[] | select(.group=="Lid & sleep")] | length')"
is_laptop() { return 0; }

section "a root-owned write that cannot happen says so"
# Omarchy ships no polkit agent, so "nothing can ask for root" is the common
# outcome in the panel. It returned 0: `set` printed the new value and exited
# 0, and the panel reported a write that never happened. Both ways to root are
# stubbed as functions, so this can never raise a real prompt.
pkexec() { return 1; }
sudo() { return 1; }
nowhere="$TMP/not-a-dir/99-lid.conf"
rc=0; out=$(ini_set "$nowhere" Login.HandleLidSwitch ignore "" 2>&1) || rc=$?
check "the write reports failure" "1" "$rc"
check_false "…and so does root_apply on its own" root_apply "$nowhere" "$TMP/none" ""
check_false "…and nothing was written in its place" test -e "$nowhere"
# The message gives a `sudo install` command. The file it names used to be
# deleted before anybody could read the message.
staged=$(grep -oE '[^ ]*/staged/[^ ]+' <<<"$out" | head -n1)
check_true "the file the printed command names exists" test -f "$staged"
check "…and holds the new value" "1" "$(grep -cx 'HandleLidSwitch=ignore' "$staged" 2>/dev/null || true)"
check_true "…inside the plugin's own directory" test "${staged#"$OMARCHY_REPLICANT_HOME"/}" != "$staged"
unset -f pkexec sudo

section "a notice only when a setting genuinely cannot work"
# One rule, deliberately. A screensaver at or after the lock timer never appears,
# so the control silently does nothing — worth saying. Orderings people merely
# *assume* are wrong (display sleeping before the lock, suspend before the lock)
# are normal and must stay silent, or the notice trains people to ignore it.
cat > "$HOME/.config/omarchy/shell.json" <<'JSON'
{ "idle": { "lock": 300, "screensaver": 150, "lazyDpms": 60, "lazySuspendAc": 0, "lazySuspendBatt": 120 },
  "bar": { "position": "top", "transparent": false } }
JSON
notice_of() { build_settings_json | jq -r --arg id "$1" '[.[] | select(.id==$id)][0].notice'; }
check "a sane order says nothing"            "" "$(notice_of idle.screensaver)"
check "…display sleeping first is not a fault" "" "$(notice_of idle.lazyDpms)"
check "…nor is suspending before the lock"     "" "$(notice_of idle.lazySuspendBatt)"

# Screensaver at 10 min with a 5 min lock: it can never appear.
jq '.idle.screensaver = 600' "$HOME/.config/omarchy/shell.json" > "$TMP/s.json" && mv "$TMP/s.json" "$HOME/.config/omarchy/shell.json"
check "a screensaver that can never appear is called out" "1" \
  "$(notice_of idle.screensaver | grep -c 'never appears' || true)"
jq '.idle.screensaver = 150' "$HOME/.config/omarchy/shell.json" > "$TMP/s.json" && mv "$TMP/s.json" "$HOME/.config/omarchy/shell.json"
check "…and it clears when the order is fixed" "" "$(notice_of idle.screensaver)"
check "every setting carries the field"        "0" \
  "$(build_settings_json | jq '[.[] | select(has("notice") | not)] | length')"

section "Hyprland is asked what is in force, not the file"
# OmaSettings writes the same keys into hypr/omasettings.lua and loads it after
# input.lua, so the file this panel edits can say one thing while the session
# does another.
cat > "$HOME/.config/hypr/input.lua" <<'LUA'
hl.config({
  input = {
    kb_layout = "es",
    repeat_rate = 40,
    touchpad = {
      natural_scroll = true,
      tap_to_click = true,
    },
  },
})
LUA
printf 'require("hypr.input")\nrequire("hypr.omasettings")\n' > "$HOME/.config/hypr/hyprland.lua"
cat > "$HOME/.config/hypr/omasettings.lua" <<'LUA'
hl.config({
  input = {
    touchpad = {
      natural_scroll = false,
    },
  },
})
LUA
load_auto_manifest
printf '%s\t%s\n' \
  input:touchpad:natural_scroll '{"option": "input:touchpad:natural_scroll", "bool": false, "set": true}' \
  input:touchpad:tap_to_click   '{"option": "input:touchpad:tap_to_click", "int": 1, "set": true}' \
  input:repeat_rate             '{"option": "input:repeat_rate", "int": 40, "set": true}' \
  input:kb_layout               '{"option": "input:kb_layout", "str": "es", "set": true}' \
  > "$HYPRCTL_OPTIONS"
check "the Lua key is the option's last segment" "natural_scroll" "$(lua_key_of input:touchpad:natural_scroll)"
check "the value still reads from the file" "true" "$(get_setting_value input.naturalScroll)"
check_contains "a value another file overrides says what is in force" "In force: off" "$(notice_of input.naturalScroll)"
check_contains "…and which file sets it" "hypr/omasettings.lua" "$(notice_of input.naturalScroll)"
check "a value Hyprland agrees with says nothing" "" "$(notice_of input.repeatRate)"
check "…a switch Hyprland reports as 1 agrees with true" "" "$(notice_of input.tapToClick)"
check "…and so does a layout" "" "$(notice_of input.kbLayout)"
rm -f "$HYPRCTL_OPTIONS"
check "with no Hyprland to ask, nothing is claimed" "" "$(notice_of input.naturalScroll)"
rm -f "$HOME/.config/hypr/omasettings.lua" "$HOME/.config/hypr/hyprland.lua"
load_auto_manifest

section "the keyboard layouts are this machine's own"
# The list was fixed to eight layouts, so a user outside them had a control
# that could not show or keep the value. It comes from localectl now.
cat > "$TMP/fakebin/localectl" <<'EOF'
#!/bin/bash
[[ "$1" == list-x11-keymap-layouts ]] && printf 'es\nru\nus\n'
EOF
chmod +x "$TMP/fakebin/localectl"
layouts=$(setting_options "$(find_setting input.kbLayout)")
check_true "a layout the machine knows is offered" grep -qx ru <<<"${layouts//,/$'\n'}"
set_setting_value input.kbLayout ru >/dev/null 2>&1
check "…and can be written" "ru" "$(get_setting_value input.kbLayout)"
printf '#!/bin/bash\nexit 1\n' > "$TMP/fakebin/localectl"
layouts=$(setting_options "$(find_setting input.kbLayout)")
check_true "without localectl, a short list is still offered" grep -qx us <<<"${layouts//,/$'\n'}"
rm -f "$TMP/fakebin/localectl"

section "toml_set writes one key in one section and nothing else"
# The same key name appears in more than one section of shell.toml, and the
# writer is a line editor, not a TOML parser. It must stay inside its section.
f="$TMP/two-sections.toml"
printf '[a]\nsize = 1\n\n[b]\nsize = 2\n' > "$f"
toml_set "$f" b.size 3
check "the key in the named section changes" "3" "$(map_lookup "$f" toml b.size)"
check "…and the same key in another section does not" "1" "$(map_lookup "$f" toml a.size)"
check "…and no section header is written twice" "1" "$(grep -c '^\[b\]' "$f")"
toml_set "$f" c.size 4
check "a missing section is added once, with its key" "4" "$(map_lookup "$f" toml c.size)"
check "…and the sections before it are kept" "1" "$(map_lookup "$f" toml a.size)"

section "the registry itself is well-formed"
bad_fields=0; dupe=0; seen=""
for entry in "${SETTINGS[@]}"; do
  n=$(printf '%s' "$entry" | awk -F'|' '{print NF}')
  [[ "$n" == 16 ]] || { bad_fields=$((bad_fields+1)); echo "    16 fields expected, got $n: $(setting_field "$entry" 1)"; }
  id=$(setting_field "$entry" 1)
  [[ ",$seen," == *",$id,"* ]] && dupe=$((dupe+1))
  seen="$seen,$id"
done
check "every line has 16 fields" "0" "$bad_fields"
check "no duplicate setting ids" "0" "$dupe"
# A dropdown that lists one option twice looks broken, and lid.closeDocked
# offered `ignore` twice.
dupe_opts=""
for entry in "${SETTINGS[@]}"; do
  opts=$(setting_field "$entry" 10)
  [[ -n "$opts" ]] || continue
  d=$(tr ',' '\n' <<<"$opts" | sort | uniq -d | paste -sd, -)
  [[ -n "$d" ]] && dupe_opts+=" $(setting_field "$entry" 1):$d"
done
check "no setting offers the same option twice" "" "$dupe_opts"

section "a hint has to fit the row that draws it"
# The panel gives a setting's subtitle two lines and elides after them. There
# is no warning when a hint overruns — it just loses its tail, and two of them
# did, on the two rows whose hints carried the consequence of the setting
# ("setting it stops the font scaling it"), which is the half worth reading.
# 80 is two lines at the panel's width, measured on a capture, less room for
# the "inherited · " some rows carry in front.
HINT_MAX=80
for entry in "${SETTINGS[@]}"; do
  id=$(setting_field "$entry" 1)
  h=$(setting_field "$entry" 11)
  check_true "hint fits: $id" test "${#h}" -le "$HINT_MAX"
done

section "47 settings in their new groups"
check "47 settings total" "47" "${#SETTINGS[@]}"
check "Keyboard holds repeat, delay, layout and numlock" "4" "$(printf '%s\n' "${SETTINGS[@]}" | grep -c '^[^|]*|Keyboard|')"
check "Mouse & pointer holds five" "5" "$(printf '%s\n' "${SETTINGS[@]}" | grep -c '^[^|]*|Mouse & pointer|')"
check "Touchpad holds seven" "7" "$(printf '%s\n' "${SETTINGS[@]}" | grep -c '^[^|]*|Touchpad|')"
check "Windows holds fourteen" "14" "$(printf '%s\n' "${SETTINGS[@]}" | grep -c '^[^|]*|Windows|')"
check "seven existing ids are kept" "7" "$(for k in input.repeatRate input.repeatDelay input.kbLayout input.numlock input.naturalScroll input.tapToClick input.disableWhileTyping; do find_setting "$k" >/dev/null 2>&1 && echo kept; done | wc -l)"
check "no Input group remains" "0" "$(printf '%s\n' "${SETTINGS[@]}" | grep -c '|Input|')"
for g in "Keyboard" "Mouse & pointer" "Touchpad" "Windows"; do
  check_true "group declared: $g" grep -q "^$g|" < <(printf '%s\n' "${SETTING_GROUPS[@]}")
done
sj=$(build_settings_json)
check "panel sees 47 rows on a laptop" "47" "$(printf '%s' "$sj" | jq 'length')"
check "every row carries blocked_reason" "0" "$(printf '%s' "$sj" | jq '[.[] | select(has("blocked_reason") | not)] | length')"
# No existing field was removed: id, group, label, type, value, available,
# value_text, default_text, repo_text, can_revert_default, notice all stay.
for f in id group label type value available value_text default_text repo_text can_revert_default notice; do
  check "field kept: $f" "0" "$(printf '%s' "$sj" | jq --arg f "$f" '[.[] | select(has($f) | not)] | length')"
done

section "a clean install whose Lua files hold only commented examples"
cat > "$HOME/.config/hypr/input.lua" <<'LUA'
-- Keep only your personal input overrides here. Uncommented settings below
-- replace Omarchy's defaults.
-- hl.config({
--   input = {
--     repeat_rate = 40,
--   },
-- })
LUA
cat > "$HOME/.config/hypr/looknfeel.lua" <<'LUA'
-- Change the default Omarchy look'n'feel.
-- hl.config({
--   decoration = {
--     rounding = 8,
--   },
-- })
LUA
rm -f "$HYPRCTL_OPTIONS"
# No Hyprland answer and no file value: mouse sensitivity falls back to the
# registry default and reads as inherited, not as missing.
sj=$(build_settings_json)
check "clean mouse sensitivity inherits the registry fallback" "0" "$(printf '%s' "$sj" | jq -r '[.[] | select(.id=="input.sensitivity")][0].value')"
check "…and says so" "true" "$(printf '%s' "$sj" | jq -r '[.[] | select(.id=="input.sensitivity")][0].implicit')"
# With Hyprland answering, the effective value wins over the fallback.
printf '%s\t%s\n' input:sensitivity '{"option":"input:sensitivity","float":0.25,"set":true}' > "$HYPRCTL_OPTIONS"
sj=$(build_settings_json)
check "Hyprland effective beats the fallback" "0.25" "$(printf '%s' "$sj" | jq -r '[.[] | select(.id=="input.sensitivity")][0].value')"
rm -f "$HYPRCTL_OPTIONS"
# First write inserts the managed block at the end, keeping the comments.
set_setting_value input.sensitivity 0.2 >/dev/null 2>&1
check "first write lands" "0.2" "$(get_setting_value input.sensitivity)"
check_contains "block opens at the end" '-- replicant:settings:start' "$(cat "$HOME/.config/hypr/input.lua")"
check_contains "commented example untouched" '--     repeat_rate = 40,' "$(cat "$HOME/.config/hypr/input.lua")"

section "shared leaves stay apart: enabled and scroll_factor"
cat > "$HOME/.config/hypr/input.lua" <<'LUA'
hl.config({
  input = {
    scroll_factor = 1.0,
    touchpad = {
      scroll_factor = 0.5,
    },
  },
})
LUA
cat > "$HOME/.config/hypr/looknfeel.lua" <<'LUA'
hl.config({
  animations = {
    enabled = true,
  },
  decoration = {
    blur = {
      enabled = false,
    },
    shadow = {
      enabled = true,
    },
  },
})
LUA
check "input scroll_factor" "1.0" "$(get_setting_value input.scrollFactor)"
check "touchpad scroll_factor" "0.5" "$(get_setting_value input.touchScrollFactor)"
check "animations enabled" "true" "$(get_setting_value window.animations)"
check "blur enabled" "false" "$(get_setting_value window.blur)"
check "shadow enabled" "true" "$(get_setting_value window.shadows)"

section "reading: inherited, managed, repo and Omarchy defaults"
# Inherited: nothing written, Hyprland answers.
cat > "$HOME/.config/hypr/input.lua" <<'LUA'
hl.config({ input = { } })
LUA
printf '%s\t%s\n' input:left_handed '{"option":"input:left_handed","bool":false,"set":false}' > "$HYPRCTL_OPTIONS"
sj=$(build_settings_json)
check "inherited value is Hyprland's" "false" "$(printf '%s' "$sj" | jq -r '[.[] | select(.id=="input.leftHanded")][0].value')"
check "…marked inherited" "true" "$(printf '%s' "$sj" | jq -r '[.[] | select(.id=="input.leftHanded")][0].implicit')"
rm -f "$HYPRCTL_OPTIONS"
# Managed: the block wins over manual content above it.
cat > "$HOME/.config/hypr/input.lua" <<'LUA'
hl.config({
  input = {
    repeat_rate = 40,
  },
})
LUA
set_setting_value input.repeatRate 55 >/dev/null 2>&1
check "managed wins" "55" "$(get_setting_value input.repeatRate)"
check "manual kept above" "1" "$(grep -c 'repeat_rate = 40' "$HOME/.config/hypr/input.lua")"
# Repo: what the saved copy holds.
mkdir -p "$CONFIG_DIR/hypr"
cp "$HOME/.config/hypr/input.lua" "$CONFIG_DIR/hypr/input.lua"
check "repo value reads the saved copy" "55" "$(setting_repo_value input.repeatRate)"
# Omarchy default: the installed looknfeel ships border 2 (wiki says 1).
export OMARCHY_PATH="$TMP/omarchy-defaults"
mkdir -p "$OMARCHY_PATH/config/hypr" "$OMARCHY_PATH/default/hypr"
printf -- '-- shipped commented file, no values\n' > "$OMARCHY_PATH/config/hypr/looknfeel.lua"
cat > "$OMARCHY_PATH/default/hypr/looknfeel.lua" <<'LUA'
hl.config({
  general = {
    border_size = 2,
  },
})
LUA
check "Omarchy default wins over the wiki fallback" "2" "$(setting_default_value window.borderSize)"
export OMARCHY_PATH="$TMP/omarchy"
rm -rf "$TMP/omarchy-defaults"

section "managed block: insert, repeat, damaged markers, manual bytes"
cat > "$HOME/.config/hypr/input.lua" <<'LUA'
-- manual header survives every write
hl.config({
  input = {
    repeat_rate = 40,
  },
})
LUA
set_setting_value input.repeatRate 55 >/dev/null 2>&1
check "insert writes the block" "55" "$(lua_file_value "$HOME/.config/hypr/input.lua" "input:repeat_rate")"
cp "$HOME/.config/hypr/input.lua" /tmp/replicant-block-once.lua
set_setting_value input.repeatRate 55 >/dev/null 2>&1
check_true "repeat update is idempotent" cmp -s /tmp/replicant-block-once.lua "$HOME/.config/hypr/input.lua"
set_setting_value input.sensitivity 0.2 >/dev/null 2>&1
check "second key joins the same block" "0.2" "$(lua_file_value "$HOME/.config/hypr/input.lua" "input:sensitivity")"
check "first key still there" "55" "$(lua_file_value "$HOME/.config/hypr/input.lua" "input:repeat_rate")"
check "manual header kept" "1" "$(grep -c 'manual header survives' "$HOME/.config/hypr/input.lua")"
check "one start marker" "1" "$(grep -cF -- '-- replicant:settings:start' "$HOME/.config/hypr/input.lua")"
check "one end marker" "1" "$(grep -cF -- '-- replicant:settings:end' "$HOME/.config/hypr/input.lua")"
set_setting_value input.kbLayout us >/dev/null 2>&1
set_setting_value input.accelProfile flat >/dev/null 2>&1
check "later writes preserve an earlier enum" "us" "$(lua_file_value "$HOME/.config/hypr/input.lua" "input:kb_layout")"
check "later writes preserve a second enum" "flat" "$(lua_file_value "$HOME/.config/hypr/input.lua" "input:accel_profile")"
if command -v lua >/dev/null 2>&1; then
  if lua - "$HOME/.config/hypr/input.lua" <<'LUA' >/dev/null 2>&1
hl = { config = function(value)
  if value.input.kb_layout ~= nil then assert(type(value.input.kb_layout) == "string") end
  if value.input.accel_profile ~= nil then assert(type(value.input.accel_profile) == "string") end
end }
assert(loadfile(arg[1]))()
LUA
  then t_ok "generated Lua preserves enum types"; else t_bad "generated Lua preserves enum types"; fi
else
  t_bad "Lua interpreter is available for generated-block tests"
fi
printf '%s\n' '-- replicant:settings:start' >> "$HOME/.config/hypr/input.lua"
cp "$HOME/.config/hypr/input.lua" /tmp/replicant-block-dup.lua
check_false "duplicated markers refuse a write" set_setting_value input.repeatRate 60
check_true "duplicated markers leave the file alone" cmp -s /tmp/replicant-block-dup.lua "$HOME/.config/hypr/input.lua"
printf 'hl.config({ input = { repeat_rate = 40 } })\n-- replicant:settings:start\nbroken\n' > "$HOME/.config/hypr/input.lua"
check_false "damaged markers refuse a write" set_setting_value input.repeatRate 60
printf '%s\n' '  -- replicant:settings:start' 'hl.config({ input = { repeat_rate = 40 } })' '  -- replicant:settings:end' > "$HOME/.config/hypr/input.lua"
cp "$HOME/.config/hypr/input.lua" /tmp/replicant-block-indented.lua
check_false "indented markers refuse a write" set_setting_value input.repeatRate 60
check_true "indented markers leave the file alone" cmp -s /tmp/replicant-block-indented.lua "$HOME/.config/hypr/input.lua"
cat > "$HOME/.config/hypr/input.lua" <<'LUA'
--[[
hl.config({
  input = { repeat_rate = 99 },
})
]]
hl.config({
  input = {
    repeat_rate = 40,
    kb_layout = "es--comment",
  },
})
LUA
check "multiline comments do not create settings" "40" "$(lua_file_value "$HOME/.config/hypr/input.lua" "input:repeat_rate")"
check "quoted comment delimiters remain literal" "es--comment" "$(lua_file_value "$HOME/.config/hypr/input.lua" "input:kb_layout")"
# Restore a good file for the sections below.
cat > "$HOME/.config/hypr/input.lua" <<'LUA'
hl.config({
  input = {
    repeat_rate = 40,
  },
})
LUA
cat > "$HOME/.config/hypr/looknfeel.lua" <<'LUA'
hl.config({
  decoration = {
    rounding = 5,
  },
})
LUA

section "types, limits and steps"
check_false "int rejects decimals" set_setting_value window.rounding 5.5
check_false "int below minimum rejected" set_setting_value window.rounding -1
check_false "int above maximum rejected" set_setting_value window.rounding 101
check_false "float rejects words" set_setting_value input.sensitivity wide
check_false "float below minimum rejected" set_setting_value input.sensitivity -1.5
check_false "float above maximum rejected" set_setting_value input.sensitivity 1.5
check_false "bool rejects words" set_setting_value window.blur maybe
check_false "enum rejects unknown" set_setting_value window.layout sideways
check_false "accel_profile custom needs manual config" set_setting_value input.accelProfile custom
set_setting_value input.sensitivity -0.5 >/dev/null 2>&1
check "decimals land" "-0.5" "$(get_setting_value input.sensitivity)"
sj=$(build_settings_json)
check "sensitivity steps in 0.05" "0.05" "$(printf '%s' "$sj" | jq -r '[.[] | select(.id=="input.sensitivity")][0].display_step')"
check "column width steps in 0.01" "0.01" "$(printf '%s' "$sj" | jq -r '[.[] | select(.id=="window.columnWidth")][0].display_step')"
check "accel offers adaptive and flat only" "adaptive,flat" "$(printf '%s' "$sj" | jq -r '[.[] | select(.id=="input.accelProfile")][0].options | join(",")')"
check "layout offers four portable layouts" "dwindle,master,scrolling,monocle" "$(printf '%s' "$sj" | jq -r '[.[] | select(.id=="window.layout")][0].options | join(",")')"

section "dependencies disable their dependents"
set_setting_value window.dimInactive false >/dev/null 2>&1
sj=$(build_settings_json)
check "dim strength blocked without dim" "Turn on Dim inactive windows to use dim strength." "$(printf '%s' "$sj" | jq -r '[.[] | select(.id=="window.dimStrength")][0].blocked_reason')"
set_setting_value window.dimInactive true >/dev/null 2>&1
sj=$(build_settings_json)
check "dim strength frees with dim" "" "$(printf '%s' "$sj" | jq -r '[.[] | select(.id=="window.dimStrength")][0].blocked_reason')"
set_setting_value window.blur false >/dev/null 2>&1
sj=$(build_settings_json)
check "blur special blocked without blur" "Turn on Blur to use the special workspace blur." "$(printf '%s' "$sj" | jq -r '[.[] | select(.id=="window.blurSpecial")][0].blocked_reason')"
set_setting_value window.blur true >/dev/null 2>&1
set_setting_value window.layout dwindle >/dev/null 2>&1
sj=$(build_settings_json)
check "column width blocked without scrolling" "Switch Window layout to scrolling to use column width." "$(printf '%s' "$sj" | jq -r '[.[] | select(.id=="window.columnWidth")][0].blocked_reason')"
set_setting_value window.layout scrolling >/dev/null 2>&1
sj=$(build_settings_json)
check "column width frees on scrolling" "" "$(printf '%s' "$sj" | jq -r '[.[] | select(.id=="window.columnWidth")][0].blocked_reason')"

section "device rules warn without naming hardware"
cat > "$HOME/.config/hypr/input.lua" <<'LUA'
hl.config({
  input = {
    sensitivity = 0.2,
  },
})
hl.device({ name = "secret-mouse-1", sensitivity = -0.5 })
LUA
sj=$(build_settings_json)
check_contains "device override warns" "per-device rule" "$(printf '%s' "$sj" | jq -r '[.[] | select(.id=="input.sensitivity")][0].notice')"
check "device name stays private" "0" "$(printf '%s' "$sj" | jq -r '[.[] | select(.id=="input.sensitivity")][0].notice' | grep -c 'secret-mouse-1' || true)"
cat > "$HOME/.config/hypr/input.lua" <<'LUA'
hl.config({
  input = {
    sensitivity = 0.2,
  },
})
LUA

section "reload and configerrors: rollback, no commit, no false applied"
cat > "$HOME/.config/hypr/input.lua" <<'LUA'
hl.config({
  input = {
    repeat_rate = 40,
  },
})
LUA
head_before=$(git -C "$REPO_DIR" rev-parse HEAD 2>/dev/null || echo none)
HYPRCTL_FAIL_RELOAD=1 set_setting_value input.repeatRate 70 >/dev/null 2>&1; rc=$?
check "reload failure reports failure" "1" "$rc"
check "reload failure restores the file" "40" "$(lua_file_value "$HOME/.config/hypr/input.lua" "input:repeat_rate")"
check "reload failure commits nothing" "$head_before" "$(git -C "$REPO_DIR" rev-parse HEAD 2>/dev/null || echo none)"
unset HYPRCTL_FAIL_RELOAD
# Simulate a NEW error: configerrors is clean before the write (file holds
# 40) and reports an error after (file holds 70). A static file cannot do
# that, so swap in a stub that answers from the live file, then restore it.
cp "$TMP/fakebin/hyprctl" /tmp/replicant-hyprctl-stub.bak
cat > "$TMP/fakebin/hyprctl" <<'EOF'
#!/bin/bash
if [[ "$1" == reload ]]; then exit 0; fi
if [[ "$1" == getoption ]]; then printf '{"option":"x","int":40,"set":true}'; exit 0; fi
if [[ "$1" == configerrors ]]; then
  if grep -q "repeat_rate = 70" "$HOME/.config/hypr/input.lua" 2>/dev/null; then echo "error: invalid repeat_rate"; else echo "no errors"; fi
  exit 0
fi
exit 0
EOF
chmod +x "$TMP/fakebin/hyprctl"
head_before=$(git -C "$REPO_DIR" rev-parse HEAD 2>/dev/null || echo none)
set_setting_value input.repeatRate 70 >/dev/null 2>&1; rc=$?
check "new config error reports failure" "1" "$rc"
check "new config error restores the file" "40" "$(lua_file_value "$HOME/.config/hypr/input.lua" "input:repeat_rate")"
check "new config error commits nothing" "$head_before" "$(git -C "$REPO_DIR" rev-parse HEAD 2>/dev/null || echo none)"
cp /tmp/replicant-hyprctl-stub.bak "$TMP/fakebin/hyprctl"
chmod +x "$TMP/fakebin/hyprctl"
# Same errors as before are not new: the write stands.
printf 'error: old\n' > "$TMP/configerrors-old"
export HYPRCTL_CONFIGERRORS="$TMP/configerrors-old"
set_setting_value input.repeatRate 70 >/dev/null 2>&1; rc=$?
check "pre-existing errors do not roll back" "0" "$rc"
check "value lands despite old errors" "70" "$(lua_file_value "$HOME/.config/hypr/input.lua" "input:repeat_rate")"
unset HYPRCTL_CONFIGERRORS
# A retained old error must not hide a new error from this change.
cat > "$TMP/fakebin/hyprctl" <<'EOF'
#!/bin/bash
if [[ "$1" == reload ]]; then exit 0; fi
if [[ "$1" == getoption ]]; then printf '{"option":"x","int":40,"set":true}'; exit 0; fi
if [[ "$1" == configerrors ]]; then
  echo "error: old"
  grep -q "repeat_rate = 71" "$HOME/.config/hypr/input.lua" 2>/dev/null && echo "error: new"
  exit 0
fi
exit 0
EOF
chmod +x "$TMP/fakebin/hyprctl"
set_setting_value input.repeatRate 71 >/dev/null 2>&1; rc=$?
check "mixed old and new errors reject the change" "1" "$rc"
check "mixed errors restore the prior value" "70" "$(lua_file_value "$HOME/.config/hypr/input.lua" "input:repeat_rate")"
# A failed error query cannot prove that the candidate is valid. It must roll
# back just like a newly reported error.
cat > "$TMP/fakebin/hyprctl" <<'EOF'
#!/bin/bash
if [[ "$1" == reload ]]; then exit 0; fi
if [[ "$1" == getoption ]]; then printf '{"option":"x","int":40,"set":true}'; exit 0; fi
if [[ "$1" == configerrors ]]; then
  grep -q "repeat_rate = 72" "$HOME/.config/hypr/input.lua" 2>/dev/null && exit 1
  echo "no errors"; exit 0
fi
exit 0
EOF
chmod +x "$TMP/fakebin/hyprctl"
set_setting_value input.repeatRate 72 >/dev/null 2>&1; rc=$?
check "failed candidate error query rejects the change" "1" "$rc"
check "failed candidate error query restores the value" "70" "$(lua_file_value "$HOME/.config/hypr/input.lua" "input:repeat_rate")"
cp /tmp/replicant-hyprctl-stub.bak "$TMP/fakebin/hyprctl"
chmod +x "$TMP/fakebin/hyprctl"
# Without Hyprland there is no applied to claim: hide both test stubs so PATH
# has no hyprctl, then restore. A real /usr/bin/hyprctl still skips here and
# is covered in CI where no real Hyprland exists.
saved_path="$PATH"
stubless=$(printf '%s\n' "$PATH" | tr ':' '\n' | grep -v -x -e "$TMP/fakebin" -e "$STUB_DIR" | paste -sd: -)
if PATH="$stubless" command -v hyprctl >/dev/null 2>&1; then
  check_true "hyprctl present here, missing-path covered in CI" true
else
  PATH="$stubless" check_false "missing Hyprland rejects the change" set_setting_value input.repeatRate 71
fi
PATH="$saved_path"
# Back to a good file.
cat > "$HOME/.config/hypr/input.lua" <<'LUA'
hl.config({
  input = {
    repeat_rate = 40,
  },
})
LUA

section "new settings follow shared, profile and off"
core_scope_transact hypr/looknfeel.lua profile >/dev/null 2>&1
check "profile scope sticks for a window file" "profile" "$(scope_for hypr/looknfeel.lua)"
# Earlier sections leave direct worktree writes behind (the two-ways-back
# check edits the repo copy by hand); a selective save needs a clean tree,
# so drop what was already verified before saving through it.
git -C "$REPO_DIR" checkout -- . >/dev/null 2>&1 || true
set_setting_value window.rounding 8 >/dev/null 2>&1; rc=$?
check "profile write applies" "0" "$rc"
core_save --id hypr/looknfeel.lua -m "test profile window" >/dev/null 2>&1; rc=$?
check "profile save commits" "0" "$rc"
profile_copy=$(repo_copy_for_rel hypr/looknfeel.lua)
check "profile copy carries the window value" "8" "$(lua_file_value "$profile_copy" "decoration:rounding" 2>/dev/null || read_setting_from "$(find_setting window.rounding)" "$profile_copy")"
core_scope_transact hypr/looknfeel.lua shared >/dev/null 2>&1
core_scope_transact hypr/input.lua off >/dev/null 2>&1
check "off sticks too" "off" "$(scope_for hypr/input.lua)"
head_before=$(git -C "$REPO_DIR" rev-parse HEAD)
set_setting_value input.sensitivity 0.3 >/dev/null 2>&1; rc=$?
check "scope-off write still applies locally" "0" "$rc"
check "scope-off commits nothing" "$head_before" "$(git -C "$REPO_DIR" rev-parse HEAD)"
sj=$(build_settings_json)
check_contains "scope-off warns before the next change" "Applies locally only" "$(printf '%s' "$sj" | jq -r '[.[] | select(.id=="input.sensitivity")][0].notice')"
core_scope_transact hypr/input.lua shared >/dev/null 2>&1
# The CLI path, not just the sourced function: new ids and decimals through
# `replicant set`, committed through the owning entry like any other setting.
CLI="$HERE/../bin/replicant"
"$CLI" set input.sensitivity 0.2 >/dev/null 2>&1; rc=$?
check "CLI set accepts a decimal" "0" "$rc"
check "CLI value lands live" "0.2" "$(get_setting_value input.sensitivity)"
check "CLI value reaches the repo" "0.2" "$(setting_repo_value input.sensitivity)"

summary
