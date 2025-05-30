#!/usr/bin/env bash

sleep 0.2

# make sure it's executable with:
# chmod +x ~/.config/sketchybar/plugins/aerospace.sh
SPACE_LIST=("1" "2" "3" "4" "5" "A" "B" "C" "D" "E")
ACTIVATED_WORKSPACES="$(aerospace list-workspaces --monitor all --empty no)"
#

if [ -z "$FOCUSED_WORKSPACE" ]; then
  FOCUSED_WORKSPACE=$(aerospace list-workspaces --focused)
fi

sketchybar --animate tanh 10 --set space.$FOCUSED_WORKSPACE \
  icon.width="dynamic" \
  label.width="dynamic" \
  width="dynamic" \
  icon.highlight=on \
  label.highlight=on

sketchybar --set space.$FOCUSED_WORKSPACE background.drawing=on

for sid in ${SPACE_LIST[@]}; do
  if [[ "$sid" == "$FOCUSED_WORKSPACE" ]]; then
    APP_LIST="$(aerospace list-windows --workspace $sid | awk -F '|' '{print $2}')"
    ICON_LIST=""
    while IFS= read -r line; do 
      line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
      icon=$($CONFIG_DIR/icon_map.sh "$line")
      if ! grep -q "$icon" <<< "$ICON_LIST"; then
        ICON_LIST="$ICON_LIST $icon"
      fi
    done <<< "$APP_LIST"

    sketchybar --set space.$sid label="$ICON_LIST" \
      icon.highlight=on \
      label.highlight=on
    continue
  fi
  if [[ " ${ACTIVATED_WORKSPACES[*]} " = *"$sid"* ]]; then
    APP_LIST="$(aerospace list-windows --workspace $sid | awk -F '|' '{print $2}')"
    ICON_LIST=""
    while IFS= read -r line; do 
      line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
      icon=$($CONFIG_DIR/icon_map.sh "$line")
      if ! grep -q "$icon" <<< "$ICON_LIST"; then
        ICON_LIST="$ICON_LIST $icon"
      fi
    done <<< "$APP_LIST"

    sketchybar --set space.$sid \
      background.drawing=off \
      label="$ICON_LIST"
    sketchybar --animate tanh 10 --set space.$sid icon.width="dynamic" \
      label.width="dynamic" \
      icon.highlight=off \
      label.highlight=off \
      width="dynamic"

  else
    sketchybar --animate sin 10 --set space.$sid icon.width=0 \
      label.width=0 \
      width=0
  fi
done
