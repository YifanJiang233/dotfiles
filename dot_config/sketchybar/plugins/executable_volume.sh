#!/usr/bin/env bash

source "$CONFIG_DIR/styles/style.sh"
source "$CONFIG_DIR/plugins/right_tooltip.sh"

if [ "$SENDER" = "mouse.entered" ] || [ "$SENDER" = "mouse.exited" ]; then
  right_tooltip_hover "$NAME" "$SENDER"
  exit 0
fi

AUDIO_DEVICE_HELPER="${AUDIO_DEVICE_HELPER:-$CONFIG_DIR/plugins/audio_device.sh}"
device_class="unknown"
device_name="Audio output unavailable"
helper_volume=""
muted=0

if [ -x "$AUDIO_DEVICE_HELPER" ]; then
  device_info=$("$AUDIO_DEVICE_HELPER" 2>/dev/null || true)
  if [ -n "$device_info" ]; then
    IFS=$'\t' read -r device_class device_name helper_volume muted <<< "$device_info"
  fi
fi

volume="$INFO"
case "$volume" in
  ''|*[!0-9]*) volume="$helper_volume" ;;
esac
case "$volume" in
  ''|*[!0-9]*) exit 0 ;;
esac

if [ "$muted" = "1" ] || [ "$volume" -eq 0 ]; then
  device_icon=""
else
  case "$device_class" in
    headphones|bluetooth)
      device_icon=""
      ;;
    speakers)
      device_icon=""
      ;;
    display)
      device_icon="󰽟"
      ;;
    *)
      if [ "$volume" -ge 60 ]; then
        device_icon=""
      else
        device_icon=""
      fi
      ;;
  esac
fi

case "$device_name" in
  ''|"Unknown output") device_name="Audio output unavailable" ;;
esac

sketchybar --set "$NAME" \
  icon="${volume}%" icon.color="$TEXT" \
  label="$device_icon" label.color="$TEXT"
right_tooltip_update "$NAME" "$device_name"
