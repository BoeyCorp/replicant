# shellcheck shell=bash disable=SC2034
# reconcile.sh: portable software reconciliation. Sourced by
# replicant-core.sh, which sets the paths it uses. It defines functions and
# data and runs nothing.
#
# A restore copies files; it never installs software. Reconciliation is the
# explicit, selected step after it: which packages, plugins, and themes of
# another machine are missing here, and the exact official command that
# installs the selected ones. Nothing is ever removed, and nothing installs
# without being named first.

# reconcile_machines — "name<TAB>epoch", newest first. The epoch is the last
# commit that touched the machine's inventory, the same answer the panel's
# machine list gives.
reconcile_machines() {
  local d mname mepoch
  for d in "$STATE_ROOT"/*/; do
    [[ -d "$d" ]] || continue
    mname=$(basename "$d")
    mepoch=$(git -C "$REPO_DIR" log -1 --format='%at' -- "state/$mname" 2>/dev/null || true)
    [[ -n "$mepoch" ]] || mepoch=0
    printf '%s\t%s\n' "$mname" "$mepoch"
  done | sort -t$'\t' -k2 -nr
}

# reconcile_default_source — the newest saved machine. When that is this
# machine, there is nothing newer to reconcile from, and the lists come back
# empty with the reason why.
reconcile_default_source() {
  reconcile_machines | head -n1 | cut -f1
}

# reconcile_valid_machine <name> — accept one directory component only.
reconcile_valid_machine() {
  local name="${1:-}"
  [[ "$name" =~ ^[A-Za-z0-9._-]+$ && ${#name} -le 100 && "$name" != "." && "$name" != ".." ]]
}

# reconcile_known_set — the base set plus the ignored list, the packages no
# machine should ever propose. Mirrors regenerate_inventory so a delta file
# recorded before an ignore-list change is still filtered.
reconcile_known_set() {
  local omarchy_path base_omarchy other_omarchy
  omarchy_path=${OMARCHY_PATH:-/usr/share/omarchy}
  base_omarchy="$omarchy_path/install/omarchy-base.packages"
  other_omarchy="$omarchy_path/install/omarchy-other.packages"
  if [[ -r "$base_omarchy" ]]; then
    cat "$base_omarchy" "$other_omarchy" 2>/dev/null | sed 's/#.*//' | tr -s ' \t' '\n' | sed '/^$/d'
  fi
  if [[ -r "$REPO_DIR/bin/pacman-delta-ignore" ]]; then
    sed 's/#.*//' "$REPO_DIR/bin/pacman-delta-ignore" | tr -d ' \t' | sed '/^$/d'
  elif [[ -r "$PLUGIN_DIR/bin/pacman-delta-ignore" ]]; then
    sed 's/#.*//' "$PLUGIN_DIR/bin/pacman-delta-ignore" | tr -d ' \t' | sed '/^$/d'
  fi
}

# reconcile_source_delta <machine> <official|aur> — the recorded delta lines.
reconcile_source_delta() {
  local machine="$1" which="$2" f
  if [[ "$which" == official ]]; then f="$STATE_ROOT/$machine/pacman-delta.txt"
  else f="$STATE_ROOT/$machine/pacman-delta-aur.txt"; fi
  [[ -f "$f" ]] || return 0
  grep -v '^#' "$f" 2>/dev/null | sed '/^$/d' || true
}

# reconcile_local_installed <official|aur> — what this machine has now.
reconcile_local_installed() {
  if [[ "$1" == official ]]; then pacman -Qqen 2>/dev/null || true
  else pacman -Qqem 2>/dev/null || true; fi
}

# reconcile_missing <machine> <official|aur> — source packages missing here,
# minus the base and ignored set. One name per line, sorted, deduplicated.
reconcile_missing() {
  local machine="$1" which="$2"
  reconcile_valid_machine "$machine" || { echo "reconcile: bad machine name '$machine'" >&2; return 1; }
  [[ -d "$STATE_ROOT/$machine" ]] || { echo "reconcile: no saved machine '$machine'" >&2; return 1; }
  local f_src f_exc
  f_src=$(mktemp) || return 1
  f_exc=$(mktemp) || { rm -f "$f_src"; return 1; }
  # shellcheck disable=SC2064
  trap "rm -f '$f_src' '$f_exc'" RETURN
  reconcile_source_delta "$machine" "$which" | sort -u > "$f_src" || { trap - RETURN; rm -f "$f_src" "$f_exc"; return 1; }
  { reconcile_local_installed "$which"; reconcile_known_set; } | sort -u > "$f_exc" \
    || { trap - RETURN; rm -f "$f_src" "$f_exc"; return 1; }
  comm -23 "$f_src" "$f_exc" || true
  trap - RETURN; rm -f "$f_src" "$f_exc"
}

# reconcile_missing_plugins <machine> — third-party plugins the SOURCE
# machine records that this one lacks. Pinned to the source, unlike
# missing_plugins, which takes any machine's inventory: the preview answers
# "what is on the source", not "what is anywhere".
reconcile_missing_plugins() {
  local machine="$1" inv="$STATE_ROOT/$1/omarchy-plugins.txt" pid pver porigin pmethod
  [[ -f "$inv" ]] || return 0
  while IFS=$'\t' read -r pid pver porigin pmethod; do
    [[ -n "$pid" && "$pid" != \#* ]] || continue
    [[ -d "$HOME/.config/omarchy/plugins/$pid" ]] && continue
    [[ "$porigin" == "-" || -z "$porigin" ]] && continue
    [[ -z "$pmethod" || "$pmethod" == "-" ]] && pmethod=add
    printf '%s\t%s\t%s\n' "$pid" "$porigin" "$pmethod"
  done < "$inv"
}

# reconcile_missing_themes <machine> — same question for themes.
reconcile_missing_themes() {
  local machine="$1" inv="$STATE_ROOT/$1/omarchy-themes.txt" tname torigin
  [[ -f "$inv" ]] || return 0
  while IFS=$'\t' read -r tname torigin; do
    [[ -n "$tname" && "$tname" != \#* ]] || continue
    [[ -d "$HOME/.config/omarchy/themes/$tname" ]] && continue
    [[ "$torigin" == "-" || -z "$torigin" ]] && continue
    printf '%s\t%s\n' "$tname" "$torigin"
  done < "$inv"
}

# reconcile_missing_json <machine> — {"source","official":[],"aur":[]} plus
# plugin and theme pending items with origins.
reconcile_missing_json() {
  local machine="$1" off aur
  off=$(reconcile_missing "$machine" official 2>/dev/null | jq -Rsc 'split("\n") | map(select(length > 0))') || off='[]'
  aur=$(reconcile_missing "$machine" aur 2>/dev/null | jq -Rsc 'split("\n") | map(select(length > 0))') || aur='[]'
  local plugs themes
  plugs=$(reconcile_missing_plugins "$machine" 2>/dev/null | jq -Rsc 'split("\n") | map(select(length > 0) | split("\t")
    | {id: .[0], origin: .[1], method: .[2]})') || plugs='[]'
  themes=$(reconcile_missing_themes "$machine" 2>/dev/null | jq -Rsc 'split("\n") | map(select(length > 0) | split("\t")
    | {name: .[0], origin: .[1]})') || themes='[]'
  jq -cn --arg src "$machine" --argjson off "$off" --argjson aur "$aur" \
    --argjson plugs "$plugs" --argjson themes "$themes" \
    '{source: $src, official: $off, aur: $aur, plugins: $plugs, themes: $themes}'
}

reconcile_preview() {
  local json=0 src="" source_given=0
  while (( $# )); do case "$1" in
    --json) json=1; shift ;;
    --from)
      (( $# >= 2 )) || { echo "reconcile: --from needs a machine" >&2; return 2; }
      src="$2"; source_given=1; shift 2 ;;
    --from=*) src="${1#--from=}"; source_given=1; shift ;;
    *) echo "reconcile: unknown option '$1'" >&2; return 2 ;;
  esac; done
  (( source_given == 0 )) || [[ -n "$src" ]] \
    || { echo "reconcile: --from needs a machine" >&2; return 2; }
  if [[ -z "$src" ]]; then
    src=$(reconcile_default_source) || src=""
    [[ -n "$src" ]] || { echo "reconcile: no saved machine to reconcile from" >&2; return 1; }
  fi
  reconcile_valid_machine "$src" \
    || { echo "reconcile: bad machine name '$src'" >&2; return 1; }
  [[ -d "$STATE_ROOT/$src" ]] || { echo "reconcile: no saved machine '$src'" >&2; return 1; }
  if (( json )); then
    reconcile_missing_json "$src"
    return 0
  fi
  local payload off_n aur_n
  payload=$(reconcile_missing_json "$src") || return 1
  off_n=$(jq -r '.official | length' <<<"$payload")
  aur_n=$(jq -r '.aur | length' <<<"$payload")
  if [[ "$src" == "$MACHINE" ]]; then
    printf 'Source: %s (this machine — the newest save, so nothing is newer)\n' "$src"
  else
    printf 'Source: %s (newest save; --from <machine> to choose another)\n' "$src"
  fi
  printf 'Official packages missing here (%s):\n' "$off_n"
  if (( off_n > 0 )); then jq -r '.official[] | "  \(.)"' <<<"$payload"; fi
  printf 'AUR packages missing here (%s):\n' "$aur_n"
  if (( aur_n > 0 )); then jq -r '.aur[] | "  \(.)"' <<<"$payload"; fi
  local pn tn
  pn=$(jq -r '.plugins | length' <<<"$payload"); tn=$(jq -r '.themes | length' <<<"$payload")
  printf 'Plugins missing here (%s):\n' "$pn"
  if (( pn > 0 )); then
    jq -r '.plugins[] | "  \(.id)  \(.origin)  [review: replicant install-plugin \(.id) --check]"' <<<"$payload"
  fi
  printf 'Themes missing here (%s):\n' "$tn"
  if (( tn > 0 )); then
    jq -r '.themes[] | "  \(.name)  \(.origin)"' <<<"$payload"
  fi
  printf 'Base and ignored packages are never proposed, and nothing is ever removed.\n'
  if (( off_n > 0 )); then
    printf 'Install the selected official ones with:\n  omarchy pkg add %s\n' \
      "$(jq -r '.official | join(" ")' <<<"$payload")"
  fi
  if (( aur_n > 0 )); then
    printf 'Install the selected AUR ones with:\n  omarchy pkg aur add %s\n' \
      "$(jq -r '.aur | join(" ")' <<<"$payload")"
  fi
  if (( off_n > 0 || aur_n > 0 )); then
    printf 'Or install named ones explicitly:\n  replicant reconcile install <pkg...> [--aur] --from %q [--apply]\n' "$src"
  fi
}

# reconcile_install <kind> <pkgs...> — install selected missing packages.
# Preview-first: without --apply it names the exact command and stops.
reconcile_install() {
  local kind="$1"; shift
  local apply=0 dry=0 src="" source_given=0
  local -a pkgs=()
  while (( $# )); do
    case "$1" in
      --apply) apply=1; shift ;;
      --dry-run) dry=1; shift ;;
      --from)
        (( $# >= 2 )) || { echo "reconcile: --from needs a machine" >&2; return 2; }
        src="$2"; source_given=1; shift 2 ;;
      --from=*) src="${1#--from=}"; source_given=1; shift ;;
      -*) echo "reconcile: unknown option '$1'" >&2; return 2 ;;
      *) pkgs+=("$1"); shift ;;
    esac
  done
  (( dry )) && apply=0
  local missing one bad=0
  (( source_given == 0 )) || [[ -n "$src" ]] \
    || { echo "reconcile: --from needs a machine" >&2; return 2; }
  if [[ -z "$src" ]]; then src=$(reconcile_default_source) || src=""; fi
  [[ -n "$src" ]] || { echo "reconcile: no saved machine to reconcile from" >&2; return 1; }
  reconcile_valid_machine "$src" \
    || { echo "reconcile: bad machine name '$src'" >&2; return 1; }
  [[ -d "$STATE_ROOT/$src" ]] \
    || { echo "reconcile: no saved machine '$src'" >&2; return 1; }
  missing=$(reconcile_missing "$src" "$kind") || return 1
  (( ${#pkgs[@]} )) || { echo "reconcile: install needs at least one package" >&2; return 2; }
  for one in "${pkgs[@]}"; do
    [[ "$one" =~ ^[A-Za-z0-9@._+-]+$ ]] || { echo "reconcile: '$one' is not a package name" >&2; bad=1; }
  done
  (( bad == 0 )) || return 1
  for one in "${pkgs[@]}"; do
    grep -qxF -- "$one" <<<"$missing" \
      || { echo "reconcile: '$one' is not missing from $src (already installed, or never recorded)" >&2; bad=1; }
  done
  (( bad == 0 )) || return 1
  local cmd
  if [[ "$kind" == aur ]]; then cmd="omarchy pkg aur add ${pkgs[*]}"
  else cmd="omarchy pkg add ${pkgs[*]}"; fi
  if (( ! apply )); then
    printf 'Would run:\n  %s\n' "$cmd"
    printf 'Preview only — nothing changed. Pass --apply to install it here, visibly.\n'
    return 0
  fi
  command -v omarchy >/dev/null 2>&1 || { echo "reconcile: omarchy is not available — nothing was installed" >&2; return 1; }
  if [[ "$kind" == aur ]]; then
    omarchy pkg aur add -- "${pkgs[@]}" || { echo "reconcile: installation failed" >&2; return 1; }
  else
    omarchy pkg add -- "${pkgs[@]}" || { echo "reconcile: installation failed" >&2; return 1; }
  fi
  printf 'Installed: %s\n' "${pkgs[*]}"
}

# build_pending_packages_json — {"source","official":[],"aur":[]} for the
# panel's Restore tab. Empty machine lists mean "nothing recorded anywhere";
# an empty source with no machines at all means "nothing to compare with".
build_pending_packages_json() {
  local src
  src=$(reconcile_default_source 2>/dev/null || true)
  if [[ -z "$src" ]]; then
    printf '{"source":"","official":[],"aur":[]}\n'
    return 0
  fi
  local off aur
  off=$(reconcile_missing "$src" official 2>/dev/null | jq -Rsc 'split("\n") | map(select(length > 0))') || off='[]'
  aur=$(reconcile_missing "$src" aur 2>/dev/null | jq -Rsc 'split("\n") | map(select(length > 0))') || aur='[]'
  jq -cn --arg src "$src" --argjson off "$off" --argjson aur "$aur" \
    '{source: $src, official: $off, aur: $aur}'
}
