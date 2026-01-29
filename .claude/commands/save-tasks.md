# Save Task List for Reuse

Save the current session's task list so it can be reused in future sessions.

## Instructions

1. **Find the current task list ID** by looking at the scratchpad path or checking `~/.claude/tasks/` for the most recently modified directory.

2. **Make sure the recently modified directory matches** the most recently modified directory to find the task list, then make sur you use the corect task list by comparing to your on going or completed tasks.

3. **Ask the user for a name** if not provided as an argument. The name should be short and descriptive (e.g., `issue-124-refactor`, `feature-auth`, `bug-fix-123`).

4. **Optional: Rename the task directory**:

   ```bash
   mv ~/.claude/tasks/<current-uuid> ~/.claude/tasks/<user-provided-name>
   ```

5. **Verify the rename worked** by listing the files in the new directory.

6. **Output the startup command** for the user:

   ```
   To continue with this task list in a new session:

   CLAUDE_CODE_TASK_LIST_ID=<name> claude
   ```

7. **Show the current task summary** so the user knows what's preserved.

## Arguments

- `$ARGUMENTS` - Optional name for the task list. If not provided, ask the user.

## Example Usage

```
/save-tasks issue-124-appstate
```

This will:

- Rename the current task directory to `issue-124-appstate`
- Output: `CLAUDE_CODE_TASK_LIST_ID=issue-124-appstate claude`
