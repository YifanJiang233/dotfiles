#!/usr/bin/env bash

# make sure it's executable with:
# chmod +x ~/.config/sketchybar/plugins/aerospace.sh

#

sid=$(aerospace list-workspaces --focused)

APP_LIST="$(aerospace list-windows --workspace $sid | awk -F '|' '{print $2}')"
ICON_LIST=""
while IFS= read -r line; do 
      line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
      icon=$($CONFIG_DIR/icon_map.sh "$line")
      if ! grep -q "$icon" <<< "$ICON_LIST"; then
        ICON_LIST="$ICON_LIST $icon"
      fi
done <<< "$APP_LIST"

sleep 0.2
sketchybar --set space.$sid label="$ICON_LIST" \
  icon.width="dynamic" \
  label.width="dynamic" \
  width="dynamic" \
  background.drawing=on
