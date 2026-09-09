#!/usr/bin/env bash

source "$CONFIG_DIR/styles/style.sh"
source "$CONFIG_DIR/plugins/right_tooltip.sh"

if [ "$SENDER" = "mouse.entered" ] || [ "$SENDER" = "mouse.exited" ]; then
  right_tooltip_hover "$NAME" "$SENDER"
  exit 0
fi

BLUEUTIL="${BLUEUTIL:-/opt/homebrew/bin/blueutil}"
JQ="${JQ:-/opt/homebrew/bin/jq}"

if [ ! -x "$BLUEUTIL" ]; then
  sketchybar --set "$NAME" icon="" icon.color="$TEXT" label="" label.color="$TEXT"
  right_tooltip_update "$NAME" "Bluetooth unavailable"
  exit 0
fi

power=$("$BLUEUTIL" --power 2>/dev/null || true)
connected_json=$("$BLUEUTIL" --connected --format json 2>/dev/null || true)

connected_count=0
device_names=""
if [ -x "$JQ" ] && [ -n "$connected_json" ]; then
  connected_devices=$(
    printf '%s' "$connected_json" |
      "$JQ" -c '
        if type == "array" then
          map({
            id: (.address // .name // ""),
            name: (.name // .address // "")
          })
          | map(select(.id != "" and .name != ""))
          | unique_by(.id)
        else
          []
        end
      ' 2>/dev/null || true
  )

  if [ -n "$connected_devices" ]; then
    connected_count=$(printf '%s' "$connected_devices" | "$JQ" -r 'length' 2>/dev/null || printf '0')
    device_names=$(printf '%s' "$connected_devices" | "$JQ" -r '.[].name' 2>/dev/null || true)
  fi
fi

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
fi

sketchybar --set "$NAME" \
  icon="$status_text" icon.color="$color" \
  label="" label.color="$color"
right_tooltip_update "$NAME" "$tooltip"
