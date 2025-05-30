#!/usr/bin/env bash

# airport is deprecated

# speed() {
#   CURRENT_WIFI="$(/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I)"
#   SSID="$(echo "$CURRENT_WIFI" | grep -o "SSID: .*" | sed 's/^SSID: //')"
#   CURR_TX="$(echo "$CURRENT_WIFI" | grep -o "lastTxRate: .*" | sed 's/^lastTxRate: //')"
#   CURR_TX=$((CURR_TX / 8))
#   LABEL="${CURR_TX}MB/s"
#   sketchybar --set $NAME label="$LABEL"

#   CURRENT_WIDTH="$(sketchybar --query $NAME | jq -r .label.width)"

#   WIDTH=0
#   if [ "$CURRENT_WIDTH" -eq "0" ]; then
#     WIDTH=dynamic
#   fi
#   sketchybar --animate sin 20 --set $NAME label.width="$WIDTH"
# }

# popup() {
#   sketchybar --set "$NAME" popup.drawing=toggle
#   source "$CONFIG_DIR/styles/style.sh"

#   args=(--remove '/wifi.ssid\.*/')

#   WIFI_INFO="$(/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -s | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
#   INFO="$(awk -F' {2,}' 'NR>1 {print $1 "  " $2}' <<< "$WIFI_INFO" | tail -r)"

#   # RSSI=" $( awk -F' {2,}' 'NR>1 {print $2}' <<< "$WIFI_INFO" )"
#   COUNTER=0
#   CURRENT="$(/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I | grep -o "SSID: .*" | sed 's/^SSID: //')"
#   WIFI_LIST=" "
#   while IFS= read -r line; do
#     COLOR=$GREY
#     SSID="$(echo "$line" | awk -F' {2,}' '{print $1}')"
#     RSSI="$(echo "$line" | awk -F' {2,}' '{print $2}')"
#     if [ "$SSID" = "$CURRENT" ]; then
#       COLOR=$TEXT
#     fi

#     ICON_COLOR=$PEACH
#     if [ "$((RSSI))" -gt "-50" ]; then
#       ICON_COLOR=$SKY
#     elif [ "$((RSSI))" -gt "-60" ]; then
#       ICON_COLOR=$GREEN
#     fi

#     if [ "$((RSSI))" -gt "-70" ] && [[ ! "$WIFI_LIST" == *"$SSID "* ]]; then
#       WIFI_LIST="$WIFI_LIST$SSID "
#       args+=(--add item wifi.ssid.$COUNTER popup."$NAME"
#         --set wifi.ssid.$COUNTER label="$SSID"
#         label.color="$COLOR"
#         label.font="$FONT:Medium:13.0"
#         icon=◉
#         icon.color="$ICON_COLOR"
#         icon.font.size=13.0
#         click_script="sketchybar --set /wifi.ssid\.*/ label.color=$GREY --set $NAME popup.drawing=off && networksetup -setairportnetwork en0 $SSID")
#       COUNTER=$((COUNTER + 1))
#     fi
#   done <<< "$(echo -e "$INFO")"
#   sketchybar -m "${args[@]}" > /dev/null
# }

# if [ "$BUTTON" = "right" ] || [ "$MODIFIER" = "shift" ]; then
#   speed
# else
#   popup
# fi

INFO="$(networksetup -getairportnetwork en0 | awk -F ': ' '{print $2}')"
sketchybar --set $NAME label="$INFO"

CURRENT_WIDTH="$(sketchybar --query $NAME | jq -r .label.width)"

WIDTH=0
if [ "$CURRENT_WIDTH" -eq "0" ]; then
  WIDTH=dynamic
fi
sketchybar --animate sin 20 --set $NAME label.width="$WIDTH"
