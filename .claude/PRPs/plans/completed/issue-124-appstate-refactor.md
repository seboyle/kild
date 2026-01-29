# Implementation Plan: Issue #124 - Refactor AppState

**Source Issue**: #124
**Branch**: `refactor/appstate-type-safe-modules`
**Status**: ✅ ALL PHASES COMPLETE
**Complexity**: High
**Confidence**: High

---

## Progress

| Phase | Status | Description |
|-------|--------|-------------|
| 1 | ✅ Complete | DialogState enum - prevents impossible dialog states |
| 2 | ✅ Complete | OperationErrors - unified error tracking |
| 3 | ✅ Complete | ProjectManager - encapsulated projects with enforced invariants |
| 4 | ✅ Complete | SelectionState - encapsulated selection state |
| 5 | ✅ Complete | SessionStore - encapsulated displays, load_error, last_refresh |
| 6 | ✅ Complete | Final AppState Facade - all fields private, controlled access |

**All phases complete!** Ready for PR creation.

---

## Summary

Refactor `AppState` in `crates/kild-ui/src/state.rs` from a god object with 19 public fields into type-safe state modules with encapsulation. This eliminates impossible states, enforces invariants at compile-time, and consolidates duplicate logic.

---

## Problem Analysis

### Current State (Evidence from Codebase)

1. **19 public fields** - All fields are `pub`, allowing arbitrary mutation from any code
2. **Duplicate invariant logic** - `active_project` cleanup exists in BOTH:
   - `main_view.rs:682-684` (local state update)
   - `actions.rs:305-307` (persistence layer)
3. **5 error fields for same concept**:
   - `open_error: Option<OperationError>`
   - `stop_error: Option<OperationError>`
   - `bulk_errors: Vec<OperationError>`
   - `editor_error: Option<OperationError>`
   - `focus_error: Option<OperationError>`
4. **9 dialog-related fields** that allow impossible states (all 3 dialogs open simultaneously):
   - `show_create_dialog`, `create_form`, `create_error`
   - `show_confirm_dialog`, `confirm_target_branch`, `confirm_error`
   - `show_add_project_dialog`, `add_project_form`, `add_project_error`

---

## Proposed Architecture

```
AppState (facade with controlled methods)
├── dialog: DialogState (enum - mutually exclusive)
├── selection: SelectionState (auto-clearing stale references)
├── errors: OperationErrors (unified HashMap + bulk Vec)
├── projects: ProjectManager (enforced invariants)
└── sessions: SessionStore (displays + refresh timestamp)
```

---

## Implementation Phases

### Phase 1: DialogState Enum (Medium Risk) ✅ COMPLETE

**Goal**: Replace 9 dialog fields with a single enum that prevents impossible states.

**Current (allows 3 dialogs open):**
```rust
pub show_create_dialog: bool,
pub create_form: CreateFormState,
pub create_error: Option<String>,
pub show_confirm_dialog: bool,
pub confirm_target_branch: Option<String>,
pub confirm_error: Option<String>,
pub show_add_project_dialog: bool,
pub add_project_form: AddProjectFormState,
pub add_project_error: Option<String>,
```

**After (compile-time mutual exclusion):**
```rust
pub enum DialogState {
    None,
    Create {
        form: CreateFormState,
        error: Option<String>,
    },
    Confirm {
        branch: String,
        error: Option<String>,
    },
    AddProject {
        form: AddProjectFormState,
        error: Option<String>,
    },
}
```

**Files to Change:**
- `state.rs` - Add `DialogState` enum, update `AppState`
- `main_view.rs` - Update dialog open/close handlers
- `views/create_dialog.rs` - Update to use `DialogState::Create`
- `views/confirm_dialog.rs` - Update to use `DialogState::Confirm`
- `views/add_project_dialog.rs` - Update to use `DialogState::AddProject`

**Pattern to Mirror:** `ProcessStatus` enum in `state.rs:12-21`

---

### Phase 2: OperationErrors Consolidation (Low Risk) ✅ COMPLETE

**Goal**: Replace 5 error fields with a unified error tracking struct.

**Current (5 fields, error-prone):**
```rust
pub open_error: Option<OperationError>,
pub stop_error: Option<OperationError>,
pub bulk_errors: Vec<OperationError>,
pub editor_error: Option<OperationError>,
pub focus_error: Option<OperationError>,
```

**After (unified collection):**
```rust
pub struct OperationErrors {
    by_branch: HashMap<String, OperationError>,  // Keyed by branch
    bulk: Vec<OperationError>,  // For multi-kild operations
}

impl OperationErrors {
    pub fn set(&mut self, branch: &str, error: OperationError);
    pub fn get(&self, branch: &str) -> Option<&OperationError>;
    pub fn clear(&mut self, branch: &str);
    pub fn clear_all(&mut self);
    pub fn add_bulk(&mut self, error: OperationError);
    pub fn bulk_errors(&self) -> &[OperationError];
    pub fn clear_bulk(&mut self);
}
```

**Files to Change:**
- `state.rs` - Add `OperationErrors` struct, update `AppState`
- `main_view.rs` - Update error setting/clearing calls
- `views/kild_list.rs` - Update error display logic (row_error lookup)

---

### Phase 3: ProjectManager (Low Risk)

**Goal**: Encapsulate projects + active_project with enforced invariants.

**Current (invariant not enforced, duplicated logic):**
```rust
pub projects: Vec<Project>,
pub active_project: Option<PathBuf>,  // Can reference non-existent project!
```

**After (compile-time guarantee):**
```rust
pub struct ProjectManager {
    projects: Vec<Project>,  // Private!
    active_index: Option<usize>,  // Index bounds enforced
}

impl ProjectManager {
    pub fn select(&mut self, path: &Path) -> Result<(), ProjectError>;
    pub fn select_all(&mut self);  // Sets active_index to None
    pub fn add(&mut self, project: Project) -> Result<(), ProjectError>;
    pub fn remove(&mut self, path: &Path) -> Result<Project, ProjectError>;
    pub fn active(&self) -> Option<&Project>;
    pub fn active_path(&self) -> Option<&Path>;
    pub fn iter(&self) -> impl Iterator<Item = &Project>;
    pub fn is_empty(&self) -> bool;
    pub fn len(&self) -> usize;
}
```

**Key Invariant (SINGLE LOCATION):**
```rust
pub fn remove(&mut self, path: &Path) -> Result<Project, ProjectError> {
    let index = self.projects.iter().position(|p| p.path() == path)
        .ok_or(ProjectError::NotFound)?;

    // Automatically fix active_index - SINGLE LOCATION
    if self.active_index == Some(index) {
        self.active_index = if self.projects.len() > 1 { Some(0) } else { None };
    } else if let Some(active) = self.active_index {
        if active > index {
            self.active_index = Some(active - 1);
        }
    }

    Ok(self.projects.remove(index))
}
```

**Files to Change:**
- `state.rs` - Add `ProjectManager`, update `AppState`
- `main_view.rs` - Replace direct field access with method calls
- `actions.rs` - Remove duplicate invariant logic (lines 305-308)
- `views/sidebar.rs` - Update to use ProjectManager methods

---

### Phase 4: SelectionState (Low Risk)

**Goal**: Encapsulate selection with auto-clearing behavior.

**Current:**
```rust
pub selected_kild_id: Option<String>,  // Can reference deleted kild
```

**After (auto-clearing):**
```rust
pub struct SelectionState {
    selected_id: Option<String>,
}

impl SelectionState {
    pub fn select(&mut self, id: String);
    pub fn clear(&mut self);
    pub fn id(&self) -> Option<&str>;

    /// Returns selected kild, auto-clearing if stale
    pub fn get<'a>(&mut self, displays: &'a [KildDisplay]) -> Option<&'a KildDisplay>;
}
```

**Files to Change:**
- `state.rs` - Add `SelectionState`, update `AppState`
- `main_view.rs` - Update selection calls
- `views/kild_list.rs` - Update selection display

---

### Phase 5: SessionStore (Low Risk)

**Goal**: Encapsulate displays + last_refresh + load_error together.

**Current:**
```rust
pub displays: Vec<KildDisplay>,
pub load_error: Option<String>,
pub last_refresh: std::time::Instant,
```

**After:**
```rust
pub struct SessionStore {
    displays: Vec<KildDisplay>,
    load_error: Option<String>,
    last_refresh: std::time::Instant,
}

impl SessionStore {
    pub fn refresh(&mut self);
    pub fn update_statuses_only(&mut self);
    pub fn displays(&self) -> &[KildDisplay];
    pub fn filtered_by_project(&self, project_id: Option<&str>) -> Vec<&KildDisplay>;
    pub fn load_error(&self) -> Option<&str>;
    pub fn last_refresh(&self) -> std::time::Instant;
    pub fn stopped_count(&self) -> usize;
    pub fn running_count(&self) -> usize;
    pub fn kild_count_for_project(&self, project_id: &str) -> usize;
    pub fn total_count(&self) -> usize;
}
```

**Files to Change:**
- `state.rs` - Add `SessionStore`, update `AppState`
- `main_view.rs` - Update refresh calls
- `views/kild_list.rs` - Update displays access

---

### Phase 6: Final AppState Facade (Medium Risk)

**Goal**: Make all fields private, expose controlled mutation methods only.

**After:**
```rust
pub struct AppState {
    // All private
    dialog: DialogState,
    selection: SelectionState,
    errors: OperationErrors,
    projects: ProjectManager,
    sessions: SessionStore,
}

impl AppState {
    // Factory
    pub fn new() -> Self;

    // Dialog methods
    pub fn open_create_dialog(&mut self);
    pub fn open_confirm_dialog(&mut self, branch: String);
    pub fn open_add_project_dialog(&mut self);
    pub fn close_dialog(&mut self);
    pub fn dialog(&self) -> &DialogState;
    pub fn dialog_mut(&mut self) -> &mut DialogState;

    // Selection methods
    pub fn select_kild(&mut self, id: String);
    pub fn clear_selection(&mut self);
    pub fn selected_kild(&mut self) -> Option<&KildDisplay>;

    // Error methods
    pub fn set_error(&mut self, branch: &str, error: OperationError);
    pub fn clear_error(&mut self, branch: &str);
    pub fn clear_all_errors(&mut self);
    pub fn get_error(&self, branch: &str) -> Option<&OperationError>;
    pub fn bulk_errors(&self) -> &[OperationError];
    pub fn add_bulk_error(&mut self, error: OperationError);
    pub fn clear_bulk_errors(&mut self);

    // Project methods (delegate to ProjectManager)
    pub fn select_project(&mut self, path: &Path) -> Result<(), ProjectError>;
    pub fn select_all_projects(&mut self);
    pub fn add_project(&mut self, project: Project) -> Result<(), ProjectError>;
    pub fn remove_project(&mut self, path: &Path) -> Result<Project, ProjectError>;
    pub fn active_project(&self) -> Option<&Project>;
    pub fn active_project_path(&self) -> Option<&Path>;
    pub fn active_project_id(&self) -> Option<String>;
    pub fn projects(&self) -> impl Iterator<Item = &Project>;

    // Session methods (delegate to SessionStore)
    pub fn refresh_sessions(&mut self);
    pub fn update_statuses_only(&mut self);
    pub fn displays(&self) -> &[KildDisplay];
    pub fn filtered_displays(&self) -> Vec<&KildDisplay>;
    pub fn load_error(&self) -> Option<&str>;
    pub fn stopped_count(&self) -> usize;
    pub fn running_count(&self) -> usize;
    pub fn kild_count_for_project(&self, path: &Path) -> usize;
    pub fn total_kild_count(&self) -> usize;
}
```

---

## Step-by-Step Tasks

### Phase 1: DialogState Enum

1. **CREATE** `DialogState` enum in `state.rs`
   - MIRROR: `ProcessStatus` enum pattern
   - Include `Default` impl (returns `None`)
   - Include helper methods: `is_open()`, `is_create()`, etc.

2. **UPDATE** `AppState` to use `DialogState`
   - Replace 9 dialog fields with single `pub dialog: DialogState`
   - Update `new()` constructor
   - Update `make_test_state()` helper

3. **UPDATE** `main_view.rs` dialog handlers:
   - `on_create_button_click`: `self.state.dialog = DialogState::Create { ... }`
   - `on_dialog_cancel`: `self.state.dialog = DialogState::None`
   - `on_dialog_submit`: Access `DialogState::Create { form, .. }`
   - `on_destroy_click`: `self.state.dialog = DialogState::Confirm { ... }`
   - `on_confirm_destroy`/`cancel`: Access `DialogState::Confirm`
   - `on_add_project_*`: Access `DialogState::AddProject`

4. **UPDATE** `main_view.rs` `on_key_down`:
   - Pattern match on `self.state.dialog` instead of checking bool flags

5. **UPDATE** `main_view.rs` `render()`:
   - Pattern match on `self.state.dialog` for `.when()` conditions

6. **UPDATE** view files to pattern match:
   - `create_dialog.rs`: Accept `DialogState` or extracted form
   - `confirm_dialog.rs`: Accept `DialogState` or extracted branch/error
   - `add_project_dialog.rs`: Accept `DialogState` or extracted form

### Phase 2: OperationErrors

7. **CREATE** `OperationErrors` struct in `state.rs`
   - HashMap for per-branch errors
   - Vec for bulk errors
   - Methods: `set`, `get`, `clear`, `clear_all`, `add_bulk`, `bulk_errors`, `clear_bulk`

8. **UPDATE** `AppState` to use `OperationErrors`
   - Replace 5 error fields with single `pub errors: OperationErrors`
   - Update `new()` constructor

9. **UPDATE** `main_view.rs` error handling:
   - Replace `self.state.open_error = Some(...)` with `self.state.errors.set(branch, ...)`
   - Replace `self.state.clear_open_error()` with `self.state.errors.clear(branch)`
   - Same for stop, editor, focus errors

10. **UPDATE** `views/kild_list.rs` error display:
    - Replace manual error checking with `state.errors.get(&branch)`

### Phase 3: ProjectManager

11. **CREATE** `ProjectManager` struct in `state.rs` or new `project_manager.rs`
    - Private fields: `projects: Vec<Project>`, `active_index: Option<usize>`
    - Methods with enforced invariants

12. **UPDATE** `AppState` to use `ProjectManager`
    - Replace `projects` and `active_project` with `projects: ProjectManager`

13. **UPDATE** `main_view.rs` project handlers:
    - `on_project_select`: Use `self.state.projects.select(path)`
    - `on_project_select_all`: Use `self.state.projects.select_all()`
    - `on_remove_project`: Use `self.state.projects.remove(path)`
    - `on_add_project_submit`: Use `self.state.projects.add(project)`

14. **DELETE** duplicate invariant logic in `actions.rs:305-308`
    - The invariant is now enforced in `ProjectManager::remove()`

15. **UPDATE** `views/sidebar.rs`:
    - Use `state.projects.iter()` instead of `&state.projects`
    - Use `state.projects.active()` instead of manual matching

### Phase 4: SelectionState

16. **CREATE** `SelectionState` struct in `state.rs`
    - Private field: `selected_id: Option<String>`
    - Methods with auto-clearing behavior

17. **UPDATE** `AppState` to use `SelectionState`
    - Replace `selected_kild_id` with `selection: SelectionState`

18. **UPDATE** `main_view.rs` selection handlers:
    - `on_kild_select`: Use `self.state.selection.select(id)`
    - `clear_selection()`: Use `self.state.selection.clear()`

19. **UPDATE** `views/kild_list.rs`:
    - Use `state.selection.id()` for selection check

### Phase 5: SessionStore

20. **CREATE** `SessionStore` struct in `state.rs`
    - Encapsulate `displays`, `load_error`, `last_refresh`
    - Methods for refresh, filtering, counts

21. **UPDATE** `AppState` to use `SessionStore`
    - Replace 3 fields with `sessions: SessionStore`

22. **UPDATE** all session access across files

### Phase 6: Final Cleanup

23. **MAKE** all `AppState` fields private (remove `pub`)

24. **ADD** facade methods to `AppState` for all state access

25. **UPDATE** all external access to use facade methods

26. **UPDATE** tests to use new API

---

## Validation Commands

```bash
# Type check (critical)
cargo check -p kild-ui

# Lint
cargo clippy -p kild-ui -- -D warnings

# Format
cargo fmt --check

# Tests
cargo test -p kild-ui

# Build
cargo build -p kild-ui

# Integration test (manual)
cargo run -p kild-ui
# - Test create dialog (open, fill, submit, cancel)
# - Test confirm dialog (destroy flow)
# - Test add project dialog
# - Test project selection
# - Test kild open/stop/destroy
```

---

## Acceptance Criteria

- [ ] Zero `pub` fields on AppState (all access through methods)
- [ ] `DialogState` enum prevents multiple dialogs open (compile-time)
- [ ] `ProjectManager` enforces `active` is always valid (single location)
- [ ] Single source of truth for operation errors (`OperationErrors`)
- [ ] All existing tests pass
- [ ] No duplicate invariant maintenance logic
- [ ] `cargo clippy` passes with zero warnings
- [ ] `cargo fmt --check` passes

---

## Risk Assessment

| Phase | Risk | Mitigation |
|-------|------|------------|
| 1 (DialogState) | Medium | Many UI touchpoints - test each dialog flow |
| 2 (OperationErrors) | Low | Mechanical refactor - straightforward |
| 3 (ProjectManager) | Low | Well-isolated, removes duplicate logic |
| 4 (SelectionState) | Low | Minimal changes needed |
| 5 (SessionStore) | Low | Straightforward encapsulation |
| 6 (Final cleanup) | Medium | Making fields private - compile errors guide fixes |

---

## GOTCHA Warnings

1. **DialogState Form Access**: When reading form data in submit handlers, need to pattern match the enum variant. If accessed incorrectly, the form data won't be available.

2. **ProjectManager Active Index**: After removing a project, the active_index might need adjustment if it was pointing to a later project. The `remove()` method must handle this.

3. **Test State Construction**: The `make_test_state()` helper and inline test state construction will need updates for each phase.

4. **View Function Signatures**: Some view functions take `&AppState` - they may need to take extracted data instead if we can't pattern match on enum variants.

5. **Render Lifetime**: GPUI's render methods may complicate borrowing - if pattern matching DialogState borrows the state, the view functions may not be able to take `&self.state`. May need to clone or extract data before pattern matching.
