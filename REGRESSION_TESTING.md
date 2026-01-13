# SHARDS Regression Testing

## Overview

The regression testing script (`scripts/regression-test.sh`) provides comprehensive testing of SHARDS functionality including:

- **Session Creation**: Tests different agent configurations and terminal types
- **Session Management**: Validates listing and info commands
- **Cleanup Functionality**: Tests individual session cleanup and global cleanup
- **Error Handling**: Ensures proper cleanup even when tests fail

## Usage

### Basic Usage
```bash
# Run all regression tests
./scripts/regression-test.sh

# Show help
./scripts/regression-test.sh --help

# Dry run (show what would be tested)
./scripts/regression-test.sh --dry-run
```

### Test Configurations

The script tests these agent/terminal combinations:

| Configuration | Agent Command | Terminal Type | Purpose |
|---------------|---------------|---------------|---------|
| `claude-native` | `claude` | `native` | Test Claude Code with system default terminal |
| `codex-iterm2` | `codex` | `iterm2` | Test Codex with iTerm2 terminal |
| `kiro-ghostty` | `kiro-cli chat --trust-all-tools` | `ghostty` | Test Kiro CLI with Ghostty terminal |
| `gemini-terminal` | `gemini` | `terminal` | Test Gemini with Terminal.app |

## Test Phases

### Phase 1: Session Creation
- Creates test sessions with different agent configurations
- Validates that each session is created successfully
- Tests different terminal launching mechanisms

### Phase 2: Session Management
- Tests `shards list` command functionality
- Validates `shards info <session>` for each created session
- Ensures all test sessions appear in listings

### Phase 3: Cleanup Functionality
- Tests `shards destroy <session>` for individual cleanup
- Validates worktree directory removal
- Checks git branch cleanup
- Verifies session removal from registry

### Phase 4: Final Verification
- Tests `shards cleanup` command for orphaned sessions
- Ensures no test artifacts remain after cleanup
- Validates complete system state reset

## Safety Features

### Automatic Cleanup
- All test sessions are automatically cleaned up on script exit
- Test branches are removed from both local and remote repositories
- Cleanup occurs even if tests fail or script is interrupted

### Unique Naming
- Test sessions use timestamped names to avoid conflicts
- Format: `regression-test-<config>-<timestamp>`
- Prevents interference with existing sessions

### Error Handling
- Script continues testing even if individual tests fail
- Comprehensive error reporting with colored output
- Graceful handling of missing dependencies

## Expected Output

```bash
[15:30:01] Starting SHARDS regression tests...
[15:30:01] Building SHARDS...
✅ Build successful
[15:30:02] === Phase 1: Testing Session Creation ===
[15:30:02] Testing session creation: claude-native
✅ Session created successfully: regression-test-claude-native-20260113-153002
[15:30:05] Testing session creation: codex-iterm2
✅ Session created successfully: regression-test-codex-iterm2-20260113-153002
...
✅ All session creation tests passed
[15:30:15] === Phase 2: Testing Session Management ===
✅ Session listing works
✅ Found session in list: regression-test-claude-native-20260113-153002
...
✅ Regression tests completed!
```

## Troubleshooting

### Common Issues

**Build Failures**
```bash
# Ensure dependencies are installed
cargo check
```

**Terminal Launch Issues**
```bash
# Check if terminals are installed
which ghostty
which iterm2
```

**Permission Issues**
```bash
# Ensure script is executable
chmod +x scripts/regression-test.sh
```

### Manual Cleanup

If the script fails and leaves test artifacts:

```bash
# List any remaining test sessions
cargo run -- list | grep regression-test

# Clean up manually
cargo run -- cleanup

# Remove test branches
git branch | grep regression-test | xargs git branch -D
```

## Integration with CI/CD

The regression test can be integrated into automated workflows:

```yaml
# Example GitHub Actions step
- name: Run Regression Tests
  run: ./scripts/regression-test.sh
```

## Extending Tests

To add new test configurations, modify the `AGENT_CONFIGS` array in the script:

```bash
declare -A AGENT_CONFIGS=(
    ["claude-native"]="claude:native"
    ["new-agent"]="new-command:terminal-type"
)
```

## Performance Notes

- Full regression test takes approximately 2-3 minutes
- Each session creation includes a 2-second delay for stability
- Terminal launching may take additional time depending on system performance
- Cleanup operations are performed sequentially for reliability
