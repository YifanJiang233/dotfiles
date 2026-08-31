#!/usr/bin/env bash

set -u

RIFT_CLI="${RIFT_CLI:-/opt/homebrew/bin/rift-cli}"
JQ="${JQ:-/opt/homebrew/bin/jq}"
RIFT_LOG_FILE="${RIFT_AUTOTILING_LOG_FILE:-/tmp/rift_${USER:-$(/usr/bin/id -un)}.out.log}"
COALESCE_DELAY="${RIFT_AUTOTILING_COALESCE_DELAY:-0}"
STATE_DIR="${RIFT_AUTOTILING_STATE_DIR:-${TMPDIR:-/tmp}/rift-autotiling-${UID:-$(/usr/bin/id -u)}}"
STATE_FILE="$STATE_DIR/state.json"
EVENT_FILE="$STATE_DIR/events.jsonl"
LOCK_DIR="$STATE_DIR/lock"
DIAGNOSTIC_LOG="$STATE_DIR/diagnostics.jsonl"
TRANSACTION_FILE="$STATE_DIR/animation-transaction.json"
DIAGNOSTIC_LIMIT=262144

[ -x "$RIFT_CLI" ] || exit 0
[ -x "$JQ" ] || exit 0

mkdir -p "$STATE_DIR" || exit 0

event_json="${RIFT_EVENT_JSON:-${1:-}}"
if ! printf '%s' "$event_json" | "$JQ" -e . >/dev/null 2>&1; then
  event_json='{"type":"initialize"}'
fi
printf '%s\n' "$event_json" >> "$EVENT_FILE" || exit 0

# Every callback records its event, but only one callback becomes the worker.
# Events arriving while it is busy remain queued for the next pass.
mkdir "$LOCK_DIR" 2>/dev/null || exit 0
lock_held=true
transaction_active=false
transaction_original_animate=false
transaction_commands='[]'

write_atomic() {
  local path=$1
  local contents=$2
  local temporary="$path.$$.${RANDOM}.tmp"
  printf '%s\n' "$contents" > "$temporary" || return 1
  mv -f "$temporary" "$path"
}

write_state() {
  write_atomic "$STATE_FILE" "$1"
}

release_lock() {
  if [ "$lock_held" = true ]; then
    rmdir "$LOCK_DIR" 2>/dev/null || true
    lock_held=false
  fi
}

restore_animation() {
  [ "$transaction_active" = true ] || return 0
  "$RIFT_CLI" execute config set-animate "$transaction_original_animate" >/dev/null 2>&1 || true
  rm -f "$TRANSACTION_FILE"
  transaction_active=false
}

cleanup() {
  restore_animation
  release_lock
}
trap cleanup EXIT HUP INT TERM

recover_interrupted_transaction() {
  local original
  [ -r "$TRANSACTION_FILE" ] || return 0
  original=$("$JQ" -r '.animate // false' "$TRANSACTION_FILE" 2>/dev/null || printf false)
  case "$original" in
    true|false) "$RIFT_CLI" execute config set-animate "$original" >/dev/null 2>&1 || return 1 ;;
    *) return 1 ;;
  esac
  rm -f "$TRANSACTION_FILE"
}

begin_transaction() {
  local config
  config=$("$RIFT_CLI" execute config get 2>/dev/null) || config='{}'
  transaction_original_animate=$(printf '%s' "$config" | "$JQ" -r '.settings.animate // false')
  case "$transaction_original_animate" in
    true|false) ;;
    *) transaction_original_animate=false ;;
  esac
  write_atomic "$TRANSACTION_FILE" "{\"animate\":$transaction_original_animate}" || return 1
  transaction_active=true
  transaction_commands='[]'
  if [ "$transaction_original_animate" = true ]; then
    "$RIFT_CLI" execute config set-animate false >/dev/null 2>&1 || return 1
  fi
}

finish_transaction() {
  restore_animation
}

record_command() {
  local name=$1
  local status=$2
  local output=$3
  transaction_commands=$(printf '%s' "$transaction_commands" | "$JQ" -c \
    --arg name "$name" \
    --argjson status "$status" \
    --arg output "${output:0:600}" \
    '. + [{name: $name, status: $status, output: $output}]')
}

run_rift() {
  local name=$1
  shift
  local output status
  output=$("$RIFT_CLI" "$@" 2>&1)
  status=$?
  record_command "$name" "$status" "$output"
  return "$status"
}

rotate_diagnostics() {
  local size temporary
  size=$(stat -f '%z' "$DIAGNOSTIC_LOG" 2>/dev/null || printf 0)
  [ "$size" -le "$DIAGNOSTIC_LIMIT" ] && return 0
  temporary="$DIAGNOSTIC_LOG.$$.tmp"
  tail -c 131072 "$DIAGNOSTIC_LOG" > "$temporary" 2>/dev/null || return 1
  # Discard a possible partial first JSON line after byte-based truncation.
  sed '1d' "$temporary" > "$temporary.trimmed" 2>/dev/null || return 1
  mv -f "$temporary.trimmed" "$DIAGNOSTIC_LOG"
  rm -f "$temporary"
}

log_transaction() {
  local status=$1
  local workspace=$2
  local anchor=$3
  local new_window=$4
  local desired=$5
  local before_workspace=$6
  local after_workspace=$7
  local before_tree=$8
  local after_tree=$9
  local verification=${10}
  local saved_snapshot=${11}
  local line

  line=$("$JQ" -cn \
    --arg timestamp "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
    --arg status "$status" \
    --arg workspace "$workspace" \
    --arg anchor "$anchor" \
    --arg new_window "$new_window" \
    --arg desired "$desired" \
    --argjson before_workspace "$before_workspace" \
    --argjson after_workspace "$after_workspace" \
    --arg before_tree "$before_tree" \
    --arg after_tree "$after_tree" \
    --argjson verification "$verification" \
    --argjson snapshot "$saved_snapshot" \
    --argjson commands "$transaction_commands" '
      {
        timestamp: $timestamp,
        status: $status,
        workspace: $workspace,
        anchor: $anchor,
        new_window: $new_window,
        desired: $desired,
        saved_snapshot: $snapshot,
        before: $before_workspace,
        after: $after_workspace,
        before_tree: $before_tree,
        after_tree: $after_tree,
        verification: $verification,
        commands: $commands
      }
    ') || return 1
  printf '%s\n' "$line" >> "$DIAGNOSTIC_LOG"
  rotate_diagnostics
}

query_current() {
  local workspaces_json displays_json
  workspaces_json=$("$RIFT_CLI" query workspaces 2>/dev/null) || return 1
  displays_json=$("$RIFT_CLI" query displays 2>/dev/null) || displays_json='[]'

  "$JQ" -cn --argjson workspaces "$workspaces_json" --argjson displays "$displays_json" '
    def entries:
      if $workspaces | type == "array" then $workspaces
      elif ($workspaces.workspaces | type) == "array" then $workspaces.workspaces
      else []
      end;
    def nearly_equal($a; $b): (($a - $b) | fabs) <= 1;
    def is_fullscreen($window):
      any(
        $displays[]?;
        nearly_equal($window.frame.origin.x; .frame.origin.x)
        and nearly_equal($window.frame.origin.y; .frame.origin.y)
        and nearly_equal($window.frame.size.width; .frame.size.width)
        and nearly_equal($window.frame.size.height; .frame.size.height)
      );
    [
      entries[]
      | . as $workspace
      | [
          (.windows // [])[]
          | select(.is_floating != true)
          | {
              key: ((.id.pid | tostring) + ":" + (.id.idx | tostring)),
              pid: (.id.pid | tonumber),
              idx: (.id.idx | tonumber),
              focused: (.is_focused == true),
              fullscreen: is_fullscreen(.),
              x: (.frame.origin.x // 0),
              y: (.frame.origin.y // 0),
              width: (.frame.size.width // 0),
              height: (.frame.size.height // 0)
            }
        ] as $windows
      | {
          key: (.id | tostring),
          name: (.name // ""),
          index: (.index // -1),
          active: (.is_active == true),
          mode: (.layout_mode // "traditional"),
          windows: $windows,
          focused: (first($windows[] | select(.focused) | .key) // null)
        }
    ]
  '
}

capture_debug_tree() {
  local log_offset log_size attempts
  [ -r "$RIFT_LOG_FILE" ] || return 1
  log_offset=$(stat -f '%z' "$RIFT_LOG_FILE" 2>/dev/null) || return 1
  "$RIFT_CLI" execute debug >/dev/null 2>&1 || return 1

  attempts=0
  log_size=$log_offset
  while [ "$attempts" -lt 12 ]; do
    log_size=$(stat -f '%z' "$RIFT_LOG_FILE" 2>/dev/null) || return 1
    [ "$log_size" -gt "$log_offset" ] && break
    /bin/sleep 0.01
    attempts=$((attempts + 1))
  done
  [ "$log_size" -gt "$log_offset" ] || return 1
  tail -c "+$((log_offset + 1))" "$RIFT_LOG_FILE"
}

# Output: parent orientation, previous sibling, selected, stacked ancestor,
# direct child count, target and previous sizes, parent total, parent outer
# size, and outer-parent total for a target window.
tree_info_from_output() {
  local target_window=$1
  awk -v target="$target_window" '
    function node_kind(line) {
      if (line ~ / HorizontalStack \[/) return "horizontal_stack"
      if (line ~ / VerticalStack \[/) return "vertical_stack"
      if (line ~ / Horizontal \[/) return "horizontal"
      if (line ~ / Vertical \[/) return "vertical"
      return ""
    }
    function window_key(line, value, parts) {
      if (line !~ /WindowId \{ pid: [0-9]+, idx: [0-9]+ \}/) return "container"
      value = line
      sub(/^.*WindowId \{ pid: /, "", value)
      split(value, parts, ", idx: ")
      sub(/ \}.*$/, "", parts[2])
      return parts[1] ":" parts[2]
    }
    function node_size(line, value) {
      if (line !~ /\[size [-+0-9.eE]+/) return 0
      value = line
      sub(/^.*\[size /, "", value)
      sub(/[ ].*$/, "", value)
      sub(/\].*$/, "", value)
      return value + 0
    }
    function node_total(line, value) {
      if (line !~ / total=[-+0-9.eE]+/) return 0
      value = line
      sub(/^.* total=/, "", value)
      sub(/\].*$/, "", value)
      return value + 0
    }
    /NodeId\(/ {
      column = index($0, "NodeId(")
      for (depth in node_at_depth) {
        if ((depth + 0) >= column) delete node_at_depth[depth]
      }
      parent_column = 0
      for (depth in node_at_depth) {
        if ((depth + 0) < column && (depth + 0) > parent_column) parent_column = depth + 0
      }
      parent = parent_column ? node_at_depth[parent_column] : ""
      node = $0
      sub(/^.*NodeId\(/, "", node)
      sub(/\).*$/, "", node)
      kind = node_kind($0)
      child = window_key($0)
      parents[node] = parent
      sizes[node] = node_size($0)
      totals[node] = node_total($0)

      if (parent != "") {
        child_count[parent]++
        previous = last_child[parent]
        previous_node = last_child_node[parent]
        last_child[parent] = child
        last_child_node[parent] = node
      } else {
        previous = ""
        previous_node = ""
      }

      if (kind != "") {
        kinds[node] = kind
        node_at_depth[column] = node
        last_child[node] = ""
        last_child_node[node] = ""
      }

      if (child == target) {
        target_node = node
        target_parent = parent
        target_previous = previous
        target_previous_size = sizes[previous_node]
        target_selected = index($0, "☒") > 0 ? 1 : 0
        target_stacked = 0
        for (depth in node_at_depth) {
          if ((depth + 0) < column && kinds[node_at_depth[depth]] ~ /_stack$/) target_stacked = 1
        }
      }
    }
    END {
      if (target_parent != "") {
        outer_parent = parents[target_parent]
        previous_value = target_previous == "" ? "-" : target_previous
        printf "%s\t%s\t%d\t%d\t%d\t%.9g\t%.9g\t%.9g\t%.9g\t%.9g\n",
          kinds[target_parent], previous_value, target_selected, target_stacked,
          child_count[target_parent], sizes[target_node], target_previous_size,
          totals[target_parent], sizes[target_parent], totals[outer_parent]
      }
    }
  '
}

initialize_state() {
  local current_json=$1
  "$JQ" -cn --argjson current "$current_json" '
    def snapshot($workspace):
      reduce $workspace.windows[] as $window ({};
        .[$window.key] = {
          x: $window.x,
          y: $window.y,
          width: $window.width,
          height: $window.height
        }
      );
    {
      version: 2,
      workspaces: reduce $current[] as $workspace ({};
        .[$workspace.key] = {
          known: [$workspace.windows[].key],
          anchor: $workspace.focused,
          snapshot: snapshot($workspace)
        }
      )
    }
  '
}

reconcile_state() {
  local state_json=$1
  local current_json=$2
  "$JQ" -cn --argjson state "$state_json" --argjson current "$current_json" '
    def snapshot($workspace):
      reduce $workspace.windows[] as $window ({};
        .[$window.key] = {
          x: $window.x,
          y: $window.y,
          width: $window.width,
          height: $window.height
        }
      );
    reduce $current[] as $workspace ($state | .version = 2 | .workspaces //= {};
      if .workspaces[$workspace.key] == null then
        .workspaces[$workspace.key] = {
          known: [$workspace.windows[].key],
          anchor: $workspace.focused,
          snapshot: snapshot($workspace)
        }
      else
        ($workspace.windows | map(.key)) as $present
        | .workspaces[$workspace.key].known = [
            .workspaces[$workspace.key].known[]?
            | select(. as $id | $present | index($id))
          ]
        | .workspaces[$workspace.key].snapshot //= {}
        | .workspaces[$workspace.key].snapshot |= with_entries(
            select(.key as $id | $present | index($id))
          )
        | if .workspaces[$workspace.key].anchor as $anchor
             | ($anchor != null and ($present | index($anchor) | not)) then
            .workspaces[$workspace.key].anchor = null
          else . end
      end
    )
  '
}

verification_report() {
  local expected_snapshot=$1
  local after_workspace=$2
  local anchor=$3
  local new_window=$4
  local desired=$5

  "$JQ" -cn \
    --argjson expected "$expected_snapshot" \
    --argjson after "$after_workspace" \
    --arg anchor "$anchor" \
    --arg new "$new_window" \
    --arg desired "$desired" '
      def close($a; $b): (($a - $b) | fabs) <= 1;
      def same_frame($a; $b):
        $a != null and $b != null
        and close($a.x; $b.x)
        and close($a.y; $b.y)
        and close($a.width; $b.width)
        and close($a.height; $b.height);
      def union($a; $b):
        if $a == null or $b == null then null
        else
          ([$a.x, $b.x] | min) as $x
          | ([$a.y, $b.y] | min) as $y
          | ([($a.x + $a.width), ($b.x + $b.width)] | max) as $right
          | ([($a.y + $a.height), ($b.y + $b.height)] | max) as $bottom
          | {x: $x, y: $y, width: ($right - $x), height: ($bottom - $y)}
        end;
      def window_map($workspace):
        reduce $workspace.windows[] as $window ({}; .[$window.key] = $window);

      window_map($after) as $after_map
      | $after_map[$anchor] as $after_anchor
      | $after_map[$new] as $after_new
      | $expected[$anchor] as $target
      | union($after_anchor; $after_new) as $actual
      | [
          $expected | keys[]
          | select(. != $anchor)
          | same_frame($expected[.]; $after_map[.])
        ] as $unrelated_checks
      | ($unrelated_checks | all) as $unrelated_ok
      | same_frame($target; $actual) as $union_ok
      | (
          if $desired == "horizontal" then
            $after_anchor != null and $after_new != null
            and close($after_anchor.y; $after_new.y)
            and close($after_anchor.height; $after_new.height)
            and close($after_anchor.width; $after_new.width)
          else
            $after_anchor != null and $after_new != null
            and close($after_anchor.x; $after_new.x)
            and close($after_anchor.width; $after_new.width)
            and close($after_anchor.height; $after_new.height)
          end
        ) as $equal_split_ok
      | {
          ok: ($unrelated_ok and $union_ok and $equal_split_ok),
          unrelated_ok: $unrelated_ok,
          union_ok: $union_ok,
          equal_split_ok: $equal_split_ok,
          target: $target,
          actual: $actual
        }
    '
}

focus_window() {
  local window_key=$1
  local pid=${window_key%%:*}
  local idx=${window_key##*:}
  local id_json
  id_json=$("$JQ" -cn --argjson pid "$pid" --argjson idx "$idx" '{pid: $pid, idx: $idx}')
  run_rift "focus:$window_key" execute window focus --window-id "$id_json"
}

apply_autotiling_structure() {
  local anchor=$1
  local new_window=$2
  local parent_kind=$3
  local desired=$4
  local parent_children=$5
  local join_direction

  if [ "$parent_kind" = "$desired" ] && [ "$parent_children" -le 2 ]; then
    return 0
  fi
  focus_window "$anchor" || return 1

  if [ "$parent_kind" = horizontal ]; then
    join_direction=right
  else
    join_direction=down
  fi
  run_rift "join:$join_direction" execute layout join-window "$join_direction" || return 1
  if [ "$parent_kind" != "$desired" ]; then
    run_rift "orient:$desired" execute layout toggle-orientation || return 1
  fi
  focus_window "$new_window"
}

resize_outer_branch() {
  local new_window=$1
  local outer_kind=$2
  local inner_kind=$3
  local amount=$4
  local inner_rotated=false

  focus_window "$new_window" || return 1
  if [ "$inner_kind" = horizontal ]; then
    run_rift "rotate-inner-for-outer-resize" execute layout toggle-orientation || return 1
    inner_rotated=true
  fi

  if [ "$outer_kind" = vertical ]; then
    run_rift "ascend-for-outer-resize" execute layout ascend || return 1
    run_rift "rotate-outer-for-resize" execute layout toggle-orientation || return 1
    run_rift "descend-for-outer-resize" execute layout descend || return 1
  fi

  run_rift "resize-outer:$amount" execute window resize-by -- "$amount" || return 1

  if [ "$outer_kind" = vertical ]; then
    run_rift "ascend-after-outer-resize" execute layout ascend || return 1
    run_rift "restore-outer-after-resize" execute layout toggle-orientation || return 1
    run_rift "descend-after-outer-resize" execute layout descend || return 1
  fi

  if [ "$inner_rotated" = true ]; then
    run_rift "restore-inner-after-outer-resize" execute layout toggle-orientation || return 1
  fi
}

outer_share_report='{"ok":true,"target":null,"actual":null}'
correct_outer_share() {
  local new_window=$1
  local outer_kind=$2
  local target_share=$3
  local tree relation inner_kind stacked grouped_size outer_total
  local attempts current_share error amount next_share observed_slope slope

  tree=$(capture_debug_tree 2>/dev/null || true)
  relation=$(printf '%s\n' "$tree" | tree_info_from_output "$new_window")
  [ -n "$relation" ] || return 1
  IFS=$'\t' read -r inner_kind _ _ stacked _ _ _ _ grouped_size outer_total <<< "$relation"
  [ "$stacked" != 1 ] && [ "$grouped_size" != 0 ] && [ "$outer_total" != 0 ] || return 1

  current_share=$("$JQ" -nr \
    --argjson size "$grouped_size" \
    --argjson total "$outer_total" '$size / $total')
  slope=1
  attempts=0
  while [ "$attempts" -lt 5 ]; do
    error=$("$JQ" -nr \
      --argjson target "$target_share" \
      --argjson actual "$current_share" '$target - $actual')
    if [ "$("$JQ" -nr --argjson error "$error" '($error | fabs) <= 0.00075')" = true ]; then
      break
    fi

    amount=$("$JQ" -nr \
      --argjson error "$error" \
      --argjson slope "$slope" '
        if ($slope | fabs) <= 0.0001 then $error
        else ($error / $slope) | if . > 0.25 then 0.25 elif . < -0.25 then -0.25 else . end
        end
      ')
    resize_outer_branch "$new_window" "$outer_kind" "$inner_kind" "$amount" || return 1
    /bin/sleep 0.01

    tree=$(capture_debug_tree 2>/dev/null || true)
    relation=$(printf '%s\n' "$tree" | tree_info_from_output "$new_window")
    [ -n "$relation" ] || return 1
    IFS=$'\t' read -r inner_kind _ _ stacked _ _ _ _ grouped_size outer_total <<< "$relation"
    [ "$stacked" != 1 ] && [ "$grouped_size" != 0 ] && [ "$outer_total" != 0 ] || return 1
    next_share=$("$JQ" -nr \
      --argjson size "$grouped_size" \
      --argjson total "$outer_total" '$size / $total')
    observed_slope=$("$JQ" -nr \
      --argjson before "$current_share" \
      --argjson after "$next_share" \
      --argjson amount "$amount" '
        if ($amount | fabs) > 0.000001 then (($after - $before) / $amount) else 0 end
      ')
    if [ "$("$JQ" -nr --argjson slope "$observed_slope" \
      '($slope | fabs) > 0.0001')" = true ]; then
      slope=$observed_slope
    fi
    current_share=$next_share
    attempts=$((attempts + 1))
  done

  outer_share_report=$("$JQ" -cn \
    --argjson target "$target_share" \
    --argjson actual "$current_share" \
    --argjson attempts "$attempts" '
      {
        ok: ((($target - $actual) | fabs) <= 0.001),
        target: $target,
        actual: $actual,
        attempts: $attempts
      }
  ')
  [ "$(printf '%s' "$outer_share_report" | "$JQ" -r '.ok')" = true ]
}

accept_new_window() {
  local state_json=$1
  local current_json=$2
  local workspace_key=$3
  local new_window=$4

  "$JQ" -cn \
    --argjson state "$state_json" \
    --argjson current "$current_json" \
    --arg workspace "$workspace_key" \
    --arg window "$new_window" '
      ($state.workspaces[$workspace].known + [$window] | unique) as $known
      | ($current[] | select(.key == $workspace)) as $current_workspace
      | $state
      | .workspaces[$workspace].known = $known
      | .workspaces[$workspace].anchor = $window
      | .workspaces[$workspace].snapshot = reduce $current_workspace.windows[] as $item ({};
          if $known | index($item.key) then
            .[$item.key] = {
              x: $item.x,
              y: $item.y,
              width: $item.width,
              height: $item.height
            }
          else . end
        )
    '
}

process_one_new_window() {
  local candidate workspace_key new_window anchor
  local before_workspace saved_snapshot new_fullscreen desired
  local before_tree relation parent_kind previous_sibling selected stacked parent_children
  local new_size anchor_size parent_total target_branch_share
  local safe structural_ok after_json after_workspace after_tree verification status

  candidate=$("$JQ" -rn --argjson state "$state" --argjson current "$current" '
    first(
      $current[]
      | select(.active and .mode == "traditional" and .name != "__scratchpad")
      | . as $workspace
      | ($state.workspaces[$workspace.key]) as $saved
      | first(
          $workspace.windows[]
          | select(.key as $id | $saved.known | index($id) | not)
          | [$workspace.key, .key, ($saved.anchor // "")] | @tsv
        )
    ) // empty
  ')
  [ -n "$candidate" ] || return 1

  IFS=$'\t' read -r workspace_key new_window anchor <<< "$candidate"
  before_workspace=$(printf '%s' "$current" | "$JQ" -c --arg workspace "$workspace_key" 'first(.[] | select(.key == $workspace))')
  saved_snapshot=$(printf '%s' "$state" | "$JQ" -c --arg workspace "$workspace_key" '.workspaces[$workspace].snapshot // {}')
  new_fullscreen=$(printf '%s' "$before_workspace" | "$JQ" -r --arg window "$new_window" 'first(.windows[] | select(.key == $window) | .fullscreen) // false')

  before_tree=$(capture_debug_tree 2>/dev/null || true)
  relation=$(printf '%s\n' "$before_tree" | tree_info_from_output "$new_window")
  if [ -n "$relation" ]; then
    IFS=$'\t' read -r parent_kind previous_sibling selected stacked parent_children \
      new_size anchor_size parent_total _ _ <<< "$relation"
  else
    parent_kind=""
    previous_sibling=""
    selected=0
    stacked=0
    parent_children=0
    new_size=0
    anchor_size=0
    parent_total=0
  fi

  target_branch_share=""
  if [ "$parent_children" -gt 2 ]; then
    target_branch_share=$("$JQ" -nr \
      --argjson anchor "$anchor_size" \
      --argjson new "$new_size" \
      --argjson total "$parent_total" '
        if $total > 0 then ($anchor + $new) / $total else empty end
    ')
  fi

  desired=$(printf '%s' "$saved_snapshot" | "$JQ" -r --arg anchor "$anchor" '
    .[$anchor]
    | if . == null then empty
      elif .height > .width then "vertical"
      else "horizontal"
      end
  ')
  safe=false
  if [ -n "$anchor" ] \
      && [ -n "$desired" ] \
      && [ "$new_fullscreen" != true ] \
      && [ "$stacked" != 1 ] \
      && [ "$previous_sibling" = "$anchor" ] \
      && [ "$parent_children" -ge 2 ] \
      && { [ "$parent_kind" = horizontal ] || [ "$parent_kind" = vertical ]; }; then
    safe=true
  fi

  transaction_commands='[]'
  outer_share_report='{"ok":true,"target":null,"actual":null}'
  structural_ok=true
  if [ "$safe" = true ]; then
    begin_transaction || structural_ok=false
    if [ "$structural_ok" = true ]; then
      apply_autotiling_structure "$anchor" "$new_window" "$parent_kind" "$desired" "$parent_children" || structural_ok=false
    fi
    if [ "$structural_ok" = true ] && [ -n "$target_branch_share" ]; then
      correct_outer_share "$new_window" "$parent_kind" "$target_branch_share" || structural_ok=false
    fi
  fi

  /bin/sleep 0.02
  after_json=$(query_current 2>/dev/null || printf '%s' "$current")
  after_workspace=$(printf '%s' "$after_json" | "$JQ" -c --arg workspace "$workspace_key" 'first(.[] | select(.key == $workspace))')
  verification='null'
  status=skipped

  if [ "$safe" = true ]; then
    verification=$(verification_report "$saved_snapshot" "$after_workspace" "$anchor" "$new_window" "$desired" 2>/dev/null || printf '{"ok":false}')
    verification=$(printf '%s' "$verification" | "$JQ" -c --argjson outer "$outer_share_report" '. + {outer_share: $outer}')
    if [ "$structural_ok" = true ] \
        && [ "$(printf '%s' "$verification" | "$JQ" -r '.ok // false')" = true ] \
        && [ "$(printf '%s' "$outer_share_report" | "$JQ" -r '.ok')" = true ]; then
      status=verified
    else
      status=failed
    fi
  fi

  if [ "$safe" = true ] && [ "$selected" != 1 ]; then
    focus_window "$anchor" || true
  fi
  after_tree=$(capture_debug_tree 2>/dev/null || true)
  finish_transaction
  log_transaction "$status" "$workspace_key" "$anchor" "$new_window" "$desired" \
    "$before_workspace" "$after_workspace" "$before_tree" "$after_tree" "$verification" "$saved_snapshot" || true

  state=$(accept_new_window "$state" "$after_json" "$workspace_key" "$new_window") || return 1
  current=$after_json
  return 0
}

finalize_state() {
  local state_json=$1
  local current_json=$2

  "$JQ" -cn --argjson state "$state_json" --argjson current "$current_json" '
    def snapshot($workspace):
      reduce $workspace.windows[] as $window ({};
        .[$window.key] = {
          x: $window.x,
          y: $window.y,
          width: $window.width,
          height: $window.height
        }
      );
    reduce $current[] as $workspace ($state;
      .workspaces[$workspace.key].known = [$workspace.windows[].key]
      | .workspaces[$workspace.key].snapshot = snapshot($workspace)
      | if $workspace.active
          and $workspace.mode == "traditional"
          and $workspace.name != "__scratchpad"
          and $workspace.focused != null then
          .workspaces[$workspace.key].anchor = $workspace.focused
        else . end
    )
  '
}

process_batch() {
  local batch_file=$1
  local initialize processed

  current=$(query_current) || return 0
  initialize=$("$JQ" -s -r 'any(.[]; .type == "initialize")' "$batch_file" 2>/dev/null || printf false)

  if [ "$initialize" = true ] || [ ! -r "$STATE_FILE" ]; then
    state=$(initialize_state "$current") || return 0
    write_state "$state"
    return 0
  fi

  state=$("$JQ" -c . "$STATE_FILE" 2>/dev/null) || state=$(initialize_state "$current")
  state=$(reconcile_state "$state" "$current") || return 0

  processed=0
  while [ "$processed" -lt 16 ]; do
    if process_one_new_window; then
      processed=$((processed + 1))
    else
      break
    fi
  done

  state=$(finalize_state "$state" "$current") || return 0
  write_state "$state"
}

recover_interrupted_transaction || true

while :; do
  [ "$COALESCE_DELAY" = 0 ] || /bin/sleep "$COALESCE_DELAY"
  batch_file="$STATE_DIR/events.$$.jsonl"
  if [ -f "$EVENT_FILE" ]; then
    mv -f "$EVENT_FILE" "$batch_file" || break
    process_batch "$batch_file"
    rm -f "$batch_file"
  fi

  [ -f "$EVENT_FILE" ] && continue

  release_lock
  if [ -f "$EVENT_FILE" ]; then
    if mkdir "$LOCK_DIR" 2>/dev/null; then
      lock_held=true
      continue
    fi
  fi
  exit 0
done
