---
name: shards
description: |
  Create and manage parallel AI development sessions in isolated Git worktrees.

  TRIGGERS - Use this skill when user says:
  - Creating: "create a shard", "spin up shards", "new shard for", "create worktrees"
  - Listing: "list shards", "show shards", "active shards", "shards list"
  - Status: "shard status", "check shard", "shard health", "how are my shards"
  - Navigation: "cd to shard", "go to shard", "path to shard", "open in editor", "edit shard", "code shard"
  - Lifecycle: "stop shard", "open shard", "destroy shard", "clean up shards"
  - Output: "list as json", "json output", "quiet mode"

  Shards creates isolated Git worktrees where AI agents work independently without
  affecting your main branch. Each shard gets its own terminal window, port range,
  and process tracking.

  IMPORTANT: Always use defaults from user's config. Only specify --agent, --terminal,
  or --flags when the user explicitly requests a different value.

  EXAMPLES

  User says "Create a shard for the auth feature"
  Command - shards create feature-auth
  Result - Creates worktree using default agent from config, opens in default terminal

  User says "Create a shard with kiro instead"
  Command - shards create feature-auth --agent kiro
  Result - Overrides default agent with kiro

  User says "Show me all active shards"
  Command - shards list
  Result - Table showing branch, agent, status, note, ports, and process info

  User says "Open the auth shard in my editor"
  Command - shards code feature-auth
  Result - Opens worktree in user's default editor ($EDITOR or zed)

  User says "Go to the auth shard directory"
  Command - shards cd feature-auth
  Result - Prints path for shell integration: /Users/x/.shards/worktrees/project/feature-auth

allowed-tools: Bash, Read, Glob, Grep
---

# Shards CLI - Parallel AI Development Manager

Shards creates isolated Git worktrees for parallel AI development sessions. Each shard runs in its own workspace with dedicated port ranges and process tracking.

## Important: Use Defaults

**Always use the user's configured defaults.** Users set their preferences in config files:
- `~/.shards/config.toml` (user-level)
- `./.shards/config.toml` (project-level)

**DO NOT specify `--agent`, `--terminal`, or `--flags` unless the user explicitly asks to override.**

```bash
# CORRECT - use defaults
shards create feature-auth

# CORRECT - user asked for kiro specifically
shards create feature-auth --agent kiro

# WRONG - don't assume agent
shards create feature-auth --agent claude
```

**When to override:**
- User says "use kiro" → add `--agent kiro`
- User says "use iTerm" → add `--terminal iterm`
- User says "with trust all tools" → add `--flags '--trust-all-tools'`

## Core Commands

### Create a Shard
```bash
shards create <branch> [--agent <agent>] [--terminal <terminal>] [--flags <flags>] [--note <note>]
```

Creates an isolated workspace with:
- New Git worktree in `~/.shards/worktrees/<project>/<branch>/`
- Unique port range (10 ports, starting from 3000)
- Native terminal with AI agent launched
- Process tracking (PID, name, start time)
- Session metadata saved to `~/.shards/sessions/`

**Supported agents** - claude, kiro, gemini, codex, aether
**Supported terminals** - ghostty, iterm, terminal, native

**Examples**
```bash
# Basic - uses defaults from config
shards create feature-auth
# Result: Creates shard with default agent/terminal from config

# With description
shards create feature-auth --note "Implementing JWT authentication"
# Result: Creates shard with note shown in list/status output

# Override agent (only when user requests)
shards create feature-auth --agent kiro
# Result: Uses kiro instead of default agent

# Override terminal (only when user requests)
shards create feature-auth --terminal iterm
# Result: Opens in iTerm instead of default terminal
```

### List All Shards
```bash
shards list [--json]
```

Shows table with branch, agent, status, timestamps, port range, process status, command, and note.

**Examples**
```bash
# Human-readable table
shards list
# Result: Formatted table with all shard info

# JSON for scripting
shards list --json
# Result: JSON array of session objects

# Filter with jq
shards list --json | jq '.[] | select(.status == "Active") | .branch'
# Result: List of active branch names
```

### Status (Detailed View)
```bash
shards status <branch> [--json]
```

Shows detailed info for a specific shard including worktree path, process metadata, port allocation, and note.

**Examples**
```bash
# Human-readable
shards status feature-auth
# Result: Detailed status box with all shard info

# JSON for scripting
shards status feature-auth --json
# Result: JSON object with full session data
```

### Print Worktree Path (Shell Integration)
```bash
shards cd <branch>
```

Prints the worktree path for shell integration. Use with shell wrapper for actual directory change.

**Examples**
```bash
# Print path
shards cd feature-auth
# Result: /Users/x/.shards/worktrees/project/feature-auth

# Shell integration (user adds to .zshrc/.bashrc)
scd() { cd "$(shards cd "$1")" }

# Then use:
scd feature-auth
# Result: Actually changes directory to the worktree
```

### Open in Editor
```bash
shards code <branch> [--editor <editor>]
```

Opens the shard's worktree in the user's editor. Priority: `--editor` flag > `$EDITOR` env var > "zed" default.

**Examples**
```bash
# Use default editor
shards code feature-auth
# Result: Opens worktree in $EDITOR or zed

# Override editor
shards code feature-auth --editor vim
# Result: Opens worktree in vim
```

### Open a New Agent in a Shard
```bash
shards open <branch> [--agent <agent>]
```

Opens a new agent terminal in an existing shard. This is **additive** - it doesn't close existing terminals, allowing multiple agents to work in the same shard.

**Examples**
```bash
# Reopen with default agent
shards open feature-auth
# Result: New terminal opens with default agent

# Open with different agent
shards open feature-auth --agent kiro
# Result: New terminal opens with kiro (original agent still running if any)
```

### Stop a Shard
```bash
shards stop <branch>
```

Stops the agent process and closes the terminal, but preserves the shard (worktree and uncommitted changes remain). Can be reopened later with `shards open`.

**Example**
```bash
shards stop feature-auth
# Result: Terminal closes, worktree preserved, status changes to "Stopped"
```

### Destroy a Shard
```bash
shards destroy <branch> [--force]
```

Completely removes a shard - closes terminal, kills process, removes worktree and branch, deletes session.

**Flags**
- `--force` / `-f` - Force destroy even with uncommitted changes (bypasses git safety checks)

**Examples**
```bash
# Normal destroy (blocks if uncommitted changes)
shards destroy feature-auth
# Result: Removes shard if clean

# Force destroy (bypasses git checks)
shards destroy feature-auth --force
# Result: Removes shard regardless of uncommitted changes
```

### Health Monitoring
```bash
shards health [branch] [--json] [--watch] [--interval <seconds>]
```

Shows health dashboard with process status, CPU/memory metrics, and summary statistics.

**Examples**
```bash
# Dashboard view
shards health
# Result: Table with CPU, memory, status for all shards

# Watch mode (auto-refresh)
shards health --watch --interval 5
# Result: Live dashboard updating every 5 seconds

# JSON output
shards health --json
# Result: JSON with health metrics
```

### Cleanup Orphaned Resources
```bash
shards cleanup [--all] [--orphans] [--no-pid] [--stopped] [--older-than <days>]
```

Cleans up resources that got out of sync (crashes, manual deletions, etc.).

**Flags**
- `--all` - Clean all orphaned resources (default)
- `--orphans` - Clean worktrees with no matching session
- `--no-pid` - Clean sessions without PID tracking
- `--stopped` - Clean sessions with dead processes
- `--older-than <days>` - Clean sessions older than N days

## Global Flags

### Quiet Mode
```bash
shards -q <command>
shards --quiet <command>
```

Suppresses JSON log output for clean, scriptable output.

**Examples**
```bash
# Normal (shows JSON logs)
shards list
# Result: JSON logs + table

# Quiet (clean output)
shards -q list
# Result: Just the table, no logs

# Useful for scripting
shards -q list --json | jq '.[] | .branch'
# Result: Clean JSON without log noise
```

## Configuration

Shards uses hierarchical TOML config. Later sources override earlier:

1. **Hardcoded defaults** - Built into shards
2. **User config** - `~/.shards/config.toml`
3. **Project config** - `./.shards/config.toml`
4. **CLI flags** - Always win

### Config File Structure

```toml
# ~/.shards/config.toml or ./.shards/config.toml

[agent]
default = "claude"  # Default agent for new shards

[terminal]
preferred = "ghostty"  # Default terminal: ghostty, iterm, terminal, native
spawn_delay_ms = 1000   # Wait time for terminal spawn
max_retry_attempts = 5  # Retries for PID capture

[ports]
base = 3000       # Starting port number
range_size = 10   # Ports per shard

[agents.claude]
command = "claude"
flags = "--dangerously-skip-permissions"  # Auto-apply these flags

[agents.kiro]
command = "kiro"
flags = "--trust-all-tools"

[agents.codex]
command = "codex"
flags = "--yolo"
```

### Helping Users with Config

If a user wants to change defaults, help them edit their config:

**User wants claude with auto-permissions by default:**
```toml
# ~/.shards/config.toml
[agent]
default = "claude"

[agents.claude]
flags = "--dangerously-skip-permissions"
```

**User wants to use iTerm instead of Ghostty:**
```toml
# ~/.shards/config.toml
[terminal]
preferred = "iterm"
```

**Project-specific agent:**
```toml
# ./.shards/config.toml (in project root)
[agent]
default = "kiro"  # This project uses kiro
```

## Autonomous Mode (YOLO / Trust All Tools)

Each agent has its own flag for skipping permission prompts. These should be set in config, not passed every time.

**Claude Code** - `--dangerously-skip-permissions`
**Kiro CLI** - `--trust-all-tools`
**Codex CLI** - `--yolo` or `--dangerously-bypass-approvals-and-sandbox`

**Recommended:** Set in config once:
```toml
[agents.claude]
flags = "--dangerously-skip-permissions"
```

Then just: `shards create feature-x` (flags auto-applied)

**Override only when needed:**
```bash
# User explicitly wants no flags this time
shards create feature-x --flags ''
```

## Key Features

- **Process Tracking** - Captures PID, process name, start time. Validates identity before killing.
- **Port Allocation** - Unique port range per shard (default 10 ports from base 3000).
- **Session Persistence** - File-based storage in `~/.shards/sessions/`
- **Session Notes** - Document what each shard is for with `--note`
- **JSON Output** - Scriptable output with `--json` flag
- **Quiet Mode** - Clean output with `-q` flag

## Best Practices

- Use descriptive branch names like `feature-auth`, `bug-fix-123`, `issue-456`
- Add notes to remember what each shard is for: `--note "Working on auth"`
- Always destroy shards when done to clean up resources
- Use `shards cleanup` after crashes or manual deletions
- Set your preferred defaults in `~/.shards/config.toml` once

## Additional Resources

- For installation and updating, see [cookbook/installation.md](cookbook/installation.md)
- For E2E testing, see [cookbook/e2e-testing.md](cookbook/e2e-testing.md)
