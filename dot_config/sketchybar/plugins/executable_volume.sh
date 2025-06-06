#!/usr/bin/env bash

# WIDTH=60

# volume_change() {
#   source "$CONFIG_DIR/styles/style.sh"
#   case $INFO in
#     [6-9][0-9] | 100)
#       ICON=$VOLUME_100
#       ;;
#     [3-5][0-9])
#       ICON=$VOLUME_66
#       ;;
#     [1-2][0-9])
#       ICON=$VOLUME_33
#       ;;
#     [1-9])
#       ICON=$VOLUME_10
#       ;;
#     0)
#       ICON=$VOLUME_0
#       ;;
#     *) ICON=$VOLUME_100 ;;
#   esac

#   CURRENT="$(SwitchAudioSource -t output -c)"

#   case "$CURRENT" in
#     "Beoplay EQ" | "External Headphones")
#       ICON=$HEADSET
#       ;;
#     "BenQ GW2470" | "PL2409HD")
#       ICON="󰽟"
#       ;;
#   esac

#   sketchybar --set volume_icon icon=$ICON \
#     --set $NAME slider.percentage=$INFO

#   INITIAL_WIDTH="$(sketchybar --query $NAME | jq -r ".slider.width")"
#   if [ "$INITIAL_WIDTH" -eq "0" ]; then
#     sketchybar --animate tanh 30 --set $NAME slider.width=$WIDTH
#   fi

#   sleep 2

#   # Check wether the volume was changed another time while sleeping
#   FINAL_PERCENTAGE="$(sketchybar --query $NAME | jq -r ".slider.percentage")"
#   if [ "$FINAL_PERCENTAGE" -eq "$INFO" ]; then
#     sketchybar --animate tanh 30 --set $NAME slider.width=0
#   fi
# }

# mouse_clicked() {
#   osascript -e "set volume output volume $PERCENTAGE"
# }

# case "$SENDER" in
#   "volume_change")
#     volume_change
#     ;;
#   "mouse.clicked")
#     mouse_clicked
#     ;;
# esac

source "$CONFIG_DIR/styles/style.sh"

case $INFO in
  [6-9][0-9] | 100)
    ICON=$VOLUME_100
    ;;
  [3-5][0-9])
    ICON=$VOLUME_66
    ;;
  [1-2][0-9])
    ICON=$VOLUME_33
    ;;
  [1-9])
    ICON=$VOLUME_10
    ;;
  0)
    ICON=$VOLUME_0
    ;;
  *) ICON=$VOLUME_100 ;;
esac

CURRENT="$(SwitchAudioSource -t output -c)"

case "$CURRENT" in
  "Beoplay EQ" | "External Headphones")
    ICON=$HEADSET
    ;;
  "BenQ GW2470" | "PL2409HD")
    ICON="󰽟"
    ;;
esac

sketchybar --set $NAME icon=$ICON \
  label="${INFO}%"

# --set $NAME slider.percentage=$INFO

# INITIAL_WIDTH="$(sketchybar --query $NAME | jq -r ".slider.width")"
# if [ "$INITIAL_WIDTH" -eq "0" ]; then
#   sketchybar --animate tanh 30 --set $NAME slider.width=$WIDTH
# fi

# sleep 2

# Check wether the volume was changed another time while sleeping
# FINAL_PERCENTAGE="$(sketchybar --query $NAME | jq -r ".slider.percentage")"
# if [ "$FINAL_PERCENTAGE" -eq "$INFO" ]; then
#   sketchybar --animate tanh 30 --set $NAME slider.width=0
# fi
