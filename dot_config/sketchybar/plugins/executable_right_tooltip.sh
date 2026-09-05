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
  local line
  local wrapped_line
  local emoji
  local text_padding
  local text_right_padding
  local row_right_padding
  local alignment=left
  local row_width=dynamic
  local label_width
  local content
  local content_width
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

  if [ "$parent" = "weather" ]; then
    alignment=center
    row_width=152
    for line in "${lines[@]}"; do
      content="$line"
      case "$content" in
        "📍 "*|"⚠️ "*) content="${content#* }" ;;
      esac
      content_width=$((${#content} * 9 + 64))
      [ "$content_width" -le "$row_width" ] || row_width="$content_width"
    done
  fi

  args=(--remove "/^${parent}\\.tooltip\\.line\\.[0-9][0-9]*$/")

  for line in "${lines[@]}"; do
    emoji=""
    text_padding=12
    text_right_padding=12
    row_right_padding=0
    label_width="$row_width"
    if [ "$parent" = "weather" ]; then
      case "$line" in
        "📍 "*|"⚠️ "*)
          emoji="${line%% *}"
          line="${line#* }"
          text_padding=0
          text_right_padding=0
          # Balance the emoji slot so the text stays on the popup centerline.
          label_width=$((row_width - 64))
          row_right_padding=32
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
        label.padding_right="$text_right_padding"
        label.width="$label_width"
        label.align="$alignment"
        padding_left=0
        padding_right="$row_right_padding"
    )
    if [ -n "$emoji" ]; then
      # Fixed icon width includes the 12-point inset plus 20 points for COLR art.
      args+=(--set "$item"
        icon="$emoji"
        icon.drawing=on
        icon.font="Twemoji Mozilla:Regular:15.0"
        icon.color="$TEXT"
        icon.width=32
        icon.align=left
        icon.padding_left=12
        icon.padding_right=0
      )
    fi
    index=$((index + 1))
  done

  if sketchybar "${args[@]}" >/dev/null 2>&1; then
    printf '%s' "$cache_key" > "$cache_file"
  fi
}
