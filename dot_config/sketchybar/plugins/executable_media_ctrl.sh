#!/bin/bash

next() {
  /opt/homebrew/bin/nowplaying-cli next
}

back() {
  /opt/homebrew/bin/nowplaying-cli previous
}

play() {
  PLAYBACK_RATE=$(/opt/homebrew/bin/nowplaying-cli get playbackRate)
  /opt/homebrew/bin/nowplaying-cli togglePlayPause
  if [ "$PLAYBACK_RATE" -eq 0 ]; then
    sketchybar --set media_ctrl.play icon=􀊆
  else
    sketchybar --set media_ctrl.play icon=􀊄
  fi
}

case "$NAME" in
  "media_ctrl.next")
    next
    ;;
  "media_ctrl.back")
    back
    ;;
  "media_ctrl.play")
    play
    ;;
  *)
    exit
    ;;
esac
