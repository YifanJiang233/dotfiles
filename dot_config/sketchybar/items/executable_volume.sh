#!/usr/bin/env bash

sketchybar --add item volume right \
  --set volume \
    update_freq=10 \
    script="$PLUGIN_DIR/volume.sh" \
    click_script="open 'x-apple.systempreferences:com.apple.Sound-Settings.extension'" \
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
  --subscribe volume volume_change system_woke mouse.entered mouse.exited
