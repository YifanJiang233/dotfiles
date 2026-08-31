class RiftNative < Formula
  desc "Personal Rift build with native focused-leaf autotiling and scratchpad"
  homepage "https://github.com/acsandmann/rift"
  url "https://github.com/acsandmann/rift/archive/46f5ba06781ac73d145780d2dbfe96516c8ccfb0.tar.gz"
  version "0.5.3-native.1"
  sha256 "3070454428b3edc9442dcd0c035c79d896499b205e1ea27f5f88f3b1fbea21e7"
  license "Apache-2.0"

  depends_on "rust" => :build
  conflicts_with "rift", because: "both install rift and rift-cli"

  patch :DATA

  def install
    system "cargo", "build", "--release", "--locked", "--bins"
    bin.install "target/release/rift", "target/release/rift-cli"

    system "codesign", "--force", "--sign", "-", bin/"rift"
    system "codesign", "--force", "--sign", "-", bin/"rift-cli"
  end

  def caveats
    <<~EOS
      This is a pinned personal build. The official rift keg can remain installed
      and unlinked as a rollback target.

      Rift requires Accessibility permission in:
        System Settings > Privacy & Security > Accessibility
    EOS
  end

  service do
    run "#{opt_bin}/rift"
    environment_variables PATH: std_service_path_env, LANG: "en_US.UTF-8"
    keep_alive true
    process_type :interactive
    require "etc"
    user = (Etc.getpwuid(Process.uid).name rescue "unknown")
    log_path "/tmp/rift_#{user}.out.log"
    error_log_path "/tmp/rift_#{user}.err.log"
  end

  test do
    assert_match "Command-line interface for rift", shell_output("#{bin}/rift-cli --help")
  end
end

__END__
diff --git a/crates/rift-protocol/src/commands.rs b/crates/rift-protocol/src/commands.rs
index 7609c11..1a4e7d7 100644
--- a/crates/rift-protocol/src/commands.rs
+++ b/crates/rift-protocol/src/commands.rs
@@ -68,6 +68,11 @@ pub enum LayoutCommand {
         follow: bool,
         window_id: Option<u32>,
     },
+    ScratchpadSend,
+    ScratchpadShow,
+    ScratchpadRelease {
+        workspace: WorkspaceSelector,
+    },
     SetWorkspaceLayout {
         workspace: Option<usize>,
         mode: LayoutMode,
diff --git a/src/actor/reactor/events/command.rs b/src/actor/reactor/events/command.rs
index ed12384..8064a94 100644
--- a/src/actor/reactor/events/command.rs
+++ b/src/actor/reactor/events/command.rs
@@ -47,6 +47,7 @@ pub fn handle_command_layout(
             | LayoutCommand::PrevWorkspace(_)
             | LayoutCommand::SwitchToWorkspace(_)
             | LayoutCommand::MoveWindowToWorkspace { follow: true, .. }
+            | LayoutCommand::ScratchpadRelease { .. }
             | LayoutCommand::SwitchToLastWorkspace
     );
     let requires_workspace_space = matches!(
@@ -55,6 +56,9 @@ pub fn handle_command_layout(
             | LayoutCommand::PrevWorkspace(_)
             | LayoutCommand::SwitchToWorkspace(_)
             | LayoutCommand::MoveWindowToWorkspace { follow: true, .. }
+            | LayoutCommand::ScratchpadSend
+            | LayoutCommand::ScratchpadShow
+            | LayoutCommand::ScratchpadRelease { .. }
             | LayoutCommand::SetWorkspaceLayout { .. }
             | LayoutCommand::CreateWorkspace
             | LayoutCommand::SwitchToLastWorkspace
diff --git a/src/bin/rift-cli.rs b/src/bin/rift-cli.rs
index 7849562..cbd1af5 100644
--- a/src/bin/rift-cli.rs
+++ b/src/bin/rift-cli.rs
@@ -115,6 +115,11 @@ enum ExecuteCommands {
         #[command(subcommand)]
         workspace_cmd: WorkspaceCommands,
     },
+    /// Native scratchpad commands
+    Scratchpad {
+        #[command(subcommand)]
+        scratchpad_cmd: ScratchpadCommands,
+    },
     /// Layout commands
     Layout {
         #[command(subcommand)]
@@ -295,6 +300,16 @@ enum WorkspaceCommands {
     },
 }
 
+#[derive(Subcommand)]
+enum ScratchpadCommands {
+    /// Move the focused window to the reserved scratchpad workspace
+    Send,
+    /// Show the most recent hidden scratchpad window, or hide the focused shown window
+    Show,
+    /// Release the focused shown scratchpad window into a normal workspace
+    Release { workspace_id: usize },
+}
+
 #[derive(Subcommand)]
 enum LayoutCommands {
     /// Move selection up the tree
@@ -616,6 +631,9 @@ fn build_execute_request(execute: ExecuteCommands) -> Result<RiftRequest, String
     let rift_command = match execute {
         ExecuteCommands::Window { window_cmd } => map_window_command(window_cmd)?,
         ExecuteCommands::Workspace { workspace_cmd } => map_workspace_command(workspace_cmd)?,
+        ExecuteCommands::Scratchpad { scratchpad_cmd } => {
+            map_scratchpad_command(scratchpad_cmd)?
+        }
         ExecuteCommands::Layout { layout_cmd } => map_layout_command(layout_cmd)?,
         ExecuteCommands::Config { config_cmd } => map_config_command(config_cmd)?,
         ExecuteCommands::MissionControl { mission_cmd } => {
@@ -882,6 +900,18 @@ fn map_workspace_command(cmd: WorkspaceCommands) -> Result<CliCommand, String> {
     }
 }
 
+fn map_scratchpad_command(cmd: ScratchpadCommands) -> Result<CliCommand, String> {
+    use layout::LayoutCommand as LC;
+    let command = match cmd {
+        ScratchpadCommands::Send => LC::ScratchpadSend,
+        ScratchpadCommands::Show => LC::ScratchpadShow,
+        ScratchpadCommands::Release { workspace_id } => LC::ScratchpadRelease {
+            workspace: WorkspaceSelector::Index(workspace_id),
+        },
+    };
+    Ok(CliCommand::Reactor(reactor::Command::Layout(command)))
+}
+
 fn map_layout_command(cmd: LayoutCommands) -> Result<CliCommand, String> {
     use layout::LayoutCommand as LC;
     match cmd {
@@ -1167,6 +1197,25 @@ mod tests {
         );
     }
 
+    #[test]
+    fn scratchpad_release_uses_typed_workspace_selector() {
+        let request = build_execute_request(ExecuteCommands::Scratchpad {
+            scratchpad_cmd: ScratchpadCommands::Release { workspace_id: 4 },
+        })
+        .unwrap();
+
+        assert_eq!(
+            serde_json::to_value(request).unwrap(),
+            serde_json::json!({
+                "execute_command": {
+                    "command": {
+                        "layout": { "scratchpad_release": { "workspace": 4 } }
+                    }
+                }
+            })
+        );
+    }
+
     #[test]
     fn config_commands_are_not_embedded_as_json_strings() {
         let request = build_execute_request(ExecuteCommands::Config {
diff --git a/src/common/config.rs b/src/common/config.rs
index 9fad0f6..174c2a8 100644
--- a/src/common/config.rs
+++ b/src/common/config.rs
@@ -696,6 +696,10 @@ pub struct TraditionalLayoutSettings {
     /// average sibling weight instead of splitting the selected node's share.
     #[serde(default = "yes")]
     pub equalize_nodes: bool,
+    /// Split the currently focused tiled leaf when a new window is discovered.
+    /// This is opt-in because it changes traditional layout insertion semantics.
+    #[serde(default)]
+    pub autotile_focused_leaf: bool,
 }
 
 impl Default for TraditionalLayoutSettings {
@@ -703,6 +707,7 @@ impl Default for TraditionalLayoutSettings {
         Self {
             base: BaseLayoutSettings::default(),
             equalize_nodes: true,
+            autotile_focused_leaf: false,
         }
     }
 }
@@ -1629,6 +1634,7 @@ mod tests {
                 [traditional]
                 window_insertion_point = "next_to_selection"
                 equalize_nodes = true
+                autotile_focused_leaf = true
 
                 [scrolling]
                 animate = false
@@ -1645,9 +1651,18 @@ mod tests {
             WindowInsertionPoint::EndOfTree
         );
         assert!(settings.traditional.equalize_nodes);
+        assert!(settings.traditional.autotile_focused_leaf);
         assert_eq!(settings.scrolling.animate, Some(false));
     }
 
+    #[test]
+    fn traditional_native_autotiling_is_opt_in() {
+        assert!(!TraditionalLayoutSettings::default().autotile_focused_leaf);
+        let settings: TraditionalLayoutSettings =
+            toml::from_str("autotile_focused_leaf = true").unwrap();
+        assert!(settings.autotile_focused_leaf);
+    }
+
     #[test]
     fn virtual_workspace_prevent_wrapping_defaults_to_false_and_accepts_suggested_alias() {
         let defaults: VirtualWorkspaceSettings = toml::from_str("").unwrap();
diff --git a/src/layout_engine/engine.rs b/src/layout_engine/engine.rs
index 8044770..61a43ee 100644
--- a/src/layout_engine/engine.rs
+++ b/src/layout_engine/engine.rs
@@ -14,6 +14,7 @@ use crate::common::config::{LayoutMode, LayoutSettings, WorkspaceSelector};
 use crate::layout_engine::LayoutSystem;
 use crate::layout_engine::floating::FloatingFullscreenKind;
 use crate::layout_engine::systems::WindowLayoutConstraints;
+use crate::layout_engine::utils::compute_tiling_area;
 use crate::model::app_rules::{AppRuleOutcome, AppRuleResize, AppRuleWorkspaceFocus};
 use crate::model::broadcast::{BroadcastEvent, BroadcastSender, protocol_workspace_id};
 use crate::model::virtual_workspace::{VirtualWorkspace, VirtualWorkspaceId, WorkspaceStore};
@@ -88,6 +89,53 @@ struct WindowRemovalImpact {
     active_space: Option<SpaceId>,
 }
 
+#[derive(Debug, Clone, Default, Serialize, Deserialize)]
+pub(super) struct ScratchpadState {
+    members: Vec<WindowId>,
+    shown: Option<WindowId>,
+}
+
+impl ScratchpadState {
+    fn add(&mut self, window: WindowId) {
+        self.members.retain(|member| *member != window);
+        self.members.push(window);
+    }
+
+    fn remove(&mut self, window: WindowId) {
+        self.members.retain(|member| *member != window);
+        if self.shown == Some(window) {
+            self.shown = None;
+        }
+    }
+
+    fn contains(&self, window: WindowId) -> bool { self.members.contains(&window) }
+
+    fn rekey(&mut self, from: WindowId, to: WindowId) {
+        for member in &mut self.members {
+            if *member == from {
+                *member = to;
+            }
+        }
+        let mut unique = Vec::with_capacity(self.members.len());
+        for member in self.members.drain(..) {
+            if !unique.contains(&member) {
+                unique.push(member);
+            }
+        }
+        self.members = unique;
+        if self.shown == Some(from) {
+            self.shown = Some(to);
+        }
+    }
+
+    fn remove_pid(&mut self, pid: pid_t) {
+        self.members.retain(|window| window.pid != pid);
+        if self.shown.is_some_and(|window| window.pid == pid) {
+            self.shown = None;
+        }
+    }
+}
+
 #[non_exhaustive]
 #[derive(Debug, Clone)]
 pub enum LayoutEvent {
@@ -157,6 +205,7 @@ pub struct LayoutEngine {
     broadcast_tx: Option<BroadcastSender>,
     space_display_map: HashMap<SpaceId, Option<String>>,
     display_last_space: HashMap<String, SpaceId>,
+    scratchpad: ScratchpadState,
     persistence: PersistenceState,
     /// Set only while a master-file startup restore is waiting for the first display snapshot.
     startup_restore_pending: bool,
@@ -449,6 +498,8 @@ impl LayoutEngine {
                 LayoutSystemKind::Traditional(system) => {
                     system.set_window_insertion_point(insertion_point);
                     system.set_equalize_nodes(settings.traditional.equalize_nodes);
+                    system
+                        .set_autotile_focused_leaf(settings.traditional.autotile_focused_leaf);
                 }
                 LayoutSystemKind::Bsp(system) => {
                     system.set_window_insertion_point(insertion_point);
@@ -1032,6 +1083,7 @@ impl LayoutEngine {
         wid: WindowId,
         preserve_floating: bool,
     ) {
+        self.scratchpad.remove(wid);
         let removal = self.remove_window_layout_membership(window_store, wid);
 
         if preserve_floating {
@@ -1114,8 +1166,10 @@ impl LayoutEngine {
             self.floating.add_active(space, wid.pid, wid);
         } else if let Some(layout) = self.workspace_layouts.active(space, assigned_workspace) {
             if !self.workspace_tree(assigned_workspace).contains_window(layout, wid) {
+                let anchor_frame =
+                    self.selected_tiled_frame(space, assigned_workspace, layout);
                 self.workspace_tree_mut(assigned_workspace)
-                    .add_window_after_selection(layout, wid);
+                    .add_window_after_selection_with_anchor_frame(layout, wid, anchor_frame);
             }
         } else {
             warn!(
@@ -1127,6 +1181,324 @@ impl LayoutEngine {
         self.space_with_window(wid) != active_space_before
     }
 
+    fn selected_tiled_frame(
+        &self,
+        space: SpaceId,
+        workspace_id: VirtualWorkspaceId,
+        layout: LayoutId,
+    ) -> Option<CGRect> {
+        let screen_size = self.workspace_layouts.active_size(space, workspace_id)?;
+        let workspace = self.virtual_workspace_manager.workspace_info(space, workspace_id)?;
+        let selected = workspace.layout_system.selected_window(layout)?;
+        let display_uuid = self.display_uuid_for_space(space);
+        let gaps = self
+            .layout_settings
+            .gaps
+            .effective_for_display(display_uuid.as_deref());
+        let screen = CGRect::new(CGPoint::new(0.0, 0.0), screen_size);
+
+        workspace
+            .layout_system
+            .calculate_layout(
+                layout,
+                screen,
+                self.layout_settings.stack.stack_offset,
+                &self.window_layout_constraints,
+                &gaps,
+                0.0,
+                Default::default(),
+                Default::default(),
+            )
+            .into_iter()
+            .find_map(|(window, frame)| (window == selected).then_some(frame))
+    }
+
+    fn scratchpad_workspace(&self, space: SpaceId) -> Option<VirtualWorkspaceId> {
+        self.virtual_workspace_manager
+            .existing_workspaces(space)
+            .into_iter()
+            .find_map(|(workspace, name)| (name == "__scratchpad").then_some(workspace))
+    }
+
+    fn workspace_for_selector(
+        &self,
+        space: SpaceId,
+        selector: &WorkspaceSelector,
+    ) -> Option<VirtualWorkspaceId> {
+        let workspaces = self.virtual_workspace_manager.existing_workspaces(space);
+        match selector {
+            WorkspaceSelector::Index(index) => workspaces.get(*index).map(|(id, _)| *id),
+            WorkspaceSelector::Name(name) => workspaces
+                .into_iter()
+                .find_map(|(id, candidate)| (candidate == *name).then_some(id)),
+        }
+    }
+
+    fn scratchpad_centered_frame(
+        &self,
+        space: SpaceId,
+        workspace: VirtualWorkspaceId,
+        center: CGPoint,
+        current: CGRect,
+    ) -> Option<CGRect> {
+        let size = self.workspace_layouts.active_size(space, workspace)?;
+        let display_uuid = self.display_uuid_for_space(space);
+        let gaps = self
+            .layout_settings
+            .gaps
+            .effective_for_display(display_uuid.as_deref());
+        let screen = CGRect::new(
+            CGPoint::new(center.x - size.width / 2.0, center.y - size.height / 2.0),
+            size,
+        );
+        let usable = compute_tiling_area(screen, &gaps);
+        let width = current.size.width.min(usable.size.width).max(1.0);
+        let height = current.size.height.min(usable.size.height).max(1.0);
+        Some(CGRect::new(
+            CGPoint::new(
+                usable.origin.x + (usable.size.width - width) / 2.0,
+                usable.origin.y + (usable.size.height - height) / 2.0,
+            ),
+            CGSize::new(width, height),
+        ))
+    }
+
+    fn tiled_focus_for_workspace(
+        &self,
+        space: SpaceId,
+        workspace: VirtualWorkspaceId,
+    ) -> Option<WindowId> {
+        let layout = self.workspace_layouts.active(space, workspace)?;
+        self.workspace_tree(workspace)
+            .selected_window(layout)
+            .or_else(|| {
+                self.workspace_tree(workspace)
+                    .visible_windows_in_layout(layout)
+                    .into_iter()
+                    .next()
+            })
+    }
+
+    fn handle_scratchpad_command(
+        &mut self,
+        window_store: &mut WindowStore,
+        space: SpaceId,
+        visible_space_centers: &HashMap<SpaceId, CGPoint>,
+        command: LayoutCommand,
+    ) -> EventResponse {
+        let Some(scratch_workspace) = self.scratchpad_workspace(space) else {
+            warn!("Scratchpad command ignored: workspace `__scratchpad` does not exist");
+            return EventResponse::default();
+        };
+        let Some(active_workspace) = self.virtual_workspace_manager.active_workspace(space) else {
+            return EventResponse::default();
+        };
+
+        match command {
+            LayoutCommand::ScratchpadSend => {
+                let Some(window) = self.focused_window else {
+                    return EventResponse::default();
+                };
+                if active_workspace == scratch_workspace || self.scratchpad.contains(window) {
+                    return EventResponse::default();
+                }
+                let Some(frame) = window_store.window(window).map(|state| state.frame_monotonic)
+                else {
+                    return EventResponse::default();
+                };
+
+                if !self.virtual_workspace_manager.assign_window_to_workspace(
+                    window_store,
+                    space,
+                    window,
+                    scratch_workspace,
+                ) {
+                    warn!(?window, "Scratchpad send failed to assign reserved workspace");
+                    return EventResponse::default();
+                }
+                self.remove_window_from_all_tiling_trees(window);
+                self.floating.remove_active_for_window(window);
+                self.floating.add_floating(window);
+                self.floating_positions.remove_window(window);
+                self.floating_positions
+                    .store(space, scratch_workspace, window, frame);
+                self.scratchpad.add(window);
+                self.scratchpad.shown = None;
+
+                let focus = self.tiled_focus_for_workspace(space, active_workspace);
+                self.commit_workspace_focus(window_store, space, focus);
+                self.broadcast_windows_changed(window_store, space);
+                EventResponse {
+                    changed: true,
+                    raise_windows: focus.into_iter().collect(),
+                    focus_window: focus,
+                    boundary_hit: None,
+                }
+            }
+            LayoutCommand::ScratchpadShow => {
+                if self.scratchpad.shown == self.focused_window {
+                    let window = self.scratchpad.shown.expect("checked shown scratchpad window");
+                    let frame = window_store
+                        .window(window)
+                        .map(|state| state.frame_monotonic)
+                        .or_else(|| {
+                            self.floating_positions.get(
+                                space,
+                                active_workspace,
+                                window,
+                            )
+                        });
+                    if !self.virtual_workspace_manager.assign_window_to_workspace(
+                        window_store,
+                        space,
+                        window,
+                        scratch_workspace,
+                    ) {
+                        return EventResponse::default();
+                    }
+                    self.floating.remove_active_for_window(window);
+                    self.floating_positions.remove_window(window);
+                    if let Some(frame) = frame {
+                        self.floating_positions
+                            .store(space, scratch_workspace, window, frame);
+                    }
+                    self.scratchpad.shown = None;
+
+                    let focus = self.tiled_focus_for_workspace(space, active_workspace);
+                    self.commit_workspace_focus(window_store, space, focus);
+                    self.broadcast_windows_changed(window_store, space);
+                    return EventResponse {
+                        changed: true,
+                        raise_windows: focus.into_iter().collect(),
+                        focus_window: focus,
+                        boundary_hit: None,
+                    };
+                }
+
+                let candidate = self
+                    .scratchpad
+                    .shown
+                    .filter(|window| window_store.window(*window).is_some())
+                    .or_else(|| {
+                        self.scratchpad
+                            .members
+                            .iter()
+                            .rev()
+                            .copied()
+                            .find(|window| window_store.window(*window).is_some())
+                    });
+                let Some(window) = candidate else {
+                    return EventResponse::default();
+                };
+
+                let Some(center) = visible_space_centers.get(&space).copied() else {
+                    return EventResponse::default();
+                };
+                let Some(current) = window_store.window(window).map(|state| state.frame_monotonic)
+                else {
+                    return EventResponse::default();
+                };
+                let Some(frame) =
+                    self.scratchpad_centered_frame(space, active_workspace, center, current)
+                else {
+                    return EventResponse::default();
+                };
+                self.floating.remove_active_for_window(window);
+                if !self.virtual_workspace_manager.assign_window_to_workspace(
+                    window_store,
+                    space,
+                    window,
+                    active_workspace,
+                ) {
+                    return EventResponse::default();
+                }
+                self.floating.add_floating(window);
+                self.floating.add_active(space, window.pid, window);
+                self.floating.set_last_focus(Some(window));
+                self.floating_positions.remove_window(window);
+                self.floating_positions
+                    .store(space, active_workspace, window, frame);
+                self.scratchpad.shown = Some(window);
+                self.commit_workspace_focus(window_store, space, Some(window));
+                self.broadcast_windows_changed(window_store, space);
+
+                EventResponse {
+                    changed: true,
+                    raise_windows: vec![window],
+                    focus_window: Some(window),
+                    boundary_hit: None,
+                }
+            }
+            LayoutCommand::ScratchpadRelease { workspace } => {
+                let Some(window) = self.focused_window else {
+                    return EventResponse::default();
+                };
+                if self.scratchpad.shown != Some(window) || !self.scratchpad.contains(window) {
+                    return EventResponse::default();
+                }
+                let Some(target_workspace) = self.workspace_for_selector(space, &workspace) else {
+                    warn!(?workspace, "Scratchpad release target does not exist");
+                    return EventResponse::default();
+                };
+                if target_workspace == scratch_workspace {
+                    warn!("Scratchpad release target cannot be `__scratchpad`");
+                    return EventResponse::default();
+                }
+                let Some(target_layout) =
+                    self.workspace_layouts.active(space, target_workspace)
+                else {
+                    return EventResponse::default();
+                };
+                let anchor = self.selected_tiled_frame(space, target_workspace, target_layout);
+
+                if !self.virtual_workspace_manager.assign_window_to_workspace(
+                    window_store,
+                    space,
+                    window,
+                    target_workspace,
+                ) {
+                    return EventResponse::default();
+                }
+                self.floating.remove_active_for_window(window);
+                self.floating.remove_floating(window);
+                self.floating_positions.remove_window(window);
+                self.workspace_tree_mut(target_workspace)
+                    .add_window_after_selection_with_anchor_frame(target_layout, window, anchor);
+                self.scratchpad.remove(window);
+                self.virtual_workspace_manager.set_last_focused_window(
+                    space,
+                    target_workspace,
+                    Some(window),
+                );
+
+                let mut response = if target_workspace == active_workspace {
+                    self.commit_workspace_focus(window_store, space, Some(window));
+                    EventResponse {
+                        changed: true,
+                        raise_windows: vec![window],
+                        focus_window: Some(window),
+                        boundary_hit: None,
+                    }
+                } else {
+                    self.activate_workspace(
+                        window_store,
+                        space,
+                        target_workspace,
+                        Some(window),
+                    )
+                };
+                if !response.raise_windows.contains(&window) {
+                    response.raise_windows.push(window);
+                }
+                response.focus_window = Some(window);
+                self.commit_workspace_focus(window_store, space, Some(window));
+                self.broadcast_windows_changed(window_store, space);
+                response
+            }
+            _ => unreachable!("only scratchpad commands reach this handler"),
+        }
+    }
+
     fn remove_window_from_all_tiling_trees(&mut self, wid: WindowId) {
         let ws_ids: Vec<_> = self.virtual_workspace_manager.workspaces.keys().collect();
         for ws_id in ws_ids {
@@ -1247,7 +1619,26 @@ impl LayoutEngine {
             // their normal insertion semantics, so preserve the selection
             // explicitly across discovery-driven synchronization.
             let selected_window = self.workspace_tree(ws_id).selected_window(layout);
-            self.workspace_tree_mut(ws_id).set_windows_for_app(layout, pid, desired);
+            if self.workspace_tree(ws_id).uses_focused_leaf_autotiling() {
+                let additions: Vec<_> = desired
+                    .iter()
+                    .copied()
+                    .filter(|window| !current.contains(window))
+                    .collect();
+                let retained: Vec<_> = desired
+                    .into_iter()
+                    .filter(|window| current.contains(window))
+                    .collect();
+                self.workspace_tree_mut(ws_id)
+                    .set_windows_for_app(layout, pid, retained);
+                for window in additions {
+                    let anchor = self.selected_tiled_frame(space, ws_id, layout);
+                    self.workspace_tree_mut(ws_id)
+                        .add_window_after_selection_with_anchor_frame(layout, window, anchor);
+                }
+            } else {
+                self.workspace_tree_mut(ws_id).set_windows_for_app(layout, pid, desired);
+            }
             if let Some(selected_window) = selected_window
                 && self.workspace_tree(ws_id).contains_window(layout, selected_window)
             {
@@ -1347,6 +1738,7 @@ impl LayoutEngine {
             broadcast_tx,
             space_display_map: HashMap::default(),
             display_last_space: HashMap::default(),
+            scratchpad: ScratchpadState::default(),
             persistence: PersistenceState::default(),
             startup_restore_pending: false,
         }
@@ -1615,6 +2007,7 @@ impl LayoutEngine {
                 };
             }
             LayoutEvent::AppClosed(pid) => {
+                self.scratchpad.remove_pid(pid);
                 for (_, ws) in self.virtual_workspace_manager.workspaces.iter_mut() {
                     ws.layout_system.remove_windows_for_app(pid);
                 }
@@ -1715,6 +2108,22 @@ impl LayoutEngine {
                 debug!("No active workspace for space {:?}", space);
             }
         }
+        if matches!(
+            &command,
+            LayoutCommand::ScratchpadSend
+                | LayoutCommand::ScratchpadShow
+                | LayoutCommand::ScratchpadRelease { .. }
+        ) {
+            let Some(space) = space else {
+                return EventResponse::default();
+            };
+            return self.handle_scratchpad_command(
+                window_store,
+                space,
+                visible_space_centers,
+                command,
+            );
+        }
         let is_floating = if let Some(focus) = self.focused_window {
             self.floating.is_floating(focus)
         } else {
@@ -2040,6 +2449,9 @@ impl LayoutEngine {
             | LayoutCommand::MoveWindowToWorkspace { .. }
             | LayoutCommand::SetWorkspaceLayout { .. }
             | LayoutCommand::CreateWorkspace
+            | LayoutCommand::ScratchpadSend
+            | LayoutCommand::ScratchpadShow
+            | LayoutCommand::ScratchpadRelease { .. }
             | LayoutCommand::SwitchToLastWorkspace => EventResponse::default(),
             LayoutCommand::JoinWindow(direction) => {
                 self.workspace_layouts.mark_last_saved(space, workspace_id, layout);
@@ -3082,6 +3494,7 @@ impl LayoutEngine {
         self.virtual_workspace_manager.transfer_window_identity(from, to);
         self.floating_positions.transfer_window_identity(from, to);
         self.floating.transfer_window_identity(from, to);
+        self.scratchpad.rekey(from, to);
         self.transfer_persisted_window_identity(from, to);
         if let Some(constraints) = self.window_layout_constraints.remove(&from) {
             self.window_layout_constraints.insert(to, constraints);
@@ -3214,6 +3627,9 @@ mod tests {
         AppRulePosition, AppRuleSize, AppWorkspaceRule, LayoutMode, LayoutSettings,
         VirtualWorkspaceSettings, WorkspaceLayoutRule, WorkspaceSelector,
     };
+    use crate::model::reactor::WindowState;
+    use crate::sys::app::WindowInfo;
+    use crate::sys::window_server::WindowServerId;
 
     fn test_engine() -> LayoutEngine {
         LayoutEngine::new(
@@ -3763,6 +4179,268 @@ mod tests {
         assert!(response.changed);
     }
 
+    #[test]
+    fn native_scratchpad_show_and_hide_never_change_tiled_frames() {
+        let workspace_settings = VirtualWorkspaceSettings {
+            default_workspace_count: 3,
+            workspace_names: vec!["1".into(), "2".into(), "__scratchpad".into()],
+            ..VirtualWorkspaceSettings::default()
+        };
+        let mut layout_settings = LayoutSettings::default();
+        layout_settings.traditional.autotile_focused_leaf = true;
+        layout_settings.gaps.outer = crate::common::config::OuterGaps {
+            top: 38.0,
+            left: 4.0,
+            bottom: 4.0,
+            right: 4.0,
+        };
+        layout_settings.gaps.inner = crate::common::config::InnerGaps {
+            horizontal: 8.0,
+            vertical: 8.0,
+        };
+
+        let mut engine = LayoutEngine::new(&workspace_settings, &layout_settings, None);
+        let mut window_store = WindowStore::default();
+        let space = SpaceId::new(711);
+        let screen = CGRect::new(CGPoint::new(0.0, 0.0), CGSize::new(1344.0, 756.0));
+        let tiled = WindowId::new(70, 1);
+        let scratch = WindowId::new(70, 2);
+        for (window, sys_id, origin) in [
+            (tiled, 7001, CGPoint::new(4.0, 38.0)),
+            (scratch, 7002, CGPoint::new(676.0, 38.0)),
+        ] {
+            let frame = CGRect::new(origin, CGSize::new(500.0, 300.0));
+            window_store.insert_window(
+                window,
+                WindowState {
+                    info: WindowInfo {
+                        is_standard: true,
+                        is_root: true,
+                        is_minimized: false,
+                        is_resizable: true,
+                        title: format!("window {}", window.idx),
+                        frame,
+                        min_size: None,
+                        max_size: None,
+                        sys_id: Some(WindowServerId::new(sys_id)),
+                        bundle_id: Some("com.example.scratchpad-test".into()),
+                        path: None,
+                        ax_role: None,
+                        ax_subrole: None,
+                    },
+                    frame_monotonic: frame,
+                    is_manageable: true,
+                    manage_override: None,
+                },
+            );
+        }
+        let info = |window| {
+            (
+                window,
+                None,
+                None,
+                None,
+                true,
+                CGSize::new(500.0, 300.0),
+                None,
+                None,
+            )
+        };
+        let _ = engine.handle_event(
+            &mut window_store,
+            LayoutEvent::SpaceExposed(space, screen.size),
+        );
+        let _ = engine.handle_event(
+            &mut window_store,
+            LayoutEvent::windows_on_screen_updated(
+                space,
+                tiled.pid,
+                vec![info(tiled), info(scratch)],
+                None,
+            ),
+        );
+        let _ = engine.handle_event(
+            &mut window_store,
+            LayoutEvent::WindowFocused(space, scratch),
+        );
+
+        let visible_spaces = vec![space];
+        let mut centers = HashMap::default();
+        centers.insert(space, screen.mid());
+        assert_eq!(engine.focused_window, Some(scratch));
+        assert!(window_store.window(scratch).is_some());
+        assert_eq!(
+            engine
+                .virtual_workspace_manager
+                .existing_workspaces(space)
+                .into_iter()
+                .map(|(_, name)| name)
+                .collect::<Vec<_>>(),
+            vec![
+                "1".to_string(),
+                "2".to_string(),
+                "__scratchpad".to_string(),
+            ]
+        );
+        let send = engine.handle_command(
+            &mut window_store,
+            Some(space),
+            &visible_spaces,
+            &centers,
+            LayoutCommand::ScratchpadSend,
+        );
+        assert!(send.changed);
+        let scratch_workspace = engine
+            .scratchpad_workspace(space)
+            .expect("scratchpad workspace missing");
+        assert!(engine.scratchpad.contains(scratch));
+        assert_eq!(
+            engine
+                .virtual_workspace_manager
+                .workspace_for_window(&window_store, space, scratch),
+            Some(scratch_workspace)
+        );
+
+        let baseline: HashMap<WindowId, CGRect> = engine
+            .calculate_layout(
+                space,
+                screen,
+                &layout_settings.gaps,
+                0.0,
+                Default::default(),
+                Default::default(),
+            )
+            .into_iter()
+            .collect();
+        assert_eq!(baseline.len(), 1);
+        assert!(baseline.contains_key(&tiled));
+
+        let shown = engine.handle_command(
+            &mut window_store,
+            Some(space),
+            &visible_spaces,
+            &centers,
+            LayoutCommand::ScratchpadShow,
+        );
+        assert_eq!(shown.focus_window, Some(scratch));
+        assert_eq!(
+            engine
+                .calculate_layout(
+                    space,
+                    screen,
+                    &layout_settings.gaps,
+                    0.0,
+                    Default::default(),
+                    Default::default(),
+                )
+                .into_iter()
+                .collect::<HashMap<_, _>>(),
+            baseline
+        );
+
+        let first_workspace = engine
+            .workspace_for_selector(space, &WorkspaceSelector::Index(0))
+            .unwrap();
+        let second_workspace = engine
+            .workspace_for_selector(space, &WorkspaceSelector::Index(1))
+            .unwrap();
+        engine
+            .virtual_workspace_manager
+            .set_active_workspace(space, second_workspace);
+        engine.update_active_floating_windows(&window_store, space);
+        engine.focused_window = None;
+        let relocated = engine.handle_command(
+            &mut window_store,
+            Some(space),
+            &visible_spaces,
+            &centers,
+            LayoutCommand::ScratchpadShow,
+        );
+        assert_eq!(relocated.focus_window, Some(scratch));
+        assert_eq!(
+            engine
+                .virtual_workspace_manager
+                .workspace_for_window(&window_store, space, scratch),
+            Some(second_workspace),
+            "showing again after a workspace switch must relocate the shown window"
+        );
+        let _ = engine.handle_command(
+            &mut window_store,
+            Some(space),
+            &visible_spaces,
+            &centers,
+            LayoutCommand::ScratchpadShow,
+        );
+        engine
+            .virtual_workspace_manager
+            .set_active_workspace(space, first_workspace);
+        engine.update_active_floating_windows(&window_store, space);
+        engine.commit_workspace_focus(&mut window_store, space, Some(tiled));
+        let _ = engine.handle_command(
+            &mut window_store,
+            Some(space),
+            &visible_spaces,
+            &centers,
+            LayoutCommand::ScratchpadShow,
+        );
+
+        let hidden = engine.handle_command(
+            &mut window_store,
+            Some(space),
+            &visible_spaces,
+            &centers,
+            LayoutCommand::ScratchpadShow,
+        );
+        assert_eq!(hidden.focus_window, Some(tiled));
+        assert_eq!(
+            engine
+                .calculate_layout(
+                    space,
+                    screen,
+                    &layout_settings.gaps,
+                    0.0,
+                    Default::default(),
+                    Default::default(),
+                )
+                .into_iter()
+                .collect::<HashMap<_, _>>(),
+            baseline
+        );
+
+        let _ = engine.handle_command(
+            &mut window_store,
+            Some(space),
+            &visible_spaces,
+            &centers,
+            LayoutCommand::ScratchpadShow,
+        );
+        let released = engine.handle_command(
+            &mut window_store,
+            Some(space),
+            &visible_spaces,
+            &centers,
+            LayoutCommand::ScratchpadRelease {
+                workspace: WorkspaceSelector::Index(0),
+            },
+        );
+        assert_eq!(released.focus_window, Some(scratch));
+        assert!(!engine.scratchpad.contains(scratch));
+        assert!(!engine.floating.is_floating(scratch));
+        assert_eq!(
+            engine
+                .calculate_layout(
+                    space,
+                    screen,
+                    &layout_settings.gaps,
+                    0.0,
+                    Default::default(),
+                    Default::default(),
+                )
+                .len(),
+            2
+        );
+    }
+
     #[test]
     fn workspace_switch_response_reports_whether_workspace_changed() {
         let mut window_store = WindowStore::default();
diff --git a/src/layout_engine/engine/persistence/mod.rs b/src/layout_engine/engine/persistence/mod.rs
index 3f4528a..384597f 100644
--- a/src/layout_engine/engine/persistence/mod.rs
+++ b/src/layout_engine/engine/persistence/mod.rs
@@ -8,7 +8,7 @@ use objc2_core_foundation::CGSize;
 pub use rift_protocol::{RestoreScope, RestoreSource};
 use serde::{Deserialize, Serialize};
 
-use super::{FloatingManager, LayoutEngine, WorkspaceLayouts};
+use super::{FloatingManager, LayoutEngine, ScratchpadState, WorkspaceLayouts};
 use crate::actor::app::{WindowId, pid_t};
 use crate::common::collections::{HashMap, HashSet};
 use crate::common::config::{LayoutSettings, VirtualWorkspaceSettings};
diff --git a/src/layout_engine/engine/persistence/snapshot.rs b/src/layout_engine/engine/persistence/snapshot.rs
index d28ef70..31af51a 100644
--- a/src/layout_engine/engine/persistence/snapshot.rs
+++ b/src/layout_engine/engine/persistence/snapshot.rs
@@ -20,6 +20,8 @@ pub(super) struct PersistedLayout {
     pub(super) space_display_map: HashMap<SpaceId, Option<String>>,
     #[serde(default)]
     pub(super) display_last_space: HashMap<String, SpaceId>,
+    #[serde(default)]
+    pub(super) scratchpad: ScratchpadState,
     #[serde(flatten)]
     pub(super) persistence: PersistenceState,
 }
@@ -34,6 +36,7 @@ struct PersistedLayoutRef<'a> {
     virtual_workspace_manager: &'a WorkspaceStore,
     space_display_map: &'a HashMap<SpaceId, Option<String>>,
     display_last_space: &'a HashMap<String, SpaceId>,
+    scratchpad: &'a ScratchpadState,
     #[serde(flatten)]
     persistence: &'a PersistenceState,
 }
@@ -52,6 +55,7 @@ impl PersistedLayout {
             virtual_workspace_manager: &engine.virtual_workspace_manager,
             space_display_map: &engine.space_display_map,
             display_last_space: &engine.display_last_space,
+            scratchpad: &engine.scratchpad,
             persistence: &engine.persistence,
         })
         .expect("persisted layout serialization must support all engine layout state")
@@ -70,6 +74,7 @@ impl PersistedLayout {
             broadcast_tx: None,
             space_display_map: self.space_display_map,
             display_last_space: self.display_last_space,
+            scratchpad: self.scratchpad,
             persistence: self.persistence,
             startup_restore_pending: false,
         }
diff --git a/src/layout_engine/engine/persistence/tests.rs b/src/layout_engine/engine/persistence/tests.rs
index 2c33976..69557eb 100644
--- a/src/layout_engine/engine/persistence/tests.rs
+++ b/src/layout_engine/engine/persistence/tests.rs
@@ -1924,6 +1924,39 @@ fn every_layout_system_round_trips_through_ron() {
     }
 }
 
+#[test]
+fn native_scratchpad_membership_round_trips_through_ron() {
+    let settings = VirtualWorkspaceSettings {
+        default_workspace_count: 2,
+        workspace_names: vec!["1".into(), "__scratchpad".into()],
+        ..VirtualWorkspaceSettings::default()
+    };
+    let mut engine = LayoutEngine::new(&settings, &LayoutSettings::default(), None);
+    let mut window_store = WindowStore::default();
+    let space = SpaceId::new(414);
+    let window = WindowId::new(414, 1);
+    let _ = engine.handle_event(
+        &mut window_store,
+        LayoutEvent::SpaceExposed(space, CGSize::new(1344.0, 756.0)),
+    );
+    let _ = engine.handle_event(&mut window_store, LayoutEvent::WindowAdded(space, window));
+    engine.floating.add_floating(window);
+    engine.scratchpad.add(window);
+    engine.scratchpad.shown = Some(window);
+    engine.persistence.windows.insert(window, WindowFingerprint {
+        window_server_id: Some(4141),
+        title: Some("persistent scratchpad".into()),
+        width: 500.0,
+        height: 300.0,
+        app_id: Some("com.example.scratchpad".into()),
+    });
+
+    let loaded = LayoutEngine::deserialize_from_str(&engine.serialize_to_string()).unwrap();
+
+    assert!(loaded.scratchpad.contains(window));
+    assert_eq!(loaded.scratchpad.shown, Some(window));
+}
+
 #[test]
 fn legacy_internally_tagged_layout_systems_are_migrated() {
     let settings = LayoutSettings::default();
diff --git a/src/layout_engine/systems.rs b/src/layout_engine/systems.rs
index 205a226..d33bb34 100644
--- a/src/layout_engine/systems.rs
+++ b/src/layout_engine/systems.rs
@@ -126,6 +126,15 @@ pub trait LayoutSystem: Serialize + for<'de> Deserialize<'de> {
     ) -> (Option<WindowId>, Vec<WindowId>);
     fn window_in_direction(&self, layout: LayoutId, direction: Direction) -> Option<WindowId>;
     fn add_window_after_selection(&mut self, layout: LayoutId, wid: WindowId);
+    fn add_window_after_selection_with_anchor_frame(
+        &mut self,
+        layout: LayoutId,
+        wid: WindowId,
+        _anchor_frame: Option<CGRect>,
+    ) {
+        self.add_window_after_selection(layout, wid);
+    }
+    fn uses_focused_leaf_autotiling(&self) -> bool { false }
     /// Replace a window identity in-place without changing its layout position.
     fn replace_window(&mut self, from: WindowId, to: WindowId);
     fn remove_window(&mut self, wid: WindowId);
diff --git a/src/layout_engine/systems/traditional.rs b/src/layout_engine/systems/traditional.rs
index 8499710..7a44e8d 100644
--- a/src/layout_engine/systems/traditional.rs
+++ b/src/layout_engine/systems/traditional.rs
@@ -21,6 +21,8 @@ pub struct TraditionalLayoutSystem {
     window_insertion_point: WindowInsertionPoint,
     #[serde(skip, default)]
     equalize_nodes: bool,
+    #[serde(skip, default)]
+    autotile_focused_leaf: bool,
 }
 
 impl Default for TraditionalLayoutSystem {
@@ -30,6 +32,7 @@ impl Default for TraditionalLayoutSystem {
             layout_roots: Default::default(),
             window_insertion_point: WindowInsertionPoint::default(),
             equalize_nodes: true,
+            autotile_focused_leaf: false,
         }
     }
 }
@@ -41,6 +44,7 @@ impl TraditionalLayoutSystem {
             layout_roots: Default::default(),
             window_insertion_point,
             equalize_nodes,
+            autotile_focused_leaf: false,
         }
     }
 
@@ -50,6 +54,69 @@ impl TraditionalLayoutSystem {
 
     pub fn set_equalize_nodes(&mut self, value: bool) { self.equalize_nodes = value; }
 
+    pub fn set_autotile_focused_leaf(&mut self, value: bool) {
+        self.autotile_focused_leaf = value;
+    }
+
+    /// Replace the focused leaf with a two-child container while preserving the leaf's
+    /// complete outer share. This changes only the focused frame and the new window frame;
+    /// every unrelated sibling keeps its existing weight.
+    fn insert_focused_leaf_pair(
+        &mut self,
+        layout: LayoutId,
+        selection: NodeId,
+        wid: WindowId,
+        kind: LayoutKind,
+    ) -> Option<NodeId> {
+        self.window_at(selection)?;
+        let parent = selection.parent(self.map())?;
+        if self.layout(parent).is_group()
+            || self.tree.data.layout.is_effectively_fullscreen(selection)
+            || selection
+                .ancestors(self.map())
+                .any(|node| self.tree.data.layout.is_effectively_fullscreen(node))
+        {
+            return None;
+        }
+
+        let siblings: Vec<_> = parent.children(self.map()).collect();
+        if siblings.len() == 1 {
+            self.set_layout(parent, kind);
+            let node = self.add_window_under(layout, parent, wid);
+            self.tree.data.layout.info[selection].size = 1.0;
+            self.tree.data.layout.info[node].size = 1.0;
+            self.tree.data.layout.info[parent].total = 2.0;
+            return Some(node);
+        }
+
+        let parent_total = self.tree.data.layout.info[parent].total;
+        let selected_size = self.tree.data.layout.info[selection].size;
+        let sibling_sizes: Vec<_> = siblings
+            .iter()
+            .filter(|&&node| node != selection)
+            .map(|&node| (node, self.tree.data.layout.info[node].size))
+            .collect();
+
+        let container = self.tree.mk_node().insert_before(selection);
+        self.tree
+            .data
+            .layout
+            .assume_size_of(container, selection, &self.tree.map);
+        selection.detach(&mut self.tree).push_back(container);
+        let node = self.add_window_under(layout, container, wid);
+
+        self.set_layout(container, kind);
+        self.tree.data.layout.info[container].size = selected_size;
+        self.tree.data.layout.info[selection].size = 1.0;
+        self.tree.data.layout.info[node].size = 1.0;
+        self.tree.data.layout.info[container].total = 2.0;
+        self.tree.data.layout.info[parent].total = parent_total;
+        for (sibling, size) in sibling_sizes {
+            self.tree.data.layout.info[sibling].size = size;
+        }
+        Some(node)
+    }
+
     fn find_best_focus_target(&self, node: NodeId) -> Option<(NodeId, WindowId)> {
         if let Some(wid) = self.tree.data.window.at(node) {
             return Some((node, wid));
@@ -623,6 +690,32 @@ impl LayoutSystem for TraditionalLayoutSystem {
         self.select(node);
     }
 
+    fn add_window_after_selection_with_anchor_frame(
+        &mut self,
+        layout: LayoutId,
+        wid: WindowId,
+        anchor_frame: Option<CGRect>,
+    ) {
+        if self.autotile_focused_leaf
+            && self.window_insertion_point == WindowInsertionPoint::NextToSelection
+            && let Some(frame) = anchor_frame
+        {
+            let kind = if frame.size.width >= frame.size.height {
+                LayoutKind::Horizontal
+            } else {
+                LayoutKind::Vertical
+            };
+            let selection = self.selection(layout);
+            if let Some(node) = self.insert_focused_leaf_pair(layout, selection, wid, kind) {
+                self.select(node);
+                return;
+            }
+        }
+        self.add_window_after_selection(layout, wid);
+    }
+
+    fn uses_focused_leaf_autotiling(&self) -> bool { self.autotile_focused_leaf }
+
     fn replace_window(&mut self, from: WindowId, to: WindowId) {
         self.tree.data.window.replace_window(from, to);
     }
@@ -5540,4 +5633,188 @@ mod tests {
             .expect("right node proportion missing");
         assert_eq!(before, after);
     }
+
+    #[test]
+    fn native_autotile_splits_only_focused_leaf_through_ten_windows() {
+        let mut system = TraditionalLayoutSystem::default();
+        system.set_autotile_focused_leaf(true);
+        let layout = system.create_layout();
+        let screen = CGRect::new(CGPoint::new(0.0, 0.0), CGSize::new(1344.0, 756.0));
+        let gaps = crate::common::config::GapSettings {
+            outer: crate::common::config::OuterGaps {
+                top: 38.0,
+                left: 4.0,
+                bottom: 4.0,
+                right: 4.0,
+            },
+            inner: crate::common::config::InnerGaps {
+                horizontal: 8.0,
+                vertical: 8.0,
+            },
+            ..Default::default()
+        };
+        let calculate = |system: &TraditionalLayoutSystem| -> HashMap<WindowId, CGRect> {
+            system
+                .calculate_layout(
+                    layout,
+                    screen,
+                    0.0,
+                    &Default::default(),
+                    &gaps,
+                    0.0,
+                    Default::default(),
+                    Default::default(),
+                )
+                .into_iter()
+                .collect()
+        };
+        let frame_delta = |a: CGRect, b: CGRect| {
+            (a.origin.x - b.origin.x).abs()
+                + (a.origin.y - b.origin.y).abs()
+                + (a.size.width - b.size.width).abs()
+                + (a.size.height - b.size.height).abs()
+        };
+
+        system.add_window_after_selection_with_anchor_frame(layout, w(201), None);
+        for index in 202..=210 {
+            let selected = system.selected_window(layout).expect("selected window missing");
+            let before = calculate(&system);
+            let anchor = before[&selected];
+            let new_window = w(index);
+
+            system.add_window_after_selection_with_anchor_frame(
+                layout,
+                new_window,
+                Some(anchor),
+            );
+            let after = calculate(&system);
+
+            for (&window, &frame) in &before {
+                if window != selected {
+                    assert!(
+                        frame_delta(frame, after[&window]) <= 4.0,
+                        "inserting {new_window:?} changed unrelated {window:?}: {frame:?} -> {:?}",
+                        after[&window]
+                    );
+                }
+            }
+
+            let selected_frame = after[&selected];
+            let new_frame = after[&new_window];
+            let min_x = selected_frame.origin.x.min(new_frame.origin.x);
+            let min_y = selected_frame.origin.y.min(new_frame.origin.y);
+            let max_x = (selected_frame.origin.x + selected_frame.size.width)
+                .max(new_frame.origin.x + new_frame.size.width);
+            let max_y = (selected_frame.origin.y + selected_frame.size.height)
+                .max(new_frame.origin.y + new_frame.size.height);
+            assert!((min_x - anchor.origin.x).abs() <= 1.0);
+            assert!((min_y - anchor.origin.y).abs() <= 1.0);
+            assert!((max_x - (anchor.origin.x + anchor.size.width)).abs() <= 1.0);
+            assert!((max_y - (anchor.origin.y + anchor.size.height)).abs() <= 1.0);
+            if anchor.size.width >= anchor.size.height {
+                assert!((selected_frame.size.width - new_frame.size.width).abs() <= 1.0);
+            } else {
+                assert!((selected_frame.size.height - new_frame.size.height).abs() <= 1.0);
+            }
+        }
+    }
+
+    #[test]
+    fn native_autotile_preserves_manual_ancestor_ratios_exactly() {
+        let mut system = TraditionalLayoutSystem::default();
+        let layout = system.create_layout();
+        let first = w(221);
+        let selected = w(222);
+        let last = w(223);
+        let inserted = w(224);
+        for window in [first, selected, last] {
+            system.add_window_after_selection(layout, window);
+        }
+        let root = system.root(layout);
+        let first_node = system.tree.data.window.node_for(layout, first).unwrap();
+        let selected_node = system.tree.data.window.node_for(layout, selected).unwrap();
+        let last_node = system.tree.data.window.node_for(layout, last).unwrap();
+        system.tree.data.layout.info[first_node].size = 3.0;
+        system.tree.data.layout.info[selected_node].size = 1.0;
+        system.tree.data.layout.info[last_node].size = 2.0;
+        system.tree.data.layout.info[root].total = 6.0;
+        assert!(system.select_window(layout, selected));
+        system.set_autotile_focused_leaf(true);
+
+        system.add_window_after_selection_with_anchor_frame(
+            layout,
+            inserted,
+            Some(CGRect::new(
+                CGPoint::new(0.0, 0.0),
+                CGSize::new(300.0, 500.0),
+            )),
+        );
+
+        let inserted_node = system.tree.data.window.node_for(layout, inserted).unwrap();
+        let pair = selected_node.parent(system.map()).unwrap();
+        assert_eq!(inserted_node.parent(system.map()), Some(pair));
+        assert_eq!(pair.parent(system.map()), Some(root));
+        assert_eq!(system.tree.data.layout.info[first_node].size, 3.0);
+        assert_eq!(system.tree.data.layout.info[pair].size, 1.0);
+        assert_eq!(system.tree.data.layout.info[last_node].size, 2.0);
+        assert_eq!(system.tree.data.layout.info[root].total, 6.0);
+        assert_eq!(system.tree.data.layout.info[selected_node].size, 1.0);
+        assert_eq!(system.tree.data.layout.info[inserted_node].size, 1.0);
+        assert_eq!(system.tree.data.layout.info[pair].total, 2.0);
+        assert_eq!(system.layout(pair), LayoutKind::Vertical);
+    }
+
+    #[test]
+    fn native_autotile_keeps_equal_weights_when_constraints_change_physical_frames() {
+        let mut system = TraditionalLayoutSystem::default();
+        system.set_autotile_focused_leaf(true);
+        let layout = system.create_layout();
+        let constrained = w(231);
+        let normal = w(232);
+        system.add_window_after_selection_with_anchor_frame(layout, constrained, None);
+        system.add_window_after_selection_with_anchor_frame(
+            layout,
+            normal,
+            Some(CGRect::new(
+                CGPoint::new(0.0, 0.0),
+                CGSize::new(1344.0, 756.0),
+            )),
+        );
+        let constrained_node = system.tree.data.window.node_for(layout, constrained).unwrap();
+        let normal_node = system.tree.data.window.node_for(layout, normal).unwrap();
+        assert_eq!(system.tree.data.layout.info[constrained_node].size, 1.0);
+        assert_eq!(system.tree.data.layout.info[normal_node].size, 1.0);
+
+        let mut constraints = HashMap::default();
+        constraints.insert(
+            constrained,
+            WindowLayoutConstraints {
+                is_resizable: false,
+                locked_width: 900.0,
+                locked_height: 0.0,
+                min_width: 900.0,
+                min_height: 0.0,
+                max_width: 900.0,
+                max_height: 0.0,
+            }
+            .normalized(),
+        );
+        let frames: HashMap<_, _> = system
+            .calculate_layout(
+                layout,
+                CGRect::new(CGPoint::new(0.0, 0.0), CGSize::new(1344.0, 756.0)),
+                0.0,
+                &constraints,
+                &Default::default(),
+                0.0,
+                Default::default(),
+                Default::default(),
+            )
+            .into_iter()
+            .collect();
+        assert!(frames[&constrained].size.width >= 899.0);
+        assert!(frames[&constrained].size.width > frames[&normal].size.width);
+        assert_eq!(system.tree.data.layout.info[constrained_node].size, 1.0);
+        assert_eq!(system.tree.data.layout.info[normal_node].size, 1.0);
+    }
 }
diff --git a/src/model/virtual_workspace.rs b/src/model/virtual_workspace.rs
index 3e8c0ab..dcd174d 100644
--- a/src/model/virtual_workspace.rs
+++ b/src/model/virtual_workspace.rs
@@ -85,12 +85,14 @@ impl VirtualWorkspace {
 
     pub fn create_layout_system(mode: LayoutMode, settings: &LayoutSettings) -> LayoutSystemKind {
         match mode {
-            LayoutMode::Traditional => LayoutSystemKind::Traditional(
-                crate::layout_engine::systems::TraditionalLayoutSystem::new(
+            LayoutMode::Traditional => {
+                let mut system = crate::layout_engine::systems::TraditionalLayoutSystem::new(
                     settings.window_insertion_point_for(mode),
                     settings.traditional.equalize_nodes,
-                ),
-            ),
+                );
+                system.set_autotile_focused_leaf(settings.traditional.autotile_focused_leaf);
+                LayoutSystemKind::Traditional(system)
+            }
             LayoutMode::Bsp => {
                 LayoutSystemKind::Bsp(crate::layout_engine::systems::BspLayoutSystem::new(
                     settings.window_insertion_point_for(mode),
