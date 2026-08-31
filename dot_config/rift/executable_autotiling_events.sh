#!/usr/bin/env bash

set -u

RIFT_CLI="${RIFT_CLI:-/opt/homebrew/bin/rift-cli}"
CALLBACK="${RIFT_AUTOTILING_CALLBACK:-${HOME}/.config/rift/autotiling.sh}"

[ -x "$RIFT_CLI" ] || exit 0
[ -x "$CALLBACK" ] || exit 0

for event in focused_window_changed windows_changed workspace_changed; do
  "$RIFT_CLI" subscribe cli --event "$event" --command "$CALLBACK" >/dev/null 2>&1 || exit 1
done

# Establish the baseline without touching any windows that already exist.
"$CALLBACK" '{"type":"initialize"}'
