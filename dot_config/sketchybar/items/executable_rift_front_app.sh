#!/usr/bin/env bash

sketchybar --add item rift_front_app_icon center --set rift_front_app_icon drawing=off icon.drawing=off label.drawing=off padding_left=0 padding_right=0 background.drawing=on background.color=0x00000000 background.image.drawing=off background.image.scale=0.8 background.image.corner_radius=4 background.image.padding_right=6 \
  --add item rift_front_app center --set rift_front_app drawing=off icon.drawing=off label.color="$TEXT" label.font="JetBrains Mono:Bold:15.0" label.max_chars=32 label.padding_left=0 label.padding_right=0 background.drawing=off background.image.drawing=off script="$PLUGIN_DIR/rift_front_app.sh" --subscribe rift_front_app rift_state_changed

NAME=rift_front_app "$PLUGIN_DIR/rift_front_app.sh"
