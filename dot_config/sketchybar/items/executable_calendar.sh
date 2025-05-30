#!/usr/bin/env bash

sketchybar --add item calendar right \
  --set calendar update_freq=10 \
  script="$PLUGIN_DIR/calendar.sh" \
  icon.drawing=off
