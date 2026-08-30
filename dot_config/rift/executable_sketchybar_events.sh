#!/usr/bin/env bash

set -u

RIFT_CLI="/opt/homebrew/bin/rift-cli"
CALLBACK="${HOME}/.config/rift/sketchybar_event.sh"

[ -x "$RIFT_CLI" ] || exit 0
[ -x "$CALLBACK" ] || exit 0

for event in workspace_changed windows_changed focused_window_changed window_title_changed; do
  "$RIFT_CLI" subscribe cli --event "$event" --command "$CALLBACK" >/dev/null 2>&1 || exit 1
done

# Repaint immediately after registration so SketchyBar does not remain hidden
# when it started before Rift became queryable during login.
"$CALLBACK"
