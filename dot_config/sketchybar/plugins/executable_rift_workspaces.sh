#!/usr/bin/env bash

RIFT_CLI="/opt/homebrew/bin/rift-cli"
JQ="/opt/homebrew/bin/jq"
RIFT_WORKSPACE_INDICES=(0 1 2 3 4 5 6 7 8 9)
WORKSPACE_LABEL_MAX=20
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
COLORS_FILE="$SCRIPT_DIR/../styles/colors.sh"
STATE_DIR="${TMPDIR:-/tmp}/rift-sketchybar-${UID:-$(id -u)}"
SNAPSHOT_FILE="$STATE_DIR/workspace.snapshot"

[ -r "$COLORS_FILE" ] || exit 0
source "$COLORS_FILE"

if [ ! -x "$RIFT_CLI" ] || [ ! -x "$JQ" ]; then
  exit 0
fi

# Serialize queries and rendering so a slow older update cannot overwrite a newer one.
mkdir -p "$STATE_DIR" || exit 0
exec 9>"$STATE_DIR/workspace.lock" || exit 0
/usr/bin/lockf 9 || exit 0

workspace_updates=$(
  "$RIFT_CLI" query workspaces 2>/dev/null |
    "$JQ" -r --argjson workspace_label_max "$WORKSPACE_LABEL_MAX" '
      def entries:
        if type == "array" then .
        elif .workspaces then .workspaces
        else []
        end;
      def idx:
        (.index // .workspace_index // (if (.id | type) == "object" then .id.idx else null end));
      def app_name:
        if .bundle_id == "org.wezfurlong.wezterm" then "wezterm"
        elif .bundle_id == "org.qutebrowser.qutebrowser" then "QuteBrowser"
        elif .bundle_id == "org.nicotine_plus.Nicotine" then "Nicotine"
        elif .bundle_id == "me-him188-ani-app-desktop-AniDesktop" then "Animeko"
        elif .bundle_id == "glide-glide" then "glide"
        elif (.app_name // "") != "" then .app_name
        else empty
        end;
      def unique_apps:
        reduce .[] as $app
          ([];
           if any(.[]; ascii_downcase == ($app | ascii_downcase))
           then .
           else . + [$app]
           end);
      def capped_apps($max):
        reduce .[] as $app
          ({parts: [], length: 0, truncated: false, embedded_ellipsis: false};
           if .truncated then .
           elif (.parts | length) == 0 and ($app | length) > ($max - 1) then
             .parts = [($app[0:($max - 1)] + "…")]
             | .length = $max
             | .truncated = true
             | .embedded_ellipsis = true
           elif (.length + (if (.parts | length) == 0 then 0 else 3 end) + ($app | length)) <= $max then
             .length = (.length + (if (.parts | length) == 0 then 0 else 3 end) + ($app | length))
             | .parts += [$app]
           else
             .truncated = true
           end)
        | (.parts | join(" ¦ ")) + (if .truncated and (.embedded_ellipsis | not) then "…" else "" end);
      # An empty transient snapshot produces no updates, preserving the bar.
      entries
      | select(length > 0)
      | .[]
      | select(idx != null)
      | select(
          ((.window_count // 0) > 0)
          or ((.windows // []) | length) > 0
          or .is_active == true
        )
      | ([.windows // [] | .[] | app_name] | unique_apps) as $apps
      | ((idx | tonumber) + 1 | tostring) as $number
      | ($workspace_label_max - (($number | length) + 2)) as $app_limit
      | [
          (idx | tonumber),
          ($number + (if ($apps | length) == 0 then "" else "  " + ($apps | capped_apps($app_limit)) end)),
          (if .is_active == true then "true" else "false" end)
        ]
      | @tsv
    '
) || exit 0

[ -n "$workspace_updates" ] || exit 0

if [ "${RIFT_FORCE_UPDATE:-0}" != "1" ] && [ -r "$SNAPSHOT_FILE" ]; then
  previous_snapshot=$(<"$SNAPSHOT_FILE")
  [ "$previous_snapshot" != "$workspace_updates" ] || exit 0
fi

sketchybar_args=()
visible_workspaces=" "

while IFS=$'\t' read -r index name is_active; do
  [ -n "$index" ] || continue

  case "$index" in
    0|1|2|3|4|5|6|7|8|9) ;;
    *) continue ;;
  esac

  item="rift.workspace.$index"
  visible_workspaces="${visible_workspaces}${index} "

  if [ "$is_active" = "true" ]; then
    sketchybar_args+=(
      --set "$item"
      drawing=on
      label="$name"
      label.color="$TEXT"
      background.drawing=on
      background.color="$SURFACE2"
      background.corner_radius=0
      background.height=28
      background.y_offset=2
      background.border_width=0
      background.shadow.drawing=on
      background.shadow.color="$BLUE"
      background.shadow.angle=90
      background.shadow.distance=3
    )
  else
    sketchybar_args+=(
      --set "$item"
      drawing=on
      label="$name"
      label.color="$TEXT"
      background.drawing=off
      background.border_width=0
      background.shadow.drawing=off
    )
  fi
done <<< "$workspace_updates"

# Add stale-item hides after the new snapshot so an update never blanks the
# entire workspace strip before its replacement state is ready.
for index in "${RIFT_WORKSPACE_INDICES[@]}"; do
  case "$visible_workspaces" in
    *" $index "*) continue ;;
  esac
  sketchybar_args+=(
    --set "rift.workspace.$index"
    drawing=off
    background.drawing=off
    background.border_width=0
    background.shadow.drawing=off
  )
done

if sketchybar --animate tanh 6 "${sketchybar_args[@]}"; then
  [ -d "$STATE_DIR" ] || mkdir -p "$STATE_DIR" || exit 0
  snapshot_temp="$STATE_DIR/workspace.$$.${RANDOM}.tmp"
  printf '%s' "$workspace_updates" > "$snapshot_temp" || exit 0
  mv -f "$snapshot_temp" "$SNAPSHOT_FILE"
fi
