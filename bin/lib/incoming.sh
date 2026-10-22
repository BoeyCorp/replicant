# shellcheck shell=bash disable=SC2034
# incoming.sh: what another machine changed, and what differs on this one.
# Sourced by replicant-core.sh, which sets the paths it uses. It defines
# functions and data and runs nothing. Other modules read its data.

# ─── incoming: what another machine changed and this one has not caught up ──
# Read through one assoc array, filled once. Every row in the panel asks, so a
# per-row re-read of the file is fifty reads of the same six lines.
declare -gA INCOMING=()
INCOMING_LOADED=0
read_incoming() {
  (( INCOMING_LOADED )) && return 0
  INCOMING_LOADED=1
  INCOMING=()
  [[ -f "$INCOMING_FILE" ]] || return 0
  local line
  while IFS= read -r line; do
    [[ -z "$line" || "$line" == \#* ]] && continue
    INCOMING["$line"]=1
  done < "$INCOMING_FILE"
  return 0
}

# is_incoming_rel <rel> — 0 when the last pull brought a newer copy of this
# entry. The CALLER still has to check the file actually differs: an entry that
# has since been restored, or deliberately saved over, matches again and must
# stop claiming anything. That is the same self-healing rule the unsaved badge
# follows, and it is why no pass has to remember to clear this flag.
is_incoming_rel() {
  [[ -n "${1:-}" ]] || return 1
  read_incoming
  [[ -n "${INCOMING[$1]:-}" ]]
}

# record_incoming <rel>... — replace the list with exactly these entries.
# Called by `pull`, which is the one moment the direction of a difference is
# known for certain.
record_incoming() {
  local tmp
  mkdir -p "$REPLICANT_HOME" || { echo "incoming: cannot create $REPLICANT_HOME" >&2; return 1; }
  tmp="$REPLICANT_HOME/.incoming.tmp.$$"
  if (( $# == 0 )); then
    rm -f -- "$INCOMING_FILE" || { echo "incoming: cannot clear $INCOMING_FILE" >&2; return 1; }
  else
    printf '%s\n' "$@" | sort -u > "$tmp" || { rm -f -- "$tmp"; return 1; }
    mv -f -- "$tmp" "$INCOMING_FILE" || { rm -f -- "$tmp"; echo "incoming: cannot publish $INCOMING_FILE" >&2; return 1; }
  fi
  INCOMING_LOADED=0
  briefcache_invalidate
  return 0
}

# entry_differs lives in state.sh now, beside the evaluator that is its only
# remaining reader through state_facts (the builders and the backup hold
# decision call it there). This module keeps the incoming mark itself.

# count_changes — prints "<unsaved> <incoming> <locked> <missing>" over every
# tracked entry.
#
# The bar icon used to read repoState.dirty, which counts what git sees in the
# REPO working tree — files core_backup has already copied in. Edit a config and
# never save it and the icon sat at the calm "in sync" hexagon all day, which is
# the one thing this plugin exists to tell you. The panel was fixed for this in
# 0.6.1 and the bar was not.
#
# It answers with content only. The git half ("copied in, not committed") is
# already in the brief payload as `dirty`, and the icon ORs the two. The
# content pass is dozens of comparisons instead of a full row payload, which
# is what used to make the once-a-minute poll the plugin's main idle cost.
#
# Locked is the third number: a version 2 secret whose vault cannot be read on
# this machine. It is counted apart from unsaved so the bar can ask for the key
# instead of asking for a save. Missing is the fourth: a saved entry gone from
# this machine, which asks for restore or forget, never for calm.
# Older callers that read only two fields keep working: the first field stays
# the unsaved count.
count_changes() {
  local n_unsaved=0 n_incoming=0 n_locked=0 n_missing=0
  local regrow live same member locked scope repo source gitdirty k v
  local -a rf=()
  # Built once in this shell, so the loops below need no fork for each row.
  registry_build
  # Content only, like entry_differs always was: the git half (copied in, not
  # committed) already reaches the bar as `dirty` in the brief payload, and
  # adding it here would count one file twice.
  # Iterated over REGISTRY, not TRACKED: the full payload counts the same rows,
  # so the bar and the panel answer from one row set. A per-entry resolve here
  # also scanned the registry once per row (quadratic); this is one pass.
  for regrow in ${REGISTRY[@]+"${REGISTRY[@]}"}; do
    mapfile -t rf < <(row_split "$regrow" 9)
    source="${rf[2]}"; scope="${rf[4]}"
    [[ "$scope" == "off" ]] && continue
    live=false; same=false; member=false; locked=false; repo=false; gitdirty=false
    while IFS='=' read -r k v; do
      case "$k" in
        live) live="$v" ;; same) same="$v" ;; repo) repo="$v" ;;
        incoming) member="$v" ;; locked) locked="$v" ;;
        git_dirty) gitdirty="$v" ;;
      esac
    done < <(state_facts "$regrow")
    if [[ "$locked" == true ]]; then n_locked=$(( n_locked + 1 )); continue; fi
    if [[ "$live" == false ]]; then
      # Same inclusion rule as the full payload: a shipped or found entry
      # neither here nor in the repo draws no row, and the bar stays quiet
      # about it too. An explicit user or override row always draws one, so a
      # tracked file gone from this machine counts as missing even before its
      # first save, exactly as the panel shows it.
      if [[ "$source" == manifest || "$source" == auto ]] && [[ "$repo" == false ]]; then
        continue
      fi
      n_missing=$(( n_missing + 1 ))
      continue
    fi
    # Unsaved is either half, exactly as the badge precedence is: content that
    # differs, or a repo copy that is not committed yet. A file the repo has a
    # newer copy of is asking for Restore, not for Save, and counting it in
    # both totals put the same file behind two contradictory buttons.
    [[ "$same" == false || "$gitdirty" == true ]] || continue
    if [[ "$member" == true ]]; then n_incoming=$(( n_incoming + 1 ))
    else n_unsaved=$(( n_unsaved + 1 )); fi
  done
  printf '%s %s %s %s\n' "$n_unsaved" "$n_incoming" "$n_locked" "$n_missing"
}

# _incoming_merge_prune [rel...] — merge new markers with the existing file
# and drop resolved ones. New rels come from the just-finished pull; existing
# ones are unresolved work from earlier pulls. A marker clears only after a
# verified resolution: the registry row exists and its copies still differ
# (unsaved). A restore and a deliberate save over the marker both make the
# copies match, so both count as resolution. Unknown ids (no registry row)
# clear too: there is no row to act on. When the registry cannot be read,
# nothing is dropped — the merge still lands, so a later pull cannot wipe
# unresolved work.
_incoming_merge_prune() {
  local -a fresh=("$@") keys=() keep=()
  local k line
  if [[ -f "$INCOMING_FILE" ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
      [[ -z "$line" || "$line" == \#* ]] && continue
      keys+=("$line")
    done < "$INCOMING_FILE"
  fi
  for k in ${fresh[@]+"${fresh[@]}"}; do
    [[ -n "$k" ]] && keys+=("$k")
  done
  local -a cands=()
  if (( ${#keys[@]} )); then
    mapfile -t cands < <(printf '%s\n' "${keys[@]}" | sort -u)
  fi
  if (( ${#cands[@]} == 0 )); then
    record_incoming
    return 0
  fi
  if ! registry_build 2>/dev/null; then
    record_incoming "${cands[@]}"
    return 0
  fi
  local cand regrow verdict unsaved
  for cand in "${cands[@]}"; do
    regrow=$(registry_row_for "$cand" 2>/dev/null) || continue
    verdict=$(state_verdict "$regrow" 2>/dev/null) || { keep+=("$cand"); continue; }
    unsaved=$(awk '{print $3}' <<<"$verdict" 2>/dev/null || true)
    [[ "$unsaved" == true ]] || continue
    keep+=("$cand")
  done
  if (( ${#keep[@]} == 0 )); then
    record_incoming
  else
    record_incoming "${keep[@]}"
  fi
  return 0
}

# _incoming_vault_ids <before-rev> <after-rev> — secret IDs whose vault rows
# changed across a pull. Prints one ID per line, never values, blob bytes, or
# index JSON. Fails closed: when either side cannot be decrypted (no key,
# corrupt or missing metadata), it prints every tracked secret ID instead of
# nothing, so ciphertext changes cannot silently disappear. Callers merge the
# result with config rows; the copies-still-differ check then hides rows that
# already match, and locked rows stay locked rather than synchronized.
_incoming_vault_ids() {
  local before="$1" after="$2"
  local -a vpaths=()
  local p
  while IFS= read -r p; do
    [[ -n "$p" ]] || continue
    case "$p" in
      vault/index.age|vault/blobs/*.age) vpaths+=("$p") ;;
    esac
  done < <(git -C "$REPO_DIR" diff --name-only "$before" "$after" -- vault/ 2>/dev/null)
  (( ${#vpaths[@]} )) || return 0
  local after_json="" before_json=""
  local after_ok=0 before_ok=0
  if after_json=$(vault_index_decrypt 2>/dev/null); then
    after_ok=1
  fi
  before_json=$(_incoming_before_index "$before" 2>/dev/null) && before_ok=1 || before_json=""
  if (( after_ok && before_ok )); then
    # Every ID in either side whose canonical row differs (added, removed,
    # blob, scope, path, or source change).
    local -a changed=()
    local id a_row b_row
    local -a all_ids=()
    mapfile -t all_ids < <((jq -r '.secrets[].id' <<<"$after_json" 2>/dev/null; jq -r '.secrets[].id' <<<"$before_json" 2>/dev/null) | sort -u || true)
    for id in ${all_ids[@]+"${all_ids[@]}"}; do
      [[ -n "$id" ]] || continue
      a_row=$(jq -c --arg id "$id" '.secrets[] | select(.id == $id) | {blob,scope,path,source}' <<<"$after_json" 2>/dev/null || true)
      b_row=$(jq -c --arg id "$id" '.secrets[] | select(.id == $id) | {blob,scope,path,source}' <<<"$before_json" 2>/dev/null || true)
      [[ "$a_row" != "$b_row" ]] || continue
      changed+=("$id")
    done
    # Blob-only changes keep identical index rows (same blob ID, same scope):
    # map changed blob files back to their IDs through the after index,
    # falling back to the before index for deleted blobs.
    local vp blob bid mid
    for vp in "${vpaths[@]}"; do
      case "$vp" in
        vault/blobs/*.age)
          blob=$(basename "$vp" .age)
          [[ "$blob" =~ ^[0-9a-f]{32}$ ]] || continue
          mid=$(jq -r --arg b "$blob" '.secrets[] | select(.blob == $b) | .id // empty' <<<"$after_json" 2>/dev/null | head -n1 || true)
          [[ -z "$mid" ]] && mid=$(jq -r --arg b "$blob" '.secrets[] | select(.blob == $b) | .id // empty' <<<"$before_json" 2>/dev/null | head -n1 || true)
          [[ -n "$mid" ]] || continue
          changed+=("$mid")
          ;;
      esac
    done
    if (( ${#changed[@]} )); then
      printf '%s\n' "${changed[@]}" | sort -u
    fi
    return 0
  fi
  # Keyless, corrupt, or missing metadata: mark every tracked secret so the
  # pending state survives. IDs only, never values.
  local -a broad=()
  local entry rel
  for entry in ${TRACKED_SECRETS[@]+"${TRACKED_SECRETS[@]}"}; do
    rel="${entry##*:}"
    [[ -n "$rel" ]] && broad+=("$rel")
  done
  if (( ${#broad[@]} )); then
    printf '%s\n' "${broad[@]}" | sort -u
  fi
  return 0
}

# _incoming_before_index <rev> — the vault index JSON at a git revision,
# decrypted and validated. Prints JSON on success, nothing on failure.
_incoming_before_index() {
  local rev="$1" tmp idf plain
  tmp=$(mktemp) || return 1
  if ! git -C "$REPO_DIR" show "$rev:vault/index.age" > "$tmp" 2>/dev/null; then
    rm -f -- "$tmp"
    printf '{"version":2,"secrets":[]}\n'
    return 0
  fi
  idf=$(vault_identity_file 2>/dev/null) || { rm -f -- "$tmp"; return 1; }
  [[ -f "$idf" ]] || { rm -f -- "$tmp"; return 1; }
  crypto_require_age 2>/dev/null || { rm -f -- "$tmp"; return 1; }
  plain=$(mktemp) || { rm -f -- "$tmp"; return 1; }
  if ! age -d -i "$idf" -o "$plain" "$tmp" 2>/dev/null; then
    rm -f -- "$tmp" "$plain"
    return 1
  fi
  rm -f -- "$tmp"
  local content
  content=$(cat -- "$plain" 2>/dev/null || true)
  rm -f -- "$plain"
  [[ -n "$content" ]] || return 1
  vault_index_validate "$content" 2>/dev/null || return 1
  printf '%s\n' "$content"
}

# Used by the replicant CLI wrapper
# core_incoming <before-rev> <after-rev> — which tracked entries a pull moved.
# Written down for the panel and printed for the caller.
#
# The file keeps the union of earlier unresolved markers and the new ones: an
# inventory-only pull must not wipe a pending config restore, and a second
# config pull adds to the pending set instead of replacing it. Entries whose
# copies now match clear on the next pull; the verdict already hides them from
# status in the meantime.
#
# It lives here rather than in the CLI for the reason everything else does: the
# mapping from a repo path back to the row a person can press a button on is
# business logic, and owning_rel is the only thing that knows a file three
# levels inside a tracked directory belongs to the directory's row.
core_incoming() {
  local before="$1" after="$2" p rel
  local -a rels=()
  while IFS= read -r p; do
    case "$p" in
      config/*)            rel="${p#config/}" ;;
      secrets/*)           rel="${p#secrets/}" ;;
      # Only THIS machine's profile. profiles/laptop/... is the laptop's own copy
      # of a file that is kept per profile precisely so the two machines do not
      # share it — reporting it as incoming here would tell the desktop to
      # restore the laptop's monitor layout onto itself.
      profiles/*/config/*) rel="${p#profiles/}"
                           [[ "${rel%%/*}" == "$(current_profile)" ]] || continue
                           rel="${rel#*/config/}" ;;
      *)                   continue ;;   # state/, .replicant-*: not rows anyone acts on
    esac
    rels+=("$(owning_rel "$rel")")
  done < <(git -C "$REPO_DIR" diff --name-only "$before" "$after" 2>/dev/null)
  local -a uniq=()
  if (( ${#rels[@]} )); then
    mapfile -t uniq < <(printf '%s\n' "${rels[@]}" | sort -u)
  fi
  local -a vault_ids=()
  mapfile -t vault_ids < <(_incoming_vault_ids "$before" "$after" 2>/dev/null || true)
  local -a all_uniq=()
  if (( ${#uniq[@]} || ${#vault_ids[@]} )); then
    mapfile -t all_uniq < <(printf '%s\n' ${uniq[@]+"${uniq[@]}"} ${vault_ids[@]+"${vault_ids[@]}"} | sort -u)
  fi
  _incoming_merge_prune ${all_uniq[@]+"${all_uniq[@]}"} || return 1
  if (( ${#all_uniq[@]} )); then
    printf '%s\n' "${all_uniq[@]}"
  fi
  return 0
}
