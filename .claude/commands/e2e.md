---
description: Run end-to-end tests for the Shards CLI after merges
allowed-tools: ["Bash", "Read"]
---

# Shards E2E Test Runner

Run a comprehensive end-to-end test of the Shards CLI. Use this after every merge to main to verify the CLI works correctly.

## Instructions

You are running an E2E test suite for the Shards CLI. Execute each phase in order, verify the expected output, and course-correct if something fails. Do not continue past a failure until it's investigated.

### Pre-flight

1. Ensure you're in the SHARDS repository root
2. Ensure you're on the main branch with latest changes
3. Build the release binary:
   ```bash
   cargo build --release --bin shards
   ```

### Phase 1: Clean State Check

Run `./target/release/shards list` and note any existing shards. These should not be affected by our tests.

### Phase 2: Full Lifecycle Test

Execute in order, verifying each step:

1. **Create**: `./target/release/shards create e2e-test-shard --agent claude`
   - Expect: Success, terminal opens, port range shown

2. **List**: `./target/release/shards list`
   - Expect: Table shows e2e-test-shard, status active, process running

3. **Status**: `./target/release/shards status e2e-test-shard`
   - Expect: Detailed info box, process running with PID

4. **Health (all)**: `./target/release/shards health`
   - Expect: Dashboard table, Working status, CPU/memory metrics

5. **Health (single)**: `./target/release/shards health e2e-test-shard`
   - Expect: Detailed health for just this shard

6. **Cleanup --orphans**: `./target/release/shards cleanup --orphans`
   - Expect: "No orphaned resources found" (shard has valid session)

7. **Restart**: `./target/release/shards restart e2e-test-shard`
   - Expect: Success, agent restarted

8. **Destroy**: `./target/release/shards destroy e2e-test-shard`
   - Expect: Success, terminal closes, worktree removed

9. **Verify clean**: `./target/release/shards list`
   - Expect: e2e-test-shard gone, only pre-existing shards remain

### Phase 3: Edge Cases

Test error handling:

1. **Destroy non-existent**: `./target/release/shards destroy fake-shard-xyz`
   - Expect: Error "not found"

2. **Status non-existent**: `./target/release/shards status fake-shard-xyz`
   - Expect: Error "not found"

3. **Cleanup with nothing to clean**: `./target/release/shards cleanup --stopped`
   - Expect: "No orphaned resources found"

4. **Health JSON output**: `./target/release/shards health --json`
   - Expect: Valid JSON (parse it to verify)

### Phase 4: Report

Create a summary table:

| Test | Status | Notes |
|------|--------|-------|
| Build | | |
| Create | | |
| List | | |
| Status | | |
| Health (all) | | |
| Health (single) | | |
| Cleanup --orphans | | |
| Restart | | |
| Destroy | | |
| Clean state | | |
| Edge: destroy fake | | |
| Edge: status fake | | |
| Edge: cleanup empty | | |
| Edge: health json | | |

Mark each as PASS or FAIL. If any FAIL, investigate before reporting.

### Troubleshooting

- **Terminal doesn't open**: Try `--terminal iterm` or `--terminal terminal`
- **PID not tracked**: Check `~/.shards/pids/` directory
- **Worktree exists**: Run `git worktree prune`
- **JSON log noise**: Normal - look for human-readable ✅ messages

### Success Criteria

All tests must pass. Report the final summary table to the user.
