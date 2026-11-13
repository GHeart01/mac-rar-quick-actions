#!/bin/bash
# update.sh — install the newest GitHub release of RAR Quick Actions, if newer.
#
# Run automatically once a day (and at login) by a LaunchAgent that install.sh
# sets up. Run it by hand to update right away:
#
#   "$HOME/Library/Application Support/RarQuickActions/update.sh" --verbose
#
# Only tagged releases (vX.Y.Z) from the official repository are installed;
# untagged commits on main are never picked up.

set -u

REPO="GHeart01/mac-rar-quick-actions"
APP_DIR="$HOME/Library/Application Support/RarQuickActions"
LOG="$HOME/Library/Logs/RarQuickActions.log"
export PATH="/usr/bin:/bin:/usr/sbin:/sbin"

VERBOSE=0; [ "${1:-}" = "--verbose" ] && VERBOSE=1

mkdir -p "$(dirname "$LOG")"
log() { printf '%s  update: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >>"$LOG"; [ $VERBOSE = 1 ] && echo "$*"; return 0; }

# True if version $1 is newer than $2 (dotted numbers, e.g. 1.10.0 > 1.9.2).
version_gt() {
  local IFS=. i x y
  local -a a=($1) b=($2)
  for ((i = 0; i < ${#a[@]} || i < ${#b[@]}; i++)); do
    x=${a[i]:-0}; y=${b[i]:-0}
    ((10#$x > 10#$y)) && return 0
    ((10#$x < 10#$y)) && return 1
  done
  return 1
}

# One update at a time.
LOCK="$APP_DIR/.update.lock"
mkdir "$LOCK" 2>/dev/null || { log "another update is running"; exit 0; }
WORK=""
trap 'rmdir "$LOCK" 2>/dev/null; [ -n "$WORK" ] && rm -rf "$WORK"' EXIT

current=$(cat "$APP_DIR/VERSION" 2>/dev/null || echo 0)

# Ask the GitHub API for the latest release's tag. If that fails (e.g. rate
# limited), fall back to github.com/<repo>/releases/latest, which redirects to
# .../releases/tag/<tag> (that redirect can lag behind a new release).
tag=$(curl -fsS --proto '=https' --max-time 20 -H 'Accept: application/vnd.github+json' \
        "https://api.github.com/repos/$REPO/releases/latest" 2>/dev/null \
      | sed -nE 's/^[[:space:]]*"tag_name":[[:space:]]*"([^"]+)".*/\1/p' | head -1)
if [ -z "$tag" ]; then
  location=$(curl -fsSI --proto '=https' --max-time 20 "https://github.com/$REPO/releases/latest" 2>/dev/null \
             | tr -d '\r' | awk 'tolower($1) == "location:" { print $2 }' | tail -1)
  tag=${location##*/releases/tag/}
fi
if ! [[ "$tag" =~ ^v[0-9]+(\.[0-9]+)*$ ]]; then
  log "couldn't find the latest release (offline?)"
  exit 0
fi
latest=${tag#v}

if ! version_gt "$latest" "$current"; then
  [ $VERBOSE = 1 ] && echo "Up to date (version $current)."
  exit 0
fi

log "updating $current -> $latest"
WORK=$(mktemp -d "${TMPDIR:-/tmp}/rarqa-update.XXXXXX") || exit 1
if ! curl -fsSL --proto '=https' --max-time 300 -o "$WORK/src.tar.gz" \
      "https://github.com/$REPO/archive/refs/tags/$tag.tar.gz"; then
  log "download of $tag failed"
  exit 1
fi
mkdir "$WORK/src" && tar -xzf "$WORK/src.tar.gz" -C "$WORK/src" --strip-components 1 || { log "couldn't unpack $tag"; exit 1; }

# Sanity check: it's our repo, at the version the tag says.
if [ ! -f "$WORK/src/install.sh" ] || [ "$(tr -d '[:space:]' <"$WORK/src/VERSION" 2>/dev/null)" != "$latest" ]; then
  log "release $tag doesn't look right; not installing it"
  exit 1
fi

if RQA_UPDATER=1 /bin/bash "$WORK/src/install.sh" >>"$LOG" 2>&1; then
  log "installed version $latest"
  osascript -e "display notification \"Updated to version $latest\" with title \"RAR Quick Actions\"" >/dev/null 2>&1 || true
else
  log "install of $latest failed (see above)"
  exit 1
fi
