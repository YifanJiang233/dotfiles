#!/usr/bin/env bash

sketchybar --load-font "$CONFIG_DIR/fonts/Twemoji.Mozilla.ttf"

# COLR glyphs report zero path bounds; reserve space for the weather emoji.
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
    label.font="Twemoji Mozilla:Regular:15.0" \
    label.width=20 \
    label.color="$TEXT" \
    label.y_offset=1 \
    label.padding_left=0 \
    label.padding_right=0 \
    padding_left=5 \
    padding_right=5 \
    "${tooltip_defaults[@]}" \
  --subscribe weather weather_refresh mouse.entered mouse.exited
