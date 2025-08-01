#!/usr/bin/env sh

sketchybar --add item svim.mode right \
  --set svim.mode popup.align=right \
  icon= \
  icon.color=0xffcdd6f4 \
  icon.font="JetBrainsMono Nerd Font:Regular:20.0" \
  label.font="JetBrainsMono Nerd Font:Bold:13.0" \
  label.width=0 \
  padding_left=0 \
  padding_right=0 \
  script="sketchybar --set svim.mode popup.drawing=off" \
  --subscribe svim.mode front_app_switched window_focus \
  --add item svim.cmdline popup.svim.mode
