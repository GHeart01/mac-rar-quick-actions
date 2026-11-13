#!/bin/bash
# Remove the RAR Quick Actions, the helper, the auto-updater and the downloaded rar/unrar binaries.
set -euo pipefail

AGENT_LABEL="io.github.gheart01.rar-quick-actions.update"
launchctl bootout "gui/$(id -u)/$AGENT_LABEL" 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/$AGENT_LABEL.plist"
rm -rf "$HOME/Library/Services/Extract RAR.workflow" \
       "$HOME/Library/Services/Compress to RAR.workflow" \
       "$HOME/Library/Automator/RarQuickActions.action" \
       "$HOME/Library/Application Support/RarQuickActions"
/System/Library/CoreServices/pbs -update 2>/dev/null || true
echo "Removed RAR Quick Actions. (Log kept at ~/Library/Logs/RarQuickActions.log)"
