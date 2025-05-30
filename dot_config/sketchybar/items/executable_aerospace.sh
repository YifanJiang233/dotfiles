#!/usr/bin/env bash

sketchybar --add event aerospace_workspace_change

# SPACE_LIST="$(aerospace list-workspaces --all)";
SPACE_LIST=("1" "2" "3" "4" "5" "A" "B" "C" "D" "E")

for sid in ${SPACE_LIST[@]}; do
  sketchybar --add item space.$sid left

  sketchybar --set space.$sid \
    icon.width=0 \
    label.width=0 \
    icon.color="$GREY" \
    label.color="$GREY" \
    icon.highlight_color="$TEXT" \
    label.highlight_color="$TEXT" \
    background.color="$SURFACE2" \
    background.corner_radius=4 \
    background.height=20 \
    background.drawing=off \
    icon.font="SF Pro:Bold:13.0" \
    icon="$sid:" \
    icon.padding_right=0 \
    label.font="sketchybar-app-font:Regular:13.0" \
    label.padding_left=0 \
    label.padding_right=15 \
    label.y_offset=-1 \
    click_script="aerospace workspace $sid"
done

sketchybar --add item aerospace left \
  --subscribe aerospace aerospace_workspace_change \
  --set aerospace \
  drawing=off \
  script="$CONFIG_DIR/plugins/aerospace.sh"

sketchybar --add item dummy left \
  --subscribe dummy front_app_switched \
  --set dummy script="$CONFIG_DIR/plugins/space_app.sh" \
  drawing=off
