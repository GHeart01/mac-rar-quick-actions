#!/bin/bash
# Build RarQuickActions.action (universal arm64 + x86_64, ad-hoc signed).
# The built bundle is committed to the repo so installing doesn't need Xcode.
set -euo pipefail
cd "$(dirname "$0")"
OUT="RarQuickActions.action"
rm -rf "$OUT"
mkdir -p "$OUT/Contents/MacOS"
clang -fobjc-arc -O2 -bundle -framework Automator -framework Foundation \
  -arch arm64 -arch x86_64 -mmacosx-version-min=11.0 \
  -o "$OUT/Contents/MacOS/RarQuickActions" RarQuickAction.m
cp Info.plist "$OUT/Contents/Info.plist"
codesign -s - -f "$OUT"
plutil -lint "$OUT/Contents/Info.plist" >/dev/null
echo "built action/$OUT"
