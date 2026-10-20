#!/bin/bash
# Reconciliation: what another saved machine has that this one lacks, the
# exact official install command, and installs of named packages only.
# Nothing is ever removed, and base/ignored packages are never proposed.
#
# Two simulated machines share one repo: desk saved first, lap second (so lap
# is the default source). pacman and omarchy are stubs; the repo is real.
set -uo pipefail

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CLI="$HERE/../bin/replicant"
# shellcheck source=tests/lib.sh
source "$HERE/lib.sh"

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
export OMARCHY_REPLICANT_HOME="$TMP/replicant"
export OMARCHY_PATH="$TMP/omarchy"
REPO="$OMARCHY_REPLICANT_HOME/repo"
mkdir -p "$TMP/omarchy/install"

# The base set and the ignore list: never proposed, from either side.
printf 'base-pkg\nshared-base\n' > "$TMP/omarchy/install/omarchy-base.packages"
printf 'other-pkg\n' > "$TMP/omarchy/install/omarchy-other.packages"

# pacman answers from fixture files so installed-vs-missing is deterministic.
export PACMAN_OFFICIAL="$TMP/pacman-official.txt"
export PACMAN_AUR="$TMP/pacman-aur.txt"
printf 'shared-pkg\nlocal-only-pkg\nshared-base\n' > "$PACMAN_OFFICIAL"
printf 'local-aur-pkg\n' > "$PACMAN_AUR"
mkdir -p "$TMP/fakebin"
cat > "$TMP/fakebin/pacman" <<'EOF'
#!/bin/bash
if [[ "$1" == "-Qqen" ]]; then cat "$PACMAN_OFFICIAL" 2>/dev/null; exit 0; fi
if [[ "$1" == "-Qqem" ]]; then cat "$PACMAN_AUR" 2>/dev/null; exit 0; fi
if [[ "$1" == "-Q" ]]; then
  shift
  [[ "$1" == "--" ]] && shift
  grep -qxF -- "$1" "$PACMAN_OFFICIAL" "$PACMAN_AUR" 2>/dev/null; exit
fi
exit 1
EOF
chmod +x "$TMP/fakebin/pacman"
cat > "$TMP/fakebin/omarchy" <<'EOF'
#!/bin/bash
echo "omarchy $*" >> "$OMARCHY_LOG"
if [[ "$1" == "pkg" && "$2" == "add" ]]; then
  [[ "${OMARCHY_FAIL:-0}" == 1 ]] && exit 1
  shift 2; [[ "$1" == "--" ]] && shift
  for p in "$@"; do printf '%s\n' "$p" >> "$PACMAN_OFFICIAL"; done
  exit 0
fi
if [[ "$1" == "pkg" && "$2" == "aur" && "$3" == "add" ]]; then
  [[ "${OMARCHY_FAIL:-0}" == 1 ]] && exit 1
  shift 3; [[ "$1" == "--" ]] && shift
  for p in "$@"; do printf '%s\n' "$p" >> "$PACMAN_AUR"; done
  exit 0
fi
exit 97
EOF
chmod +x "$TMP/fakebin/omarchy"
export PATH="$TMP/fakebin:$PATH"
export OMARCHY_LOG="$TMP/omarchy.log"
: > "$OMARCHY_LOG"

# Desk saves first, lap second: lap is the newest save, the default source.
export HOME="$TMP/desk-home" REPLICANT_MACHINE="desk"
mkdir -p "$HOME/.config/hypr" "$HOME/.config/omarchy"
printf '{"bar":{"layout":{"left":[],"center":[],"right":[]}}}\n' > "$HOME/.config/omarchy/shell.json"
"$CLI" init >/dev/null 2>&1
mkdir -p "$REPO/bin"
printf 'ignored-pkg\n' > "$REPO/bin/pacman-delta-ignore"
mkdir -p "$REPO/state/desk"
printf 'desk-only-pkg\nshared-pkg\nbase-pkg\nignored-pkg\n' > "$REPO/state/desk/pacman-delta.txt"
printf 'desk-aur-pkg\n' > "$REPO/state/desk/pacman-delta-aur.txt"
printf '# id\tversion\torigin\tmethod\ndesk-plugin\t1.0\thttps://example.com/desk-plugin.git\tadd\n' > "$REPO/state/desk/omarchy-plugins.txt"
printf '# name\torigin\ndesk-theme\thttps://example.com/desk-theme.git\n' > "$REPO/state/desk/omarchy-themes.txt"
git -C "$REPO" add -A >/dev/null 2>&1
GIT_AUTHOR_DATE="2026-10-19T10:00:00" GIT_COMMITTER_DATE="2026-10-19T10:00:00" \
  git -C "$REPO" commit -qm "desk save" --date="2026-10-19T10:00:00"

export HOME="$TMP/lap-home" REPLICANT_MACHINE="lap"
mkdir -p "$HOME/.config/hypr" "$HOME/.config/omarchy"
printf '{"bar":{"layout":{"left":[],"center":[],"right":[]}}}\n' > "$HOME/.config/omarchy/shell.json"
mkdir -p "$REPO/state/lap"
printf 'lap-only-pkg\nlap-spare-pkg\nshared-pkg\nbase-pkg\nignored-pkg\n' > "$REPO/state/lap/pacman-delta.txt"
printf 'lap-aur-pkg\n' > "$REPO/state/lap/pacman-delta-aur.txt"
printf '# id\tversion\torigin\tmethod\nlap-plugin\t2.0\thttps://example.com/lap-plugin.git\tadd\n' > "$REPO/state/lap/omarchy-plugins.txt"
printf '# name\torigin\nlap-theme\thttps://example.com/lap-theme.git\n' > "$REPO/state/lap/omarchy-themes.txt"
git -C "$REPO" add -A >/dev/null 2>&1
GIT_AUTHOR_DATE="2026-10-20T10:00:00" GIT_COMMITTER_DATE="2026-10-20T10:00:00" \
  git -C "$REPO" commit -qm "lap save" --date="2026-10-20T10:00:00"

# This machine is a third one: neither inventory is its own.
export HOME="$TMP/here-home" REPLICANT_MACHINE="here"
mkdir -p "$HOME/.config/hypr" "$HOME/.config/omarchy"
printf '{"bar":{"layout":{"left":[],"center":[],"right":[]}}}\n' > "$HOME/.config/omarchy/shell.json"

run() { "$CLI" "$@" 2>&1; }

section "the preview names its source and separates the lists"
out=$(run reconcile)
check_contains "default source is the newest save" "Source: lap" "$out"
check_contains "official section" "Official packages missing here" "$out"
check_contains "official item" "lap-only-pkg" "$out"
check_contains "AUR section" "AUR packages missing here" "$out"
check_contains "AUR item" "lap-aur-pkg" "$out"
check_contains "exact official command" "omarchy pkg add lap-only-pkg" "$out"
check_contains "exact AUR command" "omarchy pkg aur add lap-aur-pkg" "$out"
check_contains "never removes" "nothing is ever removed" "$out"
check "base set never proposed" "0" "$(printf '%s' "$out" | grep -c 'base-pkg' || true)"
check "ignored never proposed" "0" "$(printf '%s' "$out" | grep -c 'ignored-pkg' || true)"
check "installed never proposed" "0" "$(printf '%s' "$out" | grep -cx '  shared-pkg' || true)"
check "local-only never proposed" "0" "$(printf '%s' "$out" | grep -c 'local-only-pkg' || true)"
out=$(run reconcile --json)
check "preview is valid JSON" "0" "$(printf '%s' "$out" | jq empty >/dev/null 2>&1; echo $?)"
check "JSON names the source" "lap" "$(printf '%s' "$out" | jq -r '.source')"
check "JSON lists the official one" "lap-only-pkg" "$(printf '%s' "$out" | jq -r '.official[0]')"
check "JSON lists plugins with origins" "https://example.com/lap-plugin.git" "$(printf '%s' "$out" | jq -r '.plugins[0].origin')"
out=$(run reconcile --from desk)
check_contains "another source can be chosen" "Source: desk" "$out"
check_contains "desk item listed" "desk-only-pkg" "$out"
check_contains "the explicit install example keeps its source" "--from desk" "$out"
check_false "an unknown source is refused" run reconcile --from nope
check_false "an unsafe source is refused" run reconcile --from ../repo
check_false "the parent directory is not a source" run reconcile --from ..
check_false "the state root is not a source" run reconcile --from .
check_false "an empty source is refused" run reconcile --from=
check_false "a missing source value is refused" run reconcile --from

section "install takes only named missing packages"
check_false "install needs a package" run reconcile install --apply
check_false "bad names refused" run reconcile install 'a;b' --apply
check_false "unknown packages refused" run reconcile install nope-pkg --apply
check_false "base packages refused" run reconcile install base-pkg --apply
check_false "installed packages refused" run reconcile install shared-pkg --apply
check_false "unknown flags refused" run reconcile install lap-only-pkg --bogus --apply
check_false "install refuses an empty source" run reconcile install lap-only-pkg --from=
check_false "another source item is absent from the default" run reconcile install desk-only-pkg
prev=$(run reconcile install desk-only-pkg --from desk)
check_contains "install keeps the selected source" "omarchy pkg add desk-only-pkg" "$prev"
prev=$(run reconcile install lap-only-pkg)
check_contains "install preview names the command" "omarchy pkg add lap-only-pkg" "$prev"
check_contains "install preview changes nothing" "Preview only" "$prev"
check "install preview touches nothing" "0" "$(grep -c 'pkg add' "$OMARCHY_LOG" || true)"
prev=$(run reconcile install lap-aur-pkg --aur)
check_contains "AUR preview names its command" "omarchy pkg aur add lap-aur-pkg" "$prev"
run reconcile install lap-only-pkg --apply >/dev/null 2>&1; rc=$?
check "official install succeeds" "0" "$rc"
check "official install ran visibly" "1" "$(grep -c 'omarchy pkg add -- lap-only-pkg' "$OMARCHY_LOG" || true)"
run reconcile install lap-aur-pkg --aur --apply >/dev/null 2>&1; rc=$?
check "AUR install succeeds" "0" "$rc"
check "AUR install ran visibly" "1" "$(grep -c 'omarchy pkg aur add -- lap-aur-pkg' "$OMARCHY_LOG" || true)"
out=$(run reconcile)
check "installed official leaves the list" "0" "$(printf '%s' "$out" | grep -cx '  lap-only-pkg' || true)"
check "installed AUR leaves the list" "0" "$(printf '%s' "$out" | grep -cx '  lap-aur-pkg' || true)"
OMARCHY_FAIL=1 run reconcile install lap-spare-pkg --apply >/dev/null 2>&1; rc=$?
check "a failed install reports failure" "1" "$rc"
check "a failed install installs nothing" "0" "$(grep -c 'lap-spare-pkg' "$PACMAN_OFFICIAL" || true)"
unset OMARCHY_FAIL
run reconcile install lap-spare-pkg --apply >/dev/null 2>&1
check "spare install succeeds" "0" "$?"
check_false "an empty missing set stays closed" run reconcile install arbitrary-pkg --apply

section "plugins and themes list with origins and review steps"
out=$(run reconcile)
check_contains "plugin listed" "lap-plugin" "$out"
check_contains "plugin origin shown" "https://example.com/lap-plugin.git" "$out"
check_contains "review step shown" "install-plugin lap-plugin --check" "$out"
check_contains "theme listed" "lap-theme" "$out"
mkdir -p "$REPO/state/empty"
git -C "$REPO" add -A >/dev/null 2>&1
GIT_AUTHOR_DATE="2026-10-18T10:00:00" GIT_COMMITTER_DATE="2026-10-18T10:00:00" \
  git -C "$REPO" commit -qm "empty save" --date="2026-10-18T10:00:00"
check "empty inventories list nothing" "0" "$(run reconcile --from empty --json | jq '[.official[], .aur[]] | length')"

section "status carries pending packages for Restore"
out=$(run status --json)
check "status is valid JSON" "0" "$(printf '%s' "$out" | jq empty >/dev/null 2>&1; echo $?)"
check "pending packages name the source" "lap" "$(printf '%s' "$out" | jq -r '.pending_packages.source')"
check "pending official drained by installs" "0" "$(printf '%s' "$out" | jq '[.pending_packages.official[]] | length')"
check "pending aur drained by installs" "0" "$(printf '%s' "$out" | jq '[.pending_packages.aur[]] | length')"

section "usage and help name the command"
check_contains "usage lists reconcile" "reconcile [--from" "$(run --help)"
check_contains "reconcile help lists install" "reconcile install" "$(run reconcile --help)"

section "the panel presents reconciliation inside Restore"
check_true "pending packages reach the panel" \
  bash -c 'grep -q "pendingPackages" "$1/Panel.qml"' _ "$HERE/.."
check_true "Restore has a packages card" \
  bash -c 'grep -q "Packages to install" "$1/components/RestoreTab.qml"' _ "$HERE/.."
check_true "packages install through reconcile" \
  bash -c 'grep -q "reconcile install" "$1/Panel.qml"' _ "$HERE/.."
check_true "the ask names the exact command" \
  bash -c 'grep -q "askInstallPackage" "$1/Panel.qml"' _ "$HERE/.."
check_true "the panel keeps the source for install" \
  bash -c 'grep -q "packageParts\[2\]" "$1/Panel.qml"' _ "$HERE/.."
check_true "the panel opens package installs visibly" \
  bash -c 'grep -q "runVisible(packageCommand)" "$1/Panel.qml"' _ "$HERE/.."
check_true "the panel uses Omarchy's public terminal launcher" \
  bash -c 'grep -q "omarchy launch floating terminal with presentation" "$1/Panel.qml"' _ "$HERE/.."

summary
