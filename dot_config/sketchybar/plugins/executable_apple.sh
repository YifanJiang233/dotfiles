#!/usr/bin/env bash

sleep() {
  osascript -e 'tell application "System Events" to sleep'
}

toggle_popup() {
  sketchybar --set $NAME popup.drawing=toggle
}

if [ "$BUTTON" = "right" ] || [ "$MODIFIER" = "shift" ]; then
  sleep
else
  toggle_popup
fi
