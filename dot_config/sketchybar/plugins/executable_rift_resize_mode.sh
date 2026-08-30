#!/usr/bin/env bash

case "${STATE:-off}" in
  on) sketchybar --set "$NAME" drawing=on ;;
  *) sketchybar --set "$NAME" drawing=off ;;
esac
