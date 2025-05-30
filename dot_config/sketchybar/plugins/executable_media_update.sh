#!/usr/bin/env bash
PLAYING=1
TRACK="$(/opt/homebrew/bin/nowplaying-cli get title)"
if [ "$TRACK" != "null" ]; then
  PLAYING=0
  ARTIST="$(/opt/homebrew/bin/nowplaying-cli get artist)"
  MEDIA="$TRACK - $ARTIST"
  PLAYBACK_RATE=$(/opt/homebrew/bin/nowplaying-cli get playbackRate)
fi

args=()
if [ $PLAYING -eq 0 ]; then
  /opt/homebrew/bin/nowplaying-cli get artworkData | base64 --decode > ~/Library/Application\ Support/sketchybar/cover.jpg
  args+=(--set media_ctrl.title label="$TRACK"
    --set media_ctrl.artist label="$ARTIST")
  args+=(--set media_ctrl.play icon=􀊆
    --set media_ctrl.cover background.image="~/Library/Application Support/sketchybar/cover.jpg"
    background.color=0x00000000)
  if [ "$PLAYBACK_RATE" -eq 0 ]; then
    args+=(--set media_ctrl.play icon=􀊄)
  fi
fi
sketchybar -m "${args[@]}"
