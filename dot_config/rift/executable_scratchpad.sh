#!/usr/bin/env bash

set -u

RIFT_CLI="${RIFT_CLI:-/opt/homebrew/bin/rift-cli}"
JQ="${JQ:-/opt/homebrew/bin/jq}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CENTER_WINDOW_HELPER="${CENTER_WINDOW_HELPER:-$SCRIPT_DIR/center_focused_window.sh}"
SCRATCHPAD_WORKSPACE_INDEX=11
STATE_DIR="${RIFT_SCRATCHPAD_STATE_DIR:-${TMPDIR:-/tmp}/rift-scratchpad-${UID:-$(id -u)}}"
STATE_FILE="$STATE_DIR/state.json"
LOCK_DIR="$STATE_DIR/lock"

[ -x "$RIFT_CLI" ] || exit 0
[ -x "$JQ" ] || exit 0

mkdir -p "$STATE_DIR" || exit 0
mkdir "$LOCK_DIR" 2>/dev/null || exit 0
trap 'rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT HUP INT TERM

action="${1:-}"
case "$action" in
  send|show|reset|status) ;;
  release)
    release_target="${2:-}"
    case "$release_target" in
      0|1|2|3|4|5|6|7|8|9) ;;
      *) exit 0 ;;
    esac
    ;;
  *) exit 0 ;;
esac

rift_pid="${RIFT_SESSION_ID:-$(/usr/bin/pgrep -x rift 2>/dev/null | /usr/bin/head -n 1)}"
[ -n "$rift_pid" ] || exit 0

workspaces_json=$("$RIFT_CLI" query workspaces 2>/dev/null) || exit 0
entries_filter='if type == "array" then . elif (.workspaces | type) == "array" then .workspaces else [] end'

workspace_exists=$(
  printf '%s' "$workspaces_json" |
    "$JQ" -r --argjson scratchpad "$SCRATCHPAD_WORKSPACE_INDEX" \
      "$entries_filter | any(.[]; ((.index // -1) | tonumber) == \$scratchpad)"
) || exit 0
[ "$workspace_exists" = "true" ] || exit 0

valid_ids=$(
  printf '%s' "$workspaces_json" |
    "$JQ" -c "$entries_filter | [.[] | .windows[]? | (.id.idx | tonumber)] | unique"
) || exit 0

initial_state="{\"session\":\"$rift_pid\",\"members\":[],\"shown\":null}"
state="$initial_state"
if [ -r "$STATE_FILE" ]; then
  state=$("$JQ" -c . "$STATE_FILE" 2>/dev/null || printf '%s' "$initial_state")
fi

state=$(
  printf '%s' "$state" |
    "$JQ" -c --arg session "$rift_pid" --argjson valid_ids "$valid_ids" '
      if .session != $session then
        { session: $session, members: [], shown: null }
      else
        .members = [
          .members[]?
          | tonumber
          | select(. as $id | $valid_ids | index($id))
        ]
        | .members |= reduce .[] as $id ([]; if index($id) then . else . + [$id] end)
        | .shown as $shown
        | if ($shown == null or ($valid_ids | index($shown)) != null) then . else .shown = null end
      end
    '
) || exit 0

write_state() {
  state_temp="$STATE_DIR/state.$$.${RANDOM}.tmp"
  printf '%s\n' "$1" > "$state_temp" || return 1
  mv -f "$state_temp" "$STATE_FILE"
}

window_workspace() {
  printf '%s' "$workspaces_json" |
    "$JQ" -r --argjson window_id "$1" \
      "$entries_filter | first(.[] as \$workspace | \$workspace.windows[]? | select((.id.idx | tonumber) == \$window_id) | (\$workspace.index | tonumber)) // empty"
}

window_info() {
  printf '%s' "$workspaces_json" |
    "$JQ" -c --argjson window_id "$1" \
      "$entries_filter | first(.[] | .windows[]? | select((.id.idx | tonumber) == \$window_id)) // empty"
}

if [ "$action" = "reset" ]; then
  write_state "$initial_state"
  exit 0
fi

write_state "$state" || exit 0

if [ "$action" = "status" ]; then
  printf '%s\n' "$state"
  exit 0
fi

focused=$(
  printf '%s' "$workspaces_json" |
    "$JQ" -c "$entries_filter | first(.[] as \$workspace | \$workspace.windows[]? | select(.is_focused == true) | { id: (.id.idx | tonumber), workspace: (\$workspace.index | tonumber) }) // empty"
) || exit 0

focused_id=$(printf '%s' "$focused" | "$JQ" -r '.id // empty' 2>/dev/null)
focused_workspace=$(printf '%s' "$focused" | "$JQ" -r '.workspace // empty' 2>/dev/null)

if [ "$action" = "release" ]; then
  focused_is_member=false
  focused_info=""
  if [ -n "$focused_id" ]; then
    focused_is_member=$(
      printf '%s' "$state" |
        "$JQ" -r --argjson window_id "$focused_id" '.members | index($window_id) != null'
    ) || focused_is_member=false
    if [ "$focused_is_member" = "true" ]; then
      focused_info=$(window_info "$focused_id")
    fi
  fi

  if "$RIFT_CLI" execute workspace move-window --follow "$release_target" >/dev/null 2>&1; then
    if [ "$focused_is_member" = "true" ]; then
      state=$(
        printf '%s' "$state" |
          "$JQ" -c --argjson window_id "$focused_id" '
            .members = [.members[] | select(. != $window_id)]
            | if .shown == $window_id then .shown = null else . end
          '
      ) || exit 0
      write_state "$state" || exit 0

      focused_floating=$(printf '%s' "$focused_info" | "$JQ" -r '.is_floating == true')
      if [ "$focused_floating" = "true" ]; then
        focused_window_id=$(printf '%s' "$focused_info" | "$JQ" -c '.id')
        focused_server_id=$(printf '%s' "$focused_info" | "$JQ" -r '.window_server_id')
        if "$RIFT_CLI" execute window focus \
          --window-id "$focused_window_id" \
          --window-server-id "$focused_server_id" >/dev/null 2>&1; then
          "$RIFT_CLI" execute window toggle-float >/dev/null 2>&1 || true
        fi
      fi
    fi
  fi
  exit 0
fi

if [ "$action" = "send" ]; then
  [ -n "$focused_id" ] || exit 0
  [ "$focused_workspace" != "$SCRATCHPAD_WORKSPACE_INDEX" ] || exit 0

  if "$RIFT_CLI" execute workspace move-window "$SCRATCHPAD_WORKSPACE_INDEX" "$focused_id" >/dev/null 2>&1; then
    state=$(
      printf '%s' "$state" |
        "$JQ" -c --argjson window_id "$focused_id" '
          .members = ([$window_id] + [.members[] | select(. != $window_id)])
          | if .shown == $window_id then .shown = null else . end
        '
    ) || exit 0
    write_state "$state"
  fi
  exit 0
fi

active_workspace=$(
  printf '%s' "$workspaces_json" |
    "$JQ" -r "$entries_filter | first(.[] | select(.is_active == true) | (.index | tonumber)) // empty"
) || exit 0
[ -n "$active_workspace" ] || exit 0
[ "$active_workspace" != "$SCRATCHPAD_WORKSPACE_INDEX" ] || exit 0

shown=$(printf '%s' "$state" | "$JQ" -r '.shown // empty')
if [ -n "$shown" ] && [ "$focused_id" = "$shown" ]; then
  if "$RIFT_CLI" execute workspace move-window "$SCRATCHPAD_WORKSPACE_INDEX" "$shown" >/dev/null 2>&1; then
    state=$(printf '%s' "$state" | "$JQ" -c '.shown = null') || exit 0
    write_state "$state"
  fi
  exit 0
fi

candidate=""
while IFS= read -r member; do
  [ -n "$member" ] || continue
  [ "$member" != "$shown" ] || continue
  if [ "$(window_workspace "$member")" = "$SCRATCHPAD_WORKSPACE_INDEX" ]; then
    candidate="$member"
    break
  fi
done < <(printf '%s' "$state" | "$JQ" -r '.members[]')

if [ -n "$shown" ] && [ -z "$candidate" ]; then
  shown_info=$(window_info "$shown")
  [ -n "$shown_info" ] || exit 0
  shown_window_id=$(printf '%s' "$shown_info" | "$JQ" -c '.id')
  shown_server_id=$(printf '%s' "$shown_info" | "$JQ" -r '.window_server_id')
  "$RIFT_CLI" execute window focus \
    --window-id "$shown_window_id" \
    --window-server-id "$shown_server_id" >/dev/null 2>&1 || true
  exit 0
fi

if [ -n "$shown" ]; then
  "$RIFT_CLI" execute workspace move-window "$SCRATCHPAD_WORKSPACE_INDEX" "$shown" >/dev/null 2>&1 || exit 0
  state=$(printf '%s' "$state" | "$JQ" -c '.shown = null') || exit 0
fi

if [ -z "$candidate" ]; then
  while IFS= read -r member; do
    [ -n "$member" ] || continue
    if [ "$(window_workspace "$member")" = "$SCRATCHPAD_WORKSPACE_INDEX" ]; then
      candidate="$member"
      break
    fi
  done < <(printf '%s' "$state" | "$JQ" -r '.members[]')
fi
[ -n "$candidate" ] || {
  write_state "$state"
  exit 0
}

candidate_info=$(window_info "$candidate")
[ -n "$candidate_info" ] || exit 0
candidate_window_id=$(printf '%s' "$candidate_info" | "$JQ" -c '.id')
candidate_server_id=$(printf '%s' "$candidate_info" | "$JQ" -r '.window_server_id')
candidate_floating=$(printf '%s' "$candidate_info" | "$JQ" -r '.is_floating == true')

"$RIFT_CLI" execute workspace move-window "$active_workspace" "$candidate" >/dev/null 2>&1 || exit 0
if "$RIFT_CLI" execute window focus \
  --window-id "$candidate_window_id" \
  --window-server-id "$candidate_server_id" >/dev/null 2>&1; then
  if [ "$candidate_floating" != "true" ]; then
    "$RIFT_CLI" execute window toggle-float >/dev/null 2>&1 || true
  fi
  if [ -x "$CENTER_WINDOW_HELPER" ]; then
    "$CENTER_WINDOW_HELPER" >/dev/null 2>&1 || true
  fi
fi

state=$(
  printf '%s' "$state" |
    "$JQ" -c --argjson window_id "$candidate" '
      .members = ([.members[] | select(. != $window_id)] + [$window_id])
      | .shown = $window_id
    '
) || exit 0
write_state "$state"
