#!/bin/bash
# Remove the RAR Quick Actions, the helper and the downloaded rar/unrar binaries.
set -euo pipefail

rm -rf "$HOME/Library/Services/Extract RAR.workflow" \
       "$HOME/Library/Services/Compress to RAR.workflow" \
       "$HOME/Library/Application Support/RarQuickActions"
/System/Library/CoreServices/pbs -update 2>/dev/null || true
echo "Removed RAR Quick Actions. (Log kept at ~/Library/Logs/RarQuickActions.log)"
