#!/usr/bin/env bash

source "$CONFIG_DIR/styles/style.sh"
source "$CONFIG_DIR/plugins/right_tooltip.sh"

if [ "$SENDER" = "mouse.entered" ] || [ "$SENDER" = "mouse.exited" ]; then
  right_tooltip_hover "$NAME" "$SENDER"
  exit 0
fi

NETWORKSETUP="/usr/sbin/networksetup"
SYSTEM_PROFILER="/usr/sbin/system_profiler"
JQ="/opt/homebrew/bin/jq"

wifi_device=""
if [ -x "$NETWORKSETUP" ]; then
  wifi_device=$(
    "$NETWORKSETUP" -listallhardwareports 2>/dev/null |
      awk '/^(Hardware Port|Device):/ { if ($0 ~ /^Hardware Port: Wi-Fi/) want=1; else if ($0 ~ /^Hardware Port:/) want=0; else if (want && $0 ~ /^Device:/) { print $2; exit } }'
  )
fi

[ -n "$wifi_device" ] || wifi_device="en0"

ssid=""
if [ -x "$NETWORKSETUP" ]; then
  ssid=$(
    "$NETWORKSETUP" -getairportnetwork "$wifi_device" 2>/dev/null |
      sed -n 's/^Current Wi-Fi Network: //p'
  )
fi

default_interface=$(route -n get default 2>/dev/null | awk '/interface:/{print $2; exit}')
signal=""

if [ -n "$ssid" ] && [ -x "$SYSTEM_PROFILER" ] && [ -x "$JQ" ]; then
  signal_raw=$(
    "$SYSTEM_PROFILER" SPAirPortDataType -json 2>/dev/null |
      "$JQ" -r '.. | objects | .spairport_signal_noise? // empty' 2>/dev/null |
      head -1
  )
  rssi=$(printf '%s' "$signal_raw" | sed -n 's/^[^0-9-]*\(-[0-9][0-9]*\).*/\1/p')
  case "$rssi" in
    -[0-9]*)
      signal=$((2 * (rssi + 100)))
      [ "$signal" -lt 0 ] && signal=0
      [ "$signal" -gt 100 ] && signal=100
      ;;
  esac
fi

if [ -n "$ssid" ]; then
  if [ -n "$signal" ]; then
    network_text="$signal%"
    network_icon=""
    tooltip="$ssid ($signal%)"
  else
    network_text=""
    network_icon=""
    tooltip="$ssid"
  fi
  color="$TEXT"
elif [ -n "$default_interface" ]; then
  network_text="$default_interface"
  network_icon=""
  tooltip="$default_interface"
  color="$TEXT"
else
  network_text=""
  network_icon=""
  tooltip="Disconnected"
  color="$RED"
fi

sketchybar --set "$NAME" \
  icon="$network_text" icon.color="$color" \
  label="$network_icon" label.color="$color"
right_tooltip_update "$NAME" "$tooltip"
