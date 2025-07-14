#!/usr/bin/env bash

battery=(
  script="$PLUGIN_DIR/battery.sh"
  padding_right=0
  label.width=0
  update_freq=120
)

sketchybar --add item battery right \
  --set battery "${battery[@]}" \
  click_script="$PLUGIN_DIR/battery_click.sh" \
  --subscribe battery power_source_change system_woke
