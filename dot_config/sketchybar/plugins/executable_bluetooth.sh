#!/usr/bin/env bash

source "$CONFIG_DIR/styles/style.sh"
source "$CONFIG_DIR/plugins/right_tooltip.sh"

if [ "$SENDER" = "mouse.entered" ] || [ "$SENDER" = "mouse.exited" ]; then
  right_tooltip_hover "$NAME" "$SENDER"
  exit 0
fi

BLUEUTIL="/opt/homebrew/bin/blueutil"
JQ="/opt/homebrew/bin/jq"

if [ ! -x "$BLUEUTIL" ]; then
  sketchybar --set "$NAME" icon="" icon.color="$TEXT" label="" label.color="$TEXT"
  right_tooltip_update "$NAME" "Bluetooth unavailable"
  exit 0
fi

power=$("$BLUEUTIL" --power 2>/dev/null || true)
connected_json=$("$BLUEUTIL" --connected --format json 2>/dev/null || true)
connected_text=$("$BLUEUTIL" --connected 2>/dev/null || true)

connected_count=""
device_names=""
if [ -x "$JQ" ] && [ -n "$connected_json" ]; then
  connected_count=$(printf '%s' "$connected_json" | "$JQ" -r '
    if type == "array" then length
    elif (.devices // null | type) == "array" then (.devices | length)
    else 0
    end
  ' 2>/dev/null || true)
  device_names=$(printf '%s' "$connected_json" | "$JQ" -r '
    if type == "array" then .[]
    elif (.devices // null | type) == "array" then .devices[]
    else empty
    end
    | (.name // .alias // .device_alias // .address // empty)
  ' 2>/dev/null || true)
fi

case "$connected_count" in
  ''|*[!0-9]*)
    connected_count=$(printf '%s\n' "$connected_text" | awk 'NF { count += 1 } END { print count + 0 }')
    ;;
esac

if [ "$connected_count" -gt 0 ]; then
  status_text="$connected_count"
  color="$GREEN"
  status="on"
else
  case "$power" in
    1)
      status_text="on"
      color="$TEXT"
      status="on"
      ;;
    0)
      status_text="off"
      color="$RED"
      status="off"
      ;;
    *)
      status_text=""
      color="$TEXT"
      status="unavailable"
      ;;
  esac
fi

tooltip="Bluetooth: $status"$'\n\n'"$connected_count connected"
if [ -n "$device_names" ]; then
  tooltip="$tooltip"$'\n\n'"$device_names"
elif [ -n "$connected_text" ]; then
  tooltip="$tooltip"$'\n\n'"$connected_text"
fi

sketchybar --set "$NAME" \
  icon="$status_text" icon.color="$color" \
  label="" label.color="$color"
right_tooltip_update "$NAME" "$tooltip"
