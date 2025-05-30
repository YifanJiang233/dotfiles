#!/usr/bin/env sh

# Load defined icons
source "$CONFIG_DIR/styles/icons.sh"

# Load defined colors
source "$CONFIG_DIR/styles/colors.sh"

PADDINGS=4
FONT="SF Pro"
NERD_FONT="Symbols Nerd Font"

bar_config=(
  blur_radius=30
  color="$BAR_COLOR"
  corner_radius=9
  height=30
  margin=4
  notch_width=0
  padding_left=6
  padding_right=6
  position=top
  shadow=of
  sticky=on
  topmost=off
  y_offset=4
)

icon_defaults=(
  icon.color="$ICON_COLOR"
  icon.font="$NERD_FONT:Regular:16.0"
  icon.padding_left="$PADDINGS"
  icon.padding_right="$PADDINGS"
)

label_defaults=(
  label.color="$TEXT"
  label.font="$FONT:Bold:13.0"
  label.padding_left="$PADDINGS"
  label.padding_right="$PADDINGS"
)

background_defaults=(
  background.corner_radius=9
  background.height=30
  background.padding_left="$PADDINGS"
  background.padding_right="$PADDINGS"
)

popup_defaults=(
  popup.height=25
  popup.background.color="$POPUP"
  popup.background.corner_radius=9
  popup.background.border_color="$LAVENDER"
  popup.background.border_width=1
  popup.blur_radius=5
  popup.y_offset=4
)
