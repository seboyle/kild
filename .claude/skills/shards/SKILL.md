---
name: shards
description: Manage parallel AI development sessions in isolated Git worktrees. Use when creating isolated workspaces, managing multiple AI agents, checking session status, or cleaning up development environments.
allowed-tools: Bash(shards:*)
---

# Shards CLI - Parallel AI Development Manager

Shards creates isolated Git worktrees for parallel AI development sessions. Each shard runs in its own workspace with dedicated port ranges and process tracking.

## Core Commands

### Create a Shard
```bash
shards create <branch> [--agent <agent>] [--flags <flags>] [--terminal <terminal>] [--startup-command <command>]
```

Creates an isolated workspace with:
- New Git worktree in `~/.shards/worktrees/<project>/<branch>/`
- Unique port range (10 ports, starting from 3000)
- Native terminal with AI agent launched
- Process tracking (PID, name, start time)
- Session metadata saved to `~/.shards/sessions/`

**Supported agents**: claude, kiro, gemini, codex, aether
**Supported terminal types**: ghostty, iterm, terminal, native

**Note**: `--flags` accepts space-separated syntax: `--flags '--trust-all-tools'`

**Example**:
```bash
shards create feature-auth --agent kiro --terminal ghostty
shards create bug-fix-123 --agent claude --flags '--trust-all-tools'
```

### List All Shards
```bash
shards list
```

Shows table with:
- Branch name
- Agent type
- Status (active/stopped)
- Creation timestamp
- Port range allocation
- Process status (Running/Stopped with PID)
- Command executed (actual command with flags)

### Restart a Shard
```bash
shards restart <branch> [--agent <agent>]
```

Restarts agent process without destroying worktree. Use `-a` as shorthand for `--agent`.

What it does:
- Kills existing process (if tracked)
- Launches new terminal with same or different agent
- Preserves worktree and uncommitted changes
- Updates session metadata with new process info

**Example**:
```bash
shards restart feature-auth
shards restart bug-fix-123 --agent claude
```

### Status (Detailed View)
```bash
shards status <branch>
```

Shows detailed info for a specific shard:
- Branch and agent info
- Worktree path
- Process status and metadata
- Port range allocation

**When to use**: When you need detailed information about a specific shard, not just the list overview.

### Health Monitoring
```bash
shards health [branch] [--json] [--watch] [--interval <seconds>]
```

Shows health dashboard with:
- Process status (Working/Idle/Stuck/Crashed/Unknown)
- CPU and memory usage metrics
- Summary statistics

**Flags**:
- `--json`: Output in JSON format for programmatic use
- `--watch` / `-w`: Continuously refresh the display
- `--interval` / `-i`: Refresh interval in seconds (default: 5)

**Example**:
```bash
shards health                    # Dashboard for all shards in current project
shards health feature-auth       # Specific shard health details
shards health --json             # JSON output for scripting
shards health --watch            # Live monitoring mode
```

### Destroy a Shard
```bash
shards destroy <branch>
```

Completely removes a specific shard. Use this when you're done with a shard.

What it does:
1. Closes the terminal window
2. Kills tracked process (validates PID to prevent reuse attacks)
3. Removes Git worktree and branch
4. Deletes session file (frees port range)

**When to use**: When you know which shard to remove. For orphaned/inconsistent resources, use `cleanup` instead.

### Cleanup Orphaned Resources
```bash
shards cleanup [--all] [--orphans] [--no-pid] [--stopped] [--older-than <days>]
```

Cleans up resources that got out of sync. Use this when things go wrong (crashes, manual deletions, etc.).

**Important distinction from `destroy`**:
- `destroy <branch>` = Remove a specific shard you know about
- `cleanup` = Find and remove orphaned/inconsistent resources

**Flags**:
- `--all`: Clean all orphaned resources (default behavior)
- `--orphans`: Clean worktrees in `~/.shards/worktrees/` that have no matching session file
- `--no-pid`: Clean sessions that have no PID tracking (failed spawns, old sessions)
- `--stopped`: Clean sessions where the process has stopped/crashed
- `--older-than <days>`: Clean sessions older than N days

**When to use each flag**:
- After a crash or force-quit: `shards cleanup --stopped`
- After manually deleting worktrees: `shards cleanup --orphans`
- Cleaning up old forgotten shards: `shards cleanup --older-than 7`
- General housekeeping: `shards cleanup` or `shards cleanup --all`

**Example**:
```bash
shards cleanup                   # Clean all orphaned resources
shards cleanup --orphans         # Clean worktrees with no session
shards cleanup --stopped         # Clean sessions with dead processes
shards cleanup --older-than 7    # Clean sessions older than 7 days
```

## Configuration

Hierarchical TOML config (later overrides earlier):
1. Hardcoded defaults
2. User config: `~/.shards/config.toml`
3. Project config: `./shards/config.toml`
4. CLI flags

**Example config**:
```toml
[agent]
default = "kiro"
startup_command = "kiro-cli chat"
flags = ""

[terminal]
preferred = "iterm2"

[agents.claude]
startup_command = "claude"
flags = "--yolo"
```

## When to Use Shards

**Perfect for**:
- Parallel feature development with multiple AI agents
- Isolated bug fixes without context switching
- Experimentation in separate environments
- Agent collaboration on different parts of a project

**Not suitable for**:
- Single-threaded development (use main branch)
- Non-Git projects (requires Git repository)
- Shared working directory needs

## Key Features

**Process Tracking**: Captures PID, process name, and start time at spawn. Validates identity before killing to prevent PID reuse attacks.

**Port Allocation**: Each shard gets unique port range (default: 10 ports from base 3000). Automatically freed on destroy.

**Session Persistence**: File-based storage in `~/.shards/sessions/<project-id>_<branch>.json` with all metadata for lifecycle management.

**Cross-Platform**: Works on macOS, Linux, and Windows with native terminal integration.

## Best Practices

**Naming**: Use descriptive branch names
- `feature-auth`, `bug-fix-123`, `refactor-api`
- Include issue numbers: `issue-456`, `ticket-789`
- Use agent prefixes: `kiro-debugging`, `claude-review`

**Lifecycle**: Always destroy shards when done to clean up resources

**Recovery**: Use `shards cleanup` after crashes or manual deletions

## Architecture Notes

- **Vertical slice architecture**: Features organized by domain
- **Handler/Operations pattern**: I/O separate from business logic
- **Structured logging**: JSON events for debugging
- **File-based persistence**: No database required

## Requirements

- Must run from within a Git repository
- Native terminal emulator required
- Rust 1.89.0+ for building from source

---

## E2E Testing Guide

Use `/shards e2e` or `/shards test` to run a full end-to-end test of the CLI. This should be run after every merge to main to verify the CLI works correctly.

### Running E2E Tests

When the user asks to run e2e tests, run shards e2e, or test the CLI:

1. **Build the release binary first**
   ```bash
   cargo build --release --bin shards
   ```

2. **Run through the full lifecycle** using `./target/release/shards` (not cargo run)

### Test Sequence

Execute these tests in order. After each command, verify the expected output. If something fails, investigate and fix before continuing.

#### Phase 1: Clean State Verification
```bash
./target/release/shards list
```
**Expected**: Either "No active shards found." or a table of existing shards. Note any existing shards - they should not be affected by our tests.

#### Phase 2: Create a Test Shard
```bash
./target/release/shards create e2e-test-shard --agent claude
```
**Expected**:
- ✅ Success message
- Branch: `e2e-test-shard`
- Worktree path shown
- Port range allocated (e.g., 3000-3009)
- A new Ghostty terminal window opens with Claude

**If it fails**: Check if branch already exists (`git branch -a | grep e2e-test`), check disk space, check if in a git repo.

#### Phase 3: Verify Shard Appears in List
```bash
./target/release/shards list
```
**Expected**: Table shows `e2e-test-shard` with:
- Agent: claude
- Status: active
- Process: Running with a PID

#### Phase 4: Check Detailed Status
```bash
./target/release/shards status e2e-test-shard
```
**Expected**: Detailed box showing:
- Branch, Agent, Status
- Worktree path exists
- Process is Running with PID
- Process Name: claude

#### Phase 5: Health Check (All Shards)
```bash
./target/release/shards health
```
**Expected**: Health dashboard table with:
- Status icon (✅ for Working)
- CPU and Memory metrics
- Summary line showing totals

#### Phase 6: Health Check (Single Shard)
```bash
./target/release/shards health e2e-test-shard
```
**Expected**: Detailed health box for just this shard

#### Phase 7: Test Cleanup --orphans Flag
```bash
./target/release/shards cleanup --orphans
```
**Expected**: "No orphaned resources found" (since our shard has a valid session)

#### Phase 8: Restart the Shard
```bash
./target/release/shards restart e2e-test-shard
```
**Expected**:
- ✅ Success message
- Agent process restarted
- Terminal window may flash/reload

#### Phase 9: Restart with Different Agent (Optional)
```bash
./target/release/shards restart e2e-test-shard --agent kiro
```
**Expected**: Shard now running with kiro agent instead of claude
**Note**: Skip if kiro is not installed

#### Phase 10: Destroy the Test Shard
```bash
./target/release/shards destroy e2e-test-shard
```
**Expected**:
- ✅ Success message
- Terminal window closes
- Worktree removed

#### Phase 11: Verify Clean State
```bash
./target/release/shards list
```
**Expected**: `e2e-test-shard` no longer appears. Only shards that existed before the test remain.

### Edge Case Tests

Run these after the main sequence to test error handling:

#### Edge Case 1: Create Duplicate Shard
```bash
./target/release/shards create edge-test --agent claude
./target/release/shards create edge-test --agent claude
```
**Expected**: Second create should fail with "already exists" error
**Cleanup**: `./target/release/shards destroy edge-test`

#### Edge Case 2: Destroy Non-existent Shard
```bash
./target/release/shards destroy this-does-not-exist
```
**Expected**: Error message indicating shard not found

#### Edge Case 3: Status of Non-existent Shard
```bash
./target/release/shards status this-does-not-exist
```
**Expected**: Error message indicating shard not found

#### Edge Case 4: Invalid Agent
```bash
./target/release/shards create invalid-agent-test --agent not-a-real-agent
```
**Expected**: Error about invalid agent type

#### Edge Case 5: Cleanup When Nothing to Clean
```bash
./target/release/shards cleanup --stopped
```
**Expected**: "No orphaned resources found" message

#### Edge Case 6: Health with JSON Output
```bash
./target/release/shards health --json
```
**Expected**: Valid JSON output that can be parsed

### Test Report

After running all tests, summarize:

| Test | Status | Notes |
|------|--------|-------|
| Build | ✅/❌ | |
| List (empty) | ✅/❌ | |
| Create | ✅/❌ | |
| List (with shard) | ✅/❌ | |
| Status | ✅/❌ | |
| Health (all) | ✅/❌ | |
| Health (single) | ✅/❌ | |
| Cleanup --orphans | ✅/❌ | |
| Restart | ✅/❌ | |
| Destroy | ✅/❌ | |
| List (clean) | ✅/❌ | |
| Edge cases | ✅/❌ | |

**All tests must pass before considering a merge successful.**

### Troubleshooting

**Terminal doesn't open**: Check if Ghostty is installed, try `--terminal iterm` or `--terminal terminal`

**Process not tracked**: PID file may not have been written. Check `~/.shards/pids/`

**Worktree already exists**: Run `git worktree list` and `git worktree prune`

**Port conflict**: Another shard may be using the ports. Run `shards list` to check

**Structured logging noise**: The JSON log lines are expected. Look for the human-readable output (✅ messages, tables)
