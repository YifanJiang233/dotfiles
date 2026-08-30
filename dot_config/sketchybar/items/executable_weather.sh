#!/usr/bin/env bash

sketchybar --add item weather right \
  --set weather \
    update_freq=1800 \
    script="$PLUGIN_DIR/weather.sh" \
    click_script="$PLUGIN_DIR/weather_click.sh" \
    icon.drawing=on \
    icon.font="JetBrains Mono:Bold:15.0" \
    icon.color="$TEXT" \
    icon.padding_left=0 \
    icon.padding_right=4 \
    label.font="Apple Color Emoji:Regular:15.0" \
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
  --subscribe weather weather_refresh mouse.entered mouse.exited
