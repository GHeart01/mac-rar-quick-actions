#!/bin/bash
# Install the "Extract RAR" and "Compress to RAR" Finder Quick Actions.
#
#   ./install.sh                  # install / update
#   AUTO_UPDATE=0 ./install.sh    # install without daily automatic updates
#   RAR_VERSION=723 ./install.sh  # pick a specific RARLAB release
#   SKIP_RAR=1 ./install.sh       # don't download rar (extract via `brew install unar`)
#
# What it does:
#   1. Downloads RARLAB's official command-line `rar` + `unrar` for your CPU
#      from https://www.rarlab.com into ~/Library/Application Support/RarQuickActions/bin
#   2. Copies rartool.sh and update.sh next to it
#   3. Installs RarQuickActions.action into ~/Library/Automator (shows a live
#      percentage in the menu-bar gear; needs Third Party Automator Actions on)
#   4. Copies the two Quick Actions into ~/Library/Services and refreshes Finder
#   5. Sets up a LaunchAgent that checks GitHub for new releases daily and at login

set -euo pipefail

RAR_VERSION="${RAR_VERSION:-723}"
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="$HOME/Library/Application Support/RarQuickActions"
SERVICES_DIR="$HOME/Library/Services"
AGENT_LABEL="io.github.gheart01.rar-quick-actions.update"
AGENT_PLIST="$HOME/Library/LaunchAgents/$AGENT_LABEL.plist"
UPDATER="${RQA_UPDATER:-0}"   # 1 when run by update.sh
VERSION="$(tr -d '[:space:]' <"$REPO_DIR/VERSION")"

say() { printf '\033[1m==>\033[0m %s\n' "$*"; }

mkdir -p "$APP_DIR/bin" "$SERVICES_DIR"

# 1. rar / unrar ---------------------------------------------------------------
# During an automatic update, only download rar again if this release moved to
# a newer RARLAB version (and rar was installed in the first place).
if [ "$UPDATER" = "1" ]; then
  if [ ! -x "$APP_DIR/bin/rar" ] || [ "$(cat "$APP_DIR/RAR_VERSION" 2>/dev/null || echo "$RAR_VERSION")" = "$RAR_VERSION" ]; then
    SKIP_RAR=1
  fi
fi

if [ "${SKIP_RAR:-0}" != "1" ]; then
  case "$(uname -m)" in
    arm64)  pkg="rarmacos-arm-${RAR_VERSION}.tar.gz" ;;
    x86_64) pkg="rarmacos-x64-${RAR_VERSION}.tar.gz" ;;
    *) echo "Unsupported CPU: $(uname -m)" >&2; exit 1 ;;
  esac
  url="https://www.rarlab.com/rar/$pkg"
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT

  say "Downloading $url"
  if [ "$UPDATER" = "1" ]; then progress=-sS; else progress=--progress-bar; fi
  curl -fL --proto '=https' "$progress" -o "$tmp/$pkg" "$url"
  tar -xzf "$tmp/$pkg" -C "$tmp"
  for b in rar unrar; do
    install -m 755 "$tmp/rar/$b" "$APP_DIR/bin/$b"
    xattr -c "$APP_DIR/bin/$b" 2>/dev/null || true
    # Apple Silicon refuses to run unsigned binaries; ad-hoc sign if needed.
    codesign -v "$APP_DIR/bin/$b" 2>/dev/null || codesign -s - -f "$APP_DIR/bin/$b"
  done
  # Keep RARLAB's license and docs alongside the binaries.
  for doc in license.txt order.htm rar.txt whatsnew.txt; do
    [ -f "$tmp/rar/$doc" ] && cp "$tmp/rar/$doc" "$APP_DIR/" || true
  done
  "$APP_DIR/bin/rar" -iver >/dev/null 2>&1 || { echo "Downloaded rar doesn't run on this Mac." >&2; exit 1; }
  echo "$RAR_VERSION" >"$APP_DIR/RAR_VERSION"
  say "Installed rar $("$APP_DIR/bin/rar" -iver 2>/dev/null | tr -d '\r' | head -1)"
elif [ "$UPDATER" != "1" ]; then
  say "Skipping rar download (SKIP_RAR=1)"
  [ -x "$APP_DIR/bin/unrar" ] || command -v unar >/dev/null 2>&1 \
    || echo "    Note: install an extractor with: brew install unar"
fi

# 2. helper scripts --------------------------------------------------------------
install -m 755 "$REPO_DIR/scripts/rartool.sh" "$APP_DIR/rartool.sh"
install -m 755 "$REPO_DIR/scripts/update.sh"   "$APP_DIR/update.sh"
rm -f "$APP_DIR/progress.js"   # old progress window (before 1.2.0)
say "Installed helper to $APP_DIR"

# 3. Automator action (live % in the menu-bar gear) ------------------------------
ACTION_DIR="$HOME/Library/Automator"
ACTION="$ACTION_DIR/RarQuickActions.action"
mkdir -p "$ACTION_DIR"
rm -rf "$ACTION"
cp -R "$REPO_DIR/action/RarQuickActions.action" "$ACTION"
xattr -cr "$ACTION" 2>/dev/null || true

# Point a copied workflow's action at this user's installed action bundle.
use_action() { # workflow bundle
  plutil -replace actions.0.action.ActionBundlePath -string "$ACTION" "$1/Contents/document.wflow"
}

# macOS only runs custom actions once "Third Party Automator Actions" is
# allowed in Automator. Check by running a no-op workflow that uses ours.
probe=$(mktemp -d)
cp -R "$REPO_DIR/action/Probe.workflow" "$probe/"
use_action "$probe/Probe.workflow"
if automator "$probe/Probe.workflow" 2>&1 | grep -q 'must be explicitly enabled'; then
  WORKFLOWS_DIR="$REPO_DIR/workflows-basic"
  GEAR=0
else
  WORKFLOWS_DIR="$REPO_DIR/workflows"
  GEAR=1
fi
rm -rf "$probe"

# 4. Quick Actions ---------------------------------------------------------------
for wf in "Extract RAR" "Compress to RAR"; do
  rm -rf "$SERVICES_DIR/$wf.workflow"
  cp -R "$WORKFLOWS_DIR/$wf.workflow" "$SERVICES_DIR/"
  if [ "$GEAR" = 1 ]; then use_action "$SERVICES_DIR/$wf.workflow"; fi
  xattr -cr "$SERVICES_DIR/$wf.workflow" 2>/dev/null || true
done
/System/Library/CoreServices/pbs -update 2>/dev/null || true
say "Installed Quick Actions to $SERVICES_DIR"
if [ "$GEAR" = 1 ]; then
  say "Progress: live percentage in the menu-bar gear"
else
  say "Progress: basic (the gear will show 0% until done)"
  if [ "$UPDATER" != "1" ]; then
    echo "    For a live percentage in the gear: open Automator, choose"
    echo "    Automator > Third Party Automator Actions... in the menu bar, allow them,"
    echo "    then run ./install.sh again."
  fi
fi

# Record the installed version before the agent's first (RunAtLoad) check.
echo "$VERSION" >"$APP_DIR/VERSION"

# 5. automatic updates -----------------------------------------------------------
# (Skipped when update.sh runs us: reloading the agent would stop that update.)
if [ "$UPDATER" != "1" ]; then
  launchctl bootout "gui/$(id -u)/$AGENT_LABEL" 2>/dev/null || true
  if [ "${AUTO_UPDATE:-1}" = "1" ]; then
    mkdir -p "$(dirname "$AGENT_PLIST")"
    cat >"$AGENT_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>$AGENT_LABEL</string>
	<key>ProgramArguments</key>
	<array>
		<string>/bin/bash</string>
		<string>$APP_DIR/update.sh</string>
	</array>
	<key>RunAtLoad</key>
	<true/>
	<key>StartInterval</key>
	<integer>86400</integer>
	<key>ProcessType</key>
	<string>Background</string>
	<key>LowPriorityIO</key>
	<true/>
</dict>
</plist>
EOF
    launchctl bootstrap "gui/$(id -u)" "$AGENT_PLIST"
    say "Automatic updates on (checks GitHub daily and at login)"
  else
    rm -f "$AGENT_PLIST"
    say "Automatic updates off"
  fi
fi

[ "$UPDATER" = "1" ] && exit 0

cat <<EOF

Done! RAR Quick Actions $VERSION is installed. Right-click in Finder:
  • a .rar file        → Quick Actions ▸ Extract RAR
  • any files/folders  → Quick Actions ▸ Compress to RAR

If they don't show up, open System Settings ▸ General ▸ Login Items & Extensions
▸ Finder (or "Extensions ▸ Finder") and tick both, or run: killall Finder
EOF
