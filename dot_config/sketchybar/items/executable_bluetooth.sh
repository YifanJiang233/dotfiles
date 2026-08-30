#!/usr/bin/env bash

sketchybar --add item bluetooth right \
  --set bluetooth \
    update_freq=30 \
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
    popup.align=right \
    popup.height=22 \
    popup.y_offset=4 \
    popup.background.color="$SURFACE0" \
    popup.background.corner_radius=9 \
    popup.background.border_color="$SURFACE2" \
    popup.background.border_width=1 \
    popup.background.padding_left=12 \
    popup.background.padding_right=12 \
  --subscribe bluetooth mouse.entered mouse.exited system_woke
