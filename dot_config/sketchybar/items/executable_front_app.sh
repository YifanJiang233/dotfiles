#!/usr/bin/env bash

FRONT_APP_SCRIPT='sketchybar --set "$NAME" label="$INFO"'

front_app=(
  script="$FRONT_APP_SCRIPT"
  icon.font="sketchybar-app-font:Regular:16.0"
  # icon.padding_right=0
  icon.color="$GREEN"
  # icon.drawing=off
  background.padding_left=0
  label.color="$TEXT"
  label.font="$FONT:Bold:13.0"
  # associated_display=active
  script="$PLUGIN_DIR/front_app.sh"
)

sketchybar --add item front_app center \
  --set front_app "${front_app[@]}" \
  --subscribe front_app front_app_switched
