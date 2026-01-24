# Feature: Phase 4 - Create Shard UI

## Summary

Add a "Create Shard" button to the shards-ui dashboard that opens a dialog for creating new shards. The dialog collects branch name and agent selection, then calls the existing `shards-core` create API. Upon success, the shard list refreshes and an external terminal window opens with the agent running in the new worktree.

## User Story

As a developer using the Shards dashboard
I want to create new shards via a button and dialog
So that I can spawn AI agent worktrees without switching to the CLI

## Problem Statement

Currently the shards-ui can only display existing shards (Phase 3). Users must switch to CLI to create new shards. This breaks the visual workflow and requires remembering command syntax.

## Solution Statement

Add a [+] Create button in the header that opens a modal dialog with:
1. Branch name text input (required)
2. Agent dropdown (claude, kiro, gemini, codex, aether)
3. Create/Cancel buttons

On submit, call `session_ops::create_session()` which handles worktree creation and external terminal launch. Refresh the shard list to show the new entry.

## Metadata

| Field            | Value                                    |
| ---------------- | ---------------------------------------- |
| Type             | NEW_CAPABILITY                           |
| Complexity       | MEDIUM                                   |
| Systems Affected | shards-ui                                |
| Dependencies     | shards-core (existing), gpui 0.2         |
| Estimated Tasks  | 6                                        |

---

## UX Design

### Before State

```
╔═══════════════════════════════════════════════════════════════════════════════╗
║                              SHARDS DASHBOARD (Phase 3)                        ║
╠═══════════════════════════════════════════════════════════════════════════════╣
║                                                                               ║
║   ┌───────────────────────────────────────────────────────────────────────┐   ║
║   │  Shards                                                               │   ║
║   └───────────────────────────────────────────────────────────────────────┘   ║
║                                                                               ║
║   ┌───────────────────────────────────────────────────────────────────────┐   ║
║   │ ● test-branch-1              claude           my-project              │   ║
║   │ ● test-branch-2              kiro             my-project              │   ║
║   └───────────────────────────────────────────────────────────────────────┘   ║
║                                                                               ║
║   USER_FLOW: View shards only. Must use CLI to create new ones.               ║
║   PAIN_POINT: Context switching to CLI, remembering command syntax.           ║
║                                                                               ║
╚═══════════════════════════════════════════════════════════════════════════════╝
```

### After State

```
╔═══════════════════════════════════════════════════════════════════════════════╗
║                              SHARDS DASHBOARD (Phase 4)                        ║
╠═══════════════════════════════════════════════════════════════════════════════╣
║                                                                               ║
║   ┌───────────────────────────────────────────────────────────────────────┐   ║
║   │  Shards                                               [+ Create]      │   ║
║   └───────────────────────────────────────────────────────────────────────┘   ║
║                                                           │                   ║
║                                          [Click] ────────┘                    ║
║                                                           ▼                   ║
║   ┌─────────────────────────────────────────────────────────────┐             ║
║   │                    Create New Shard                         │             ║
║   │  ─────────────────────────────────────────────────────────  │             ║
║   │                                                             │             ║
║   │  Branch Name:  [________________________]  (required)       │             ║
║   │                                                             │             ║
║   │  Agent:        [claude           ▼]                         │             ║
║   │                                                             │             ║
║   │                           [Cancel]  [Create]                │             ║
║   └─────────────────────────────────────────────────────────────┘             ║
║                                          │                                    ║
║                               [Create] ──┘                                    ║
║                                          ▼                                    ║
║   ┌───────────────────────────────────────────────────────────────────────┐   ║
║   │ ● test-branch-1              claude           my-project              │   ║
║   │ ● test-branch-2              kiro             my-project              │   ║
║   │ ● new-feature  ◄── NEW       claude           my-project              │   ║
║   └───────────────────────────────────────────────────────────────────────┘   ║
║                                                                               ║
║   + External terminal window opens with agent running in worktree             ║
║                                                                               ║
║   USER_FLOW: Click [+ Create] → Fill form → Click Create → Done               ║
║   VALUE_ADD: No CLI needed. Visual feedback. Immediate list update.           ║
║                                                                               ║
╚═══════════════════════════════════════════════════════════════════════════════╝
```

### Interaction Changes

| Location | Before | After | User Impact |
|----------|--------|-------|-------------|
| Header | Title only | Title + Create button | Can initiate creation |
| Dialog | N/A | Modal with form | Visual input for branch/agent |
| List | Static | Refreshes after create | Sees new shard immediately |
| Terminal | N/A | External window opens | Agent starts automatically |

---

## Crate Architecture

### File Structure for shards-ui

```
crates/shards-ui/src/
├── main.rs           # Entry point, Application setup (UPDATE)
├── state.rs          # AppState with displays, dialog state (CREATE)
├── views/
│   ├── mod.rs        # View module declarations (CREATE)
│   ├── main_view.rs  # Root view with header + list + dialog (CREATE)
│   ├── shard_list.rs # Shard list component (CREATE - extract from main.rs)
│   └── create_dialog.rs # Create shard modal dialog (CREATE)
└── actions.rs        # Event handlers for create, refresh (CREATE)
```

### Rationale for Split

1. **state.rs** - Centralized state makes refresh logic cleaner. Dialog visibility, form data, and shard list all in one place.

2. **views/main_view.rs** - Root view that composes header, list, and dialog. Owns the `AppState`.

3. **views/shard_list.rs** - Extract the existing list rendering from main.rs. Pure display component.

4. **views/create_dialog.rs** - Modal dialog component. Conditional rendering based on state.

5. **actions.rs** - Business logic handlers that call shards-core and update state.

### Data Flow

```
User clicks [+ Create]
    │
    ▼
main_view.rs: on_mouse_up handler
    │
    ├── Sets state.show_create_dialog = true
    └── cx.notify() triggers re-render
    │
    ▼
create_dialog.rs: renders modal
    │
User fills form, clicks [Create]
    │
    ▼
create_dialog.rs: on_mouse_up handler
    │
    ├── Validates branch name
    ├── Calls actions::create_shard()
    │       │
    │       ├── ShardsConfig::load_hierarchy()
    │       ├── CreateSessionRequest::new(branch, agent)
    │       └── session_ops::create_session(request, &config)
    │               │
    │               ├── Creates git worktree
    │               ├── Launches external terminal
    │               └── Returns Session
    │
    ├── On success: state.show_create_dialog = false
    ├── Calls actions::refresh_shard_list()
    └── cx.notify() triggers re-render
    │
    ▼
shard_list.rs: shows updated list with new shard
```

---

## Mandatory Reading

**CRITICAL: Implementation agent MUST read these files before starting any task:**

| Priority | File | Lines | Why Read This |
|----------|------|-------|---------------|
| P0 | `crates/shards-ui/src/main.rs` | all | Current implementation to refactor |
| P0 | `crates/shards-core/src/sessions/handler.rs` | 10-150 | create_session API and error handling |
| P0 | `crates/shards-core/src/sessions/types.rs` | 103-121 | CreateSessionRequest structure |
| P1 | `crates/shards-core/src/agents/registry.rs` | 48-94 | valid_agent_names(), is_valid_agent() |
| P1 | `crates/shards-core/src/config/mod.rs` | 49-73 | ShardsConfig::load_hierarchy() |
| P2 | `crates/shards/src/commands.rs` | 46-110 | CLI create command pattern |

**External Documentation:**

| Source | Section | Why Needed |
|--------|---------|------------|
| [GPUI v0.2 GitHub](https://github.com/zed-industries/zed/tree/main/crates/gpui) | README | GPUI basics |
| [GPUI Interactivity Tutorial](https://blog.0xshadow.dev/posts/learning-gpui/gpui-interactivity/) | on_mouse_up | Click handling pattern |

---

## Patterns to Mirror

**STATE_MANAGEMENT:**
```rust
// SOURCE: crates/shards-ui/src/main.rs:65-98
// COPY THIS PATTERN for loading sessions:
struct ShardListView {
    displays: Vec<ShardDisplay>,
    load_error: Option<String>,
}

impl ShardListView {
    fn new() -> Self {
        let (sessions, load_error) = match session_ops::list_sessions() {
            Ok(s) => (s, None),
            Err(e) => {
                tracing::error!(event = "ui.shard_list.load_failed", error = %e);
                (Vec::new(), Some(e.to_string()))
            }
        };
        // ...
    }
}
```

**RENDER_PATTERN:**
```rust
// SOURCE: crates/shards-ui/src/main.rs:100-196
// COPY THIS PATTERN for conditional rendering:
impl Render for ShardListView {
    fn render(&mut self, _window: &mut Window, _cx: &mut Context<Self>) -> impl IntoElement {
        let content = if let Some(error_msg) = self.load_error() {
            // Error state
            div().text_color(rgb(0xff6b6b)).child("Error...")
        } else if self.displays().is_empty() {
            // Empty state
            div().text_color(rgb(0x888888)).child("No active shards")
        } else {
            // List state
            div().child(uniform_list(...))
        };
        // ...
    }
}
```

**CLICK_HANDLER_PATTERN:**
```rust
// GPUI pattern for click handling:
div()
    .on_mouse_up(gpui::MouseButton::Left, cx.listener(Self::on_click_handler))
    .child("Clickable element")

// Handler method:
fn on_click_handler(&mut self, _: &gpui::MouseUpEvent, _: &mut Window, cx: &mut Context<Self>) {
    // Mutate state
    self.some_flag = true;
    // Trigger re-render
    cx.notify();
}
```

**CREATE_SESSION_PATTERN:**
```rust
// SOURCE: crates/shards/src/commands.rs:46-110
// COPY THIS PATTERN for creating sessions:
use shards_core::{CreateSessionRequest, ShardsConfig, session_ops};

let config = ShardsConfig::load_hierarchy().unwrap_or_default();
let request = CreateSessionRequest::new(branch.clone(), Some(agent.clone()));

match session_ops::create_session(request, &config) {
    Ok(session) => {
        tracing::info!(
            event = "ui.create_shard_completed",
            session_id = session.id,
            branch = session.branch
        );
        // Update UI state
    }
    Err(e) => {
        tracing::error!(event = "ui.create_shard_failed", error = %e);
        // Show error to user
    }
}
```

**LOGGING_PATTERN:**
```rust
// SOURCE: crates/shards-ui/src/main.rs:36-39
// COPY THIS PATTERN for UI events:
tracing::info!(event = "ui.create_dialog.opened");
tracing::info!(event = "ui.create_shard.started", branch = branch, agent = agent);
tracing::info!(event = "ui.create_shard.completed", session_id = session.id);
tracing::error!(event = "ui.create_shard.failed", error = %e);
tracing::warn!(event = "ui.create_dialog.validation_failed", reason = "empty branch name");
```

**STYLING_PATTERN:**
```rust
// SOURCE: crates/shards-ui/src/main.rs:179-195
// COPY THIS PATTERN for consistent styling:
div()
    .size_full()
    .flex()
    .flex_col()
    .bg(rgb(0x1e1e1e))  // Dark background
    .child(
        // Header
        div().px_4().py_3().flex().items_center().child(
            div()
                .text_xl()
                .text_color(rgb(0xffffff))
                .font_weight(FontWeight::BOLD)
                .child("Shards"),
        ),
    )
```

---

## Files to Change

| File | Action | Justification |
|------|--------|---------------|
| `crates/shards-ui/src/state.rs` | CREATE | Centralized AppState for dialog + list |
| `crates/shards-ui/src/views/mod.rs` | CREATE | Module declarations |
| `crates/shards-ui/src/views/main_view.rs` | CREATE | Root view composing header + list + dialog |
| `crates/shards-ui/src/views/shard_list.rs` | CREATE | Extracted list rendering |
| `crates/shards-ui/src/views/create_dialog.rs` | CREATE | Modal dialog component |
| `crates/shards-ui/src/actions.rs` | CREATE | Business logic handlers |
| `crates/shards-ui/src/main.rs` | UPDATE | Minimal entry point using MainView |

---

## NOT Building (Scope Limits)

Explicit exclusions to prevent scope creep:

- **Embedded terminals** - Use external terminal launch only (per PRD)
- **Base branch selection** - Simplify by always using current branch as base
- **Custom agent commands** - Use config defaults only
- **Destroy/restart buttons** - That's Phase 5
- **Auto-refresh** - That's Phase 6
- **Keyboard shortcuts** - Not in MVP
- **Form validation indicators** - Simple error message is enough
- **Loading spinner during create** - Keep it simple

---

## Step-by-Step Tasks

Execute in order. Each task is atomic and independently verifiable.

### Task 1: CREATE `crates/shards-ui/src/state.rs`

- **ACTION**: Create centralized application state
- **IMPLEMENT**:
  ```rust
  pub struct AppState {
      pub displays: Vec<ShardDisplay>,
      pub load_error: Option<String>,
      pub show_create_dialog: bool,
      pub create_form: CreateFormState,
      pub create_error: Option<String>,
  }

  pub struct CreateFormState {
      pub branch_name: String,
      pub selected_agent: String,
  }
  ```
- **INCLUDE**: `ShardDisplay` and `ProcessStatus` (moved from main.rs)
- **INCLUDE**: Methods `new()`, `refresh_sessions()`, `reset_create_form()`
- **IMPORTS**: `use shards_core::{Session, session_ops};`
- **MIRROR**: State pattern from main.rs:65-98
- **VALIDATE**: `cargo check -p shards-ui`

### Task 2: CREATE `crates/shards-ui/src/views/mod.rs`

- **ACTION**: Create views module declarations
- **IMPLEMENT**:
  ```rust
  pub mod main_view;
  pub mod shard_list;
  pub mod create_dialog;

  pub use main_view::MainView;
  ```
- **VALIDATE**: `cargo check -p shards-ui`

### Task 3: CREATE `crates/shards-ui/src/views/shard_list.rs`

- **ACTION**: Extract list rendering from main.rs into component
- **IMPLEMENT**: Function that takes `&AppState` and returns element
  ```rust
  pub fn render_shard_list(state: &AppState, _cx: &mut Context<MainView>) -> impl IntoElement {
      // Error state, empty state, or uniform_list
  }
  ```
- **MIRROR**: Exact rendering from main.rs:100-177
- **IMPORTS**: `use gpui::{div, rgb, uniform_list, IntoElement, ...};`
- **VALIDATE**: `cargo check -p shards-ui`

### Task 4: CREATE `crates/shards-ui/src/views/create_dialog.rs`

- **ACTION**: Create modal dialog component
- **IMPLEMENT**:
  - Modal overlay (semi-transparent background)
  - Dialog box with title "Create New Shard"
  - Branch name display (read-only text showing current input)
  - Agent dropdown showing available agents
  - Cancel and Create buttons
  - Error message display area
- **PATTERN**: Conditional rendering when `state.show_create_dialog`
- **AGENTS**: Use `shards_core::agents::valid_agent_names()` for dropdown options
- **STYLING**: Match existing dark theme (bg 0x1e1e1e, text 0xffffff)
- **VALIDATE**: `cargo check -p shards-ui`

**Note on Text Input**: GPUI doesn't have built-in text input. For MVP, implement a simple approach:
- Store branch_name in state
- Use keyboard event handler to append/remove characters
- Display current value in a styled div
- Alternative: Use a predefined branch name pattern

### Task 5: CREATE `crates/shards-ui/src/actions.rs`

- **ACTION**: Create business logic handlers
- **IMPLEMENT**:
  ```rust
  pub fn create_shard(branch: &str, agent: &str) -> Result<Session, String> {
      let config = ShardsConfig::load_hierarchy().unwrap_or_default();
      let request = CreateSessionRequest::new(branch.to_string(), Some(agent.to_string()));

      session_ops::create_session(request, &config)
          .map_err(|e| e.to_string())
  }

  pub fn refresh_sessions() -> (Vec<ShardDisplay>, Option<String>) {
      // Same logic as current ShardListView::new()
  }
  ```
- **LOGGING**: Add tracing events per logging pattern
- **IMPORTS**: `use shards_core::{CreateSessionRequest, ShardsConfig, Session, session_ops};`
- **VALIDATE**: `cargo check -p shards-ui`

### Task 6: CREATE `crates/shards-ui/src/views/main_view.rs` and UPDATE `main.rs`

- **ACTION**: Create root view and simplify main.rs
- **IMPLEMENT MainView**:
  ```rust
  pub struct MainView {
      state: AppState,
  }

  impl MainView {
      pub fn new() -> Self { ... }

      fn on_create_button_click(&mut self, ...) {
          self.state.show_create_dialog = true;
          cx.notify();
      }

      fn on_dialog_cancel(&mut self, ...) {
          self.state.show_create_dialog = false;
          self.state.reset_create_form();
          cx.notify();
      }

      fn on_dialog_submit(&mut self, ...) {
          match actions::create_shard(&self.state.create_form.branch_name, &self.state.create_form.selected_agent) {
              Ok(_session) => {
                  self.state.show_create_dialog = false;
                  self.state.reset_create_form();
                  let (displays, error) = actions::refresh_sessions();
                  self.state.displays = displays;
                  self.state.load_error = error;
              }
              Err(e) => {
                  self.state.create_error = Some(e);
              }
          }
          cx.notify();
      }
  }

  impl Render for MainView {
      fn render(&mut self, _window: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
          div()
              .size_full()
              .flex()
              .flex_col()
              .bg(rgb(0x1e1e1e))
              .child(render_header(cx))           // Header with create button
              .child(shard_list::render_shard_list(&self.state, cx))
              .when(self.state.show_create_dialog, |this| {
                  this.child(create_dialog::render_create_dialog(&self.state, cx))
              })
      }
  }
  ```
- **UPDATE main.rs**: Simplify to just Application setup using MainView
- **VALIDATE**: `cargo build -p shards-ui && cargo run -p shards-ui`

---

## Text Input Strategy

Since GPUI lacks built-in text input, use one of these approaches:

**Option A: Keyboard Capture (Recommended for MVP)**
```rust
// In MainView, track focus and capture key events
div()
    .track_focus(&self.focus_handle)
    .key_context("create_dialog")
    .on_key_down(cx.listener(|view, event: &KeyDownEvent, cx| {
        if view.state.show_create_dialog {
            match &event.keystroke.key {
                Key::Backspace => {
                    view.state.create_form.branch_name.pop();
                }
                Key::Char(c) => {
                    view.state.create_form.branch_name.push(*c);
                }
                Key::Enter => {
                    view.on_dialog_submit(cx);
                }
                Key::Escape => {
                    view.on_dialog_cancel(cx);
                }
                _ => {}
            }
            cx.notify();
        }
    }))
```

**Option B: Preset Branch Names**
- Provide 3-4 preset branch name options as buttons
- User clicks one to select
- Simpler but less flexible

For MVP, implement Option A with basic character input.

---

## Testing Strategy

### Manual Tests to Perform

| Test Case | Steps | Expected Result |
|-----------|-------|-----------------|
| Create button visible | Open app | [+ Create] button in header |
| Dialog opens | Click [+ Create] | Modal dialog appears |
| Dialog closes on cancel | Click [Cancel] | Dialog disappears |
| Branch input works | Type characters | Characters appear in field |
| Agent dropdown works | Click agent options | Selection updates |
| Create succeeds | Fill form, click Create | Dialog closes, list updates, terminal opens |
| Create fails (empty branch) | Leave branch empty, click Create | Error message shown |
| Create fails (duplicate) | Enter existing branch | Error message shown |

### Edge Cases Checklist

- [x] Empty branch name → Show validation error
- [x] Branch name with special characters → Let shards-core validate
- [x] Create while no git repo → Show error from shards-core
- [x] Terminal launch fails → Show error, but shard still created
- [x] Dialog cancel preserves list state → List unchanged
- [x] Rapid create clicks → Should be idempotent

---

## Validation Commands

### Level 1: STATIC_ANALYSIS

```bash
cargo fmt --check -p shards-ui && cargo clippy -p shards-ui -- -D warnings
```

**EXPECT**: Exit 0, no errors or warnings

### Level 2: BUILD

```bash
cargo build -p shards-ui
```

**EXPECT**: Clean build, no warnings

### Level 3: FULL_SUITE

```bash
cargo fmt --check && cargo clippy --all -- -D warnings && cargo test --all && cargo build --all
```

**EXPECT**: All tests pass, build succeeds

### Level 4: MANUAL_VALIDATION

1. Start the UI: `cargo run -p shards-ui`
2. Verify [+ Create] button is visible in header
3. Click [+ Create] - verify dialog opens
4. Type a branch name (e.g., "test-from-ui")
5. Select an agent (or use default claude)
6. Click [Create]
7. Verify:
   - Dialog closes
   - External terminal window opens (iTerm/Ghostty/Terminal.app)
   - Agent starts in terminal
   - New shard appears in list with correct status
8. Close UI and verify via CLI: `cargo run -p shards -- list`

---

## Acceptance Criteria

- [x] [+ Create] button visible in header
- [x] Clicking button opens modal dialog
- [x] Dialog has branch name input field
- [x] Dialog has agent selection (shows available agents)
- [x] Cancel button closes dialog without action
- [x] Create button triggers shard creation
- [x] On success: dialog closes, list refreshes, terminal opens
- [x] On error: error message displayed in dialog
- [x] Level 1-3 validation commands pass with exit 0
- [x] Code follows existing patterns (naming, logging, styling)

---

## Completion Checklist

- [ ] Task 1: state.rs created with AppState
- [ ] Task 2: views/mod.rs created
- [ ] Task 3: views/shard_list.rs extracted
- [ ] Task 4: views/create_dialog.rs created
- [ ] Task 5: actions.rs created
- [ ] Task 6: views/main_view.rs created, main.rs simplified
- [ ] Level 1: cargo fmt --check && cargo clippy passes
- [ ] Level 2: cargo build -p shards-ui succeeds
- [ ] Level 3: Full suite passes
- [ ] Level 4: Manual validation complete
- [ ] All acceptance criteria met

---

## Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| GPUI text input complexity | MEDIUM | MEDIUM | Use keyboard capture approach, keep simple |
| Dialog focus management | LOW | LOW | Use track_focus, test manually |
| State mutation during async | LOW | LOW | create_session is sync, no async issues |
| Terminal spawn failure | LOW | LOW | Session still created, show error but continue |

---

## Notes

### Why not use gpui-component?

The gpui-component library (from Longbridge) provides Input, Button, Dialog components. However:
1. It's an additional dependency
2. May have version compatibility issues with gpui 0.2
3. For MVP, raw GPUI is sufficient
4. Can migrate to gpui-component in future if needed

### Keyboard Input Simplification

For MVP, we accept these limitations:
- No cursor positioning (always append/backspace from end)
- No copy/paste support
- No selection
- Basic ASCII characters only

These can be improved in future phases or with gpui-component adoption.

### Agent Selection

The agents module provides `valid_agent_names()` which returns `["aether", "claude", "codex", "gemini", "kiro"]`. Display these as selectable options with claude as default.

For MVP, use a simple cycling selection (click to cycle through agents) rather than a true dropdown, to avoid complex focus/overlay management.
