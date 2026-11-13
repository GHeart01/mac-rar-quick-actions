#!/bin/bash
# Install the "Extract RAR" and "Compress to RAR" Finder Quick Actions.
#
#   ./install.sh                  # install / update
#   RAR_VERSION=723 ./install.sh  # pick a specific RARLAB release
#   SKIP_RAR=1 ./install.sh       # don't download rar (extract via `brew install unar`)
#
# What it does:
#   1. Downloads RARLAB's official command-line `rar` + `unrar` for your CPU
#      from https://www.rarlab.com into ~/Library/Application Support/RarQuickActions/bin
#   2. Copies rartool.sh next to it
#   3. Copies the two Quick Actions into ~/Library/Services and refreshes Finder

set -euo pipefail

RAR_VERSION="${RAR_VERSION:-723}"
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="$HOME/Library/Application Support/RarQuickActions"
SERVICES_DIR="$HOME/Library/Services"

say() { printf '\033[1m==>\033[0m %s\n' "$*"; }

mkdir -p "$APP_DIR/bin" "$SERVICES_DIR"

# 1. rar / unrar ---------------------------------------------------------------
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
  curl -fL --proto '=https' --progress-bar -o "$tmp/$pkg" "$url"
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
  say "Installed rar $("$APP_DIR/bin/rar" -iver 2>/dev/null | tr -d '\r' | head -1)"
else
  say "Skipping rar download (SKIP_RAR=1)"
  command -v unar >/dev/null 2>&1 || echo "    Note: install an extractor with: brew install unar"
fi

# 2. helper script ---------------------------------------------------------------
install -m 755 "$REPO_DIR/scripts/rartool.sh" "$APP_DIR/rartool.sh"
say "Installed helper to $APP_DIR"

# 3. Quick Actions ---------------------------------------------------------------
for wf in "Extract RAR" "Compress to RAR"; do
  rm -rf "$SERVICES_DIR/$wf.workflow"
  cp -R "$REPO_DIR/workflows/$wf.workflow" "$SERVICES_DIR/"
  xattr -cr "$SERVICES_DIR/$wf.workflow" 2>/dev/null || true
done
/System/Library/CoreServices/pbs -update 2>/dev/null || true
say "Installed Quick Actions to $SERVICES_DIR"

cat <<'EOF'

Done! Right-click in Finder:
  • a .rar file        → Quick Actions ▸ Extract RAR
  • any files/folders  → Quick Actions ▸ Compress to RAR

If they don't show up, open System Settings ▸ General ▸ Login Items & Extensions
▸ Finder (or "Extensions ▸ Finder") and tick both, or run: killall Finder
EOF
