#!/usr/bin/env bash

# volume_slider=(
#   script="$PLUGIN_DIR/volume.sh"
#   label.drawing=off
#   icon.drawing=off
#   slider.highlight_color=$BLUE
#   slider.background.height=5
#   slider.background.corner_radius=3
#   slider.background.color=$OVERLAY0
#   slider.knob=􀀁
#   slider.knob.drawing=on
#   padding_left=0
# )

# volume=(
#   click_script="$PLUGIN_DIR/volume_click.sh"
#   icon.padding_right=2
#   label.drawing=off
# )

# status_bracket=(
#   background.color=$BACKGROUND_1
#   background.border_color=$BACKGROUND_2
# )

# sketchybar --add slider volume right \
#   --subscribe volume volume_change \
#   mouse.clicked \
#   --add item volume_icon right \
#   --set volume_icon "${volume_icon[@]}"

# sketchybar --add bracket status brew github.bell wifi volume_icon \
#            --set status "${status_bracket[@]}"

current_vol=$(osascript -e 'output volume of (get volume settings)')

volume=(
  script="$PLUGIN_DIR/volume.sh"
  padding_left=0
  padding_right=0
  label.width=0
)

sketchybar --add item volume right \
  --set volume "${volume[@]}" \
  click_script="$PLUGIN_DIR/volume_click.sh" \
  --subscribe volume volume_change
