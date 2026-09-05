#!/usr/bin/env bash

source "$CONFIG_DIR/styles/style.sh"
source "$CONFIG_DIR/plugins/right_tooltip.sh"

set_weather_display() {
  local weather_text="$1"
  local weather_label=""
  local weather_icon="$weather_text"

  case "$weather_text" in
    *" "*)
      weather_label="${weather_text% *}"
      weather_icon="${weather_text##* }"
      ;;
  esac

  # SketchyBar renders its icon slot before its label slot. Put Waybar's
  # left-hand text in the first slot so the glyph can keep its own font.
  sketchybar --set "$NAME" \
    icon="$weather_label" icon.color="$TEXT" \
    label="$weather_icon" label.color="$TEXT"
}

if [ "$SENDER" = "mouse.entered" ] || [ "$SENDER" = "mouse.exited" ]; then
  right_tooltip_hover "$NAME" "$SENDER"
  exit 0
fi

PYTHON="/opt/homebrew/bin/python3"
JQ="/opt/homebrew/bin/jq"
WEATHER_SCRIPT="$HOME/.config/sketchybar/weather.py"

if [ ! -x "$PYTHON" ] || [ ! -x "$JQ" ] || [ ! -f "$WEATHER_SCRIPT" ]; then
  set_weather_display "☔"
  right_tooltip_update "$NAME" "Weather unavailable"
  exit 0
fi

weather_json=$("$PYTHON" "$WEATHER_SCRIPT" 2>/dev/null) || weather_json=""

if [ -n "$weather_json" ]; then
  weather_text=$(printf '%s' "$weather_json" | "$JQ" -r '.text // "☔"' 2>/dev/null)
  weather_tooltip=$(printf '%s' "$weather_json" | "$JQ" -r '.tooltip // "Weather unavailable"' 2>/dev/null)
else
  weather_text="☔"
  weather_tooltip="Weather unavailable"
fi

[ -n "$weather_text" ] || weather_text="☔"
[ -n "$weather_tooltip" ] || weather_tooltip="Weather unavailable"

set_weather_display "$weather_text"
right_tooltip_update "$NAME" "$weather_tooltip"
