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

right_tooltip_center_rows() {
  local parent="$1"
  local count="$2"
  local index width extra
  local max_width=0
  local -a widths args

  # Measure rendered rows, including their existing 12-point edge insets.
  # Center each complete row so the pin stays beside its natural-width label.
  for ((index = 0; index < count; index++)); do
    width=$(sketchybar --query "${parent}.tooltip.line.${index}" |
      /opt/homebrew/bin/jq -er '.label.width + (if .icon.drawing == "on" then .icon.width else 0 end)') || return 1
    widths[index]="$width"
    [ "$width" -le "$max_width" ] || max_width="$width"
  done

  for ((index = 0; index < count; index++)); do
    extra=$((max_width - widths[index]))
    args+=(--set "${parent}.tooltip.line.${index}"
      padding_left=$((extra / 2))
      padding_right=$((extra - extra / 2)))
  done
  sketchybar "${args[@]}" >/dev/null 2>&1
}

right_tooltip_update() {
  local parent="$1"
  local tooltip="$2"
  local line
  local wrapped_line
  local emoji
  local text_padding
  local cache_owner="${USER:-$(id -u)}"
  local cache_file="${TMPDIR:-/tmp}/sketchybar-right-tooltip-${cache_owner}-${parent}"
  local cache_key="$tooltip"
  local index=0
  local item
  local -a lines
  local -a args

  if [ -r "$cache_file" ] && [ "$(<"$cache_file")" = "$cache_key" ]; then
    return 0
  fi

  lines=()

  while IFS= read -r line || [ -n "$line" ]; do
    line=$(printf '%s' "$line" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
    [ -n "$line" ] || continue

    while IFS= read -r wrapped_line || [ -n "$wrapped_line" ]; do
      [ -n "$wrapped_line" ] || continue
      lines+=("$wrapped_line")
    done < <(printf '%s\n' "$line" | fold -s -w 34)
  done <<< "$tooltip"

  if [ "${#lines[@]}" -eq 0 ]; then
    lines=("Unavailable")
  fi

  args=(--remove "/^${parent}\\.tooltip\\.line\\.[0-9][0-9]*$/")

  for line in "${lines[@]}"; do
    emoji=""
    text_padding=12
    if [ "$parent" = "weather" ]; then
      case "$line" in
        "📍 "*|"⚠️ "*)
          emoji="${line%% *}"
          line="${line#* }"
          text_padding=0
          ;;
      esac
    fi
    item="${parent}.tooltip.line.${index}"
    args+=(
      --add item "$item" "popup.${parent}"
      --set "$item"
        label="$line"
        icon.drawing=off
        label.color="$TEXT"
        label.font="JetBrains Mono:Bold:15.0"
        label.padding_left="$text_padding"
        label.padding_right=12
        label.width=dynamic
        label.align=left
        padding_left=0
        padding_right=0
    )
    if [ -n "$emoji" ]; then
      # Match the shared 12-point inset, then a 20-point emoji and 4-point gap.
      # COLR emoji need an explicit width because they report zero path bounds.
      args+=(--set "$item"
        icon="$emoji"
        icon.drawing=on
        icon.font="Twemoji Mozilla:Regular:15.0"
        icon.color="$TEXT"
        icon.width=36
        icon.align=left
        icon.padding_left=12
        icon.padding_right=4
      )
    fi
    index=$((index + 1))
  done

  if sketchybar "${args[@]}" >/dev/null 2>&1; then
    if [ "$parent" = "weather" ]; then
      right_tooltip_center_rows "$parent" "$index" || return 1
    fi
    printf '%s' "$cache_key" > "$cache_file"
  fi
}
