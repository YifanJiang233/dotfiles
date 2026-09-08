#!/usr/bin/env bash

PYTHON="/opt/homebrew/bin/python3"
WEATHER_SCRIPT="$HOME/.config/weather/weather.py"

[ -x "$PYTHON" ] || exit 0
[ -f "$WEATHER_SCRIPT" ] || exit 0

if [ "$BUTTON" = "right" ]; then
  "$PYTHON" "$WEATHER_SCRIPT" --open >/dev/null 2>&1
else
  "$PYTHON" "$WEATHER_SCRIPT" --refresh >/dev/null 2>&1
  sketchybar --trigger weather_refresh
fi
