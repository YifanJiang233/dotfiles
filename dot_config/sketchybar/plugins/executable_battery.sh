#!/usr/bin/env bash

source "$CONFIG_DIR/styles/style.sh"

BATTERY_INFO="$(pmset -g batt)"
PERCENTAGE=$(echo "$BATTERY_INFO" | grep -Eo "\d+%" | cut -d% -f1)
CHARGING=$(echo "$BATTERY_INFO" | grep 'AC Power')

if [ $PERCENTAGE = "" ]; then
  exit 0
fi

case ${PERCENTAGE} in
  9[0-9] | 100)
    ICON=$BATTERY_100
    COLOR=$TEXT
    ;;
  [6-8][0-9])
    ICON=$BATTERY_75
    COLOR=$TEXT
    ;;
  [3-5][0-9])
    ICON=$BATTERY_50
    COLOR=$PEACH
    ;;
  [1-2][0-9])
    ICON=$BATTERY_25
    COLOR=$RED
    ;;
  *)
    ICON=$BATTERY_0
    COLOR=$RED
    ;;
esac

if [[ $CHARGING != "" ]]; then
  ICON=$BATTERY_CHARGING
  case ${PERCENTAGE} in
    9[0-9] | 100)
      COLOR=$GREEN
      ;;
    [6-8][0-9])
      COLOR=$GREEN
      ;;
    [3-5][0-9])
      COLOR=$PEACH
      ;;
    [1-2][0-9])
      COLOR=$RED
      ;;
    *)
      ICON=$BATTERY_0
      COLOR=$RED
      ;;
  esac
fi

LABEL="${PERCENTAGE}%"

sketchybar --set $NAME icon="$ICON" icon.color=$COLOR \
  label="$LABEL" label.color=$COLOR
