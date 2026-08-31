# Maintaining the Native Rift Patch

This runbook documents the local Rift build used on this Mac, the behavior the
patch must preserve, how to carry it onto a newer upstream Rift revision, and
how to return safely to the official Homebrew build.

The local build is deliberately pinned. Do not automatically follow Rift
upstream: update only when there is time to run every validation gate in this
document.

## Current baseline

| Item | Current value |
| --- | --- |
| Upstream repository | `https://github.com/acsandmann/rift` |
| Pinned upstream commit | `46f5ba06781ac73d145780d2dbfe96516c8ccfb0` |
| Pinned commit date/subject | `2026-08-30` — `fix: reject ordered-out windows during app discovery (#460)` |
| Personal formula version | `0.5.3-native.1` |
| Source archive SHA-256 | `3070454428b3edc9442dcd0c035c79d896499b205e1ea27f5f88f3b1fbea21e7` |
| Canonical patch SHA-256 | `24b2d3491170e43401c4e07f25fd2c379cc0bd7035559a31743b6f4d852ffb98` |
| Official rollback keg installed | `rift 0.5.3` |
| Active service | `homebrew.mxcl.rift-native` |
| Personal formula repository | `~/.config/rift/homebrew-tap` |
| Registered Homebrew tap | `yifan/rift` |
| Chezmoi source repository | `~/.local/share/chezmoi` |

Homebrew currently offers official Rift `0.5.4`, but this machine retains
official Rift `0.5.3` as the tested rollback target. Pin it so an unrelated
`brew upgrade` does not replace that fallback:

```sh
brew pin rift
brew list --pinned
```

Only run `brew unpin rift` when intentionally testing or adopting a newer
official release. The personal build is independently pinned by its exact
archive URL, source checksum, embedded patch, and formula version.

The `0.5.3-native.1` string is the personal Homebrew version label. The pinned
commit is not the commit referenced by upstream's `v0.5.3` tag (`6c64d8b`), and
the root Cargo package reports `rift-wm 0.1.0`. Treat the full commit hash—not
the label or Cargo package version—as the authoritative source identity.

## Sources of truth

The maintained artifacts are:

```text
~/.config/rift/
├── PATCHING.md
├── config.toml
├── patches/
│   └── native-autotiling.patch
└── homebrew-tap/
    └── Formula/
        └── rift-native.rb
```

`patches/native-autotiling.patch` is the canonical patch. Everything after the
`__END__` line in `rift-native.rb` must be byte-for-byte identical to it. Never
maintain the two copies by hand as independent patches.

`homebrew-tap` is also a small nested Git repository. Its `.git` directory is
local tap metadata and must not be added to Chezmoi. Add the formula file, patch,
and this document to Chezmoi explicitly rather than recursively adding the tap
directory.

The registered tap clone is normally:

```text
$(brew --repository)/Library/Taps/yifan/homebrew-rift
```

Its origin is `~/.config/rift/homebrew-tap`. Commit the source tap first, then
fast-forward the registered clone.

## Version policy

Use `<upstream-version>-native.<revision>` for the personal formula.

- For a local-only patch change on the same upstream commit, increment the
  native revision, for example `0.5.3-native.1` to `0.5.3-native.2`.
- When the upstream commit/version changes, reset the native revision to `.1`,
  for example `0.5.4-native.1`.
- Never change an already-installed formula version without incrementing it.
- Record the exact upstream commit even when it corresponds to a release tag.

## User-visible additions

### Focused-leaf autotiling

The opt-in setting is:

```toml
[settings.layout.traditional]
equalize_nodes = false
autotile_focused_leaf = true
```

When a tiled window is created, the patch splits only the focused tiled leaf.
The split orientation is horizontal when the focused leaf is at least as wide
as it is tall, and vertical otherwise.

The implementation must preserve these invariants:

- One native layout mutation and one arrange pass per insertion. A shell event
  handler must not resize the tree afterward.
- The focused-leaf path is used only for traditional layout, a
  `NextToSelection` insertion point, and a calculable selected tiled frame.
- The selected leaf keeps its complete outer share in its parent.
- Ancestor ratios and unrelated sibling weights remain unchanged.
- The old and new leaves receive equal logical weights.
- Existing unrelated physical frames remain unchanged within one pixel.
- Window constraints may make physical child sizes unequal; they must not
  rewrite the equal logical weights.
- Rapidly discovered windows are inserted sequentially and deterministically,
  recomputing the focused anchor after each insertion.
- Grouped, stacked, and fullscreen selections fall back to Rift's normal
  insertion behavior instead of forcing an invalid focused-leaf split.

### Native scratchpad

The twelfth virtual workspace is reserved for scratchpad storage:

```toml
[virtual_workspaces]
default_workspace_count = 12
workspace_names = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "__scratchpad"]
```

The public commands are:

```sh
rift-cli execute scratchpad send
rift-cli execute scratchpad show
rift-cli execute scratchpad release 0
```

Workspace selectors passed by the CLI are zero-based. The Karabiner mappings
present them as normal one-based workspace keys:

| Key | Action |
| --- | --- |
| Command+Shift+- | Send the focused window to the scratchpad |
| Command+- | Show the most recent scratchpad window, or hide the focused shown scratchpad window |
| Command+Shift+1 through Command+Shift+0 | Release the shown scratchpad window to workspaces 1 through 10 |

The scratchpad must preserve these invariants:

- Sending, showing, hiding, or relocating a scratchpad window never mutates the
  original workspace's tiled tree.
- A shown scratchpad window is floating and centered in Rift's usable area.
- Its previous size is preserved unless it is too large for the usable area, in
  which case it is clamped.
- Rift's outer gaps, including the top gap reserved for SketchyBar, are honored.
- Switching workspaces does not immediately move a shown scratchpad window.
  Running `scratchpad show` on the new workspace relocates it there.
- Releasing a shown window removes it from scratchpad membership, inserts it
  into the target workspace through the same focused-leaf insertion path, then
  activates and focuses that workspace.
- Membership and the currently shown member are serialized with layout state;
  the scoped live-restore limitation is documented below.

The reserved workspace is configuration, not an automatically created special
workspace. Its name must remain exactly `__scratchpad`; renaming or removing it
strands existing scratchpad membership. Release destinations are positional,
zero-based workspace indices, so reordering workspaces changes their meaning.

### Removed shell implementation

The following scripts were deliberately removed after the behavior moved into
Rift. Do not restore them as fallbacks:

```text
autotiling.sh
autotiling_events.sh
scratchpad.sh
move_and_switch.sh
center_focused_window.sh
helpers/center_focused_window.c
```

Reintroducing event-driven resize scripts would restore the flashing and
intermediate sizing glitches that the native patch was designed to remove.

## Patch code map

The patch currently changes eleven upstream files.

### `crates/rift-protocol/src/commands.rs`

Adds typed `LayoutCommand` variants:

- `ScratchpadSend`
- `ScratchpadShow`
- `ScratchpadRelease { workspace: WorkspaceSelector }`

Keep workspace selection typed; do not pass a raw string from the CLI into the
layout engine.

### `src/actor/reactor/events/command.rs`

Routes scratchpad commands through workspace-aware command handling. A release
is also treated as a workspace switch because it activates the destination.

### `src/bin/rift-cli.rs`

Adds `rift-cli execute scratchpad send|show|release <workspace_id>`, maps release
to a typed `WorkspaceSelector::Index`, and tests the serialized protocol request.

### `src/common/config.rs`

Adds `TraditionalLayoutSettings.autotile_focused_leaf`. Its serde/default value
is `false`, so pristine upstream behavior is unchanged unless the setting is
explicitly enabled. Parsing and default behavior are tested.

### `src/layout_engine/engine.rs`

This is the integration point for both features:

- Applies the autotiling flag during startup and configuration reload.
- Captures the selected tiled frame before insertion.
- Inserts multiple newly discovered windows one at a time with a recomputed
  anchor and restored selection.
- Defines `ScratchpadState`, including member ordering and the shown member.
- Integrates scratchpad state with window removal, process removal, and window
  ID rekeying.
- Implements send, show/hide, relocation, centering, and release.
- Keeps globally tracked floating state separate from the tiled tree.
- Tests that scratchpad operations and workspace relocation leave tiled frames
  unchanged before final native release.

### `src/layout_engine/engine/persistence/mod.rs`

Exposes `ScratchpadState` to the persistence module.

### `src/layout_engine/engine/persistence/snapshot.rs`

Adds scratchpad state to persisted layout data with a serde default, preserving
the ability to read layouts that predate the field.

### `src/layout_engine/engine/persistence/tests.rs`

Tests that native scratchpad membership and shown state round-trip through RON.

### `src/layout_engine/systems.rs`

Extends the layout-system interface with an anchor-frame-aware insertion method
and a capability query. Defaults preserve existing behavior for non-traditional
layout systems.

### `src/layout_engine/systems/traditional.rs`

Owns the focused-leaf split algorithm:

- Stores the nonserialized runtime opt-in flag.
- Reuses a sole-child parent where possible.
- Nests only the selected leaf when its parent has multiple children.
- Restores the parent's total weight and every unrelated sibling's weight.
- Gives the pair weights `1/1` with total `2`.
- Chooses orientation from the selected leaf's rendered frame.
- Falls back to Rift's normal insertion when a focused-leaf split is unsafe.

Its tests cover ten sequential windows, preservation of manually edited ancestor
ratios, and equal logical weights when physical constraints distort frames.

### `src/model/virtual_workspace.rs`

Applies `autotile_focused_leaf` when constructing a traditional layout system for
a virtual workspace.

## Known limitations and rebase hazards

- Scratchpad state is global and keyed by Rift `WindowId`; it depends on the
  exact `__scratchpad` workspace name.
- Snapshot serialization includes scratchpad state and old snapshots default to
  empty state. However, the current patch does not extend Rift's in-process
  `RestorePlan`/`install_workspace_restore_state` path. Reading a RON snapshot
  directly round-trips the state, but a scoped `restore_layout` can leave the
  live engine's scratchpad state out of sync. Preserve this as a known
  limitation or add a focused test and fix it during a future patch revision.
- The persisted schema version was not incremented; compatibility relies on the
  scratchpad field's serde default. Preserve that default or add an explicit
  migration if the snapshot shape changes.
- `autotile_focused_leaf` is runtime-only on `TraditionalLayoutSystem`. Startup
  and restored workspaces depend on settings being reapplied through Rift's
  load/configuration path. A new upstream load path that bypasses that step can
  silently disable the feature.
- `engine.rs`, `traditional.rs`, `LayoutCommand`, and the `LayoutSystem` trait
  are the highest-conflict rebase surfaces. Preserve upstream discovery
  filtering, selection restoration, fullscreen/group checks, and exact tree
  weights while resolving them.
- `conflicts_with "rift"` allows retaining both kegs but prevents linking both.
  Recheck this behavior before every formula cutover rather than assuming a
  future Homebrew version handles the conflict identically.
- The formula installs only `rift` and `rift-cli`, ad-hoc signs both binaries,
  and runs `#{opt_bin}/rift` as a keep-alive interactive service with standard
  Homebrew `PATH`, `LANG=en_US.UTF-8`, and per-user logs in `/tmp`.

## Routine integrity checks

Run these before and after any maintenance work:

```sh
patch_file="$HOME/.config/rift/patches/native-autotiling.patch"
formula_file="$HOME/.config/rift/homebrew-tap/Formula/rift-native.rb"

shasum -a 256 "$patch_file"
ruby -e '
  formula, patch = ARGV.map { |path| File.binread(path) }
  embedded = formula.split("__END__\n", 2).fetch(1)
  abort "embedded patch differs from canonical patch" unless embedded == patch
' "$formula_file" "$patch_file"
ruby -c "$formula_file"
```

Also confirm the installed and linked builds explicitly:

```sh
brew list --versions rift rift-native
brew services list | grep rift
readlink "$(brew --prefix)/bin/rift"
readlink "$(brew --prefix)/bin/rift-cli"
brew list --pinned
```

## Rebasing the patch onto upstream

Perform the rebase in a disposable checkout. Never edit source under the
Homebrew Cellar or use the registered tap clone as an upstream worktree.

### 1. Record and prepare

Record the current commit, formula version, archive checksum, patch checksum,
test results, and known baseline failures in the maintenance log at the end of
this file.

Choose one exact target upstream commit. Then create a temporary full Git clone
so three-way patch application has access to old blob objects:

```sh
work_dir="$(mktemp -d)"
git clone https://github.com/acsandmann/rift.git "$work_dir/rift"
git -C "$work_dir/rift" switch --detach <new-upstream-commit>
```

Keep the currently active Rift service running during source work and tests.

### 2. Review upstream overlap before resolving conflicts

Review every upstream change between the old and new pins that touches one of
the eleven files in the code map:

```sh
git -C "$work_dir/rift" log --oneline \
  46f5ba06781ac73d145780d2dbfe96516c8ccfb0..<new-upstream-commit> -- \
  crates/rift-protocol/src/commands.rs \
  src/actor/reactor/events/command.rs \
  src/bin/rift-cli.rs \
  src/common/config.rs \
  src/layout_engine/engine.rs \
  src/layout_engine/engine/persistence/mod.rs \
  src/layout_engine/engine/persistence/snapshot.rs \
  src/layout_engine/engine/persistence/tests.rs \
  src/layout_engine/systems.rs \
  src/layout_engine/systems/traditional.rs \
  src/model/virtual_workspace.rs
```

If upstream now implements one of the local behaviors correctly, remove the
corresponding local hunk and use upstream's implementation. Do not add a
compatibility layer or preserve two paths. Re-run the behavioral tests against
the resulting single implementation.

### 3. Apply and resolve

Attempt a three-way indexed application:

```sh
git -C "$work_dir/rift" apply --3way --index \
  "$HOME/.config/rift/patches/native-autotiling.patch"
```

Resolve conflicts in the temporary checkout, delete obsolete overlapping hunks,
and stage the final source changes. Keep the interface and state model as small
as the current requirements permit.

### 4. Run source validation

Run focused tests first:

```sh
cd "$work_dir/rift"
cargo test native_autotile_splits_only_focused_leaf_through_ten_windows
cargo test native_autotile_preserves_manual_ancestor_ratios_exactly
cargo test native_autotile_keeps_equal_weights_when_constraints_change_physical_frames
cargo test traditional_native_autotiling_is_opt_in
cargo test native_scratchpad_show_and_hide_never_change_tiled_frames
cargo test native_scratchpad_membership_round_trips_through_ron
cargo test scratchpad_release_uses_typed_workspace_selector
cargo test --bin rift-cli
cargo build --release --locked --bins
```

Then run the full library suite:

```sh
cargo test --lib
```

A full-suite failure is acceptable only when the exact same test fails at the
same target upstream commit in a second pristine checkout. Record the command,
test name, and both outcomes. Never label a new or changed failure as baseline.

At the current pin, `cargo test --lib` passes 547 of 548 tests. The sole failure,
`actor::reactor::tests::topology_change_clears_stale_pending_hide_target_before_next_workspace_layout`,
reproduces unchanged in pristine upstream. Re-establish this comparison after
every upstream change instead of assuming it remains valid.

The current upstream also fails its strict Clippy baseline under Homebrew Rust
1.97, and its rustfmt settings require nightly. Do not mass-format the source or
silently weaken lints to make the patch appear clean. Compare any tool failure
to pristine upstream and record it.

### 5. Regenerate the canonical patch

Inspect the staged diff and check for whitespace errors:

```sh
git -C "$work_dir/rift" diff --cached --check
git -C "$work_dir/rift" diff --cached --stat
```

Generate the patch from the target upstream commit:

```sh
git -C "$work_dir/rift" diff --cached --binary \
  --src-prefix=a/ --dst-prefix=b/ \
  > "$HOME/.config/rift/patches/native-autotiling.patch"
```

Verify it against a fresh extraction or clean checkout of the exact target:

```sh
git -C "$work_dir/rift" reset --hard <new-upstream-commit>
git -C "$work_dir/rift" apply --check \
  "$HOME/.config/rift/patches/native-autotiling.patch"
```

The reset is safe only in this explicitly disposable temporary checkout. Never
run it in `~/.config`, the Chezmoi source repository, a Homebrew tap, or Cellar.

### 6. Update the formula

Calculate the checksum of the exact archive used by the formula, update its URL,
version, and SHA-256, then replace its embedded patch from the canonical bytes:

```sh
formula_file="$HOME/.config/rift/homebrew-tap/Formula/rift-native.rb"
patch_file="$HOME/.config/rift/patches/native-autotiling.patch"

ruby -e '
  formula_path, patch_path = ARGV
  header = File.binread(formula_path).split("__END__\n", 2).fetch(0)
  File.binwrite(formula_path, header + "__END__\n" + File.binread(patch_path))
' "$formula_file" "$patch_file"
```

Repeat the byte-identity and Ruby syntax checks from the integrity section.
Also confirm the formula uses Homebrew's `rust` build dependency; do not switch
it to `rustup` unless a toolchain has deliberately been provisioned for the
Homebrew build environment.

### 7. Validate the formula without cutting over

Run the Homebrew plan and source build checks while the currently working Rift
service remains active:

```sh
brew install --dry-run --build-from-source \
  "$HOME/.config/rift/homebrew-tap/Formula/rift-native.rb"
```

Before replacing an installed personal keg, save the current master layout:

```sh
native_cli="$(brew --prefix rift-native)/bin/rift-cli"
launchctl asuser "$(id -u)" "$native_cli" execute save-layout --master
```

For a real upgrade, first put the retained official keg into service using the
fast rollback procedure below. Leave that official service running while the
new personal formula builds. It is safe to unlink the official keg during the
Homebrew installation step; unlinking removes command symlinks but does not stop
its already-running launchd process.

Build/install the new personal formula, then test its binaries directly through
its opt prefix before stopping the official service:

```sh
brew unlink rift
brew uninstall rift-native
brew install --build-from-source \
  "$HOME/.config/rift/homebrew-tap/Formula/rift-native.rb"

"$(brew --prefix rift-native)/bin/rift-cli" --help
brew test rift-native
```

If the build fails, follow the half-failed installation recovery procedure. Do
not proceed to activation.

### 8. Transactional activation

Only after the source and formula gates pass:

1. Keep the working official binary authorized in Accessibility until the new
   personal build passes acceptance.
2. Re-enable `autotile_focused_leaf = true` in `config.toml`.
3. Authorize the exact new personal binary shown by
   `realpath "$(brew --prefix rift-native)/bin/rift"`.
4. Run the guarded activation below. It stops official Rift only at cutover and
   automatically relinks/restarts it if the personal service does not answer a
   GUI-domain query.
5. Run all live and manual acceptance checks below. Clean up stale Accessibility
   entries only after the new build is accepted.

```sh
activate_rift_native() {
  config_file="$HOME/.config/rift/config.toml"
  current_uid="$(id -u)"
  native_cli="$(brew --prefix rift-native)/bin/rift-cli"

  rollback_to_official() {
    brew services stop rift-native
    sed -i '' -E \
      's/^[[:space:]]*autotile_focused_leaf[[:space:]]*=.*/# autotile_focused_leaf = true/' \
      "$config_file"
    brew unlink rift-native
    brew link --overwrite rift
    brew services start rift
    echo "Native startup failed; official Rift was restored."
  }

  brew services stop rift
  brew link --overwrite rift-native

  if ! brew services start rift-native; then
    rollback_to_official
    return 1
  fi

  native_ready=false
  for attempt in 1 2 3 4 5 6 7 8 9 10; do
    if launchctl asuser "$current_uid" "$native_cli" query workspaces \
      >/dev/null 2>&1; then
      native_ready=true
      break
    fi
    sleep 1
  done

  if [ "$native_ready" != true ]; then
    rollback_to_official
    return 1
  fi

  brew services list | grep rift
}

activate_rift_native
```

The guard covers startup and the first live query. If later live or manual
validation fails, run the fast rollback procedure immediately.

### 9. Commit and synchronize artifacts

Commit the formula in the nested tap repository, then update its registered
clone:

```sh
git -C "$HOME/.config/rift/homebrew-tap" add Formula/rift-native.rb
git -C "$HOME/.config/rift/homebrew-tap" commit -m "feat: update pinned Rift native build"

tap_clone="$(brew --repository)/Library/Taps/yifan/homebrew-rift"
git -C "$tap_clone" pull --ff-only
```

Add only the maintained files to Chezmoi and inspect its diff before committing:

```sh
chezmoi add \
  "$HOME/.config/rift/patches/native-autotiling.patch" \
  "$HOME/.config/rift/homebrew-tap/Formula/rift-native.rb" \
  "$HOME/.config/rift/PATCHING.md"

git -C "$HOME/.local/share/chezmoi" status --short
git -C "$HOME/.local/share/chezmoi" diff --cached --check
```

Do not stage unrelated dotfile changes and do not add
`~/.config/rift/homebrew-tap/.git`.

## Live validation

CLI calls from a terminal normally work directly. From a background or Codex
shell, Rift's GUI Mach service may be invisible in the ordinary bootstrap
namespace. Use the GUI user domain explicitly:

```sh
native_cli="$(brew --prefix rift-native)/bin/rift-cli"
current_uid="$(id -u)"

launchctl asuser "$current_uid" "$native_cli" query workspaces
launchctl asuser "$current_uid" "$native_cli" query windows
launchctl asuser "$current_uid" "$native_cli" query workspace-layout
launchctl asuser "$current_uid" "$native_cli" query metrics
launchctl asuser "$current_uid" "$native_cli" subscribe list-cli
```

Confirm:

- Twelve workspaces exist and workspace index 11 is named `__scratchpad`.
- Traditional layout is active where expected.
- There are no repeated command subscriptions or obsolete autotiling scripts.
- The four intended SketchyBar CLI subscriptions remain: workspace, windows,
  title, and focus changes, all routed through `~/.config/rift/sketchybar_event.sh`.
- `/tmp/rift_<user>.err.log` contains no startup panic, config parse error, or
  repeated layout failure.

## Manual acceptance test

Use a disposable empty workspace so ordinary work is not disturbed.

1. Open ten WezTerm windows one at a time.
2. Before each new window, focus a deliberate tiled leaf and note the existing
   layout.
3. Confirm only that leaf splits, the orientation follows its dimensions, and
   unrelated windows do not stretch or move.
4. Confirm there is no full-bar or window-layout flash between creation and the
   settled frame.
5. Manually resize an ancestor split, open another window in a descendant leaf,
   and confirm the manual ratio remains exact.
6. Send one WezTerm window to scratchpad. Confirm the original tiled layout is
   unchanged.
7. Show and hide it. Confirm it is floating, centered below SketchyBar, and keeps
   its size.
8. Show it, switch to another workspace, then run Show again. Confirm it moves
   only on that second Show and neither workspace's tiled tree changes.
9. Release it with Command+Shift+number. Confirm it is inserted into the target
   focused leaf and the target workspace becomes active.

Do not accept an update that passes unit tests but flashes, changes an unrelated
window's frame, or alters the original layout when showing scratchpad.

## Fast rollback to official Rift

This keeps `rift-native`, the local tap, patch, formula, and documentation in
place for later diagnosis.

First save the layout if the personal service is responsive:

```sh
native_cli="$(brew --prefix rift-native)/bin/rift-cli"
launchctl asuser "$(id -u)" "$native_cli" execute save-layout --master
```

Then:

1. Stop `rift-native`.
2. Comment out or remove `autotile_focused_leaf = true`. Official Rift `0.5.3`
   does not know this field and can fail while parsing the configuration.
3. Unlink the personal keg and link the retained official keg.
4. In System Settings > Privacy & Security > Accessibility, remove stale Rift
   entries and add the exact official binary `/opt/homebrew/opt/rift/bin/rift`.
5. Start official Rift and verify it in the GUI user domain.

```sh
brew services stop rift-native
brew unlink rift-native
brew link --overwrite rift
brew services start rift

official_cli="$(brew --prefix rift)/bin/rift-cli"
launchctl asuser "$(id -u)" "$official_cli" query workspaces
brew services list | grep rift
```

The scratchpad Karabiner shortcuts will not work under official Rift because its
CLI lacks the native commands. They may remain configured during a temporary
rollback, but disable the `Rift scratchpad` and `Rift move window to workspace`
groups for a permanent official-only setup.

## Half-failed installation recovery

Use this when a formula build/install fails after either keg was unlinked. The
goal is to restore the retained official build, not to keep repairing Homebrew
while no window manager is active.

1. Ensure `autotile_focused_leaf` is commented out.
2. Stop any partial personal service.
3. Unlink any partially installed personal keg.
4. Relink and restart official Rift.
5. Re-authorize `/opt/homebrew/opt/rift/bin/rift` if macOS removed or invalidated
   its Accessibility entry.

```sh
brew services stop rift-native
brew unlink rift-native
brew link --overwrite rift
brew services restart rift

official_cli="$(brew --prefix rift)/bin/rift-cli"
launchctl asuser "$(id -u)" "$official_cli" query workspaces
```

If Homebrew reports that `rift-native` is not installed, that part of the stop
or unlink sequence can be skipped. Do not uninstall the official keg during a
personal formula update.

## Full operational removal of the personal build

First complete and verify the fast rollback. Then remove only the installed
personal keg and registered tap clone:

```sh
brew services stop rift-native
brew unlink rift-native
brew uninstall rift-native
brew untap yifan/rift
```

Disable the two native-only Karabiner groups and leave
`autotile_focused_leaf` absent or commented. Keep these tracked sources for
history and possible restoration:

```text
~/.config/rift/patches/native-autotiling.patch
~/.config/rift/homebrew-tap/Formula/rift-native.rb
~/.config/rift/PATCHING.md
```

`brew untap` removes the registered clone under Homebrew. It does not remove the
source tap repository in `~/.config/rift/homebrew-tap` or its Chezmoi copy.

## Maintenance history

Add one entry for every local revision or upstream rebase.

| Date | Old pin | New pin | Formula version | Patch SHA-256 | Validation and baseline notes |
| --- | --- | --- | --- | --- | --- |
| 2026-08-31 | — | `46f5ba06781ac73d145780d2dbfe96516c8ccfb0` | `0.5.3-native.1` | `24b2d3491170e43401c4e07f25fd2c379cc0bd7035559a31743b6f4d852ffb98` | Focused autotiling (3), scratchpad/persistence (2), and Rift CLI (3) tests pass; release build passes; full library suite 547/548 with the sole failure reproduced in pristine upstream; formula embedded patch byte-identical and applies to the pinned archive; live service, workspace, subscriptions, scratchpad, and ten-window behavior verified. |

For future entries, include the exact failing test names when comparing a
baseline, the manual acceptance result, and whether Accessibility had to be
reauthorized. A version or hash without the validation record is not sufficient
to identify a known-good rollback point.
