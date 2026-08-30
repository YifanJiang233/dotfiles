#!/usr/bin/env bash

source "$CONFIG_DIR/styles/style.sh"

sketchybar --set "$NAME" label="$(date '+%a %d %b %H:%M')" label.color="$TEXT"
