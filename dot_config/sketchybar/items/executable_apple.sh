#!/usr/bin/env bash

POPUP_OFF="sketchybar --set apple popup.drawing=off"
POPUP_CLICK_SCRIPT="sketchybar --set \$NAME popup.drawing=toggle"

logo=(
  icon="$APPLE"
  icon.font="JetBrainsMono Nerd Font:Regular:16.0"
  icon.color="$PEACH"
  icon.y_offset=1
  background.padding_left=5
  background.padding_right=5
  label.drawing=off
  click_script="$CONFIG_DIR/plugins/apple.sh"
)

SLEEP="osascript -e 'tell application \"System Events\" to sleep'"

sketchybar --add item apple left \
  --set apple "${logo[@]}" \
  --subscribe apple mouse.clicked

sketchybar --add item apple.prefs popup.apple \
  --add item apple.reboot popup.apple \
  --set apple.prefs icon= \
  icon.padding_right=2 \
  label="System" \
  label.font="$FONT:Medium:13.0" \
  click_script="$POPUP_OFF; open -a 'System Preferences'" \
  --set apple.reboot icon= \
  label="Reboot" \
  label.font="$FONT:Medium:13.0" \
  click_script="$POPUP_OFF; osascript -e 'tell app \"System Events\" to restart'" \
  --set apple popup.drawing=off

# click_script="$POPUP_CLICK_SCRIPT"          \
#                                                                     \
#    --add item           apple.prefs popup.apple.logo                \
#    --set apple.prefs    icon=$PREFERENCES                           \
#                         label="Preferences"                         \
#                         click_script="open -a 'System Preferences';
#                                       $POPUP_OFF"                   \
#                                                                     \
#    --add item           apple.activity popup.apple.logo             \
#    --set apple.activity icon=$ACTIVITY                              \
#                         label="Activity"                            \
#                         click_script="open -a 'Activity Monitor';
#                                       $POPUP_OFF"\
#                                                                     \
#    --add item           apple.lock popup.apple.logo                 \
#    --set apple.lock     icon=$LOCK                                  \
#                         label="Lock Screen"                         \
#                         click_script="pmset displaysleepnow;
#                                       $POPUP_OFF"
