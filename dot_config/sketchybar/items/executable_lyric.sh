#!/usr/bin/env bash

lyric=(
  icon.font="sketchybar-app-font:Regular:16.0"
  icon.color="$BLUE"
  icon=":music:"
  label.color="$BLUE"
  label.font="$FONT:Bold:13.0"
  label.width=0
  popup.horizontal=on
  popup.align=center
  popup.height=150
  click_script="$PLUGIN_DIR/lyric_click.sh"
  # script="$PLUGIN_DIR/media_update.sh"
)

media_ctrl_cover=(
  label.drawing=off
  icon.drawing=off
  padding_left=12
  padding_right=10
  background.image.scale=0.8
)

media_ctrl_title=(
  icon.drawing=off
  padding_left=0
  padding_right=0
  # align=left
  width=0
  label.font="$FONT:Bold:15.0"
  label.max_chars=15
  scroll_texts=on
  y_offset=50
)

media_ctrl_artist=(
  scroll_texts=on
  icon.drawing=off
  y_offset=25
  padding_left=0
  padding_right=0
  # align=left
  width=0
  label.max_chars=20
  label.font="$FONT:Regular:13.0"
)

media_ctrl_back=(
  icon=􀊎
  icon.padding_left=0
  icon.padding_right=15
  icon.color=$TEXT
  click_script="$PLUGIN_DIR/media_ctrl.sh"
  label.drawing=off
  y_offset=-45
)

media_ctrl_play=(
  icon=􀊄
  background.height=20
  background.corner_radius=15
  background.color=$BLUE
  # width=100
  align=center
  # background.border_color=$TEXT
  # background.border_width=0
  # background.drawing=on
  icon.padding_left=15
  icon.padding_right=15
  label.drawing=off
  click_script="$PLUGIN_DIR/media_ctrl.sh"
  y_offset=-45
)

media_ctrl_next=(
  icon=􀊐
  icon.padding_left=15
  icon.padding_right=10
  icon.color=$TEXT
  label.drawing=off
  click_script="$PLUGIN_DIR/media_ctrl.sh"
  y_offset=-45
)

# media_ctrl_controls=(
# background.corner_radius=11
# background.drawing=on
# padding_left=20
# padding_right=60
# y_offset=-45
# )

sketchybar --add item lyric center \
  --set lyric "${lyric[@]}" \
  --add item media_ctrl.cover popup.lyric \
  --set media_ctrl.cover "${media_ctrl_cover[@]}" \
  --add item media_ctrl.title popup.lyric \
  --set media_ctrl.title "${media_ctrl_title[@]}" \
  --add item media_ctrl.artist popup.lyric \
  --set media_ctrl.artist "${media_ctrl_artist[@]}" \
  --add item media_ctrl.back popup.lyric \
  --set media_ctrl.back "${media_ctrl_back[@]}" \
  --subscribe media_ctrl.back mouse.clicked \
  --add item media_ctrl.play popup.lyric \
  --set media_ctrl.play "${media_ctrl_play[@]}" \
  --subscribe media_ctrl.play mouse.clicked media_change \
  --add item media_ctrl.next popup.lyric \
  --set media_ctrl.next "${media_ctrl_next[@]}" \
  --subscribe media_ctrl.next mouse.clicked
# --add item media_ctrl.spacer popup.lyric \
# --set media_ctrl.spacer width=5

#  --add bracket media_ctrl.controls media_ctrl.back           \
#                                 media_ctrl.play           \
#                                 media_ctrl.next           \
#  --set media_ctrl.controls "${media_ctrl_controls[@]}"
# --subscribe lyric lyric_update
