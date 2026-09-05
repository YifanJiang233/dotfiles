#!/usr/bin/env bash

sketchybar --add item bluetooth right \
  --set bluetooth \
    update_freq=5 \
    script="$PLUGIN_DIR/bluetooth.sh" \
    icon.drawing=on \
    icon.font="JetBrains Mono:Bold:15.0" \
    icon.color="$TEXT" \
    icon.padding_left=0 \
    icon.padding_right=4 \
    label.font="JetBrainsMono Nerd Font:Bold:15.0" \
    label.color="$TEXT" \
    label.y_offset=1 \
    label.padding_left=0 \
    label.padding_right=0 \
    padding_left=5 \
    padding_right=5 \
    "${tooltip_defaults[@]}" \
  --subscribe bluetooth mouse.entered mouse.exited system_woke
