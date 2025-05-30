#!/usr/bin/env bash

source "$CONFIG_DIR/styles/style.sh"
# INFO="$(/System/Library/PrivateFrameworks/Apple80211.framework/Resources/airport -I | awk -F ' SSID: ' '/ SSID: / {print $2}')"
INFO="$(networksetup -getairportnetwork en0 | awk -F ': ' '{print $2}')"

ICON="$([ -n "$INFO" ] && echo "$WIFI_CONNECTED" || echo "$WIFI_DISCONNECTED")"
COLOR="$([ -n "$INFO" ] && echo "$TEXT" || echo "$RED")"

sketchybar --set $NAME icon="$ICON" \
  icon.color="$COLOR"
