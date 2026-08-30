#!/usr/bin/env bash

RIFT_WORKSPACE_EVENT="rift_state_changed"
RIFT_WORKSPACE_INDICES=(0 1 2 3 4 5 6 7 8 9)

sketchybar --add event "$RIFT_WORKSPACE_EVENT"

for index in "${RIFT_WORKSPACE_INDICES[@]}"; do
  workspace_number=$((index + 1))
  item="rift.workspace.$index"

  sketchybar --add item "$item" left
  sketchybar --set "$item" drawing=off padding_left=2 padding_right=2 icon.drawing=off label="$workspace_number" label.color="$TEXT" label.font="JetBrains Mono:Bold:15.0" label.padding_left=6 label.padding_right=6 background.drawing=off background.color="$SURFACE2" background.corner_radius=0 background.height=28 background.y_offset=2 background.border_width=0 background.shadow.drawing=off background.shadow.color="$BLUE" background.shadow.angle=90 background.shadow.distance=3 click_script="/opt/homebrew/bin/rift-cli execute workspace switch $index"
done

sketchybar --add item rift_workspaces_controller left --set rift_workspaces_controller drawing=off script="$PLUGIN_DIR/rift_workspaces.sh" --subscribe rift_workspaces_controller "$RIFT_WORKSPACE_EVENT"

RIFT_FORCE_UPDATE=1 "$PLUGIN_DIR/rift_workspaces.sh"
