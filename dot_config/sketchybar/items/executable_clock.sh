#!/usr/bin/env bash

sketchybar --add item clock right \
  --set clock \
    drawing=on \
    update_freq=10 \
    script="$PLUGIN_DIR/clock.sh" \
    label.drawing=on \
    label.font="JetBrains Mono:Bold:15.0" \
    label.color="$TEXT" \
    label.padding_left=0 \
    label.padding_right=0 \
    icon.drawing=off \
    padding_left=5 \
    padding_right=5
