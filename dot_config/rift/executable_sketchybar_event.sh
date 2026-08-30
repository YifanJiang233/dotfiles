#!/usr/bin/env bash

set -u

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
SKETCHYBAR="$(command -v sketchybar || true)"
[ -n "$SKETCHYBAR" ] || exit 0

DEBOUNCE_DIR="${TMPDIR:-/tmp}/rift-sketchybar-${UID:-$(id -u)}"
TOKEN_FILE="$DEBOUNCE_DIR/event.token"
[ -d "$DEBOUNCE_DIR" ] || mkdir -p "$DEBOUNCE_DIR" || exit 0

token="$$-$RANDOM-$RANDOM"
printf '%s' "$token" > "$TOKEN_FILE" || exit 0

(
  sleep 0.04
  current_token=$(<"$TOKEN_FILE")
  [ "$current_token" = "$token" ] || exit 0
  "$SKETCHYBAR" --trigger rift_state_changed "RIFT_EVENT_TYPE=${RIFT_EVENT_TYPE:-unknown}"
) >/dev/null 2>&1 &
