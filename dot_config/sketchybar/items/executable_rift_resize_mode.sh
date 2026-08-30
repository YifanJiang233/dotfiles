#!/usr/bin/env bash

RIFT_RESIZE_MODE_EVENT="rift_resize_mode"

sketchybar --add event "$RIFT_RESIZE_MODE_EVENT"
sketchybar --add item rift.resize_mode left \
  --set rift.resize_mode \
    drawing=off \
    icon.drawing=off \
    label="Resize" \
    label.color="$PEACH" \
    label.font="JetBrains Mono:Bold:15.0" \
    label.padding_left=4 \
    label.padding_right=8 \
    background.drawing=off \
    padding_left=2 \
    padding_right=2 \
    script="$PLUGIN_DIR/rift_resize_mode.sh" \
  --subscribe rift.resize_mode "$RIFT_RESIZE_MODE_EVENT"
