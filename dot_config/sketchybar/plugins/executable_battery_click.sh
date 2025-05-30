#!/usr/bin/env bash

CURRENT_WIDTH="$(sketchybar --query $NAME | jq -r .label.width)"
WIDTH=0
if [ "$CURRENT_WIDTH" -eq "0" ]; then
  WIDTH=dynamic
fi
sketchybar --animate sin 20 --set $NAME label.width="$WIDTH"

# percentage() {
#   CURRENT_WIDTH="$(sketchybar --query $NAME | jq -r .label.width)"
#   WIDTH=0
#   if [ "$CURRENT_WIDTH" -eq "0" ]; then
#     WIDTH=dynamic
#   fi
#   sketchybar --animate sin 20 --set $NAME label.width="$WIDTH"
# }

# if [ "$BUTTON" = "right" ] || [ "$MODIFIER" = "shift" ]; then
#   percentage
# fi
