#!/usr/bin/env bash

# WIDTH=60

# detail_on() {
#   sketchybar --animate tanh 30 --set volume slider.width=$WIDTH
# }

# detail_off() {
#   sketchybar --animate tanh 30 --set volume slider.width=0
# }

# toggle_detail() {
#   INITIAL_WIDTH=$(sketchybar --query volume | jq -r ".slider.width")
#   if [ "$INITIAL_WIDTH" -eq "0" ]; then
#     detail_on
#   else
#     detail_off
#   fi
# }

show_detail() {
  CURRENT_WIDTH="$(sketchybar --query $NAME | jq -r .label.width)"
  WIDTH=0
  if [ "$CURRENT_WIDTH" -eq "0" ]; then
    WIDTH=dynamic
  fi
  sketchybar --animate sin 20 --set $NAME label.width="$WIDTH"
}

toggle_devices() {
  which SwitchAudioSource > /dev/null || exit 0
  source "$CONFIG_DIR/styles/style.sh"

  args=(--remove '/volume.device\.*/' --set "$NAME" popup.drawing=toggle)
  COUNTER=0
  CURRENT="$(SwitchAudioSource -t output -c)"
  while IFS= read -r device; do
    COLOR=$GREY
    if [ "${device}" = "$CURRENT" ]; then
      COLOR=$TEXT
    fi
    args+=(--add item volume.device.$COUNTER popup."$NAME"
      --set volume.device.$COUNTER label="${device}"
      label.color="$COLOR"
      label.font="$FONT:Medium:13.0"
      icon.drawing=off
      click_script="SwitchAudioSource -s \"${device}\" && sketchybar --set /volume.device\.*/ label.color=$GREY --set $NAME popup.drawing=off")
    COUNTER=$((COUNTER + 1))
  done <<< "$(SwitchAudioSource -a -t output)"

  sketchybar -m "${args[@]}" > /dev/null
}

# show_detail() {
#   sketchybar --set $NAME label="$INFO"

#   CURRENT_WIDTH="$(sketchybar --query $NAME | jq -r .label.width)"

#   WIDTH=0
#   if [ "$CURRENT_WIDTH" -eq "0" ]; then
#     WIDTH=dynamic
#   fi
#   sketchybar --animate sin 20 --set $NAME label.width="$WIDTH"
# }

if [ "$BUTTON" = "right" ] || [ "$MODIFIER" = "shift" ]; then
  toggle_devices
else
  show_detail
fi
