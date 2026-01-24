# Feature: Phase 5 - Destroy, Relaunch & Refresh

## Summary

Add destroy and relaunch buttons to each shard row, plus a manual refresh button in the header. Clicking destroy shows a confirmation dialog, then removes the shard. Clicking relaunch (play icon ▶) relaunches the agent terminal. Refresh button updates the UI with latest shard data. All operations call existing shards-core handlers.

## User Story

As a developer managing multiple shards
I want to destroy or relaunch shards with button clicks, and refresh the list manually
So that I can manage shard lifecycle and see current state without switching to the CLI

## Problem Statement

After creating shards in the UI (Phase 4), users cannot manage them - they must use CLI commands. Also, shards created via CLI don't appear in the UI until restart. The management loop is incomplete.

## Solution Statement

Add three buttons with distinct purposes and visuals:
1. **Refresh** (header) - TEXT LABEL "Refresh", refreshes list with latest shard data (no icon - text is clearer)
2. **Relaunch** (per-row) - play icon ▶, relaunches agent terminal via `restart_session`
3. **Destroy** (per-row) - × icon with confirmation dialog, removes shard via `destroy_session`

Visual distinction is critical:
- Refresh = text label in header, gray background, updates UI data only
- Relaunch = ▶ icon per-row, starts agent process
- Create = accent color (blue), primary action

## Metadata

| Field            | Value                                             |
| ---------------- | ------------------------------------------------- |
| Type             | ENHANCEMENT                                       |
| Complexity       | MEDIUM                                            |
| Systems Affected | shards-ui (views, actions, state)                 |
| Dependencies     | shards-core (session_ops) - no changes to core    |
| Estimated Tasks  | 6                                                 |

---

## UX Design

### Before State

```
╔═══════════════════════════════════════════════════════════════════════════════╗
║                              SHARD LIST VIEW                                   ║
╠═══════════════════════════════════════════════════════════════════════════════╣
║                                                                               ║
║   ┌─────────────────────────────────────────────────────────────────────┐     ║
║   │ ● feature-auth     claude     my-project                            │     ║
║   │ ● fix-bug          kiro       my-project                            │     ║
║   │ ● refactor-api     claude     my-project                            │     ║
║   └─────────────────────────────────────────────────────────────────────┘     ║
║                                                                               ║
║   USER_FLOW: User sees shards, but cannot interact with them                  ║
║   PAIN_POINT: Must use CLI to destroy or restart shards                       ║
║   DATA_FLOW: Read-only display of session data                                ║
║                                                                               ║
╚═══════════════════════════════════════════════════════════════════════════════╝
```

### After State

```
╔═══════════════════════════════════════════════════════════════════════════════╗
║                              SHARD LIST VIEW                                   ║
╠═══════════════════════════════════════════════════════════════════════════════╣
║                                                                               ║
║   ┌─────────────────────────────────────────────────────────────────────┐     ║
║   │  HEADER:   Shards                       [Refresh]  [+ Create]       │     ║
║   │                                          (gray)     (blue/accent)   │     ║
║   ├─────────────────────────────────────────────────────────────────────┤     ║
║   │ ● feature-auth     claude     my-project           [▶]  [×]         │     ║
║   │ ● fix-bug          kiro       my-project           [▶]  [×]         │     ║
║   │ ● refactor-api     claude     my-project           [▶]  [×]         │     ║
║   └─────────────────────────────────────────────────────────────────────┘     ║
║                                   │                                           ║
║        [Refresh] = reload list    │   [▶] = relaunch agent (play icon)        ║
║        (TEXT label, header)       │   [×] = destroy (with confirm dialog)     ║
║                                   ▼                                           ║
║                          ┌─────────────────────────┐                          ║
║                          │    Destroy Shard?       │  ◄── Confirm dialog      ║
║                          │                         │                          ║
║                          │ Destroy 'feature-auth'? │                          ║
║                          │ This will delete the    │                          ║
║                          │ working directory and   │                          ║
║                          │ stop any running agent. │                          ║
║                          │ This cannot be undone.  │                          ║
║                          │                         │                          ║
║                          │  [Cancel]    [Destroy]  │                          ║
║                          │   (gray)      (red)     │                          ║
║                          └─────────────────────────┘                          ║
║                                                                               ║
║   USER_FLOW:                                                                  ║
║   - [Refresh] = updates list with latest shard data (no process action)       ║
║   - [▶] = relaunches agent terminal in existing worktree                      ║
║   - [×] = destroys shard (confirm first)                                      ║
║                                                                               ║
║   VALUE_ADD: Full shard lifecycle management + live data refresh              ║
║   DATA_FLOW: Button click → action handler → core API → refresh list          ║
║                                                                               ║
╚═══════════════════════════════════════════════════════════════════════════════╝
```

### Interaction Changes

| Location | Before | After | User Impact |
|----------|--------|-------|-------------|
| Header | Title + Create button | + "Refresh" text button (gray) | Can refresh list to see CLI-created shards |
| Header | Create button (gray) | Create button (blue/accent) | Clear primary action |
| Shard row | Status + branch + agent + project | + relaunch [▶] and destroy [×] buttons | Can manage shards |
| Destroy button [×] | N/A | Opens confirmation dialog with clear warning | Prevents accidental deletion |
| Relaunch button [▶] | N/A | Relaunches agent terminal, shows error if fails | Quick relaunch with feedback |

**Visual Hierarchy (CRITICAL)**:
- **Refresh**: TEXT label "Refresh" in header, gray background - secondary action, clearly different from row buttons
- **Create**: Blue/accent background - primary action, stands out
- **Relaunch [▶]**: Per-row, play/triangle icon - starts agent process
- **Destroy [×]**: Per-row, × icon, red-tinted - destructive action

---

## Mandatory Reading

**CRITICAL: Implementation agent MUST read these files before starting any task:**

| Priority | File | Lines | Why Read This |
|----------|------|-------|---------------|
| P0 | `crates/shards-ui/src/views/shard_list.rs` | all | Pattern to MODIFY for row buttons |
| P0 | `crates/shards-ui/src/views/create_dialog.rs` | 25-219 | Dialog pattern to MIRROR for confirm |
| P0 | `crates/shards-ui/src/actions.rs` | all | Action handler pattern to FOLLOW |
| P1 | `crates/shards-ui/src/state.rs` | all | State management pattern |
| P1 | `crates/shards-ui/src/views/main_view.rs` | 46-64 | State update flow after action |
| P2 | `crates/shards-core/src/sessions/handler.rs` | 189-298 | destroy_session implementation |
| P2 | `crates/shards-core/src/sessions/handler.rs` | 300-450 | restart_session implementation |

---

## Patterns to Mirror

**BUTTON_CLICK_HANDLER:**
```rust
// SOURCE: crates/shards-ui/src/views/create_dialog.rs:182-197
div()
    .id("cancel-btn")
    .px_4()
    .py_2()
    .bg(rgb(0x444444))
    .hover(|style| style.bg(rgb(0x555555)))
    .rounded_md()
    .cursor_pointer()
    .on_mouse_up(
        gpui::MouseButton::Left,
        cx.listener(|view, _, _, cx| {
            view.on_dialog_cancel(cx);
        }),
    )
    .child(div().text_color(rgb(0xffffff)).child("Cancel"))
```

**ACTION_HANDLER_PATTERN:**
```rust
// SOURCE: crates/shards-ui/src/actions.rs:10-60
pub fn create_shard(branch: &str, agent: &str) -> Result<Session, String> {
    tracing::info!(
        event = "ui.create_shard.started",
        branch = branch,
        agent = agent
    );

    // Validation
    if branch.trim().is_empty() {
        tracing::warn!(event = "ui.create_dialog.validation_failed", reason = "...");
        return Err("...".to_string());
    }

    // Call shards-core
    match session_ops::create_session(request, &config) {
        Ok(session) => {
            tracing::info!(event = "ui.create_shard.completed", ...);
            Ok(session)
        }
        Err(e) => {
            tracing::error!(event = "ui.create_shard.failed", error = %e);
            Err(e.to_string())
        }
    }
}
```

**STATE_UPDATE_AFTER_ACTION:**
```rust
// SOURCE: crates/shards-ui/src/views/main_view.rs:46-64
pub fn on_dialog_submit(&mut self, cx: &mut Context<Self>) {
    match actions::create_shard(&branch, &agent) {
        Ok(_session) => {
            self.state.show_create_dialog = false;
            self.state.reset_create_form();
            self.state.refresh_sessions();  // <-- Refresh list
        }
        Err(e) => {
            self.state.create_error = Some(e);  // <-- Show error
        }
    }
    cx.notify();  // <-- Trigger re-render
}
```

**DIALOG_OVERLAY_PATTERN:**
```rust
// SOURCE: crates/shards-ui/src/views/create_dialog.rs:25-50
div()
    .absolute()
    .inset_0()
    .bg(gpui::rgba(0x000000aa))  // Semi-transparent overlay
    .flex()
    .justify_center()
    .items_center()
    .child(
        div()
            .w(px(400.0))
            .bg(rgb(0x2d2d2d))
            .rounded_lg()
            .border_1()
            .border_color(rgb(0x444444))
            // ... dialog content
    )
```

**ERROR_DISPLAY_PATTERN:**
```rust
// SOURCE: crates/shards-ui/src/views/create_dialog.rs:158-169
.when_some(create_error, |this, error| {
    this.child(
        div()
            .px_3()
            .py_2()
            .bg(rgb(0x3d1e1e))
            .rounded_md()
            .border_1()
            .border_color(rgb(0x662222))
            .child(div().text_sm().text_color(rgb(0xff6b6b)).child(error))
    )
})
```

---

## Files to Change

| File                                   | Action | Justification                              |
| -------------------------------------- | ------ | ------------------------------------------ |
| `crates/shards-ui/src/state.rs`        | UPDATE | Add confirm dialog state fields            |
| `crates/shards-ui/src/actions.rs`      | UPDATE | Add destroy_shard and relaunch_shard       |
| `crates/shards-ui/src/views/shard_list.rs` | UPDATE | Add row buttons [▶] [×], pass click handlers |
| `crates/shards-ui/src/views/main_view.rs`  | UPDATE | Add refresh button in header, confirm dialog, action methods |
| `crates/shards-ui/src/views/confirm_dialog.rs` | CREATE | Reusable confirmation dialog       |
| `crates/shards-ui/src/views/mod.rs`    | UPDATE | Export confirm_dialog module               |

---

## NOT Building (Scope Limits)

Explicit exclusions to prevent scope creep:

- **New core logic** - Use existing `destroy_session` and `restart_session` only
- **Bulk operations** - No "destroy all" or multi-select
- **Keyboard shortcuts** - Phase 9 handles these
- **Undo functionality** - Destroy is permanent (confirm dialog prevents accidents)
- **Agent selection on relaunch** - Use existing agent (agent override is future)
- **Auto-refresh** - Phase 6 adds polling; this phase adds manual refresh only
- **Row hover effects** - Keep it simple, just buttons

---

## Step-by-Step Tasks

Execute in order. Each task is atomic and independently verifiable.

### Task 1: UPDATE `crates/shards-ui/src/state.rs`

- **ACTION**: Add confirmation dialog state fields AND relaunch error state to AppState
- **IMPLEMENT**:
  ```rust
  // Add to AppState struct

  // Confirm dialog state
  pub show_confirm_dialog: bool,
  pub confirm_target_branch: Option<String>,
  pub confirm_error: Option<String>,

  // Relaunch error state (shown inline per-row or as transient message)
  pub relaunch_error: Option<(String, String)>,  // (branch, error_message)
  ```
- **ALSO**: Add reset methods
  ```rust
  pub fn reset_confirm_dialog(&mut self) {
      self.show_confirm_dialog = false;
      self.confirm_target_branch = None;
      self.confirm_error = None;
  }

  pub fn clear_relaunch_error(&mut self) {
      self.relaunch_error = None;
  }
  ```
- **MIRROR**: Follow the pattern of `show_create_dialog` and `create_error`
- **VALIDATE**: `cargo check -p shards-ui`

### Task 2: UPDATE `crates/shards-ui/src/actions.rs`

- **ACTION**: Add destroy_shard and relaunch_shard action handlers
- **IMPLEMENT**:
  ```rust
  pub fn destroy_shard(branch: &str) -> Result<(), String> {
      tracing::info!(event = "ui.destroy_shard.started", branch = branch);

      match session_ops::destroy_session(branch) {
          Ok(()) => {
              tracing::info!(event = "ui.destroy_shard.completed", branch = branch);
              Ok(())
          }
          Err(e) => {
              tracing::error!(event = "ui.destroy_shard.failed", branch = branch, error = %e);
              Err(e.to_string())
          }
      }
  }

  /// Relaunch agent terminal in existing worktree.
  /// Uses restart_session which kills old process and spawns new terminal.
  pub fn relaunch_shard(branch: &str) -> Result<shards_core::sessions::types::Session, String> {
      tracing::info!(event = "ui.relaunch_shard.started", branch = branch);

      match session_ops::restart_session(branch, None) {
          Ok(session) => {
              tracing::info!(event = "ui.relaunch_shard.completed", branch = branch, process_id = session.process_id);
              Ok(session)
          }
          Err(e) => {
              tracing::error!(event = "ui.relaunch_shard.failed", branch = branch, error = %e);
              Err(e.to_string())
          }
      }
  }
  ```
- **MIRROR**: `crates/shards-ui/src/actions.rs:10-60` (create_shard pattern)
- **VALIDATE**: `cargo check -p shards-ui`

### Task 3: CREATE `crates/shards-ui/src/views/confirm_dialog.rs`

- **ACTION**: Create reusable confirmation dialog component
- **IMPLEMENT**: Dialog with:
  - Semi-transparent overlay (rgba 0x000000aa)
  - Modal box (400px wide, rounded, bordered)
  - Title: "Destroy Shard?"
  - Message (CLEAR, NO JARGON):
    ```
    Destroy '{branch}'?

    This will delete the working directory and stop any running agent.
    This cannot be undone.
    ```
  - Error display area (if confirm_error is Some)
  - Two buttons: "Cancel" (gray) and "Destroy" (red/danger) - NOT "Yes"
- **FUNCTION SIGNATURE**:
  ```rust
  pub fn render_confirm_dialog(state: &AppState, cx: &mut Context<MainView>) -> impl IntoElement
  ```
- **MIRROR**: `crates/shards-ui/src/views/create_dialog.rs:25-219`
- **COLORS**:
  - Danger button: `bg(rgb(0xcc4444))`, hover `bg(rgb(0xdd5555))`, text "Destroy"
  - Cancel button: `bg(rgb(0x444444))`, hover `bg(rgb(0x555555))`, text "Cancel"
- **VALIDATE**: `cargo check -p shards-ui`

### Task 4: UPDATE `crates/shards-ui/src/views/mod.rs`

- **ACTION**: Export the new confirm_dialog module
- **IMPLEMENT**: Add `pub mod confirm_dialog;`
- **VALIDATE**: `cargo check -p shards-ui`

### Task 5: UPDATE `crates/shards-ui/src/views/shard_list.rs`

- **ACTION**: Add relaunch [▶] and destroy [×] buttons to each shard row, plus error display
- **IMPLEMENT**:
  - Change function signature to accept `cx: &mut Context<MainView>` (mutable)
  - Inside uniform_list closure, add two buttons at the end of each row:
    - Relaunch button [▶]: calls `view.on_relaunch_click(branch, cx)` - **PLAY ICON**
    - Destroy button [×]: calls `view.on_destroy_click(branch, cx)`
  - Button styling:
    - Small buttons: `px_2().py_1()`
    - Relaunch [▶]: `bg(rgb(0x444444))`, hover `bg(rgb(0x555555))`, text "▶" (play triangle)
    - Destroy [×]: `bg(rgb(0x662222))`, hover `bg(rgb(0x883333))`, text "×"
  - **ERROR DISPLAY**: If `state.relaunch_error` matches this row's branch, show error text below the row:
    ```rust
    .when(state.relaunch_error.as_ref().map(|(b, _)| b == &display.session.branch).unwrap_or(false), |this| {
        this.child(
            div()
                .text_sm()
                .text_color(rgb(0xff6b6b))
                .child(state.relaunch_error.as_ref().map(|(_, e)| e.clone()).unwrap_or_default())
        )
    })
    ```
  - **VISUAL DISTINCTION**: Play icon ▶ is clearly different from "Refresh" text label
- **CHALLENGE**: uniform_list closure needs to capture branch and dispatch to view methods
- **PATTERN**: Use `cx.listener()` with captured branch:
  ```rust
  let branch_for_relaunch = display.session.branch.clone();
  .on_mouse_up(gpui::MouseButton::Left, cx.listener(move |view, _, _, cx| {
      view.on_relaunch_click(&branch_for_relaunch, cx);
  }))
  ```
- **MIRROR**: Button patterns from create_dialog.rs:182-197
- **VALIDATE**: `cargo check -p shards-ui`

### Task 6: UPDATE `crates/shards-ui/src/views/main_view.rs`

- **ACTION**: Add refresh button in header, confirm dialog rendering, and action handler methods
- **IMPLEMENT**:
  1. Add imports for confirm_dialog
  2. **Add Refresh button (TEXT LABEL) in header** - gray, secondary:
     ```rust
     // Refresh button - TEXT label, gray background (secondary action)
     div()
         .id("refresh-btn")
         .px_3()
         .py_1()
         .bg(rgb(0x444444))
         .hover(|style| style.bg(rgb(0x555555)))
         .rounded_md()
         .cursor_pointer()
         .on_mouse_up(gpui::MouseButton::Left, cx.listener(|view, _, _, cx| {
             view.on_refresh_click(cx);
         }))
         .child(div().text_color(rgb(0xffffff)).child("Refresh"))  // TEXT label, not icon
     ```
  3. **Update Create button to blue/accent** (primary action):
     ```rust
     // Create button - blue/accent background (primary action)
     div()
         .id("create-btn")
         .px_3()
         .py_1()
         .bg(rgb(0x4a9eff))  // Blue accent - primary action
         .hover(|style| style.bg(rgb(0x5aafff)))
         .rounded_md()
         .cursor_pointer()
         // ... existing click handler
         .child(div().text_color(rgb(0xffffff)).child("+ Create"))
     ```
  4. Add method `on_refresh_click(&mut self, cx: &mut Context<Self>)`:
     - Clear any transient errors: `state.clear_relaunch_error()`
     - Call `state.refresh_sessions()`
     - Call `cx.notify()`
     - Log: `tracing::info!(event = "ui.refresh_clicked")`
  5. Add method `on_destroy_click(&mut self, branch: &str, cx: &mut Context<Self>)`:
     - Set `state.confirm_target_branch = Some(branch.to_string())`
     - Set `state.show_confirm_dialog = true`
     - Call `cx.notify()`
  6. Add method `on_confirm_destroy(&mut self, cx: &mut Context<Self>)`:
     - Get branch from `state.confirm_target_branch`
     - Call `actions::destroy_shard(branch)`
     - On success: `state.reset_confirm_dialog()`, `state.refresh_sessions()`
     - On error: `state.confirm_error = Some(e)`
     - Call `cx.notify()`
  7. Add method `on_confirm_cancel(&mut self, cx: &mut Context<Self>)`:
     - Call `state.reset_confirm_dialog()`
     - Call `cx.notify()`
  8. Add method `on_relaunch_click(&mut self, branch: &str, cx: &mut Context<Self>)`:
     - Clear previous error: `state.clear_relaunch_error()`
     - Call `actions::relaunch_shard(branch)`
     - On success: `state.refresh_sessions()`
     - **On error: SET STATE** `state.relaunch_error = Some((branch.to_string(), e))` - NO SILENT FAILURES
     - Call `cx.notify()`
  9. In `render()`, add confirm dialog after create dialog:
     ```rust
     .when(self.state.show_confirm_dialog, |this| {
         this.child(confirm_dialog::render_confirm_dialog(&self.state, cx))
     })
     ```
- **VISUAL HIERARCHY**:
  - Header "Refresh" = TEXT label, gray background (secondary)
  - Header "+ Create" = TEXT label, blue/accent background (primary)
  - Row [▶] = play icon (action on this shard)
  - Row [×] = red-tinted destroy (destructive)
- **MIRROR**: `on_dialog_submit` and `on_dialog_cancel` patterns from main_view.rs:46-84
- **VALIDATE**: `cargo check -p shards-ui && cargo clippy -p shards-ui -- -D warnings`

---

## Testing Strategy

### Manual Tests to Perform

| Test Case | Steps | Expected Result |
|-----------|-------|-----------------|
| Refresh list | Create shard via CLI, click header "Refresh" | New shard appears in UI list |
| Destroy shard | Click row [×], see warning, click "Destroy" | Shard removed from list, verified with `shards list` |
| Cancel destroy | Click row [×], click "Cancel" | Dialog closes, shard still exists |
| Relaunch running shard | Create shard, click row [▶] | Terminal reopens, status stays Running |
| Relaunch stopped shard | Create shard, close terminal, click row [▶] | Terminal reopens, status becomes Running |
| Relaunch error | Delete worktree manually, click row [▶] | **Error shown inline below row** (not silent!) |
| Destroy non-existent | Delete session file externally, click [×] | Error displayed in confirmation dialog |
| Visual hierarchy | Look at header buttons | "Refresh" is gray (secondary), "+ Create" is blue (primary) |
| Confirm dialog copy | Click [×] and read | Says "delete working directory", "cannot be undone" - no jargon |

### Edge Cases Checklist

- [ ] Destroy shard that was already destroyed externally → error in dialog
- [ ] Relaunch shard whose worktree was deleted → **error shown inline** (not silent)
- [ ] Click destroy while confirm dialog already open → should be prevented or handled
- [ ] Click relaunch while create dialog is open (should work)
- [ ] Click refresh while dialogs are open (should work, clears relaunch errors)
- [ ] Multiple rapid clicks on buttons → no double-action
- [ ] Refresh when no shards exist (empty state) → shows "No active shards"
- [ ] Relaunch error then click Refresh → error cleared

---

## Validation Commands

### Level 1: STATIC_ANALYSIS

```bash
cargo fmt --check && cargo clippy -p shards-ui -- -D warnings
```

**EXPECT**: Exit 0, no errors or warnings

### Level 2: TYPE_CHECK

```bash
cargo check -p shards-ui
```

**EXPECT**: Exit 0, no errors

### Level 3: FULL_BUILD

```bash
cargo build -p shards-ui
```

**EXPECT**: Exit 0, binary builds successfully

### Level 4: MANUAL_VALIDATION

```bash
# Start the UI
cargo run -p shards-ui

# TEST 1: Visual hierarchy in header
# Verify: "Refresh" button is gray (secondary action)
# Verify: "+ Create" button is blue (primary action)
# Verify: These look distinctly different

# TEST 2: Refresh button
# Create a shard via CLI (not UI)
cargo run -- create test-cli-shard --agent claude

# In UI:
# 1. Verify test-cli-shard is NOT in list initially
# 2. Click header "Refresh" button (TEXT label, not icon)
# 3. Verify test-cli-shard NOW appears in list

# TEST 3: Destroy with confirmation
# In UI:
# 1. Verify [▶] (play) and [×] buttons appear on test-cli-shard row
# 2. Click row [×] → verify confirm dialog appears
# 3. READ THE DIALOG: Should say "delete working directory", "cannot be undone"
# 4. Verify buttons say "Cancel" and "Destroy" (NOT "Yes")
# 5. Click Cancel → verify dialog closes, shard still exists
# 6. Click row [×] again → click "Destroy" → verify shard disappears
# 7. shards list → verify test-cli-shard is gone

# TEST 4: Relaunch success
# Create another test shard
cargo run -- create test-relaunch --agent claude

# In UI:
# 1. Close the terminal window manually
# 2. Click "Refresh" → status should show Stopped
# 3. Click row [▶] (play icon) → verify terminal reopens
# 4. Click "Refresh" → status should show Running

# TEST 5: Relaunch error (NO SILENT FAILURES)
# Delete the worktree manually:
rm -rf ~/.shards/worktrees/<project>/test-relaunch

# In UI:
# 1. Click row [▶] on test-relaunch
# 2. VERIFY: Error message appears INLINE below the row
# 3. Error should NOT be silent - user must see feedback
# 4. Click "Refresh" → error message should clear
```

---

## Acceptance Criteria

- [ ] **Refresh button** appears in header as TEXT label "Refresh" (gray background)
- [ ] **Create button** appears in header with blue/accent background (primary action)
- [ ] Clicking "Refresh" refreshes list with latest shard data
- [ ] CLI-created shards appear after clicking refresh
- [ ] **Relaunch button [▶]** appears on each shard row (play triangle icon)
- [ ] **Destroy button [×]** appears on each shard row (red-tinted)
- [ ] Clicking row [×] opens confirmation dialog
- [ ] Confirmation dialog shows clear warning: "delete working directory", "cannot be undone"
- [ ] Dialog has "Cancel" and "Destroy" buttons (not "Yes")
- [ ] Cancel button closes dialog without destroying
- [ ] Destroy button in dialog destroys shard and closes dialog
- [ ] Shard disappears from list after destroy
- [ ] Clicking row [▶] relaunches the shard (terminal reopens)
- [ ] **Relaunch errors shown inline** below the row (NO SILENT FAILURES)
- [ ] Status updates after relaunch
- [ ] Clicking Refresh clears any relaunch error messages
- [ ] **Visual hierarchy is clear**: Refresh (gray) vs Create (blue) vs row buttons
- [ ] All validation commands pass

---

## Completion Checklist

- [ ] Task 1: State fields added (confirm dialog + relaunch_error)
- [ ] Task 2: Action handlers added (destroy_shard, relaunch_shard)
- [ ] Task 3: Confirm dialog created with clear copy (no jargon)
- [ ] Task 4: Module exported
- [ ] Task 5: Row buttons added ([▶] relaunch, [×] destroy) + inline error display
- [ ] Task 6: Main view updated with:
  - [ ] "Refresh" TEXT button (gray)
  - [ ] "+ Create" button (blue/accent)
  - [ ] Confirm dialog rendering
  - [ ] All action handlers including relaunch error handling
- [ ] Level 1: Static analysis passes
- [ ] Level 2: Type check passes
- [ ] Level 3: Build succeeds
- [ ] Level 4: Manual validation passes (all 5 tests)
- [ ] All acceptance criteria met
- [ ] Visual hierarchy verified: Refresh (gray text) vs Create (blue) vs row [▶] [×]
- [ ] No silent failures: relaunch errors shown inline

---

## Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| User confuses Refresh and Relaunch buttons | LOW | HIGH | Refresh is TEXT "Refresh" in header; Relaunch is ▶ icon per-row |
| uniform_list closure complexity with click handlers | MEDIUM | MEDIUM | Follow existing create_dialog button pattern with cx.listener() |
| Race condition if clicking buttons rapidly | LOW | LOW | Buttons are disabled while dialog is open; refresh after action |
| Destroy fails but dialog closes | LOW | MEDIUM | Only close dialog on success; show error in dialog on failure |
| Relaunch fails silently | LOW | HIGH | Show error inline below row - NO SILENT FAILURES per CLAUDE.md |
| User doesn't understand confirm dialog | LOW | MEDIUM | Clear copy: "delete working directory", "cannot be undone", no jargon |

---

## Notes

- **No new core logic** - Uses existing `destroy_session` and `restart_session` from shards-core.
- **No agent override on relaunch** - Uses existing session agent. Agent selection dropdown could be added later.
- **Relaunch errors shown inline** - Per CLAUDE.md "No Silent Failures" principle, errors are displayed below the row.
- **Confirmation only for destroy** - Relaunch is non-destructive (can be done repeatedly), so no confirmation needed.
- **Button order** - Relaunch [▶] before Destroy [×] to make destroy harder to hit accidentally.
- **Visual hierarchy**:
  - Header "Refresh" button: TEXT label, gray background - secondary action, clearly means "reload list data"
  - Header "+ Create" button: TEXT label, blue/accent background - primary action, stands out
  - Row relaunch button: "▶" (Unicode U+25B6, play triangle) - means "start/run this shard"
  - Row destroy button: "×" red-tinted - destructive action
- **Confirmation dialog copy** - Uses plain language: "delete working directory", "cannot be undone". Avoids jargon like "worktree".
- **Phase 6 will add auto-refresh** - This phase only adds manual refresh. Phase 6 adds 5-second polling.
- **Loading states not implemented** - Acceptable for MVP. Could add button disabling during operations later.
