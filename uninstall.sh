#!/bin/bash
# Removes the "Open in Linear" keyboard shortcut and the macOS service behind it.

set -euo pipefail

NAME="Open in Linear"
DEST="$HOME/Library/Services/$NAME.workflow"
PBS_KEY="(null) - $NAME - runWorkflowAsService"

rm -rf "$DEST"

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
if defaults export pbs "$tmp" 2>/dev/null &&
   plutil -remove "NSServicesStatus.$PBS_KEY" "$tmp" 2>/dev/null; then
  defaults import pbs "$tmp"
fi

/System/Library/CoreServices/pbs -update
echo "Removed \"$NAME\"."
