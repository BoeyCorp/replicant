#!/bin/bash
# Structured editors: deterministic shortcut, compose, and bar-layout edits
# in managed blocks, with preview-first mutations and save through the owning
# tracked entry.
#
# Runs entirely inside a temp $HOME — it never touches the real ~/.config.
set -uo pipefail

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CLI="$HERE/../bin/replicant"
# shellcheck source=tests/lib.sh
source "$HERE/lib.sh"

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
export HOME="$TMP/home"
export OMARCHY_PATH="$TMP/omarchy"
export OMARCHY_REPLICANT_HOME="$TMP/replicant"
REPO="$OMARCHY_REPLICANT_HOME/repo"
mkdir -p "$HOME/.config/hypr" "$HOME/.config/omarchy" "$OMARCHY_PATH/config"

cat > "$HOME/.config/hypr/bindings.lua" <<'LUA'
-- Personal keybindings live here.

o.bind("SUPER + T", "Terminal", "alacritty")
hl.unbind("SUPER + Q")
LUA

cat > "$HOME/.XCompose" <<'XCOMPOSE'
# Personal compose sequences.
include "/usr/share/omarchy/default/xcompose"

<Multi_key> <a> <e> : "æ"
XCOMPOSE

cat > "$HOME/.config/omarchy/shell.json" <<'JSON'
{
  "bar": {
    "position": "top",
    "transparent": false,
    "centerAnchor": "omarchy.clock",
    "layout": {
      "left": [{"id": "omarchy.menu"}],
      "center": [{"id": "omarchy.clock", "format": "HH:mm"}, {"id": "omarchy.workspaces"}],
      "right": [{"id": "omarchy.tray"}]
    }
  }
}
JSON
chmod 640 "$HOME/.config/hypr/bindings.lua" "$HOME/.XCompose" "$HOME/.config/omarchy/shell.json"

# hyprctl never talks to the real compositor: reload succeeds, configerrors is
# clean, and getoption stays silent unless a test feeds it answers.
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
exit 1
EOF
chmod +x "$TMP/fakebin/hyprctl"
cat > "$TMP/fakebin/omarchy-restart-xcompose" <<'EOF'
#!/bin/bash
echo "restarted" >> "$REPLICANT_XCOMPOSE_LOG"
[[ "${XCOMPOSE_FAIL:-0}" == 1 ]] && exit 1
exit 0
EOF
chmod +x "$TMP/fakebin/omarchy-restart-xcompose"
export PATH="$TMP/fakebin:$PATH"
export REPLICANT_XCOMPOSE_LOG="$TMP/xcompose.log"

run() { "$CLI" "$@" 2>&1; }

check_true "initial repository setup succeeds" "$CLI" init

section "shortcut list shows managed and unmanaged rows"
check_contains "plain list names the terminal binding" "SUPER + T" "$(run shortcut list)"
out=$(run shortcut list --json)
check "list is valid JSON" "0" "$(printf '%s' "$out" | jq empty >/dev/null 2>&1; echo $?)"
check "list finds two rows" "2" "$(printf '%s' "$out" | jq 'length')"
check "none is managed yet" "0" "$(printf '%s' "$out" | jq '[.[] | select(.managed)] | length')"

section "shortcut add previews first and writes only with --apply"
cp "$HOME/.config/hypr/bindings.lua" "$TMP/bindings.orig"
prev=$(run shortcut add "SUPER + R" "alacritty -e ranger")
check_contains "preview names the planned file" "bindings.lua" "$prev"
check_contains "preview shows a unified diff" "@@" "$prev"
check_contains "preview shows the new line" 'o.bind("SUPER + R"' "$prev"
check_true "preview changes nothing" cmp -s "$HOME/.config/hypr/bindings.lua" "$TMP/bindings.orig"
check_contains "dry run wins over apply" "Preview only" "$(run shortcut add "SUPER + R" "x" --dry-run --apply)"
check_true "dry run wins over apply" cmp -s "$HOME/.config/hypr/bindings.lua" "$TMP/bindings.orig"
run shortcut add "SUPER + R" "alacritty -e ranger" --apply >/dev/null 2>&1; rc=$?
check "apply succeeds" "0" "$rc"
check_contains "managed block opens" "replicant:shortcuts:start" "$(cat "$HOME/.config/hypr/bindings.lua")"
check_contains "new binding lands in the block" 'o.bind("SUPER + R", nil, "alacritty -e ranger")' "$(cat "$HOME/.config/hypr/bindings.lua")"
check_contains "unmanaged bytes survive" 'o.bind("SUPER + T", "Terminal", "alacritty")' "$(cat "$HOME/.config/hypr/bindings.lua")"
check "one start marker" "1" "$(grep -cF -- '-- replicant:shortcuts:start' "$HOME/.config/hypr/bindings.lua")"
check "one end marker" "1" "$(grep -cF -- '-- replicant:shortcuts:end' "$HOME/.config/hypr/bindings.lua")"
check "backup left behind" "1" "$(ls "$HOME/.config/hypr"/bindings.lua.bak.* 2>/dev/null | wc -l)"
check "save commits the owner" "shortcuts: add SUPER + R" "$(git -C "$REPO" log -1 --format=%s)"
check "repo copy carries the binding" "1" "$(grep -c 'SUPER + R' "$REPO/config/hypr/bindings.lua" 2>/dev/null || true)"
check "shortcut edit keeps the file mode" "640" "$(stat -c %a "$HOME/.config/hypr/bindings.lua")"

section "shortcut add refuses duplicates and bad input"
check_false "managed duplicate refused" run shortcut add "SUPER + R" "xterm" --apply
check "…and the file is untouched" "1" "$(grep -c 'SUPER + R' "$HOME/.config/hypr/bindings.lua")"
check_false "unmanaged duplicate refused" run shortcut add "SUPER + T" "xterm" --apply
check_false "empty keys refused" run shortcut add "" "xterm" --apply
check_false "empty command refused" run shortcut add "SUPER + Z" "" --apply
check_false "quotes in keys refused" run shortcut add 'SUPER + "X"' "xterm" --apply
check_false "shortcut add rejects an extra operand" run shortcut add "SUPER + Z" "xterm" extra --apply
check_false "shortcut remove rejects an extra operand" run shortcut remove "SUPER + R" extra --apply
check_false "shortcut remove rejects add options" run shortcut remove "SUPER + R" --desc ignored --apply

section "descriptions and special characters round-trip"
run shortcut add "SUPER + E" "thunar" --desc 'Files "here" (a & b)' --apply >/dev/null 2>&1
check_contains "quoted description lands escaped" 'Files \"here\"' "$(cat "$HOME/.config/hypr/bindings.lua")"
out=$(run shortcut list --json)
check "description parses back" 'Files "here" (a & b)' "$(printf '%s' "$out" | jq -r '[.[] | select(.keys=="SUPER + E")][0].description')"
check "new row is managed" "true" "$(printf '%s' "$out" | jq -r '[.[] | select(.keys=="SUPER + E")][0].managed')"
run shortcut add "SUPER + W" "xterm -e 'echo hi'" --apply >/dev/null 2>&1
check_contains "single quotes survive" "echo hi" "$(cat "$HOME/.config/hypr/bindings.lua")"

section "shortcut disable, restore and remove"
run shortcut disable "SUPER + SHIFT + B" --apply >/dev/null 2>&1; rc=$?
check "disable of a default succeeds" "0" "$rc"
check_contains "unbind line lands" 'hl.unbind("SUPER + SHIFT + B")' "$(cat "$HOME/.config/hypr/bindings.lua")"
check_false "double disable refused" run shortcut disable "SUPER + SHIFT + B" --apply
check_false "disabling an unmanaged unbind refused" run shortcut disable "SUPER + Q" --apply
check_false "disabling a managed bind refused" run shortcut disable "SUPER + R" --apply
run shortcut restore "SUPER + SHIFT + B" --apply >/dev/null 2>&1
check "restore removes the unbind" "0" "$(grep -c 'SUPER + SHIFT + B' "$HOME/.config/hypr/bindings.lua" || true)"
check_false "restoring without an unbind refused" run shortcut restore "SUPER + SHIFT + B" --apply
run shortcut remove "SUPER + R" --apply >/dev/null 2>&1
check "remove deletes the binding" "0" "$(grep -c 'SUPER + R' "$HOME/.config/hypr/bindings.lua" || true)"
check_false "removing an unmanaged binding refused" run shortcut remove "SUPER + T" --apply
check "…and it is still there" "1" "$(grep -c 'SUPER + T' "$HOME/.config/hypr/bindings.lua")"
check_false "removing an absent binding refused" run shortcut remove "SUPER + ZZZ" --apply

section "an add replaces a managed unbind for the same keys"
run shortcut disable "SUPER + D" --apply >/dev/null 2>&1
run shortcut add "SUPER + D" "dolphin" --apply >/dev/null 2>&1
check "unbind is gone" "0" "$(grep -c 'hl.unbind("SUPER + D")' "$HOME/.config/hypr/bindings.lua" || true)"
check "bind is there" "1" "$(grep -c 'o.bind("SUPER + D"' "$HOME/.config/hypr/bindings.lua")"

section "damaged markers refuse without touching the file"
cp "$HOME/.config/hypr/bindings.lua" "$TMP/bindings.good"
printf '%s\n' '-- replicant:shortcuts:start' >> "$HOME/.config/hypr/bindings.lua"
cp "$HOME/.config/hypr/bindings.lua" "$TMP/bindings.dup"
check_false "duplicated markers refuse an add" run shortcut add "SUPER + Y" "xterm" --apply
check_true "duplicated markers leave the file alone" cmp -s "$HOME/.config/hypr/bindings.lua" "$TMP/bindings.dup"
cp "$TMP/bindings.good" "$HOME/.config/hypr/bindings.lua"
printf -- '-- replicant:shortcuts:end\n-- replicant:shortcuts:start\n' >> "$HOME/.config/hypr/bindings.lua"
check_false "markers out of order refuse a disable" run shortcut disable "SUPER + Y" --apply
cp "$TMP/bindings.good" "$HOME/.config/hypr/bindings.lua"
printf 'hl.config({ input = { repeat_rate = 40 } })\n-- replicant:shortcuts:start\nbroken\n' > "$HOME/.config/hypr/bindings.lua"
check_false "missing end marker refuses a remove" run shortcut remove "SUPER + T" --apply
cp "$TMP/bindings.good" "$HOME/.config/hypr/bindings.lua"

section "a failed reload restores the file and commits nothing"
head_before=$(git -C "$REPO" rev-parse HEAD)
HYPRCTL_FAIL_RELOAD=1 run shortcut add "SUPER + Y" "xterm" --apply >/dev/null 2>&1; rc=$?
check "reload failure reports failure" "1" "$rc"
check "reload failure restores the file" "0" "$(grep -c 'SUPER + Y' "$HOME/.config/hypr/bindings.lua" || true)"
check "reload failure commits nothing" "$head_before" "$(git -C "$REPO" rev-parse HEAD)"
unset HYPRCTL_FAIL_RELOAD

section "restore-file brings back the structured change"
run shortcut add "SUPER + U" "xterm" --apply >/dev/null 2>&1
printf '\n-- a local edit after the save\n' >> "$HOME/.config/hypr/bindings.lua"
run restore-file hypr/bindings.lua >/dev/null 2>&1; rc=$?
check "restore succeeds" "0" "$rc"
check "repo binding is back" "1" "$(grep -c 'SUPER + U' "$HOME/.config/hypr/bindings.lua")"
check "local edit is gone" "0" "$(grep -c 'a local edit after the save' "$HOME/.config/hypr/bindings.lua" || true)"

section "compose list, add and remove"
out=$(run compose list --json)
check "compose list is valid JSON" "0" "$(printf '%s' "$out" | jq empty >/dev/null 2>&1; echo $?)"
check "compose list finds one row" "1" "$(printf '%s' "$out" | jq 'length')"
check "existing row is unmanaged" "false" "$(printf '%s' "$out" | jq -r '.[0].managed')"
cp "$HOME/.XCompose" "$TMP/xcompose.orig"
prev=$(run compose add '<Multi_key> <s> <s>' 'ß')
check_contains "compose preview shows the entry" '<Multi_key> <s> <s>' "$prev"
check_true "compose preview changes nothing" cmp -s "$HOME/.XCompose" "$TMP/xcompose.orig"
run compose add '<Multi_key> <s> <s>' 'ß' --apply >/dev/null 2>&1; rc=$?
check "compose add succeeds" "0" "$rc"
check "compose entry lands in the block" "1" "$(grep -c '<Multi_key> <s> <s>' "$HOME/.XCompose")"
check "compose block opens" "1" "$(grep -cF -- '# replicant:compose:start' "$HOME/.XCompose")"
check "xcompose restarted" "1" "$(grep -c restarted "$REPLICANT_XCOMPOSE_LOG" 2>/dev/null || true)"
check "unmanaged entry survives" "1" "$(grep -c '<Multi_key> <a> <e>' "$HOME/.XCompose")"
check "save commits the owner" "compose: add <Multi_key> <s> <s>" "$(git -C "$REPO" log -1 --format=%s)"
check "repo copy carries the sequence" "1" "$(grep -c '<Multi_key> <s> <s>' "$REPO/config/home/XCompose" 2>/dev/null || true)"
check "compose edit keeps the file mode" "640" "$(stat -c %a "$HOME/.XCompose")"
check_false "duplicate compose refused" run compose add '<Multi_key> <s> <s>' 'x' --apply
check_false "unmanaged duplicate refused" run compose add '<Multi_key> <a> <e>' 'x' --apply
check_false "bare token refused" run compose add 'Multi_key a' 'x' --apply
check_false "empty result refused" run compose add '<Multi_key> <q> <q>' '' --apply
check_false "compose add rejects an extra operand" run compose add '<Multi_key> <q> <q>' x extra --apply
check_false "compose remove rejects an extra operand" run compose remove '<Multi_key> <s> <s>' extra --apply
run compose add '<Multi_key> <o> <e>' 'œ "quoted"' --apply >/dev/null 2>&1
check_contains "unicode and quotes land escaped" 'œ \"quoted\"' "$(cat "$HOME/.XCompose")"
out=$(run compose list --json)
check "unicode result parses back" 'œ "quoted"' "$(printf '%s' "$out" | jq -r '[.[] | select(.sequence=="<Multi_key> <o> <e>")][0].result')"
run compose remove '<Multi_key> <s> <s>' --apply >/dev/null 2>&1
check "compose remove deletes the entry" "0" "$(grep -c '<Multi_key> <s> <s>' "$HOME/.XCompose" || true)"
check_false "removing an unmanaged sequence refused" run compose remove '<Multi_key> <a> <e>' --apply
check "…and it is still there" "1" "$(grep -c '<Multi_key> <a> <e>' "$HOME/.XCompose")"
check_false "removing an absent sequence refused" run compose remove '<Multi_key> <z> <z>' --apply

section "compose starts from nothing and survives damage"
rm -f "$HOME/.XCompose"
XCOMPOSE_FAIL=1 run compose add '<Multi_key> <c> <c>' '©' --apply >/dev/null 2>&1; rc=$?
check "failed first restart reports failure" "1" "$rc"
check_false "failed first restart removes the new file" test -e "$HOME/.XCompose"
unset XCOMPOSE_FAIL
run compose add '<Multi_key> <c> <c>' '©' --apply >/dev/null 2>&1; rc=$?
check "first add creates the file" "0" "$rc"
check "created file keeps the default include" "1" "$(grep -c 'default/xcompose' "$HOME/.XCompose")"
check "created file holds the entry" "1" "$(grep -c '<Multi_key> <c> <c>' "$HOME/.XCompose")"
cp "$HOME/.XCompose" "$TMP/xcompose.created"
printf '%s\n' '# replicant:compose:start' >> "$HOME/.XCompose"
cp "$HOME/.XCompose" "$TMP/xcompose.dup"
check_false "duplicated compose markers refuse" run compose add '<Multi_key> <d> <d>' 'x' --apply
check_true "duplicated markers leave the file alone" cmp -s "$HOME/.XCompose" "$TMP/xcompose.dup"
cp "$TMP/xcompose.created" "$HOME/.XCompose"
XCOMPOSE_FAIL=1 run compose add '<Multi_key> <d> <d>' 'x' --apply >/dev/null 2>&1; rc=$?
check "failed restart reports failure" "1" "$rc"
check "failed restart restores the file" "0" "$(grep -c '<Multi_key> <d> <d>' "$HOME/.XCompose" || true)"
unset XCOMPOSE_FAIL

section "bar-layout list shows sections in order"
out=$(run bar-layout list --json)
check "bar list is valid JSON" "0" "$(printf '%s' "$out" | jq empty >/dev/null 2>&1; echo $?)"
check "bar list finds four widgets" "4" "$(printf '%s' "$out" | jq 'length')"
check "first is the left menu" "omarchy.menu" "$(printf '%s' "$out" | jq -r '.[0].id')"
check_contains "plain list names sections" "center:1" "$(run bar-layout list)"

section "bar-layout move keeps settings and previews first"
cp "$HOME/.config/omarchy/shell.json" "$TMP/shell.orig"
prev=$(run bar-layout move omarchy.tray --section left --index 0)
check_contains "move preview shows the diff" "@@" "$prev"
check_true "move preview changes nothing" cmp -s "$HOME/.config/omarchy/shell.json" "$TMP/shell.orig"
run bar-layout move omarchy.tray --section left --index 0 --apply >/dev/null 2>&1; rc=$?
check "move succeeds" "0" "$rc"
check "tray is first on the left" "omarchy.tray" "$(jq -r '.bar.layout.left[0].id' "$HOME/.config/omarchy/shell.json")"
run bar-layout move omarchy.clock --section right --after omarchy.tray --apply >/dev/null 2>&1
check "clock keeps its format after a move" "HH:mm" "$(jq -r '[.bar.layout.left[], .bar.layout.center[], .bar.layout.right[]] | map(select(.id=="omarchy.clock"))[0].format' "$HOME/.config/omarchy/shell.json")"
check "save commits the owner" "bar: move omarchy.tray" "$(git -C "$REPO" log -1 --format=%s)"
check "bar edit keeps the file mode" "640" "$(stat -c %a "$HOME/.config/omarchy/shell.json")"
check_false "moving an absent widget refused" run bar-layout move omarchy.nope --section left --apply
check_false "moving without a section refused" run bar-layout move omarchy.menu --apply
check_false "bad section refused" run bar-layout move omarchy.menu --section top --apply
check_false "anchor in another section refused" run bar-layout move omarchy.menu --section left --after center:0 --apply
check_false "past-the-end index accepted silently" run bar-layout move omarchy.menu --section left --index 99 --apply

section "bar-layout enable, disable and spacers"
run bar-layout enable omarchy.weather --section right --apply >/dev/null 2>&1; rc=$?
check "enable succeeds" "0" "$rc"
check "weather is on the right" "1" "$(jq '[.bar.layout.right[] | select(.id=="omarchy.weather")] | length' "$HOME/.config/omarchy/shell.json")"
check_false "enabling a duplicate refused" run bar-layout enable omarchy.weather --section right --apply
check_false "enabling without a section refused" run bar-layout enable omarchy.other --apply
run bar-layout spacer --section center --apply >/dev/null 2>&1
check "spacer lands with the default size" "12" "$(jq '[.bar.layout.center[] | select(.id=="omarchy.spacer")] | map(.size)[0]' "$HOME/.config/omarchy/shell.json")"
run bar-layout spacer --section left --size 20 --before left:0 --apply >/dev/null 2>&1
check "sized spacer lands first" "20" "$(jq '.bar.layout.left[0].size' "$HOME/.config/omarchy/shell.json")"
check_false "bad spacer size refused" run bar-layout spacer --section left --size 0 --apply
run bar-layout disable omarchy.weather --apply >/dev/null 2>&1; rc=$?
check "disable succeeds" "0" "$rc"
check "weather is off the bar" "0" "$(jq '[.bar.layout.left[], .bar.layout.center[], .bar.layout.right[]] | map(select(.id=="omarchy.weather")) | length' "$HOME/.config/omarchy/shell.json")"
check_false "disabling an absent widget refused" run bar-layout disable omarchy.weather --apply
check_false "disable rejects an extra operand" run bar-layout disable omarchy.menu extra --apply
run bar-layout disable left:0 --apply >/dev/null 2>&1; rc=$?
check "spacer disables by section:index" "0" "$rc"
check "spacer is gone" "0" "$(jq '[.bar.layout.left[] | select(.id=="omarchy.spacer")] | length' "$HOME/.config/omarchy/shell.json")"

section "a corrupt bar file refuses the change"
printf '{oops' > "$HOME/.config/omarchy/shell.json"
check_false "corrupt shell.json refuses a move" run bar-layout move omarchy.menu --section left --apply
cp "$TMP/shell.orig" "$HOME/.config/omarchy/shell.json"
printf '{"bar":{}}' > "$HOME/.config/omarchy/shell.json"
check_false "missing layout refuses a move" run bar-layout move omarchy.menu --section left --apply
cp "$TMP/shell.orig" "$HOME/.config/omarchy/shell.json"

section "help names every operation"
check_contains "shortcut help lists add" "shortcut add" "$(run shortcut --help)"
check_contains "shortcut help lists remove" "shortcut remove" "$(run shortcut --help)"
check_contains "compose help lists add" "compose add" "$(run compose --help)"
check_contains "bar help lists spacer" "bar-layout spacer" "$(run bar-layout --help)"
check_contains "usage lists the editors" "bar-layout move" "$(run --help)"

summary
