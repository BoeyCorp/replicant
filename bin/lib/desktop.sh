# shellcheck shell=bash disable=SC2034
# desktop.sh: profile-aware workspace and display editors. Sourced by
# replicant-core.sh, which sets the paths it uses. It defines functions and
# data and runs nothing.
#
# Two files, two scopes. Application rules and workspace structure
# (names, layouts, keep-empty) are portable, so they live in a managed block
# in hypr/hyprland.lua (shared). Monitor assignments and display entries are
# per-machine, so they live in managed blocks in hypr/monitors.lua (profile).
# Everything outside the blocks is preserved byte-for-byte, and markers that
# are missing, duplicated, nested, or out of order refuse the change.
#
# Physical identifiers (desc: serials, makes, models) never reach public
# output: lists and previews print them redacted, and fixtures use fake ones.

DESK_WS_START="-- replicant:workspaces:start"
DESK_WS_END="-- replicant:workspaces:end"
DESK_APP_START="-- replicant:apprules:start"
DESK_APP_END="-- replicant:apprules:end"
DESK_MON_START="-- replicant:monitors:start"
DESK_MON_END="-- replicant:monitors:end"
DESK_ASG_START="-- replicant:assignments:start"
DESK_ASG_END="-- replicant:assignments:end"

desktop_hyprland_file() { printf '%s\n' "$HOME/.config/hypr/hyprland.lua"; }
desktop_monitors_file() { printf '%s\n' "$HOME/.config/hypr/monitors.lua"; }

# desktop_redact [<text>] — mask desc: physical identifiers. Managed entries
# use connector names, so anything matching desc: here is somebody's serial.
# With no argument, filter stdin (for preview diffs that quote file content).
desktop_redact() {
  if (( $# )); then
    sed -e 's/desc:[^"`]*\(["`]\|$\)/desc:<redacted>\1/g' <<<"$1"
  else
    sed -e 's/desc:[^"`]*\(["`]\|$\)/desc:<redacted>\1/g'
  fi
}

# ── capability: what Hyprland sees right now ──────────────────────────────
# hyprctl monitors -j answers name, description, availableModes and friends.
# Anything using it tolerates its absence: without a compositor there is
# nothing to check against, and the caller says so instead of failing.

desktop_monitors_json() {
  command -v hyprctl >/dev/null 2>&1 || return 1
  hyprctl monitors -j 2>/dev/null | jq -e . 2>/dev/null || return 1
}

desktop_monitor_connected() {
  local name="$1" monitors
  monitors=$(desktop_monitors_json) || return 1
  jq -e --arg n "$name" 'any(.[]; .name == $n)' <<<"$monitors" >/dev/null 2>&1
}

desktop_monitor_modes() {
  local name="$1" monitors
  monitors=$(desktop_monitors_json) || return 1
  jq -r --arg n "$name" '.[] | select(.name == $n) | .availableModes[]?' <<<"$monitors" 2>/dev/null
}

# desktop_mode_ok <monitor> <mode> — preferred always works, anything else
# must be one of the connected monitor's available modes (integer refresh
# matches its decimal reporting: 165 matches 165.00Hz).
desktop_mode_ok() {
  local name="$1" mode="$2" m
  [[ "$mode" == "preferred" ]] && return 0
  while IFS= read -r m; do
    [[ -z "$m" ]] && continue
    [[ "$m" == "$mode"* ]] && return 0
  done < <(desktop_monitor_modes "$name" 2>/dev/null || true)
  return 1
}

# ── parsing: one record per call ──────────────────────────────────────────
# hl.* and o.window calls span lines, so the reader accumulates a balanced
# call and pulls fields out of the blob. getq reads one quoted string with
# escapes; bare words (true, 2) match directly. Unparseable calls are
# skipped, never guessed at: an exotic hand-written rule stays untouched
# and unlisted. Markers are full lines, so block membership is exact.
# Transport: one line per record, "managed\037blob", with blob newlines
# folded to \034 (a byte that never appears in these files).

# desktop_hl_records <file> <func> <start> <end> — each hl.<func>(...) call.
desktop_hl_records() {
  local file="$1" func="$2" s="$3" e="$4" rc=0
  structured_block_check "$file" "$s" "$e"; rc=$?
  (( rc == 1 )) && return 1
  [[ -f "$file" ]] || return 0
  awk -v fn="$func" -v s="$s" -v e="$e" '
    $0 == s { inside = 1; next }
    $0 == e { inside = 0; next }
    /^[[:space:]]*--/ && !incall { next }
    {
      line = $0
      if (!incall) {
        if (match(line, "hl\\." fn "[[:space:]]*\\(")) {
          incall = 1; depth = 0; instr = 0; blob = ""
          rest = substr(line, RSTART + RLENGTH - 1)
          for (i = 1; i <= length(rest); i++) {
            ch = substr(rest, i, 1)
            if (ch == "\"" && substr(rest, i - 1, 1) != "\\") instr = !instr
            if (!instr) {
              if (ch == "(") depth++
              if (ch == ")") depth--
            }
          }
          blob = rest
          if (depth <= 0 && !instr) { gsub(/\n/, "\034", blob); printf "%s\037%s\n", (inside ? "1" : "0"), blob; incall = 0 }
          next
        }
      } else {
        for (i = 1; i <= length(line); i++) {
          ch = substr(line, i, 1)
          if (ch == "\"" && substr(line, i - 1, 1) != "\\") instr = !instr
          if (!instr) {
            if (ch == "(") depth++
            if (ch == ")") depth--
          }
        }
        blob = blob "\n" line
        if (depth <= 0 && !instr) { gsub(/\n/, "\034", blob); printf "%s\037%s\n", (inside ? "1" : "0"), blob; incall = 0 }
      }
    }
  ' "$file"
}

# desktop_app_records <file> <start> <end> — each o.window(...) call.
desktop_app_records() {
  local file="$1" s="$2" e="$3" rc=0
  structured_block_check "$file" "$s" "$e"; rc=$?
  (( rc == 1 )) && return 1
  [[ -f "$file" ]] || return 0
  awk -v s="$s" -v e="$e" '
    $0 == s { inside = 1; next }
    $0 == e { inside = 0; next }
    /^[[:space:]]*--/ && !incall { next }
    {
      line = $0
      if (!incall) {
        if (match(line, "o\\.window[[:space:]]*\\(")) {
          incall = 1; depth = 0; instr = 0; blob = ""
          rest = substr(line, RSTART + RLENGTH - 1)
          for (i = 1; i <= length(rest); i++) {
            ch = substr(rest, i, 1)
            if (ch == "\"" && substr(rest, i - 1, 1) != "\\") instr = !instr
            if (!instr) {
              if (ch == "(") depth++
              if (ch == ")") depth--
            }
          }
          blob = rest
          if (depth <= 0 && !instr) { gsub(/\n/, "\034", blob); printf "%s\037%s\n", (inside ? "1" : "0"), blob; incall = 0 }
          next
        }
      } else {
        for (i = 1; i <= length(line); i++) {
          ch = substr(line, i, 1)
          if (ch == "\"" && substr(line, i - 1, 1) != "\\") instr = !instr
          if (!instr) {
            if (ch == "(") depth++
            if (ch == ")") depth--
          }
        }
        blob = blob "\n" line
        if (depth <= 0 && !instr) { gsub(/\n/, "\034", blob); printf "%s\037%s\n", (inside ? "1" : "0"), blob; incall = 0 }
      }
    }
  ' "$file"
}

# desktop_unfold <transport-line> — print the blob with newlines restored.
desktop_unfold() {
  local rec="$1"
  printf '%s' "${rec#*$'\037'}" | tr '\034' '\n'
}

# desktop_flag <transport-line> — the managed flag (1 or 0).
desktop_flag() {
  printf '%s' "${1%%$'\037'*}"
}

# desktop_field <blob> <key> — the value of `key = ...` in a call blob:
# a quoted string unescaped, or a bare word. Empty when absent.
desktop_field() {
  local blob="$1" key="$2"
  awk -v k="$key" '
    function getq(line, from,   i, ch, out) {
      out = ""
      for (i = from + 1; i <= length(line); i++) {
        ch = substr(line, i, 1)
        if (ch == "\\") { out = out substr(line, i + 1, 1); i++; continue }
        if (ch == "\"") return out
        out = out ch
      }
      return ""
    }
    BEGIN { text = "" }
    { text = text $0 "\n" }
    END {
      if (match(text, k "[[:space:]]*=[[:space:]]*")) {
        rest = substr(text, RSTART + RLENGTH)
        if (rest ~ /^"/) {
          print getq(rest, 1)
        } else if (match(rest, /^[^,}[:space:]]+/)) {
          val = substr(rest, RSTART, RLENGTH)
          # Only literals resolve statically: a bare identifier
          # (scale = omarchy_monitor_scale) names no value.
          if (val ~ /^(true|false|-?[0-9]+(\.[0-9]+)?)$/) print val
        }
      }
    }
  ' <<<"$blob"
}

# desktop_ws_rows <file> <start> <end> — "ws\037monitor\037default\037persistent\037name\037layout\037managed".
desktop_ws_rows() {
  local file="$1" s="$2" e="$3" rec managed blob ws
  while IFS= read -r rec; do
    managed=$(desktop_flag "$rec"); blob=$(desktop_unfold "$rec")
    ws=$(desktop_field "$blob" "workspace") || ws=""
    [[ -n "$ws" ]] || continue
    [[ "$ws" =~ ^[0-9]+$ || "$ws" == name:* || "$ws" == special:* ]] || continue
    printf '%s\037%s\037%s\037%s\037%s\037%s\037%s\n' \
      "$ws" "$(desktop_field "$blob" "monitor")" "$(desktop_field "$blob" "default")" \
      "$(desktop_field "$blob" "persistent")" "$(desktop_field "$blob" "default_name")" \
      "$(desktop_field "$blob" "layout")" "$managed"
  done < <(desktop_hl_records "$file" "workspace_rule" "$s" "$e") || return 1
}

# desktop_mon_rows <file> — "output\037mode\037scale\037transform\037position\037mirror\037bitdepth\037vrr\037disabled\037managed".
desktop_mon_rows() {
  local file="$1" rec managed blob out
  while IFS= read -r rec; do
    managed=$(desktop_flag "$rec"); blob=$(desktop_unfold "$rec")
    out=$(desktop_field "$blob" "output") || out=""
    [[ -n "$out" ]] || continue
    printf '%s\037%s\037%s\037%s\037%s\037%s\037%s\037%s\037%s\037%s\n' \
      "$out" "$(desktop_field "$blob" "mode")" "$(desktop_field "$blob" "scale")" \
      "$(desktop_field "$blob" "transform")" "$(desktop_field "$blob" "position")" \
      "$(desktop_field "$blob" "mirror")" "$(desktop_field "$blob" "bitdepth")" \
      "$(desktop_field "$blob" "vrr")" "$(desktop_field "$blob" "disabled")" "$managed"
  done < <(desktop_hl_records "$file" "monitor" "$DESK_MON_START" "$DESK_MON_END") || return 1
}

# desktop_first_string <blob> — the first quoted string of a call (the
# o.window class). Empty when there is none.
desktop_first_string() {
  local blob="$1"
  awk '
    function getq(line, from,   i, ch, out) {
      out = ""
      for (i = from + 1; i <= length(line); i++) {
        ch = substr(line, i, 1)
        if (ch == "\\") { out = out substr(line, i + 1, 1); i++; continue }
        if (ch == "\"") return out
        out = out ch
      }
      return ""
    }
    BEGIN { text = "" }
    { text = text $0 "\n" }
    END {
      i = index(text, "\"")
      if (i > 0) print getq(text, i)
    }
  ' <<<"$blob"
}

# desktop_app_rows <file> — "class\037workspace\037managed".
desktop_app_rows() {
  local file="$1" rec managed blob cls ws
  while IFS= read -r rec; do
    managed=$(desktop_flag "$rec"); blob=$(desktop_unfold "$rec")
    cls=$(desktop_first_string "$blob")
    ws=$(desktop_field "$blob" "workspace") || ws=""
    [[ -n "$cls" && -n "$ws" ]] || continue
    [[ "$ws" =~ ^[0-9]+$ ]] || continue
    printf '%s\037%s\037%s\n' "$cls" "$ws" "$managed"
  done < <(desktop_app_records "$file" "$DESK_APP_START" "$DESK_APP_END") || return 1
}

# ── validation ──────────────────────────────────────────────────────────
desktop_valid_ws() {
  [[ "$1" =~ ^[0-9]+$ && "$1" -ge 1 && "$1" -le 20 ]] \
    || { echo "workspace: '$1' must be a workspace 1-20" >&2; return 1; }
}

desktop_valid_name() {
  [[ "$1" =~ ^[A-Za-z0-9_.-]+$ ]] \
    || { echo "workspace: '$1' must be letters, digits, dot, dash or underscore" >&2; return 1; }
}

desktop_valid_layout() {
  case "$1" in
    dwindle|master|scrolling|monocle|"") return 0 ;;
    *) echo "workspace: '$1' must be dwindle, master, scrolling or monocle" >&2; return 1 ;;
  esac
}

desktop_valid_persistent() {
  case "$1" in
    on|true) return 0 ;;
    off|false) return 0 ;;
    *) echo "workspace: persistent must be on or off" >&2; return 1 ;;
  esac
}

desktop_valid_class() {
  local cls="$1"
  [[ -n "$cls" ]] || { echo "workspace: the class must not be empty" >&2; return 1; }
  [[ "$cls" != *\"* && "$cls" != *\\* ]] || { echo "workspace: the class must not hold quotes or backslashes" >&2; return 1; }
  [[ "$cls" != *$'\n'* && "$cls" != *$'\t'* ]] || { echo "workspace: the class must be one line" >&2; return 1; }
}

desktop_valid_output() {
  local out="$1"
  [[ -n "$out" ]] || { echo "display: the monitor must not be empty" >&2; return 1; }
  [[ "$out" != *\"* && "$out" != *\\* ]] || { echo "display: the monitor must not hold quotes or backslashes" >&2; return 1; }
  [[ "$out" != *$'\n'* && "$out" != *$'\t'* ]] || { echo "display: the monitor must be one line" >&2; return 1; }
}

desktop_valid_mode() {
  [[ "$1" =~ ^(preferred|[0-9]+x[0-9]+(@[0-9]+(\.[0-9]+)?)?)$ ]] \
    || { echo "display: '$1' must be preferred or WIDTHxHEIGHT[@REFRESH]" >&2; return 1; }
}

desktop_valid_scale() {
  [[ "$1" =~ ^[0-9]*\.?[0-9]+$ ]] || { echo "display: '$1' is not a scale factor" >&2; return 1; }
  awk -v v="$1" 'BEGIN { exit !(v + 0 >= 0.5 && v + 0 <= 4) }' </dev/null \
    || { echo "display: scale must be 0.5-4" >&2; return 1; }
}

desktop_valid_transform() {
  [[ "$1" =~ ^[0-7]$ ]] || { echo "display: transform must be 0-7 (0-3 rotate, 4-7 flipped)" >&2; return 1; }
}

desktop_valid_position() {
  [[ "$1" =~ ^(auto|-?[0-9]+x-?[0-9]+)$ ]] \
    || { echo "display: '$1' must be auto or XxY" >&2; return 1; }
}

desktop_valid_vrr() {
  [[ "$1" =~ ^[0-2]$ ]] || { echo "display: vrr must be 0, 1 or 2" >&2; return 1; }
}

# ── workspace structure + app rules (shared, hyprland.lua) ──────────────
# desktop_ws_build <op> [args] — candidate inner lines for the workspaces block.
desktop_ws_build() {
  local op="$1" ws="$2" name="${3:-}" layout="${4:-}" persistent="${5:-}"
  local file rows inner
  local r_w r_m r_d r_p r_n r_l r_mgd found=0
  file=$(desktop_hyprland_file)
  desktop_valid_ws "$ws" || return 1
  rows=$(desktop_ws_rows "$file" "$DESK_WS_START" "$DESK_WS_END") \
    || { echo "workspace: markers are duplicated or damaged in $file — left untouched" >&2; return 1; }
  while IFS=$'\037' read -r r_w r_m r_d r_p r_n r_l r_mgd; do
    [[ "$r_w" == "$ws" && "$r_mgd" == "1" && -z "$r_m" ]] || continue
    found=1; break
  done <<<"$rows"
  inner=$(mktemp) || return 1
  # shellcheck disable=SC2064
  trap "rm -f '$inner'" RETURN
  structured_block_lines "$file" "$DESK_WS_START" "$DESK_WS_END" > "$inner" 2>/dev/null || true
  case "$op" in
    define)
      [[ -n "$name" || -n "$layout" || -n "$persistent" ]] \
        || { echo "workspace: define needs --name, --layout or --persistent" >&2; return 1; }
      [[ -z "$name" ]] || desktop_valid_name "$name" || return 1
      [[ -z "$layout" ]] || desktop_valid_layout "$layout" || return 1
      [[ -z "$persistent" ]] || desktop_valid_persistent "$persistent" || return 1
      if (( found )); then
        # A partial define merges: only the named fields change.
        [[ -n "$name" ]] || name="$r_n"
        [[ -n "$layout" ]] || layout="$r_l"
        if [[ -z "$persistent" ]]; then
          [[ "$r_p" == true ]] && persistent=on
          [[ "$r_p" == false ]] && persistent=off
        fi
      fi
      local line="hl.workspace_rule({ workspace = \"$ws\""
      [[ -z "$name" ]] || line+=", default_name = \"$name\""
      [[ -z "$layout" ]] || line+=", layout = \"$layout\""
      if [[ -n "$persistent" ]]; then
        [[ "$persistent" == on || "$persistent" == true ]] && line+=", persistent = true" || line+=", persistent = false"
      fi
      line+=" })"
      if (( found )); then
        awk -v ws="$ws" '
          $0 ~ "workspace[[:space:]]*=[[:space:]]*\"" ws "\"" {
            if (/\}\)/) next
            skip = 1; next
          }
          skip && /\}\)/ { skip = 0; next }
          !skip { print }
        ' "$inner" > "$inner.new" || return 1
        mv -- "$inner.new" "$inner"
      fi
      printf '%s\n' "$line" >> "$inner" || return 1
      ;;
    undefine)
      (( found )) || { echo "workspace: no workspace $ws is defined by Replicant" >&2; return 1; }
      awk -v ws="$ws" '
        $0 ~ "workspace[[:space:]]*=[[:space:]]*\"" ws "\"" {
          if (/\}\)/) next
          skip = 1; next
        }
        skip && /\}\)/ { skip = 0; next }
        !skip { print }
      ' "$inner" > "$inner.new" || return 1
      mv -- "$inner.new" "$inner"
      ;;
    *) echo "workspace: unknown operation '$op'" >&2; return 1 ;;
  esac
  cat -- "$inner"
}

# desktop_app_build <op> <class> [ws] — candidate inner lines for the app block.
desktop_app_build() {
  local op="$1" cls="$2" ws="${3:-}"
  local file rows inner
  local r_c r_w r_m found=0 unmanaged=0
  file=$(desktop_hyprland_file)
  desktop_valid_class "$cls" || return 1
  rows=$(desktop_app_rows "$file") \
    || { echo "workspace: markers are duplicated or damaged in $file — left untouched" >&2; return 1; }
  while IFS=$'\037' read -r r_c r_w r_m; do
    [[ "$r_c" == "$cls" ]] || continue
    if [[ "$r_m" == "1" ]]; then found=1; else unmanaged=1; fi
  done <<<"$rows"
  inner=$(mktemp) || return 1
  # shellcheck disable=SC2064
  trap "rm -f '$inner'" RETURN
  structured_block_lines "$file" "$DESK_APP_START" "$DESK_APP_END" > "$inner" 2>/dev/null || true
  case "$op" in
    app-add)
      desktop_valid_ws "$ws" || return 1
      (( found == 0 )) || { echo "workspace: '$cls' is already managed — remove it first" >&2; return 1; }
      (( unmanaged == 0 )) || { echo "workspace: '$cls' already has a rule in your file — remove it there first" >&2; return 1; }
      local qcls
      qcls=$(structured_lua_quote "$cls") || { echo "workspace: the class holds an unsupported character" >&2; return 1; }
      printf 'o.window(%s, { workspace = "%s" })\n' "$qcls" "$ws" >> "$inner" || return 1
      ;;
    app-remove)
      (( found )) || {
        (( unmanaged )) && { echo "workspace: '$cls' is yours, not Replicant's — edit the file directly" >&2; return 1; }
        echo "workspace: no Replicant rule for '$cls'" >&2; return 1; }
      local qcls line
      qcls=$(structured_lua_quote "$cls" | tr -d '\n') || return 1
      line=$(grep -nF "o.window($qcls," "$inner" | cut -d: -f1 | head -n1 || true)
      [[ -n "$line" ]] || { echo "workspace: no Replicant rule for '$cls'" >&2; return 1; }
      sed -e "${line}d" "$inner" > "$inner.new" || return 1
      mv -- "$inner.new" "$inner"
      ;;
    *) echo "workspace: unknown operation '$op'" >&2; return 1 ;;
  esac
  cat -- "$inner"
}

# desktop_count_build <n> — persistent 1..N on, persistent dropped above N.
desktop_count_build() {
  local want="$1" file rows inner
  local r_w r_m r_d r_p r_n r_l r_mgd
  file=$(desktop_hyprland_file)
  desktop_valid_ws "$want" || return 1
  rows=$(desktop_ws_rows "$file" "$DESK_WS_START" "$DESK_WS_END") \
    || { echo "workspace: markers are duplicated or damaged in $file — left untouched" >&2; return 1; }
  declare -A have_name=() have_layout=() have_persist=()
  while IFS=$'\037' read -r r_w r_m r_d r_p r_n r_l r_mgd; do
    [[ "$r_mgd" == "1" && -z "$r_m" ]] || continue
    [[ -n "$r_n" ]] && have_name["$r_w"]="$r_n"
    [[ -n "$r_l" ]] && have_layout["$r_w"]="$r_l"
    [[ -n "$r_p" ]] && have_persist["$r_w"]="$r_p"
  done <<<"$rows"
  inner=$(mktemp) || return 1
  # shellcheck disable=SC2064
  trap "rm -f '$inner'" RETURN
  local i line
  for (( i = 1; i <= want; i++ )); do
    line="hl.workspace_rule({ workspace = \"$i\""
    [[ -z "${have_name[$i]:-}" ]] || line+=", default_name = \"${have_name[$i]}\""
    [[ -z "${have_layout[$i]:-}" ]] || line+=", layout = \"${have_layout[$i]}\""
    line+=", persistent = true })"
    printf '%s\n' "$line" >> "$inner" || return 1
  done
  # Re-emit rules above N that still carry a name or a layout.
  declare -A done_above=()
  local key
  for key in "${!have_name[@]}" "${!have_layout[@]}"; do
    w="$key"
    (( 10#$w > want )) || continue
    [[ -z "${done_above[$w]:-}" ]] || continue
    done_above["$w"]=1
    line="hl.workspace_rule({ workspace = \"$w\""
    [[ -z "${have_name[$w]:-}" ]] || line+=", default_name = \"${have_name[$w]}\""
    [[ -z "${have_layout[$w]:-}" ]] || line+=", layout = \"${have_layout[$w]}\""
    line+=" })"
    printf '%s\n' "$line" >> "$inner" || return 1
  done
  cat -- "$inner"
}

# ── monitor assignments + display entries (profile, monitors.lua) ─────────
# desktop_asg_build <op> <ws> [monitor] [default] — candidate inner lines.
desktop_asg_build() {
  local op="$1" ws="$2" monitor="${3:-}" def="${4:-}" file rows inner
  local r_w r_m r_d r_p r_n r_l r_mgd found=0
  file=$(desktop_monitors_file)
  desktop_valid_ws "$ws" || return 1
  rows=$(desktop_ws_rows "$file" "$DESK_ASG_START" "$DESK_ASG_END") \
    || { echo "workspace: markers are duplicated or damaged in $file — left untouched" >&2; return 1; }
  while IFS=$'\037' read -r r_w r_m r_d r_p r_n r_l r_mgd; do
    [[ "$r_w" == "$ws" && "$r_mgd" == "1" ]] || continue
    found=1; break
  done <<<"$rows"
  inner=$(mktemp) || return 1
  # shellcheck disable=SC2064
  trap "rm -f '$inner'" RETURN
  structured_block_lines "$file" "$DESK_ASG_START" "$DESK_ASG_END" > "$inner" 2>/dev/null || true
  case "$op" in
    assign)
      [[ -n "$monitor" ]] || { echo "workspace: assign needs a monitor" >&2; return 1; }
      desktop_valid_output "$monitor" || return 1
      if (( found )); then
        awk -v ws="$ws" '
          $0 ~ "workspace[[:space:]]*=[[:space:]]*\"" ws "\"" {
            if (/\}\)/) next
            skip = 1; next
          }
          skip && /\}\)/ { skip = 0; next }
          !skip { print }
        ' "$inner" > "$inner.new" || return 1
        mv -- "$inner.new" "$inner"
      fi
      local line="hl.workspace_rule({ workspace = \"$ws\", monitor = \"$monitor\""
      [[ "$def" == true ]] && line+=", default = true"
      line+=" })"
      printf '%s\n' "$line" >> "$inner" || return 1
      ;;
    unassign)
      (( found )) || { echo "workspace: no Replicant assignment for workspace $ws" >&2; return 1; }
      awk -v ws="$ws" '
        $0 ~ "workspace[[:space:]]*=[[:space:]]*\"" ws "\"" {
          if (/\}\)/) next
          skip = 1; next
        }
        skip && /\}\)/ { skip = 0; next }
        !skip { print }
      ' "$inner" > "$inner.new" || return 1
      mv -- "$inner.new" "$inner"
      ;;
    *) echo "workspace: unknown operation '$op'" >&2; return 1 ;;
  esac
  cat -- "$inner"
}

# desktop_mon_build <op> [args] — candidate inner lines for the monitors block.
# set: upsert by output, merging with the existing managed entry.
desktop_mon_build() {
  local op="$1"; shift
  local file rows inner
  local output="" mode="" scale="" transform="" position="" mirror="" bitdepth="" vrr="" disabled=""
  file=$(desktop_monitors_file)
  case "$op" in
    set|disable|enable|remove|default) output="${1:-}"; shift || true ;;
    *) echo "display: unknown operation '$op'" >&2; return 1 ;;
  esac
  [[ -n "$output" ]] || { echo "display: $op needs a monitor" >&2; return 1; }
  desktop_valid_output "$output" || return 1
  while (( $# )); do case "$1" in
    --mode) mode="${2:-}"; shift 2 ;;
    --scale) scale="${2:-}"; shift 2 ;;
    --rotation|--transform) transform="${2:-}"; shift 2 ;;
    --position) position="${2:-}"; shift 2 ;;
    --mirror) mirror="${2:-}"; shift 2 ;;
    --vrr) vrr="${2:-}"; shift 2 ;;
    --hdr) bitdepth="10"; shift ;;
    --no-hdr) bitdepth="8"; shift ;;
    *) echo "display: unknown option '$1'" >&2; return 1 ;;
  esac; done
  if [[ "$op" == set ]]; then
    [[ -n "$mode$scale$transform$position$mirror$bitdepth$vrr" ]] \
      || { echo "display: set needs at least one option (--mode, --scale, --rotation, --position, --mirror, --vrr, --hdr)" >&2; return 1; }
    [[ -z "$mode" ]] || desktop_valid_mode "$mode" || return 1
    [[ -z "$scale" ]] || desktop_valid_scale "$scale" || return 1
    [[ -z "$transform" ]] || desktop_valid_transform "$transform" || return 1
    [[ -z "$position" ]] || desktop_valid_position "$position" || return 1
    [[ -z "$mirror" ]] || desktop_valid_output "$mirror" || return 1
    [[ -z "$vrr" ]] || desktop_valid_vrr "$vrr" || return 1
  fi
  local r_o r_rest r_mgd found=0
  rows=$(desktop_mon_rows "$file") \
    || { echo "display: markers are duplicated or damaged in $file — left untouched" >&2; return 1; }
  local cur_mode="" cur_scale="" cur_transform="" cur_position="" cur_mirror="" cur_bitdepth="" cur_vrr="" cur_disabled=""
  while IFS=$'\037' read -r r_o r_mode r_scale r_tr r_pos r_mir r_bd r_vrr r_dis r_mgd; do
    [[ "$r_o" == "$output" && "$r_mgd" == "1" ]] || continue
    found=1
    cur_mode="$r_mode"; cur_scale="$r_scale"; cur_transform="$r_tr"; cur_position="$r_pos"
    cur_mirror="$r_mir"; cur_bitdepth="$r_bd"; cur_vrr="$r_vrr"; cur_disabled="$r_dis"
    break
  done <<<"$rows"
  inner=$(mktemp) || return 1
  # shellcheck disable=SC2064
  trap "rm -f '$inner'" RETURN
  structured_block_lines "$file" "$DESK_MON_START" "$DESK_MON_END" > "$inner" 2>/dev/null || true
  # Drop the existing managed entry; the new one is appended below.
  if (( found )); then
    awk -v out="$output" '
      $0 ~ "output[[:space:]]*=[[:space:]]*\"" out "\"" {
        if (/\}\)/) next
        skip = 1; next
      }
      skip && /\}\)/ { skip = 0; next }
      !skip { print }
    ' "$inner" > "$inner.new" || return 1
    mv -- "$inner.new" "$inner"
  fi
  case "$op" in
    remove)
      (( found )) || { echo "display: no Replicant entry for '$output'" >&2; return 1; }
      ;;
    disable|enable)
      if [[ "$op" == disable ]]; then
        cur_disabled="true"
      elif (( found )); then
        cur_disabled=""
      else
        echo "display: no Replicant entry for '$output' — use set to create one" >&2; return 1
      fi
      desktop_mon_emit "$output" "$cur_mode" "$cur_scale" "$cur_transform" "$cur_position" \
        "$cur_mirror" "$cur_bitdepth" "$cur_vrr" "$cur_disabled" >> "$inner" || return 1
      ;;
    set)
      [[ -n "$mode" ]] && cur_mode="$mode"
      [[ -n "$scale" ]] && cur_scale="$scale"
      [[ -n "$transform" ]] && cur_transform="$transform"
      [[ -n "$position" ]] && cur_position="$position"
      [[ -n "$mirror" ]] && cur_mirror="$mirror"
      [[ -n "$bitdepth" ]] && cur_bitdepth="$bitdepth"
      [[ -n "$vrr" ]] && cur_vrr="$vrr"
      desktop_mon_emit "$output" "$cur_mode" "$cur_scale" "$cur_transform" "$cur_position" \
        "$cur_mirror" "$cur_bitdepth" "$cur_vrr" "$cur_disabled" >> "$inner" || return 1
      ;;
  esac
  cat -- "$inner"
}

# desktop_mon_emit — one canonical hl.monitor line. Empty fields are omitted,
# except disabled=false which is dropped (enabled is the default).
desktop_mon_emit() {
  local output="$1" mode="$2" scale="$3" transform="$4" position="$5"
  local mirror="$6" bitdepth="$7" vrr="$8" disabled="$9"
  local line="hl.monitor({ output = \"$output\""
  [[ -z "$mode" ]] || line+=", mode = \"$mode\""
  [[ -z "$position" ]] || line+=", position = \"$position\""
  [[ -z "$scale" ]] || line+=", scale = $scale"
  [[ -z "$transform" ]] || line+=", transform = $transform"
  [[ -z "$mirror" ]] || line+=", mirror = \"$mirror\""
  [[ -z "$bitdepth" ]] || line+=", bitdepth = $bitdepth"
  [[ -z "$vrr" ]] || line+=", vrr = $vrr"
  [[ "$disabled" == true ]] && line+=", disabled = true"
  line+=" })"
  printf '%s\n' "$line"
}

# ── lists ─────────────────────────────────────────────────────────────────
desktop_workspace_list() {
  local json=0 sfile mfile
  [[ "${1:-}" == "--json" ]] && json=1
  sfile=$(desktop_hyprland_file); mfile=$(desktop_monitors_file)
  local srows arows
  srows=$(desktop_ws_rows "$sfile" "$DESK_WS_START" "$DESK_WS_END" 2>/dev/null || true)
  arows=$(desktop_ws_rows "$mfile" "$DESK_ASG_START" "$DESK_ASG_END" 2>/dev/null || true)
  local apps
  apps=$(desktop_app_rows "$sfile" 2>/dev/null || true)
  if (( json )); then
    {
      printf '{\n"workspaces": '
      {
        [[ -z "$srows" ]] || printf '%s\n' "$srows"
        [[ -z "$arows" ]] || printf '%s\n' "$arows"
      } | jq -Rsc 'split("\n") | map(select(length > 0) | split("\u001f")
        | {workspace: .[0], monitor: .[1], default: .[2], persistent: .[3],
           name: .[4], layout: .[5], managed: (.[6] == "1")})'
      printf ', "apps": '
      if [[ -z "$apps" ]]; then printf '[]\n'; else
        printf '%s\n' "$apps" | jq -Rsc 'split("\n") | map(select(length > 0) | split("\u001f")
          | {class: .[0], workspace: .[1], managed: (.[2] == "1")})'
      fi
      printf '}\n'
    } | jq -c . 2>/dev/null | desktop_redact || { echo "workspace: cannot list" >&2; return 1; }
    return 0
  fi
  printf 'Workspaces (shared structure + profile assignments)\n'
  if [[ -z "$srows" && -z "$arows" ]]; then
    echo "  none — define one with: replicant workspace define 1 --persistent on --apply"
  else
    {
      [[ -z "$srows" ]] || printf '%s\n' "$srows"
      [[ -z "$arows" ]] || printf '%s\n' "$arows"
    } | while IFS=$'\037' read -r w m d p n l mgd; do
      printf '  %-4s %-16s %-10s %-12s %-14s %s\n' "$w" "${n:-—}" "${l:-—}" \
        "$([ "$p" == true ] && echo "keep-empty" || echo "")" \
        "$([ -n "$m" ] && echo "→ $(desktop_redact "$m")$([ "$d" == true ] && echo " (default)" || echo "")" || echo "")" \
        "$([ "$mgd" == 1 ] && echo "[managed]" || echo "")"
    done
  fi
  printf 'Application rules\n'
  if [[ -z "$apps" ]]; then
    echo "  none — add one with: replicant workspace app-add '<class>' <n> --apply"
  else
    printf '%s\n' "$apps" | while IFS=$'\037' read -r c w mgd; do
      printf '  %-24s → workspace %s%s\n' "$c" "$w" "$([ "$mgd" == 1 ] && echo " [managed]" || echo "")"
    done
  fi
}

desktop_display_list() {
  local json=0 file
  [[ "${1:-}" == "--json" ]] && json=1
  file=$(desktop_monitors_file)
  local rows monitors
  rows=$(desktop_mon_rows "$file" 2>/dev/null || true)
  monitors=$(desktop_monitors_json 2>/dev/null || true)
  if (( json )); then
    {
      printf '['
      local first=1
      while IFS=$'\037' read -r o mo sc tr po mi bd vr dis mgd; do
        [[ -z "$o" ]] && continue
        (( first )) && first=0 || printf ','
        o=$(desktop_redact "$o")
        mi=$(desktop_redact "$mi")
        jq -cn --arg o "$o" --arg mo "$mo" --arg sc "$sc" --arg tr "$tr" \
          --arg po "$po" --arg mi "$mi" --arg bd "$bd" --arg vr "$vr" \
          --arg dis "$dis" --argjson mgd "$([ "$mgd" == 1 ] && echo true || echo false)" \
          '{output: $o, mode: $mo, scale: $sc, transform: $tr, position: $po,
            mirror: $mi, bitdepth: $bd, vrr: $vr, disabled: $dis, managed: $mgd}'
      done <<<"$rows"
      printf ']\n'
    } | jq -c . 2>/dev/null || { echo "display: cannot list" >&2; return 1; }
    return 0
  fi
  printf 'Displays in %s\n' "$file"
  if [[ -z "$rows" ]]; then
    echo "  none managed — set one with: replicant display set <monitor> --mode WxH@R --apply"
  else
    printf '%s\n' "$rows" | while IFS=$'\037' read -r o mo sc tr po mi bd vr dis mgd; do
      local state=""
      [[ "$dis" == true ]] && state="disabled"
      [[ "$bd" == 10 ]] && state="${state:+$state, }HDR"
      printf '  %-28s %-16s scale %-5s %s%s%s\n' "$(desktop_redact "$o")" "${mo:-preferred}" \
        "${sc:-auto}" "$state" "" "$([ "$mgd" == 1 ] && echo " [managed]" || echo "")"
    done
  fi
  if [[ -n "$monitors" ]]; then
    printf 'Connected now\n'
    jq -r '.[] | "  \(.name)  \(.width)x\(.height)@\(.refreshRate)Hz  scale \(.scale)"' <<<"$monitors" 2>/dev/null || true
  else
    echo "  (no compositor to ask — capability checks skipped)"
  fi
}
