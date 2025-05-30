#!/usr/bin/env bash

wifi=(
  padding_right=0
  padding_left=0
  label.width=0
  icon="$WIFI_DISCONNECTED"
  script="$PLUGIN_DIR/wifi.sh"
  click_script="$PLUGIN_DIR/wifi_click.sh"
)

sketchybar --add item wifi right \
  --set wifi "${wifi[@]}" \
  --subscribe wifi wifi_change mouse.clicked
