#!/usr/bin/env bash

right_tooltip_hover() {
  local item="$1"
  local sender="$2"

  case "$sender" in
    mouse.entered)
      sketchybar --set "$item" popup.drawing=on
      ;;
    mouse.exited)
      sketchybar --set "$item" popup.drawing=off
      ;;
  esac
}

right_tooltip_update() {
  local parent="$1"
  local tooltip="$2"
  local alignment="${3:-left}"
  local line
  local wrapped_line
  local line_length
  local max_line_length=0
  local tooltip_width="dynamic"
  local index=0
  local item
  local -a lines
  local -a args

  lines=()

  while IFS= read -r line || [ -n "$line" ]; do
    line=$(printf '%s' "$line" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
    [ -n "$line" ] || continue

    while IFS= read -r wrapped_line || [ -n "$wrapped_line" ]; do
      [ -n "$wrapped_line" ] || continue
      lines+=("$wrapped_line")
      line_length=${#wrapped_line}
      [ "$line_length" -le "$max_line_length" ] || max_line_length="$line_length"
    done < <(printf '%s\n' "$line" | fold -s -w 34)
  done <<< "$tooltip"

  if [ "${#lines[@]}" -eq 0 ]; then
    lines=("Unavailable")
    max_line_length=11
  fi

  if [ "$alignment" = "center" ]; then
    tooltip_width=$((max_line_length * 9 + 24))
    [ "$tooltip_width" -ge 152 ] || tooltip_width=152
    [ "$tooltip_width" -le 336 ] || tooltip_width=336
  fi

  args=(--remove "/^${parent}\\.tooltip\\.line\\.[0-9]+$/")

  for line in "${lines[@]}"; do
    item="${parent}.tooltip.line.${index}"
    args+=(
      --add item "$item" "popup.${parent}"
      --set "$item"
        label="$line"
        icon.drawing=off
        label.color="$TEXT"
        label.font="JetBrains Mono:Bold:15.0"
        label.padding_left=12
        label.padding_right=12
        label.width="$tooltip_width"
        label.align="$alignment"
        padding_left=0
        padding_right=0
    )
    index=$((index + 1))
  done

  sketchybar "${args[@]}" >/dev/null 2>&1
}
