# Feature: Configuration Management (Config Track)

## Summary

Implement hierarchical TOML configuration system for Shards CLI that allows users to configure default agents, terminal preferences, startup commands, and flags. Configuration loads from user home (~/.shards/config.toml) with project-level overrides (./shards/config.toml) and CLI argument overrides.

## User Story

As a developer using Shards CLI
I want to configure my preferred agents, terminals, and startup commands in config files
So that I don't have to specify the same options repeatedly and can customize behavior per project

## Problem Statement

Currently, users must specify agent type, terminal preferences, and startup commands every time they create a shard. There's no way to set defaults or customize agent startup strings and flags, leading to repetitive CLI usage and inability to use custom agent configurations like YOLO mode flags.

## Solution Statement

Create a hierarchical TOML configuration system with three levels: user defaults (~/.shards/config.toml), project overrides (./shards/config.toml), and CLI argument overrides. Support agent-specific startup commands and flags, terminal preferences, and extensible configuration structure.

## Metadata

| Field            | Value                                             |
| ---------------- | ------------------------------------------------- |
| Type             | NEW_CAPABILITY                                    |
| Complexity       | MEDIUM                                            |
| Systems Affected | cli, core, sessions, terminal                     |
| Dependencies     | toml 0.8, serde 1.0 (already present)           |
| Estimated Tasks  | 8                                                 |

---

## UX Design

### Before State
```
┌─────────────────┐         ┌─────────────────┐         ┌─────────────────┐
│   User runs     │ ──────► │   Must specify  │ ──────► │   Creates shard │
│   shards create │         │   --agent every │         │   with defaults │
│   my-branch     │         │   time          │         │                 │
└─────────────────┘         └─────────────────┘         └─────────────────┘

USER_FLOW: shards create branch --agent claude (repeat for every shard)
PAIN_POINT: No way to set defaults, customize agent commands, or use flags
DATA_FLOW: CLI args → hardcoded defaults → session creation
```

### After State
```
┌─────────────────┐         ┌─────────────────┐         ┌─────────────────┐
│   User runs     │ ──────► │   Loads config  │ ──────► │   Creates shard │
│   shards create │         │   hierarchy     │         │   with custom   │
│   my-branch     │         │   (user+project)│         │   agent & flags │
└─────────────────┘         └─────────────────┘         └─────────────────┘
                                     │
                                     ▼
                            ┌─────────────────┐
                            │ Config files    │  ◄── ~/.shards/config.toml
                            │ define defaults │      ./shards/config.toml
                            └─────────────────┘

USER_FLOW: shards create branch (uses configured defaults automatically)
VALUE_ADD: Set once, use everywhere; project-specific overrides; custom flags
DATA_FLOW: Config files → CLI args → merged config → session creation
```

### Interaction Changes
| Location        | Before          | After       | User_Action | Impact        |
| --------------- | --------------- | ----------- | ----------- | ------------- |
| CLI create      | Must specify --agent | Optional --agent | shards create branch | Uses configured default |
| Agent startup   | Hardcoded "claude" | Custom command+flags | Config: startup_command = "cc --yolo" | Launches with flags |
| Terminal choice | System default | Configurable | Config: terminal = "iterm2" | Uses preferred terminal |

---

## Mandatory Reading

**CRITICAL: Implementation agent MUST read these files before starting any task:**

| Priority | File | Lines | Why Read This |
|----------|------|-------|---------------|
| P0 | `src/core/config.rs` | 1-50 | Existing config pattern to EXTEND |
| P0 | `src/cli/app.rs` | 1-100 | CLI structure to MODIFY for new args |
| P1 | `src/sessions/types.rs` | 1-80 | Session types to UNDERSTAND |
| P1 | `src/terminal/handler.rs` | 1-50 | Terminal spawning to MODIFY |
| P2 | `Cargo.toml` | 1-20 | Dependencies already available |

**External Documentation:**
| Source | Section | Why Needed |
|--------|---------|------------|
| [TOML Spec v1.0](https://toml.io/en/v1.0.0) | Basic syntax | Configuration file format |
| [Serde TOML docs](https://docs.rs/toml/latest/toml/) | Deserialization | Parsing TOML files |

---

## Patterns to Mirror

**CONFIG_STRUCTURE:**
```rust
// SOURCE: src/core/config.rs:5-25
// EXTEND THIS PATTERN:
#[derive(Debug, Clone)]
pub struct Config {
    pub shards_dir: PathBuf,
    pub log_level: String,
}

impl Default for Config {
    fn default() -> Self {
        let home_dir = dirs::home_dir().expect("Could not find home directory");
        Self {
            shards_dir: home_dir.join(".shards"),
            log_level: std::env::var("SHARDS_LOG_LEVEL").unwrap_or_else(|_| "info".to_string()),
        }
    }
}
```

**ERROR_HANDLING:**
```rust
// SOURCE: src/sessions/errors.rs:5-20
// COPY THIS PATTERN:
#[derive(Debug, thiserror::Error)]
pub enum SessionError {
    #[error("Session '{name}' already exists")]
    AlreadyExists { name: String },
    
    #[error("Session '{name}' not found")]
    NotFound { name: String },
}
```

**CLI_ARGUMENT_PARSING:**
```rust
// SOURCE: src/cli/app.rs:15-35
// MIRROR THIS PATTERN:
.arg(
    Arg::new("agent")
        .long("agent")
        .short('a')
        .help("AI agent to launch")
        .value_parser(["claude", "kiro", "gemini", "codex"])
        .default_value("claude")
)
```

**LOGGING_PATTERN:**
```rust
// SOURCE: src/terminal/handler.rs:10-15
// COPY THIS PATTERN:
info!(
    event = "terminal.spawn_started",
    working_directory = %working_directory.display(),
    command = command
);
```

**SERDE_DESERIALIZATION:**
```rust
// SOURCE: src/sessions/types.rs:5-15
// MIRROR THIS PATTERN:
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Session {
    pub id: String,
    pub project_id: String,
    pub branch: String,
}
```

---

## Files to Change

| File                             | Action | Justification                            |
| -------------------------------- | ------ | ---------------------------------------- |
| `Cargo.toml`                     | UPDATE | Add toml dependency                      |
| `src/core/config.rs`             | UPDATE | Extend existing config with TOML support |
| `src/core/errors.rs`             | UPDATE | Add config-specific error types          |
| `src/cli/app.rs`                 | UPDATE | Add config override CLI arguments        |
| `src/cli/commands.rs`            | UPDATE | Use merged config in command handlers    |
| `src/sessions/handler.rs`        | UPDATE | Accept config parameter for agent setup  |
| `src/terminal/handler.rs`        | UPDATE | Use configured terminal preference       |
| `src/core/mod.rs`                | UPDATE | Export new config types                  |

---

## NOT Building (Scope Limits)

Explicit exclusions to prevent scope creep:

- GUI configuration interface - CLI and file-based only
- Runtime config reloading - requires restart to pick up changes
- Config validation beyond basic TOML parsing - keep simple
- Agent installation/management - only configure existing agents
- Complex config templating or inheritance - flat hierarchy only

---

## Step-by-Step Tasks

Execute in order. Each task is atomic and independently verifiable.

### Task 1: UPDATE `Cargo.toml` (add dependency)

- **ACTION**: ADD toml dependency to existing dependencies
- **IMPLEMENT**: Add `toml = "0.8"` to [dependencies] section
- **MIRROR**: Existing dependency format in Cargo.toml:5-15
- **IMPORTS**: No imports needed, just dependency declaration
- **GOTCHA**: Use toml 0.8 (latest stable), not 0.7 or 1.0-beta
- **VALIDATE**: `cargo check` - dependency must resolve

### Task 2: UPDATE `src/core/config.rs` (extend config structure)

- **ACTION**: EXTEND existing Config struct with TOML support
- **IMPLEMENT**: Add agent configs, terminal prefs, hierarchical loading
- **MIRROR**: `src/core/config.rs:5-25` - extend existing pattern
- **IMPORTS**: `use serde::{Deserialize, Serialize}; use toml; use std::collections::HashMap`
- **TYPES**: `AgentConfig`, `TerminalConfig`, `ShardsConfig` structs
- **GOTCHA**: Keep existing fields for backward compatibility
- **VALIDATE**: `cargo check` - types must compile

### Task 3: UPDATE `src/core/errors.rs` (add config errors)

- **ACTION**: ADD config-specific error variants to existing error types
- **IMPLEMENT**: ConfigNotFound, ConfigParseError, InvalidAgent errors
- **MIRROR**: `src/sessions/errors.rs:5-20` - follow existing error pattern
- **PATTERN**: Use thiserror, include context, implement ShardsError trait
- **VALIDATE**: `cargo check` - error types must compile

### Task 4: CREATE config loading operations

- **ACTION**: CREATE config file loading and merging logic
- **IMPLEMENT**: load_user_config(), load_project_config(), merge_configs()
- **MIRROR**: `src/core/config.rs:25-50` - follow existing config pattern
- **IMPORTS**: `use std::fs; use std::path::Path`
- **GOTCHA**: Handle missing files gracefully (not an error)
- **VALIDATE**: `cargo check && cargo test src/core/config`

### Task 5: UPDATE `src/cli/app.rs` (add config override args)

- **ACTION**: ADD CLI arguments for config overrides
- **IMPLEMENT**: --agent, --terminal, --startup-command, --flags arguments
- **MIRROR**: `src/cli/app.rs:15-35` - follow existing arg pattern
- **PATTERN**: Use .long(), .short(), .help(), optional values
- **GOTCHA**: Make all config args optional (overrides only)
- **VALIDATE**: `cargo check && cargo test src/cli/app`

### Task 6: UPDATE `src/cli/commands.rs` (use merged config)

- **ACTION**: MODIFY command handlers to load and use config
- **IMPLEMENT**: Load config hierarchy, merge with CLI args, pass to handlers
- **MIRROR**: `src/cli/commands.rs:15-30` - follow existing command pattern
- **IMPORTS**: `use crate::core::config::ShardsConfig`
- **PATTERN**: Load config early, merge with CLI args, pass to session handler
- **VALIDATE**: `cargo check && cargo test src/cli/commands`

### Task 7: UPDATE `src/sessions/handler.rs` (accept config parameter)

- **ACTION**: MODIFY create_session to accept and use config
- **IMPLEMENT**: Use config for agent selection, startup commands, flags
- **MIRROR**: `src/sessions/handler.rs:10-30` - follow existing handler pattern
- **IMPORTS**: `use crate::core::config::ShardsConfig`
- **PATTERN**: Accept config param, use for agent setup, maintain logging
- **VALIDATE**: `cargo check && cargo test src/sessions/handler`

### Task 8: UPDATE `src/terminal/handler.rs` (use terminal config)

- **ACTION**: MODIFY spawn_terminal to use configured terminal preference
- **IMPLEMENT**: Check config for terminal preference before detection
- **MIRROR**: `src/terminal/handler.rs:10-25` - follow existing spawn pattern
- **IMPORTS**: `use crate::core::config::TerminalConfig`
- **PATTERN**: Config override → detection fallback → spawn
- **VALIDATE**: `cargo check && cargo test src/terminal/handler`

---

## Testing Strategy

### Unit Tests to Write

| Test File                                | Test Cases                 | Validates      |
| ---------------------------------------- | -------------------------- | -------------- |
| `src/core/config/tests.rs`              | TOML parsing, merging      | Config loading |
| `src/core/errors/tests.rs`              | Config error variants      | Error handling |
| `src/cli/app/tests.rs`                  | Config override args       | CLI parsing    |

### Edge Cases Checklist

- [ ] Missing config files (should use defaults)
- [ ] Invalid TOML syntax (should error gracefully)
- [ ] Unknown agent names (should error with suggestions)
- [ ] Empty startup commands (should use defaults)
- [ ] Conflicting CLI args and config (CLI wins)
- [ ] Non-existent terminal preference (fallback to detection)

---

## Validation Commands

### Level 1: STATIC_ANALYSIS

```bash
cargo check && cargo clippy -- -D warnings
```

**EXPECT**: Exit 0, no errors or warnings

### Level 2: UNIT_TESTS

```bash
cargo test src/core/config && cargo test src/cli
```

**EXPECT**: All tests pass, config loading works

### Level 3: FULL_SUITE

```bash
cargo test && cargo build --release
```

**EXPECT**: All tests pass, binary builds successfully

### Level 4: INTEGRATION_VALIDATION

```bash
# Test config file loading
mkdir -p ~/.shards && echo '[agent]\ndefault = "kiro"' > ~/.shards/config.toml
./target/release/shards create test-branch
```

**EXPECT**: Uses kiro agent from config, not hardcoded claude

### Level 5: CLI_OVERRIDE_VALIDATION

```bash
# Test CLI override of config
./target/release/shards create test-branch2 --agent claude
```

**EXPECT**: Uses claude despite config default of kiro

### Level 6: MANUAL_VALIDATION

1. Create user config: `~/.shards/config.toml` with agent defaults
2. Create project config: `./shards/config.toml` with different agent
3. Run `shards create test` - should use project config
4. Run `shards create test2 --agent gemini` - should use CLI override
5. Verify startup commands include configured flags

---

## Acceptance Criteria

- [ ] User can set default agent in `~/.shards/config.toml`
- [ ] Project can override user defaults in `./shards/config.toml`
- [ ] CLI arguments override both config files
- [ ] Agent startup commands are configurable with flags
- [ ] Terminal preference is configurable
- [ ] Invalid config shows helpful error messages
- [ ] Missing config files use sensible defaults
- [ ] All existing functionality continues to work

---

## Completion Checklist

- [ ] All tasks completed in dependency order
- [ ] Each task validated immediately after completion
- [ ] Level 1: `cargo check && cargo clippy` passes
- [ ] Level 2: `cargo test src/core/config src/cli` passes
- [ ] Level 3: `cargo test && cargo build --release` succeeds
- [ ] Level 4: Config file loading integration works
- [ ] Level 5: CLI override functionality works
- [ ] All acceptance criteria met

---

## Risks and Mitigations

| Risk               | Likelihood   | Impact       | Mitigation                              |
| ------------------ | ------------ | ------------ | --------------------------------------- |
| TOML parsing errors | MEDIUM | MEDIUM | Graceful error handling with helpful messages |
| Config file conflicts | LOW | LOW | Clear hierarchy: CLI > project > user |
| Agent command failures | MEDIUM | HIGH | Validate commands exist before spawning |
| Backward compatibility | LOW | HIGH | Keep existing CLI behavior as fallback |

---

## Notes

**Configuration Hierarchy**: CLI args > ./shards/config.toml > ~/.shards/config.toml > hardcoded defaults

**Agent Command Examples**:
- Claude: `claude` or `cc --yolo` 
- Kiro: `kiro-cli chat`
- Gemini: `gemini --yolo`
- Codex: `codex`
- Aether: `aether`

**TOML Structure**:
```toml
[agent]
default = "claude"
startup_command = "cc"
flags = "--yolo"

[terminal]
preferred = "iterm2"

[agents.claude]
startup_command = "claude"
flags = "--yolo"

[agents.kiro]
startup_command = "kiro-cli chat"
flags = ""
```

**Future Extensions**: This design allows easy addition of new config sections (git, logging, etc.) without breaking changes.
