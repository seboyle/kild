# PR Merge Order Analysis

## PRs Ready to Merge

1. **PR #8**: PID tracking and process management (+1467/-22 lines)
2. **PR #9**: Dynamic port allocation (+1007/-9 lines)
3. **PR #10**: Include patterns to override gitignore (+1710/-2 lines)

## Conflict Analysis

### Critical Overlapping Files

| File | PR #8 | PR #9 | PR #10 | Conflict Risk |
|------|-------|-------|--------|---------------|
| `src/sessions/handler.rs` | ✅ (+62/-6) | ✅ (+42/-3) | ✅ (+1/-1) | **HIGH** |
| `src/sessions/types.rs` | ✅ (+20/-0) | ✅ (+13/-0) | ❌ | **HIGH** |
| `src/sessions/operations.rs` | ✅ (+47/-0) | ✅ (+262/-0) | ❌ | **MEDIUM** |
| `src/sessions/errors.rs` | ✅ (+12/-0) | ✅ (+15/-0) | ❌ | **LOW** |
| `src/cli/commands.rs` | ✅ (+90/-6) | ✅ (+9/-6) | ❌ | **MEDIUM** |
| `src/core/config.rs` | ❌ | ✅ (+16/-0) | ✅ (+13/-0) | **LOW** |
| `Cargo.toml` | ✅ (+1/-0) | ❌ | ✅ (+4/-0) | **LOW** |
| `Cargo.lock` | ✅ (+162/-8) | ❌ | ✅ (+150/-0) | **LOW** |
| `src/lib.rs` | ✅ (+1/-0) | ❌ | ✅ (+1/-0) | **LOW** |

### Dependency Analysis

**PR #8 (PID Tracking)** adds to `Session` struct:
- `process_id: Option<u32>` field
- New `process/` module
- Updates `terminal::handler::spawn_terminal()` to return PID
- Modifies `create_session()` to store PID
- Modifies `destroy_session()` to kill process

**PR #9 (Port Allocation)** adds to `Session` struct:
- `port_start: u16` field
- `port_end: u16` field
- Port allocation logic in `operations.rs`
- Modifies `create_session()` to allocate ports
- Modifies `destroy_session()` to free ports

**PR #10 (Include Patterns)** adds:
- New `files/` module (no conflicts)
- Minimal change to `create_session()` (passes config parameter)
- Config additions for include patterns

### Conflict Severity

**HIGH RISK - Session Struct Changes**:
- PR #8 adds `process_id: Option<u32>`
- PR #9 adds `port_start: u16, port_end: u16`
- Both modify the same struct in `src/sessions/types.rs`
- **Resolution**: Simple - add all three fields

**HIGH RISK - Handler Create Function**:
- PR #8: Captures PID from terminal spawn, stores in session
- PR #9: Allocates ports before worktree, stores in session
- PR #10: Passes config to operations (minimal change)
- **Resolution**: Moderate - need to integrate all three workflows

**MEDIUM RISK - CLI Commands**:
- PR #8: Adds `status` command, modifies `list` and `destroy`
- PR #9: Modifies `list` display to show ports
- **Resolution**: Simple - combine display changes

**LOW RISK - Dependencies**:
- PR #8: Adds `sysinfo` crate
- PR #10: Adds `tempfile` crate (dev-dependency)
- **Resolution**: Trivial - both can coexist

## Recommended Merge Order

### Option 1: Feature Independence (RECOMMENDED)
**Order**: PR #10 → PR #9 → PR #8

**Rationale**:
1. **PR #10 first** - Most isolated, minimal conflicts
   - Only touches `handler.rs` with 1 line change
   - Adds independent `files/` module
   - No Session struct changes
   - Conflicts: Minimal

2. **PR #9 second** - Medium complexity
   - Adds port fields to Session struct
   - Moderate handler changes
   - After #10, only conflicts with #8
   - Conflicts: Session struct, handler logic

3. **PR #8 last** - Most invasive
   - Adds process_id to Session struct
   - Largest handler changes
   - New process module
   - Conflicts: Session struct, handler logic, CLI

**Advantages**:
- Smallest PR merged first (quick win)
- Each merge adds one major feature
- Final merge (#8) has most context from previous merges
- Easier to test incrementally

**Estimated Conflict Resolution Time**: 30-45 minutes

### Option 2: Logical Dependencies
**Order**: PR #8 → PR #9 → PR #10

**Rationale**:
- Process tracking is foundational for lifecycle management
- Port allocation builds on process management
- File copying is independent feature

**Disadvantages**:
- Largest PR first (more risk)
- More conflicts to resolve upfront
- Harder to isolate issues

**Estimated Conflict Resolution Time**: 45-60 minutes

## Conflict Resolution Plan

### Phase 1: Merge PR #10 (Include Patterns)
**Expected Conflicts**: None (clean merge expected)

**Actions**:
```bash
gh pr merge 10 --merge
```

**Validation**:
- Run `cargo test`
- Test `shards create` with include patterns config
- Verify gitignored files are copied

### Phase 2: Merge PR #9 (Port Allocation)
**Expected Conflicts**: 
- `src/sessions/types.rs` - Session struct
- `src/sessions/handler.rs` - create_session function
- `src/core/config.rs` - config additions

**Resolution Steps**:

1. **Session struct conflict** (`src/sessions/types.rs`):
```rust
pub struct Session {
    pub id: String,
    pub project_id: String,
    pub branch: String,
    pub worktree_path: PathBuf,
    pub agent: String,
    pub status: SessionStatus,
    pub created_at: String,
    // ADD THESE FROM PR #9:
    pub port_start: u16,
    pub port_end: u16,
}
```

2. **Handler conflict** (`src/sessions/handler.rs`):
- Integrate port allocation before worktree creation
- Add port fields to Session initialization
- Add port cleanup to destroy_session

3. **Config conflict** (`src/core/config.rs`):
- Keep both PR #10's include_patterns and PR #9's port config
- Merge both config sections

**Validation**:
```bash
cargo test
shards create test-ports --agent kiro
shards list  # Verify ports shown
shards destroy test-ports
```

### Phase 3: Merge PR #8 (PID Tracking)
**Expected Conflicts**:
- `src/sessions/types.rs` - Session struct (add process_id)
- `src/sessions/handler.rs` - create/destroy functions
- `src/cli/commands.rs` - list/destroy commands
- `Cargo.toml` / `Cargo.lock` - sysinfo dependency

**Resolution Steps**:

1. **Session struct conflict** (`src/sessions/types.rs`):
```rust
pub struct Session {
    pub id: String,
    pub project_id: String,
    pub branch: String,
    pub worktree_path: PathBuf,
    pub agent: String,
    pub status: SessionStatus,
    pub created_at: String,
    pub port_start: u16,      // From PR #9
    pub port_end: u16,        // From PR #9
    pub process_id: Option<u32>,  // ADD FROM PR #8
}
```

2. **Handler create_session conflict** (`src/sessions/handler.rs`):
```rust
pub fn create_session(...) -> Result<Session, SessionError> {
    // ... existing validation ...
    
    // FROM PR #9: Allocate ports
    let (port_start, port_end) = operations::allocate_port_range(...)?;
    
    // ... worktree creation ...
    
    // FROM PR #10: Copy include patterns
    files::handler::copy_include_patterns(...)?;
    
    // FROM PR #8: Capture PID from terminal spawn
    let spawn_result = terminal::handler::spawn_terminal(...)?;
    let process_id = spawn_result.process_id;
    
    // Create session with ALL fields
    let session = Session {
        // ... existing fields ...
        port_start,
        port_end,
        process_id,
    };
    
    // ... save session ...
}
```

3. **Handler destroy_session conflict** (`src/sessions/handler.rs`):
```rust
pub fn destroy_session(name: &str) -> Result<(), SessionError> {
    // ... load session ...
    
    // FROM PR #8: Kill process first
    if let Some(pid) = session.process_id {
        process::operations::kill_process(pid)?;
    }
    
    // FROM PR #9: Free ports
    operations::free_port_range(session.port_start)?;
    
    // ... existing worktree cleanup ...
}
```

4. **CLI commands conflict** (`src/cli/commands.rs`):
- Merge list command changes (show both ports and process status)
- Add status command from PR #8
- Integrate destroy changes

5. **Dependencies conflict** (`Cargo.toml`):
```toml
[dependencies]
# ... existing ...
sysinfo = "0.32"  # From PR #8

[dev-dependencies]
tempfile = "3.8"  # From PR #10
```

**Validation**:
```bash
cargo test
shards create test-full --agent kiro
shards list  # Verify ports AND process status shown
shards status test-full  # New command from PR #8
shards destroy test-full  # Verify process killed
```

## Testing Strategy

### After Each Merge

1. **Unit Tests**: `cargo test`
2. **Type Check**: `cargo check`
3. **Lint**: `cargo clippy`
4. **Build**: `cargo build --release`

### Integration Tests After All Merges

```bash
# Test complete workflow
shards create test-1 --agent kiro
shards create test-2 --agent claude
shards list  # Should show ports, PIDs, status
shards status test-1  # Should show process details
shards destroy test-1  # Should kill process, free ports
shards destroy test-2
```

### Regression Tests

- Verify existing sessions load correctly (backward compatibility)
- Test with missing optional fields (process_id, ports)
- Test error handling for each feature

## Rollback Plan

If any merge causes critical issues:

```bash
# Revert the problematic merge
git revert -m 1 <merge-commit-hash>

# Or reset to before merge
git reset --hard HEAD~1

# Force push if already pushed
git push --force-with-lease
```

## Estimated Timeline

- **PR #10 merge**: 5 minutes (clean merge)
- **PR #9 merge + conflicts**: 20-30 minutes
- **PR #8 merge + conflicts**: 30-45 minutes
- **Integration testing**: 15-20 minutes
- **Total**: 70-100 minutes

## Success Criteria

✅ All three PRs merged successfully
✅ All tests passing (cargo test)
✅ No compilation errors
✅ No clippy warnings (or only acceptable ones)
✅ Integration workflow works end-to-end
✅ Backward compatibility maintained for existing sessions
