---
description: Run comprehensive code review using specialized agents in parallel
---

# Comprehensive Code Review

## First Step: Get Review Scope

Ask the user: "What would you like to review? Options: PR number (e.g., '123'), 'diff' for current unstaged changes, 'staged' for staged changes, or 'branch' for current branch vs main"

---

## Your Mission

Orchestrate a comprehensive code review by spawning specialized agents in parallel, then synthesizing their findings into an actionable report.

---

## Phase 1: DETERMINE SCOPE

Based on user's response, determine the review scope:

| User Input | Scope Type | Command to Get Changes |
|------------|------------|------------------------|
| Number (e.g., `123`) | PR Review | `gh pr diff 123` and `gh pr view 123` |
| `diff` | Unstaged Changes | `git diff` |
| `staged` | Staged Changes | `git diff --staged` |
| `branch` | Branch vs Main | `git diff main...HEAD` |

**First, verify the scope exists:**

```bash
# For PR: Check PR exists
gh pr view [number] --json title,state

# For diff/staged/branch: Check there are changes
git diff [options] --stat
```

**If no changes found, inform user and stop.**

---

## Phase 2: SPAWN REVIEW AGENTS IN PARALLEL

**CRITICAL: Spawn ALL applicable agents simultaneously using subagents.**

For each agent, provide clear instructions including:
1. The exact scope (PR number or diff command)
2. What to analyze
3. Expected output format

### Agents to Spawn

**Always spawn these 4 core agents in parallel:**

1. **code-reviewer** - General code quality and guidelines
   ```
   Review scope: [PR #{number} | current diff | staged changes | branch diff]

   Get changes with: [gh pr diff {number} | git diff | git diff --staged | git diff main...HEAD]

   Analyze the actual code changes for:
   - Project guidelines compliance
   - Bug detection (logic errors, null handling)
   - Code quality issues

   Return findings with file:line references and confidence scores.
   ```

2. **comment-analyzer** - Documentation and comment quality
   ```
   Review scope: [PR #{number} | current diff | staged changes | branch diff]

   Get changes with: [command]

   Analyze comments and documentation in the actual changes for:
   - Factual accuracy vs code
   - Completeness and value
   - Misleading or outdated content

   Return findings with specific locations and suggestions.
   ```

3. **error-hunter** - Silent failures and error handling
   ```
   Review scope: [PR #{number} | current diff | staged changes | branch diff]

   Get changes with: [command]

   Hunt for error handling issues in the actual changes:
   - Silent failures and empty catch blocks
   - Inadequate error messages
   - Missing error logging
   - Overly broad exception catching

   Return findings with severity levels and fix suggestions.
   ```

4. **type-analyzer** - Type design and safety
   ```
   Review scope: [PR #{number} | current diff | staged changes | branch diff]

   Get changes with: [command]

   Analyze type definitions and usage in the actual changes:
   - Invariant strength and enforcement
   - Encapsulation quality
   - Type safety issues

   Return ratings and specific improvement suggestions.
   ```

**Optionally spawn if relevant:**

5. **test-analyzer** - Test coverage (if test files are changed or new functionality added)
   ```
   Review scope: [PR #{number} | current diff | staged changes | branch diff]

   Get changes with: [command]

   Analyze test coverage for the actual changes:
   - Critical gaps in coverage
   - Test quality and maintainability
   - Missing edge cases

   Return prioritized test recommendations.
   ```

---

## Phase 3: WAIT AND COLLECT

Wait for all spawned agents to complete and collect their reports.

**Track progress:**
- [ ] code-reviewer complete
- [ ] comment-analyzer complete
- [ ] error-hunter complete
- [ ] type-analyzer complete
- [ ] test-analyzer complete (if spawned)

---

## Phase 4: SYNTHESIZE REPORT

Combine all agent findings into a unified report.

### Report Structure

```markdown
# Code Review Report

**Scope**: [PR #X | Current Diff | Staged Changes | Branch Diff]
**Date**: [YYYY-MM-DD HH:MM]
**Agents**: code-reviewer, comment-analyzer, error-hunter, type-analyzer[, test-analyzer]

---

## Executive Summary

**Overall Assessment**: [APPROVED / NEEDS CHANGES / BLOCKED]
**Risk Level**: [LOW / MEDIUM / HIGH / CRITICAL]
**Recommendation**: [Ready to merge / Fix issues first / Major rework needed]

---

## Critical Issues (Must Fix)

| # | Source | Issue | Location | Fix |
|---|--------|-------|----------|-----|
| 1 | [agent] | [description] | `file:line` | [suggestion] |

---

## Important Issues (Should Fix)

| # | Source | Issue | Location | Fix |
|---|--------|-------|----------|-----|
| 1 | [agent] | [description] | `file:line` | [suggestion] |

---

## Suggestions (Nice to Have)

| # | Source | Suggestion | Location |
|---|--------|------------|----------|
| 1 | [agent] | [description] | `file:line` |

---

## Agent Summaries

### Code Quality (code-reviewer)
[Summary of findings]

### Documentation (comment-analyzer)
[Summary of findings]

### Error Handling (error-hunter)
[Summary of findings]

### Type Design (type-analyzer)
[Summary of findings]

### Test Coverage (test-analyzer)
[Summary if applicable]

---

## Strengths

- [What's well-done in this code]

---

## Next Steps

1. [Prioritized action items]
2. [...]
```

---

## Phase 5: SAVE AND POST

### 5.1 Save Report

```bash
mkdir -p .kiro/artifacts/code-review-reports
```

Save to: `.kiro/artifacts/code-review-reports/review-[scope]-[date].md`

### 5.2 Post to GitHub (PR reviews only)

**If reviewing a PR, post summary as PR comment:**

```bash
gh pr comment [number] --body "$(cat <<'EOF'
## Code Review Summary

**Assessment**: [APPROVED/NEEDS CHANGES/BLOCKED]
**Risk**: [LOW/MEDIUM/HIGH/CRITICAL]

### Critical Issues: [count]
[List or "None found"]

### Important Issues: [count]
[List or "None found"]

### Suggestions: [count]
[Brief list]

---

Full report: `.kiro/artifacts/code-review-reports/review-PR-[number]-[date].md`

*Reviewed by: code-reviewer, comment-analyzer, error-hunter, type-analyzer*
EOF
)"
```

---

## Phase 6: OUTPUT

Report to user:

```markdown
## Review Complete

**Scope**: [what was reviewed]
**Assessment**: [APPROVED/NEEDS CHANGES/BLOCKED]

### Summary
- **Critical Issues**: [count] (must fix before merge)
- **Important Issues**: [count] (should fix)
- **Suggestions**: [count] (optional improvements)

### Top Issues
1. [Most important issue with location]
2. [Second most important]
3. [Third most important]

### Report Saved
`.kiro/artifacts/code-review-reports/review-[scope]-[date].md`

### GitHub
[Posted summary to PR #X / N/A - not a PR review]

### Next Steps
[Recommended actions based on findings]
```

---

## Tips

- **Run early**: Review before creating PR, not after
- **Focus on critical**: Fix blocking issues first
- **Re-run after fixes**: Verify issues are resolved
- **Use for self-review**: Great for checking your own code before committing
