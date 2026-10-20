# shellcheck shell=bash disable=SC2034
# structured.sh: deterministic structured editors for shortcuts, compose
# sequences, and the bar layout. Sourced by replicant-core.sh, which sets the
# paths it uses. It defines functions and data and runs nothing.
#
# A structured edit owns an explicit managed block (bindings.lua, .XCompose)
# or an explicit JSON subtree (shell.json bar.layout). Everything outside the
# block is preserved byte-for-byte. Markers that are missing, duplicated,
# nested, or out of order refuse the change without touching the file.
#
# Every mutating entry point prints a unified preview first. Nothing is
# written without --apply, and an --apply writes through backup, validation,
# the official reload, and the owning tracked entry.

STRUCT_SHORT_START="-- replicant:shortcuts:start"
STRUCT_SHORT_END="-- replicant:shortcuts:end"
STRUCT_COMP_START="# replicant:compose:start"
STRUCT_COMP_END="# replicant:compose:end"

structured_bindings_file() { printf '%s\n' "$HOME/.config/hypr/bindings.lua"; }
structured_compose_file() { printf '%s\n' "$HOME/.XCompose"; }
structured_shell_file() { printf '%s\n' "$HOME/.config/omarchy/shell.json"; }

# structured_block_check <file> <start> <end>: 0 block present and well-formed,
# 2 no block, 1 duplicated or damaged markers (do not modify the file).
structured_block_check() {
  local file="$1" s="$2" e="$3" ns ne cs ce sl el
  [[ -f "$file" ]] || return 2
  ns=$(grep -cF -- "$s" "$file" 2>/dev/null || true)
  ne=$(grep -cF -- "$e" "$file" 2>/dev/null || true)
  [[ "$ns" == "0" && "$ne" == "0" ]] && return 2
  [[ "$ns" == "1" && "$ne" == "1" ]] || return 1
  cs=$(grep -cxF -- "$s" "$file" 2>/dev/null || true)
  ce=$(grep -cxF -- "$e" "$file" 2>/dev/null || true)
  [[ "$cs" == "1" && "$ce" == "1" ]] || return 1
  sl=$(grep -nxF -- "$s" "$file" | cut -d: -f1)
  el=$(grep -nxF -- "$e" "$file" | cut -d: -f1)
  [[ -n "$sl" && -n "$el" && "$sl" -lt "$el" ]] || return 1
  return 0
}

# structured_block_lines <file> <start> <end> — inner lines of the managed
# block. Empty when the file carries no block. Fails on damaged markers.
structured_block_lines() {
  local file="$1" s="$2" e="$3" rc=0
  structured_block_check "$file" "$s" "$e"; rc=$?
  (( rc == 2 )) && return 0
  (( rc != 0 )) && return 1
  awk -v s="$s" -v e="$e" '
    $0 == s { inside = 1; next }
    $0 == e { inside = 0; next }
    inside { print }
  ' "$file"
}

# structured_block_outside <file> <start> <end> — the file with the managed
# block removed. Fails on damaged markers so the caller never edits half a
# file. Missing file reads as empty.
structured_block_outside() {
  local file="$1" s="$2" e="$3" rc=0
  [[ -f "$file" ]] || return 0
  structured_block_check "$file" "$s" "$e"; rc=$?
  (( rc == 2 )) && { cat -- "$file"; return 0; }
  (( rc != 0 )) && return 1
  awk -v s="$s" -v e="$e" '
    $0 == s { skip = 1; next }
    $0 == e { skip = 0; next }
    !skip { print }
  ' "$file"
}

# structured_block_candidate <file> <start> <end> <inner-tmp> <out> [header]
# — the full file with the managed block replaced, written to <out>. Outside
# bytes are preserved; the block sits at the end. Rejects duplicated or
# damaged markers. A missing file starts from the optional header text.
structured_block_candidate() {
  local file="$1" s="$2" e="$3" inner="$4" out="$5" header="${6:-}" rc=0
  local tmp_out
  tmp_out=$(mktemp) || return 1
  # shellcheck disable=SC2064
  trap "rm -f '$tmp_out'" RETURN
  if [[ -f "$file" ]]; then
    structured_block_check "$file" "$s" "$e"; rc=$?
    (( rc == 1 )) && return 1
    if (( rc == 0 )); then
      structured_block_outside "$file" "$s" "$e" > "$tmp_out" || return 1
    else
      cat -- "$file" > "$tmp_out" || return 1
    fi
  else
    if [[ -n "$header" ]]; then
      printf '%s\n' "$header" > "$tmp_out" || return 1
    else
      : > "$tmp_out" || return 1
    fi
  fi
  if [[ -s "$tmp_out" ]] && [[ -n "$(tail -c1 "$tmp_out" 2>/dev/null)" ]]; then
    printf '\n' >> "$tmp_out" || return 1
  fi
  {
    printf '%s\n' "$s"
    cat -- "$inner" 2>/dev/null || true
    printf '%s\n' "$e"
  } >> "$tmp_out" || return 1
  [[ -s "$tmp_out" ]] || return 1
  mv -- "$tmp_out" "$out" || return 1
}

# structured_lua_quote <value> — the Lua quoted literal, or failure when the
# value carries a newline or control character. Backslashes and double quotes
# are escaped; tabs are refused rather than guessed at.
structured_lua_quote() {
  local v="$1"
  [[ "$v" != *$'\n'* && "$v" != *$'\t'* ]] || return 1
  [[ "$v" =~ [[:cntrl:]] ]] && return 1
  v="${v//\\/\\\\}"
  v="${v//\"/\\\"}"
  printf '"%s"\n' "$v"
}

# ── shortcuts ─────────────────────────────────────────────────────────────
# Managed lines are o.bind("KEYS", "DESC", "CMD") or o.bind("KEYS", nil,
# "CMD"), and hl.unbind("KEYS"). Keys never hold a quote or a backslash, so
# the first quoted string on the line is the whole identity.

structured_shortcut_keys_of() {
  local line="$1" i rest
  i=$(awk -v s="$line" 'BEGIN { print index(s, "\"") }')
  [[ "$i" -gt 0 ]] || return 1
  rest="${line:$i}"
  rest="${rest%%\"*}"
  [[ -n "$rest" ]] || return 1
  printf '%s\n' "$rest"
}

# structured_shortcut_rows <file> — "keys<TAB>desc<TAB>cmd<TAB>kind<TAB>managed"
# for every uncommented o.bind and hl.unbind in the file.
structured_shortcut_rows() {
  local file="$1" rc=0
  structured_block_check "$file" "$STRUCT_SHORT_START" "$STRUCT_SHORT_END"; rc=$?
  (( rc == 1 )) && return 1
  [[ -f "$file" ]] || return 0
  awk -v s="$STRUCT_SHORT_START" -v e="$STRUCT_SHORT_END" '
    function getq(line, from,   i, ch, out) {
      out = ""
      for (i = from + 1; i <= length(line); i++) {
        ch = substr(line, i, 1)
        if (ch == "\\") { out = out substr(line, i + 1, 1); i++; continue }
        if (ch == "\"") return out SUBSEP i
        out = out ch
      }
      return out SUBSEP 0
    }
    $0 == s { inside = 1; next }
    $0 == e { inside = 0; next }
    /^[[:space:]]*--/ { next }
    {
      line = $0; managed = (inside ? "true" : "false")
      if (match(line, /o\.bind[[:space:]]*\(/)) {
        rest = substr(line, RSTART + RLENGTH)
        qi = index(rest, "\""); if (qi == 0) next
        n = split(getq(rest, qi), q, SUBSEP); key = q[1]; rest = substr(rest, q[2] + 1)
        sub(/^[[:space:]]*,[[:space:]]*/, "", rest)
        if (rest ~ /^nil([^A-Za-z0-9_]|$)/) {
          desc = ""; sub(/^nil/, "", rest)
          sub(/^[[:space:]]*,[[:space:]]*/, "", rest)
        } else {
          qi = index(rest, "\""); if (qi == 0) next
          n = split(getq(rest, qi), qd, SUBSEP); desc = qd[1]; rest = substr(rest, qd[2] + 1)
          sub(/^[[:space:]]*,[[:space:]]*/, "", rest)
        }
        qi = index(rest, "\""); if (qi == 0) next
        n = split(getq(rest, qi), qc, SUBSEP); cmd = qc[1]
        if (key != "") printf "%s\037%s\037%s\037bind\037%s\n", key, desc, cmd, managed
        next
      }
      if (match(line, /hl\.unbind[[:space:]]*\(/)) {
        rest = substr(line, RSTART + RLENGTH)
        qi = index(rest, "\""); if (qi == 0) next
        n = split(getq(rest, qi), q, SUBSEP)
        if (q[1] != "") printf "%s\037\037\037unbind\037%s\n", q[1], managed
        next
      }
    }
  ' "$file"
}

structured_shortcut_list() {
  local json=0 file rows
  [[ "${1:-}" == "--json" ]] && json=1
  file=$(structured_bindings_file)
  rows=$(structured_shortcut_rows "$file" 2>/dev/null || true)
  if (( json )); then
    if [[ -z "$rows" ]]; then printf '[]\n'; else
      printf '%s\n' "$rows" | jq -Rsc 'split("\n") | map(select(length > 0) | split("\u001f")
        | {keys: .[0], description: .[1], command: .[2], kind: .[3], managed: (.[4] == "true")})'
    fi
    return 0
  fi
  printf 'Shortcuts in %s\n' "$file"
  if [[ -z "$rows" ]]; then
    echo "  none — add one with: replicant shortcut add <keys> <command> [--desc text]"
    return 0
  fi
  printf '%s\n' "$rows" | while IFS=$'\x1f' read -r k d c kind mgd; do
    if [[ "$kind" == "unbind" ]]; then
      printf '  %-24s (unbound)%s\n' "$k" "$([[ "$mgd" == true ]] && echo " [managed]" || true)"
    else
      printf '  %-24s %-30s %s%s\n' "$k" "${d:-$c}" "" "$([[ "$mgd" == true ]] && echo " [managed]" || true)"
    fi
  done
}

structured_shortcut_validate_keys() {
  local keys="$1"
  [[ -n "$keys" ]] || { echo "shortcut: keys must not be empty" >&2; return 1; }
  [[ "$keys" != *\"* && "$keys" != *\\* ]] || { echo "shortcut: keys must not hold quotes or backslashes" >&2; return 1; }
  [[ "$keys" != *$'\n'* && "$keys" != *$'\t'* ]] || { echo "shortcut: keys must be one line" >&2; return 1; }
}

# structured_shortcut_build <op> <keys> [desc] [cmd] — print the candidate
# managed-block inner lines for the operation to stdout. Fails with the reason
# on stderr when the operation is refused.
structured_shortcut_build() {
  local op="$1" keys="$2" desc="${3:-}" cmd="${4:-}" file rows inner
  local k d c kind mgd found_bind=0 found_unbind=0 unmanaged_bind=0 unmanaged_unbind=0
  file=$(structured_bindings_file)
  structured_shortcut_validate_keys "$keys" || return 1
  rows=$(structured_shortcut_rows "$file" 2>/dev/null) || { echo "shortcut: markers are duplicated or damaged in $file — left untouched" >&2; return 1; }
  while IFS=$'\x1f' read -r k d c kind mgd; do
    [[ "$k" == "$keys" ]] || continue
    if [[ "$kind" == "bind" ]]; then
      if [[ "$mgd" == "true" ]]; then found_bind=1; else unmanaged_bind=1; fi
    else
      if [[ "$mgd" == "true" ]]; then found_unbind=1; else unmanaged_unbind=1; fi
    fi
  done <<<"$rows"
  inner=$(mktemp) || return 1
  # shellcheck disable=SC2064
  trap "rm -f '$inner'" RETURN
  structured_block_lines "$file" "$STRUCT_SHORT_START" "$STRUCT_SHORT_END" > "$inner" 2>/dev/null || true
  case "$op" in
    add)
      [[ -n "$cmd" ]] || { echo "shortcut: add needs a command" >&2; return 1; }
      (( found_bind == 0 )) || { echo "shortcut: '$keys' is already bound by Replicant — remove it first" >&2; return 1; }
      (( unmanaged_bind == 0 )) || { echo "shortcut: '$keys' is already bound in your file — unbind it there first" >&2; return 1; }
      [[ "$cmd" != *$'\n'* ]] || { echo "shortcut: the command must be one line" >&2; return 1; }
      local qkeys qcmd qdesc
      qkeys=$(structured_lua_quote "$keys") || { echo "shortcut: keys hold an unsupported character" >&2; return 1; }
      qcmd=$(structured_lua_quote "$cmd") || { echo "shortcut: the command holds an unsupported character" >&2; return 1; }
      if [[ -n "$desc" ]]; then
        qdesc=$(structured_lua_quote "$desc") || { echo "shortcut: the description holds an unsupported character" >&2; return 1; }
      else
        qdesc="nil"
      fi
      # A managed unbind for the same keys would silence the new binding, so
      # the add replaces it. The preview shows both halves.
      if (( found_unbind )); then
        grep -vF "hl.unbind($(structured_lua_quote "$keys" | tr -d '\n'))" "$inner" > "$inner.new" 2>/dev/null || true
        mv -- "$inner.new" "$inner"
      fi
      printf 'o.bind(%s, %s, %s)\n' "$qkeys" "$qdesc" "$qcmd" >> "$inner" || return 1
      ;;
    disable)
      (( found_unbind == 0 )) || { echo "shortcut: '$keys' is already disabled by Replicant" >&2; return 1; }
      (( unmanaged_unbind == 0 )) || { echo "shortcut: '$keys' is already unbound in your file" >&2; return 1; }
      (( found_bind == 0 )) || { echo "shortcut: '$keys' is a Replicant binding — remove it instead" >&2; return 1; }
      local qkeys
      qkeys=$(structured_lua_quote "$keys") || { echo "shortcut: keys hold an unsupported character" >&2; return 1; }
      printf 'hl.unbind(%s)\n' "$qkeys" >> "$inner" || return 1
      ;;
    restore)
      (( found_unbind )) || { echo "shortcut: '$keys' has no Replicant unbind to restore" >&2; return 1; }
      local qkeys
      qkeys=$(structured_lua_quote "$keys" | tr -d '\n') || return 1
      grep -vF "hl.unbind($qkeys)" "$inner" > "$inner.new" 2>/dev/null || true
      mv -- "$inner.new" "$inner"
      ;;
    remove)
      (( found_bind )) || {
        (( unmanaged_bind )) && { echo "shortcut: '$keys' is yours, not Replicant's — edit the file directly" >&2; return 1; }
        echo "shortcut: '$keys' is not a Replicant binding" >&2; return 1; }
      local qkeys line
      qkeys=$(structured_lua_quote "$keys" | tr -d '\n') || return 1
      line=$(grep -nF "o.bind($qkeys," "$inner" | cut -d: -f1 | head -n1 || true)
      [[ -n "$line" ]] || { echo "shortcut: '$keys' is not a Replicant binding" >&2; return 1; }
      sed -e "${line}d" "$inner" > "$inner.new" || return 1
      mv -- "$inner.new" "$inner"
      ;;
    *) echo "shortcut: unknown operation '$op'" >&2; return 1 ;;
  esac
  cat -- "$inner"
}

# ── compose ───────────────────────────────────────────────────────────────
# Managed lines are XCompose entries: <Multi_key> <a> : "result". The block
# markers are full-line # comments, so ordinary # comments never collide.

structured_compose_valid_sequence() {
  local seq="$1" tok
  [[ -n "$seq" ]] || { echo "compose: the sequence must not be empty" >&2; return 1; }
  [[ "$seq" != *\"* && "$seq" != *\\* ]] || { echo "compose: the sequence must not hold quotes or backslashes" >&2; return 1; }
  [[ "$seq" != *$'\n'* && "$seq" != *$'\t'* ]] || { echo "compose: the sequence must be one line" >&2; return 1; }
  for tok in $seq; do
    [[ "$tok" =~ ^\<[A-Za-z0-9_]+\>$ ]] || { echo "compose: '$tok' is not a <keysym> token" >&2; return 1; }
  done
}

# structured_compose_rows <file> — "sequence<TAB>result<TAB>managed".
structured_compose_rows() {
  local file="$1" rc=0
  structured_block_check "$file" "$STRUCT_COMP_START" "$STRUCT_COMP_END"; rc=$?
  (( rc == 1 )) && return 1
  [[ -f "$file" ]] || return 0
  awk -v s="$STRUCT_COMP_START" -v e="$STRUCT_COMP_END" '
    $0 == s { inside = 1; next }
    $0 == e { inside = 0; next }
    /^[[:space:]]*#/ { next }
    /^[[:space:]]*$/ { next }
    /^[[:space:]]*include[[:space:]]/ { next }
    {
      line = $0; managed = (inside ? "true" : "false")
      ci = index(line, ":")
      if (ci > 0) {
        seq = substr(line, 1, ci - 1)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", seq)
        if (seq ~ /^(<[A-Za-z0-9_]+>[[:space:]]*)+$/) {
          rest = substr(line, ci + 1)
          qi = index(rest, "\"")
          if (qi > 0) {
            tail = substr(rest, qi + 1)
            out = ""
            for (i = 1; i <= length(tail); i++) {
              ch = substr(tail, i, 1)
              if (ch == "\\") { out = out ch substr(tail, i + 1, 1); i++; continue }
              if (ch == "\"") break
              out = out ch
            }
            gsub(/\\\\/, "\\", out); gsub(/\\"/, "\"", out)
            printf "%s\037%s\037%s\n", seq, out, managed
          }
        }
      }
    }
  ' "$file"
}

structured_compose_list() {
  local json=0 file rows
  [[ "${1:-}" == "--json" ]] && json=1
  file=$(structured_compose_file)
  rows=$(structured_compose_rows "$file" 2>/dev/null || true)
  if (( json )); then
    if [[ -z "$rows" ]]; then printf '[]\n'; else
      printf '%s\n' "$rows" | jq -Rsc 'split("\n") | map(select(length > 0) | split("\u001f")
        | {sequence: .[0], result: .[1], managed: (.[2] == "true")})'
    fi
    return 0
  fi
  printf 'Compose sequences in %s\n' "$file"
  if [[ -z "$rows" ]]; then
    echo "  none — add one with: replicant compose add '<Multi_key> <a>' 'ä'"
    return 0
  fi
  printf '%s\n' "$rows" | while IFS=$'\x1f' read -r s r mgd; do
    printf '  %-32s %-12s%s\n' "$s" "$r" "$([[ "$mgd" == true ]] && echo " [managed]" || true)"
  done
}

# structured_compose_build <op> <sequence> [result] — candidate inner lines.
structured_compose_build() {
  local op="$1" seq="$2" result="${3:-}" file rows inner
  local s r mgd found=0 unmanaged=0
  file=$(structured_compose_file)
  structured_compose_valid_sequence "$seq" || return 1
  rows=$(structured_compose_rows "$file" 2>/dev/null) || { echo "compose: markers are duplicated or damaged in $file — left untouched" >&2; return 1; }
  while IFS=$'\x1f' read -r s r mgd; do
    [[ "$s" == "$seq" ]] || continue
    if [[ "$mgd" == "true" ]]; then found=1; else unmanaged=1; fi
  done <<<"$rows"
  inner=$(mktemp) || return 1
  # shellcheck disable=SC2064
  trap "rm -f '$inner'" RETURN
  structured_block_lines "$file" "$STRUCT_COMP_START" "$STRUCT_COMP_END" > "$inner" 2>/dev/null || true
  case "$op" in
    add)
      [[ -n "$result" ]] || { echo "compose: add needs a result" >&2; return 1; }
      (( found == 0 )) || { echo "compose: '$seq' is already managed — remove it first" >&2; return 1; }
      (( unmanaged == 0 )) || { echo "compose: '$seq' is already in your file — remove it there first" >&2; return 1; }
      [[ "$result" != *$'\n'* ]] || { echo "compose: the result must be one line" >&2; return 1; }
      local qres
      qres="$result"; qres="${qres//\\/\\\\}"; qres="${qres//\"/\\\"}"
      printf '%s : "%s"\n' "$seq" "$qres" >> "$inner" || return 1
      ;;
    remove)
      (( found )) || {
        (( unmanaged )) && { echo "compose: '$seq' is yours, not Replicant's — edit the file directly" >&2; return 1; }
        echo "compose: '$seq' is not a Replicant sequence" >&2; return 1; }
      awk -v seq="$seq" '
        { line = $0; ci = index(line, ":"); s = substr(line, 1, ci - 1); gsub(/^[[:space:]]+|[[:space:]]+$/, "", s) }
        s == seq { next }
        { print }
      ' "$inner" > "$inner.new" || return 1
      mv -- "$inner.new" "$inner"
      ;;
    *) echo "compose: unknown operation '$op'" >&2; return 1 ;;
  esac
  cat -- "$inner"
}

# ── bar layout ────────────────────────────────────────────────────────────
# shell.json holds the bar under .bar.layout.{left,center,right}: arrays of
# widget objects. A widget is addressed as an id ("omarchy.clock") or as a
# section:index pair ("center:2"), which is the only way to name a spacer.
# jq rewrites the file, so the diff of a first edit also normalizes whatever
# whitespace the shell left behind.

structured_bar_valid_section() {
  case "$1" in
    left|center|right) return 0 ;;
    *) echo "bar-layout: section must be left, center or right" >&2; return 1 ;;
  esac
}

# structured_bar_resolve <layout> <spec> — "section<TAB>index<TAB>id".
# A spec is a widget id ("omarchy.clock") or a section:index pair
# ("center:2", the only way to name a spacer). An id that matches nothing,
# or more than one widget, is refused.
structured_bar_resolve() {
  local layout="$1" spec="$2" sect idx
  if [[ "$spec" == *:* ]]; then
    sect="${spec%%:*}"; idx="${spec##*:}"
    structured_bar_valid_section "$sect" || return 1
    [[ "$idx" =~ ^[0-9]+$ ]] || { echo "bar-layout: '$spec' is not section:index" >&2; return 1; }
    idx=$((10#$idx))
    jq -e --arg s "$sect" --argjson i "$idx" '.bar.layout[$s][$i] | .id' "$layout" >/dev/null 2>&1 \
      || { echo "bar-layout: '$spec' names no widget" >&2; return 1; }
    printf '%s\x1f%s\x1f%s\n' "$sect" "$idx" "$(jq -r --arg s "$sect" --argjson i "$idx" '.bar.layout[$s][$i].id' "$layout")"
    return 0
  fi
  local hits
  hits=$(jq -r --arg id "$spec" '
    ["left","center","right"] as $ss
    | range(0;3) as $s
    | .bar.layout[$ss[$s]] | to_entries[]
    | select(.value.id == $id)
    | "\($ss[$s])\u001f\(.key)\u001f\(.value.id)"' "$layout" 2>/dev/null) \
    || { echo "bar-layout: '$spec' is absent or ambiguous — use section:index" >&2; return 1; }
  [[ -n "$hits" ]] || { echo "bar-layout: '$spec' is absent or ambiguous — use section:index" >&2; return 1; }
  [[ "$(printf '%s\n' "$hits" | wc -l)" == 1 ]] || { echo "bar-layout: '$spec' matches more than one widget — use section:index" >&2; return 1; }
  printf '%s\n' "$hits"
}

structured_bar_list() {
  local json=0 file
  [[ "${1:-}" == "--json" ]] && json=1
  file=$(structured_shell_file)
  [[ -f "$file" ]] || { echo "bar-layout: no shell.json at $file" >&2; return 1; }
  if (( json )); then
    jq -c '[.bar.layout | to_entries[] | .key as $s | .value | to_entries[]
      | {section: $s, index: .key, id: .value.id, size: .value.size}]' "$file" 2>/dev/null \
      || { echo "bar-layout: no bar layout in $file" >&2; return 1; }
    return 0
  fi
  printf 'Bar layout in %s\n' "$file"
  jq -r '.bar.layout | to_entries[] | .key as $s | .value | to_entries[]
    | "  \($s):\(.key)\t\(.value.id)\(if .value.size != null then " (size \(.value.size))" else "" end)"' \
    "$file" 2>/dev/null || { echo "bar-layout: no bar layout in $file" >&2; return 1; }
}

# structured_bar_build <op> [args...] — write the candidate shell.json to
# stdout. Fails with the reason on stderr when the operation is refused.
structured_bar_build() {
  local op="$1"; shift
  local file tmp id sect size before after index
  file=$(structured_shell_file)
  [[ -f "$file" ]] || { echo "bar-layout: no shell.json at $file" >&2; return 1; }
  jq -e '.bar.layout | has("left") and has("center") and has("right")' "$file" >/dev/null 2>&1 \
    || { echo "bar-layout: no bar layout in $file" >&2; return 1; }
  tmp=$(mktemp) || return 1
  # shellcheck disable=SC2064
  trap "rm -f '$tmp'" RETURN
  cp -- "$file" "$tmp" || return 1
  case "$op" in
    move|enable)
      sect=""; before=""; after=""; index=""
      if [[ "$op" == "move" ]]; then
        id="$1"; shift || { echo "bar-layout: move needs a widget" >&2; return 1; }
      else
        id="$1"; shift || { echo "bar-layout: enable needs a widget id" >&2; return 1; }
        [[ "$id" != *:* ]] || { echo "bar-layout: enable takes a widget id, not section:index" >&2; return 1; }
      fi
      while (( $# )); do case "$1" in
        --section) sect="${2:-}"; shift 2 ;;
        --before) before="${2:-}"; shift 2 ;;
        --after) after="${2:-}"; shift 2 ;;
        --index) index="${2:-}"; shift 2 ;;
        *) echo "bar-layout: unknown option '$1'" >&2; return 1 ;;
      esac; done
      [[ -n "$sect" ]] || { echo "bar-layout: $op needs --section left|center|right" >&2; return 1; }
      structured_bar_valid_section "$sect" || return 1
      [[ -z "$before" || -z "$after" ]] || { echo "bar-layout: --before and --after exclude each other" >&2; return 1; }
      [[ -z "$index" || "$index" =~ ^[0-9]+$ ]] || { echo "bar-layout: --index must be a number" >&2; return 1; }
      local cur old_sect old_idx
      if cur=$(structured_bar_resolve "$tmp" "$id" 2>/dev/null); then
        if [[ "$op" == "enable" ]]; then
          echo "bar-layout: '$id' is already on the bar" >&2; return 1
        fi
        old_sect=$(cut -d $'\x1f' -f1 <<<"$cur"); old_idx=$(cut -d $'\x1f' -f2 <<<"$cur")
        # The entry keeps its settings object: only its position changes.
        entry=$(jq -c --arg s "$old_sect" --argjson i "$old_idx" '.bar.layout[$s][$i]' "$tmp") || return 1
        jq --arg s "$old_sect" --argjson i "$old_idx" 'del(.bar.layout[$s][$i])' "$tmp" > "$tmp.new" || return 1
        mv -- "$tmp.new" "$tmp"
      else
        if [[ "$op" == "move" ]]; then
          echo "bar-layout: '$id' is not on the bar" >&2; return 1
        fi
        entry=$(jq -cn --arg id "$id" '{id: $id}')
      fi
      local anchor_idx
      if [[ -n "$before" ]]; then
        anchor_idx=$(structured_bar_anchor "$tmp" "$sect" "$before") || return 1
      elif [[ -n "$after" ]]; then
        anchor_idx=$(structured_bar_anchor "$tmp" "$sect" "$after") || return 1
        anchor_idx=$((anchor_idx + 1))
      elif [[ -n "$index" ]]; then
        local sect_len
        sect_len=$(jq --arg s "$sect" '.bar.layout[$s] | length' "$tmp") || return 1
        (( 10#$index >= 0 && 10#$index <= sect_len )) \
          || { echo "bar-layout: --index must be 0-$sect_len in $sect" >&2; return 1; }
        anchor_idx="$index"
      else
        anchor_idx=$(jq --arg s "$sect" '.bar.layout[$s] | length' "$tmp")
      fi
      jq --arg s "$sect" --argjson at "$anchor_idx" --argjson e "$entry" '
        .bar.layout[$s] |= (.[0:$at] + [$e] + .[$at:])' "$tmp" > "$tmp.new" || return 1
      mv -- "$tmp.new" "$tmp"
      ;;
    disable)
      id="${1:-}"; [[ -n "$id" ]] || { echo "bar-layout: disable needs a widget" >&2; return 1; }
      local cur old_sect old_idx
      cur=$(structured_bar_resolve "$tmp" "$id") || return 1
      old_sect=$(cut -d $'\x1f' -f1 <<<"$cur"); old_idx=$(cut -d $'\x1f' -f2 <<<"$cur")
      jq --arg s "$old_sect" --argjson i "$old_idx" 'del(.bar.layout[$s][$i])' "$tmp" > "$tmp.new" || return 1
      mv -- "$tmp.new" "$tmp"
      ;;
    spacer)
      sect=""; size="12"; before=""; after=""; index=""
      while (( $# )); do case "$1" in
        --section) sect="${2:-}"; shift 2 ;;
        --size) size="${2:-}"; shift 2 ;;
        --before) before="${2:-}"; shift 2 ;;
        --after) after="${2:-}"; shift 2 ;;
        --index) index="${2:-}"; shift 2 ;;
        *) echo "bar-layout: unknown option '$1'" >&2; return 1 ;;
      esac; done
      [[ -n "$sect" ]] || { echo "bar-layout: spacer needs --section left|center|right" >&2; return 1; }
      structured_bar_valid_section "$sect" || return 1
      [[ "$size" =~ ^[0-9]+$ && "$size" -ge 1 && "$size" -le 500 ]] \
        || { echo "bar-layout: --size must be 1-500" >&2; return 1; }
      local anchor_idx
      if [[ -n "$before" ]]; then
        anchor_idx=$(structured_bar_anchor "$tmp" "$sect" "$before") || return 1
      elif [[ -n "$after" ]]; then
        anchor_idx=$(structured_bar_anchor "$tmp" "$sect" "$after") || return 1
        anchor_idx=$((anchor_idx + 1))
      elif [[ -n "$index" ]]; then
        local sect_len
        sect_len=$(jq --arg s "$sect" '.bar.layout[$s] | length' "$tmp") || return 1
        (( 10#$index >= 0 && 10#$index <= sect_len )) \
          || { echo "bar-layout: --index must be 0-$sect_len in $sect" >&2; return 1; }
        anchor_idx="$index"
      else
        anchor_idx=$(jq --arg s "$sect" '.bar.layout[$s] | length' "$tmp")
      fi
      entry=$(jq -cn --argjson n "$size" '{id: "omarchy.spacer", size: $n}')
      jq --arg s "$sect" --argjson at "$anchor_idx" --argjson e "$entry" '
        .bar.layout[$s] |= (.[0:$at] + [$e] + .[$at:])' "$tmp" > "$tmp.new" || return 1
      mv -- "$tmp.new" "$tmp"
      ;;
    *) echo "bar-layout: unknown operation '$op'" >&2; return 1 ;;
  esac
  cat -- "$tmp"
}

# structured_bar_anchor <layout> <section> <spec> — the index a placement
# anchor points at. A spec naming another section is refused: anchors stay
# inside the move.
structured_bar_anchor() {
  local layout="$1" sect="$2" spec="$3" cur asect aidx
  cur=$(structured_bar_resolve "$layout" "$spec") || return 1
  asect=$(cut -d $'\x1f' -f1 <<<"$cur"); aidx=$(cut -d $'\x1f' -f2 <<<"$cur")
  [[ "$asect" == "$sect" ]] || { echo "bar-layout: anchor '$spec' is in $asect, not $sect" >&2; return 1; }
  printf '%s\n' "$aidx"
}

# ── adopt: preview, write, reload, save ───────────────────────────────────
# structured_preview <label> <old-file> <candidate-tmp> — the unified diff.
# Always succeeds; the caller decides. STRUCTURED_REDACT=1 masks physical
# identifiers in the quoted file content (monitor serials).
structured_preview() {
  local label="$1" old="$2" cand="$3"
  printf -- '--- %s (now)\n+++ %s (planned)\n' "$label" "$label"
  if [[ "${STRUCTURED_REDACT:-0}" == 1 ]]; then
    diff -u -- "$old" "$cand" 2>/dev/null | desktop_redact || true
  else
    diff -u -- "$old" "$cand" 2>/dev/null || true
  fi
}

# structured_adopt_lua <file> <candidate> <apply-cmd> — luac, backup, write,
# reload, and rollback on any new config error. Mirrors the settings writer.
structured_adopt_lua() {
  local file="$1" cand="$2" apply="$3"
  local before_errs after_errs new_errors backup_path
  if command -v luac >/dev/null 2>&1; then
    luac -p "$cand" 2>/dev/null || { echo "not valid Lua — left $file untouched" >&2; return 1; }
  fi
  if ! command -v hyprctl >/dev/null 2>&1; then
    echo "Hyprland is not available — left $file untouched, nothing was applied" >&2
    return 1
  fi
  before_errs=$(hypr_config_errors) || { echo "could not validate the current Hyprland configuration" >&2; return 1; }
  backup_before_write "$file" || { echo "could not back up $file" >&2; return 1; }
  backup_path=$(ls -1t -- "$file".bak.* 2>/dev/null | head -n1 || true)
  [[ -n "$backup_path" ]] || { echo "backup for $file is missing" >&2; return 1; }
  cp -a -- "$cand" "$file" || { echo "could not write $file" >&2; return 1; }
  invalidate_file_maps
  if ! timeout 2 bash -c "$apply" >/dev/null 2>&1; then
    cp -a -- "$backup_path" "$file" || { echo "'$apply' failed and the restore from $backup_path failed" >&2; return 1; }
    invalidate_file_maps
    timeout 2 bash -c "$apply" >/dev/null 2>&1 || true
    echo "'$apply' failed — restored $file, nothing was applied" >&2
    return 1
  fi
  after_errs=$(hypr_config_errors) || {
    cp -a -- "$backup_path" "$file" || { echo "could not validate the candidate and the restore failed" >&2; return 1; }
    invalidate_file_maps
    timeout 2 bash -c "$apply" >/dev/null 2>&1 || true
    echo "could not validate the candidate — restored $file, nothing was saved" >&2
    return 1
  }
  new_errors=""
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    grep -Fxq -- "$line" <(printf '%s\n' "$before_errs") 2>/dev/null || new_errors+="$line"$'\n'
  done <<<"$after_errs"
  if [[ -n "$new_errors" ]]; then
    cp -a -- "$backup_path" "$file" || { echo "new config errors and the restore failed" >&2; return 1; }
    invalidate_file_maps
    timeout 2 bash -c "$apply" >/dev/null 2>&1 || true
    echo "Hyprland reported new config errors — restored $file, nothing was saved" >&2
    printf '%s' "$new_errors" >&2
    return 1
  fi
  invalidate_file_maps
}

# structured_adopt_plain <file> <candidate> [apply-cmd] — backup, write, run
# the apply hook, and roll back when it fails. No config-error check: plain
# files have no validator to ask.
structured_adopt_plain() {
  local file="$1" cand="$2" apply="${3:-}" backup_path
  backup_before_write "$file" || { echo "could not back up $file" >&2; return 1; }
  backup_path=$(ls -1t -- "$file".bak.* 2>/dev/null | head -n1 || true)
  mkdir -p "$(dirname -- "$file")" || { echo "could not write $file" >&2; return 1; }
  cp -a -- "$cand" "$file" || { echo "could not write $file" >&2; return 1; }
  invalidate_file_maps
  if [[ -n "$apply" ]]; then
    if ! timeout 10 bash -c "$apply" >/dev/null 2>&1; then
      if [[ -n "$backup_path" ]]; then
        cp -a -- "$backup_path" "$file" || { echo "'$apply' failed and the restore failed" >&2; return 1; }
        invalidate_file_maps
      fi
      echo "'$apply' failed — restored $file, nothing was applied" >&2
      return 1
    fi
  fi
  invalidate_file_maps
}
