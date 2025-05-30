#!/usr/bin/env bash

toggle_lyric() {
  pkill fswatch

  CURRENT_WIDTH="$(sketchybar --query $NAME | jq -r .label.width)"
  WIDTH=0
  sketchybar --animate sin 20 --set $NAME label.width="$WIDTH"
  if [ "$CURRENT_WIDTH" -eq "0" ]; then
    /Users/user/.config/sketchybar/plugins/lyric.sh
    WIDTH=dynamic
    sketchybar --animate sin 20 --set $NAME label.width="$WIDTH"
    fswatch -o ~/Library/Application\ Support/sketchybar/lyric.txt | xargs -n1 -I{} /Users/user/.config/sketchybar/plugins/lyric.sh
  fi
}

default_layout=(--set lyric popup.height=150
  --set media_ctrl.title drawing=on
  --set media_ctrl.artist drawing=on
  --set media_ctrl.cover drawing=on
  --set media_ctrl.back icon.padding_left=0
  icon.padding_right=15
  y_offset=-45
  --set media_ctrl.play y_offset=-45
  icon.padding_right=15
  icon.padding_left=15
  --set media_ctrl.next y_offset=-45
  icon.padding_left=15
  icon.padding_right=10)

compact_layout=(--set lyric popup.height=25
  --set media_ctrl.title drawing=off
  --set media_ctrl.artist drawing=off
  --set media_ctrl.cover drawing=off
  --set media_ctrl.back icon.padding_left=5
  icon.padding_right=5
  y_offset=0
  --set media_ctrl.play y_offset=0
  icon.padding_left=15
  icon.padding_right=15
  --set media_ctrl.next y_offset=0
  icon.padding_right=5
  icon.padding_left=5)

update() {
  TRACK="$(/opt/homebrew/bin/nowplaying-cli get title)"
  args=()
  if [ "$TRACK" != "null" ]; then
    ARTIST="$(/opt/homebrew/bin/nowplaying-cli get artist)"
    if [[ "$ARTIST" == *","* ]]; then
      ARTIST=${ARTIST//,/,\ }
    fi
    MUSIC="$(/opt/homebrew/bin/nowplaying-cli get IsMusicApp)"
    PLAYBACK_RATE=$(/opt/homebrew/bin/nowplaying-cli get playbackRate)
    /opt/homebrew/bin/nowplaying-cli get artworkData | base64 --decode > ~/Library/Application\ Support/sketchybar/cover.jpg
    args+=(--set media_ctrl.title label="$TRACK"
      --set media_ctrl.artist label="$ARTIST"
      --set media_ctrl.cover background.image="~/Library/Application Support/sketchybar/cover.jpg"
      background.color=0x00000000
    )
    if [[ "$TRACK" =~ ^[a-zA-Z0-9[:space:]-]*$ ]]; then
      args+=(--set media_ctrl.title label.max_chars=15)
    else
      args+=(--set media_ctrl.title label.max_chars=8)
    fi
    if [[ "$ARTISt" =~ ^[a-zA-Z0-9[:space:]-]*$ ]]; then
      args+=(--set media_ctrl.artist label.max_chars=19)
    else
      args+=(--set media_ctrl.artist label.max_chars=10)
    fi
    if [ "$MUSIC" == "1" ]; then
      args+=(background.image.scale=0.2)
    else
      args+=(background.image.scale=0.8)
    fi
    if [ "$PLAYBACK_RATE" == "0" ]; then
      args+=(--set media_ctrl.play icon=􀊄)
    else
      args+=(--set media_ctrl.play icon=􀊆)
    fi
    args+=("${default_layout[@]}")
  else
    args=("${compact_layout[@]}")
  fi
  sketchybar -m "${args[@]}"
}

popup() {
  sketchybar --set lyric popup.drawing=toggle
  update
}

if [ "$BUTTON" = "right" ] || [ "$MODIFIER" = "shift" ]; then
  toggle_lyric
else
  popup
fi
