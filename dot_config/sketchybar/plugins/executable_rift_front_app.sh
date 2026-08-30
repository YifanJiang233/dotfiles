#!/usr/bin/env bash

RIFT_CLI="/opt/homebrew/bin/rift-cli"
JQ="/opt/homebrew/bin/jq"
ITEM_NAME="${NAME:-rift_front_app}"
ICON_ITEM_NAME="rift_front_app_icon"

hide_front_app() {
  sketchybar --set "$ITEM_NAME" drawing=off label="" icon.drawing=off --set "$ICON_ITEM_NAME" drawing=off background.image.drawing=off
}

if [ ! -x "$RIFT_CLI" ] || [ ! -x "$JQ" ]; then
  hide_front_app
  exit 0
fi

displays_json=$("$RIFT_CLI" query displays 2>/dev/null) || {
  hide_front_app
  exit 0
}

active_space_id=$(
  printf '%s' "$displays_json" |
    "$JQ" -r '
      if type == "array" then
        first(.[] | select(.is_active_context == true and .space != null) | .space) // empty
      else
        empty
      end
    '
)

if [ -n "$active_space_id" ]; then
  workspaces_json=$("$RIFT_CLI" query workspaces --space-id "$active_space_id" 2>/dev/null) || {
    hide_front_app
    exit 0
  }
  active_index=$(
    "$RIFT_CLI" query layout "$active_space_id" 2>/dev/null |
      "$JQ" -r '(.workspace_id // .workspace_index // empty) | tostring'
  ) || active_index=""
else
  workspaces_json=$("$RIFT_CLI" query workspaces 2>/dev/null) || {
    hide_front_app
    exit 0
  }
  active_index=$(
    "$RIFT_CLI" query layout 2>/dev/null |
      "$JQ" -r '(.workspace_id // .workspace_index // empty) | tostring'
  ) || active_index=""
fi

window_json=$(
  printf '%s' "$workspaces_json" |
    "$JQ" -c --arg active "$active_index" '
      def entries:
        if type == "array" then .
        elif .workspaces then .workspaces
        else []
        end;
      def idx:
        (.index // .workspace_index // (if (.id | type) == "object" then .id.idx else null end));
      [
        entries[]
        | select(.is_active == true or (idx | tostring) == $active)
        | (.windows // [])[]
        | select(.is_focused == true)
      ]
      | first // empty
    '
)

[ -n "$window_json" ] || {
  hide_front_app
  exit 0
}

app_name=$(printf '%s' "$window_json" | "$JQ" -r '.app_name // ""')
bundle_id=$(printf '%s' "$window_json" | "$JQ" -r '.bundle_id // ""')
window_title=$(printf '%s' "$window_json" | "$JQ" -r '.title // ""')
label="$window_title"
[ -n "$label" ] || label="$app_name"

[ -n "$label" ] || {
  hide_front_app
  exit 0
}

if [ "${#label}" -gt 60 ]; then
  label="${label:0:57}…"
fi

if [ -n "$bundle_id" ]; then
  sketchybar --set "$ITEM_NAME" drawing=on label="$label" icon.drawing=off background.drawing=off \
    --set "$ICON_ITEM_NAME" drawing=on background.drawing=on background.color=0x00000000 background.image="app.$bundle_id" background.image.drawing=on background.image.scale=0.8 background.image.corner_radius=4 background.image.padding_right=6
else
  sketchybar --set "$ITEM_NAME" drawing=on label="$label" icon.drawing=off background.drawing=off \
    --set "$ICON_ITEM_NAME" drawing=off background.image.drawing=off
fi
