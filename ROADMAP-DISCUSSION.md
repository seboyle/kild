# Roadmap Discussion: Matt's Integration & Feature Proposals

Conversation between Rasmus and Matt (core contributor), analyzing KILD's current state, gaps, and potential directions.

## Context

Matt is a Linux/Wayland (Hyprland) user who contributed Linux/Alacritty support. He's built a custom workflow around KILD using Waybar (status bar), fuzzel (launcher), and OS-level window management. He's not using kild-ui — he integrates KILD as a CLI into his own tooling.

---

## 1. Multi-Agent Tracking Per Session

**Problem**: When `kild open` is called multiple times on the same session, the PID and window ID are overwritten. Only the last-opened agent is tracked. Previous agents become orphaned processes.

**Current state**:
- `Session` struct has singular fields: `process_id: Option<u32>`, `terminal_window_id: Option<String>`, `agent: String`
- `open_session` at `handler.rs:1038-1051` does direct field assignment — completely replaces previous process info
- `kild stop` and `kild destroy` only kill the last-tracked PID
- Previous agents keep running with no tracking

**Potential approach**: Replace singular fields with a `Vec<AgentProcess>`:

```rust
struct AgentProcess {
    agent: String,
    process_id: Option<u32>,
    process_name: Option<String>,
    process_start_time: Option<u64>,
    terminal_window_id: Option<String>,
    command: String,
    opened_at: String,
}
```

**Considerations**:
- Session JSON format change (migration needed for existing sessions)
- `stop` needs to know which agent to stop (all? by name? by index?)
- `status` output needs to show all running agents
- Health monitoring needs to check all PIDs
- Table formatter needs updating for multi-agent display

---

## 2. Agent Status Reporting

**Proposal**: A command like `kild agent-status <branch> working` so agents (via hooks) can report their status.

**Current state**:
- `SessionStatus` is a 3-state lifecycle enum: `Active | Stopped | Destroyed`
- `HealthStatus` is inferred at query time from PID + `last_activity` — but `last_activity` is never updated after session creation
- `last_message_from_user` in `calculate_health_status` is hardcoded to `false` with a TODO
- No mechanism for external tools/hooks to update session state
- Matt currently uses Claude Code hooks to write to his own status files outside KILD

**Two sub-problems**:

### a) Activity Heartbeat

Let agents/hooks update `last_activity` so health monitoring actually works.

- New command: `kild heartbeat <branch>` or `kild touch <branch>`
- Updates `last_activity` timestamp in session JSON
- Makes `HealthStatus::Working/Idle/Stuck` meaningful instead of always returning `Idle`

### b) Explicit Agent Status

Let agents report semantic status distinct from health inference.

- New field: `agent_status: Option<AgentStatus>` (per agent or per session)
- Enum values: `Working | Waiting | Done | Idle | Error`
- New command: `kild agent-status <branch> <status>`

**Design question**: Should status live in the session JSON or a separate lightweight file? If agents update status frequently, rewriting the full session JSON each time may be heavy. A separate `.status` file per session could be lighter.

---

## 3. Git Indicators (Lines Changed, Ahead/Behind, Diverged)

**Matt's Waybar shows**: Lines changed, ahead of main, diverged from main. He computes this outside KILD today.

**Current state**:
- `get_diff_stats()` exists in `git/operations.rs:139-165` — returns insertions/deletions/files_changed. Used by kild-ui detail panel but **not exposed via any CLI command**
- `count_unpushed_commits()` exists in `git/operations.rs:276-401` — returns ahead count. Used only for destroy safety warnings, **not exposed via CLI**
- **No "behind" count** exists — only ahead is computed
- **No divergence detection** — no check if local and remote have diverged
- `kild diff` shows raw `git diff` only (no summary stats)
- `kild commits` shows log with no ahead/behind indicator

**Potential items**:
- Expose diffstats in CLI: `kild status` or `kild diff --stat` showing `+X -Y (Z files)`
- Add ahead/behind to status output
- Add divergence detection (commits on both sides of merge base)
- New `kild stats` command — consolidated view: lines changed, commits ahead/behind, PR status. Machine-readable via `--json` for tools like Waybar

---

## 4. Window Management

**Matt's setup**: Swaps 3 windows per kild (Claude Code, editor, browser preview) using Hyprland OS-level window management, not KILD. He abandoned `kild focus`/`kild hide` for OS swapwindow because window positions stay static.

**Current state**:
- KILD tracks exactly one terminal window per session
- No concept of associated windows (editor, browser)
- No `kild hide` command exists
- `kild focus` brings one terminal window to foreground

**Assessment**: Window management is OS/WM-specific (Hyprland IPC, macOS window APIs) and likely outside KILD's core scope. Matt agrees ("some of these may make sense to integrate into kild, others definitely not").

**What KILD could do**:
- Expose window IDs in `kild status --json` so external tools can manage them
- Track multiple window IDs per session if multi-agent tracking is added
- Keep actual window swapping/hiding external

---

## 5. Git Repo Management (Merge, Rebase, Sync)

**Matt's current usage outside KILD**: Merging kild branch with default, rebasing onto default, cleanup.

**Current state**:
- `kild complete` checks if PR is merged, deletes remote branch, destroys session
- No `kild merge`, `kild rebase`, or `kild sync` commands exist
- Cleanup exists for orphaned resources but not for git branch management

**Potential items**:
- `kild rebase <branch>` — rebase kild's branch onto the base branch
- `kild merge <branch>` — merge base branch into kild's branch
- `kild sync <branch>` — fetch + rebase/merge in one command

**Considerations**:
- These operations can have conflicts — KILD should surface them, not try to resolve
- Moves KILD from "environment management" toward "git workflow tool"
- Depends on the scope/SDK decision (item 9)

---

## 6. Local Repos (No Remotes)

**Current state**: Mostly works already.
- `remote_url` is `Option<String>` — properly handled as None
- Project name falls back to directory name
- Fetch is skipped with informational message
- Tests confirm worktree creation succeeds without remote

**Gaps**:
- `kild complete` checks for merged PR — meaningless without remote
- Ahead/behind counts are meaningless without upstream
- Some warning messages assume remote existence

**Potential item**: Clean up UX for local-only repos — skip remote-specific checks/warnings, adjust messaging.

---

## 7. Comprehensive JSON Output for External Tooling

**Context**: Matt's Waybar integration, and any future external tool, needs machine-readable output from KILD.

**Current state**:
- `kild list --json` and `kild status --json` exist
- JSON output is the raw `Session` struct — includes all persisted fields
- Does not include computed fields: process running status, git status, diff stats, health status, ahead/behind

**Potential item**: Enrich `--json` output with computed fields so external tools don't need to duplicate logic. The `SessionInfo` struct used by kild-ui already combines session + process status + git status + diff stats — expose this via CLI JSON.

---

## 8. SDK vs Monolithic Tool (Strategic Decision)

**Decision: Option 3 — Both CLI JSON API and `kild-core` as library.**

KILD expands scope into **agent lifecycle + git intelligence** (the unique value proposition) while exposing integration surfaces for external tools:

- **CLI `--json`** — Primary API for non-Rust tooling (Waybar, scripts, Python TUIs). The enriched JSON pattern (#219, #226) makes this a stable contract.
- **`kild-core` as library crate** — For Rust consumers (GPUI apps, Rust TUIs). Already consumed by kild-ui and the CLI. No extra work needed since the crate structure exists.

**KILD's boundary:**
- **Owns**: Agent lifecycle, git intelligence (stats, health, cross-kild analysis, merge queue), session management, terminal spawning
- **Exposes metadata for**: Window management (IDs for tiling WMs), OS-level integration
- **Does not own**: Window layout, OS window management, IDE integration internals

---

## 9. Matt's GPUI Interest

Matt mentioned interest in replacing TUI/dmenu tools with GPUI alternatives. Not directly actionable for KILD, but relevant:
- kild-ui codebase becomes a reference/template for GPUI on Linux
- Could lead to kild-ui contributions (Linux/Wayland GPUI support)
- GPUI on Linux is still maturing

---

## Tracking

| # | Item | Type | Priority | Status | Issue | Notes |
|---|------|------|----------|--------|-------|-------|
| 1 | Multi-agent tracking per session | Bug/Core model | High | Issue created | [#217](https://github.com/Wirasm/kild/issues/217) | Current behavior orphans processes |
| 2a | Activity heartbeat (`kild heartbeat`) | New feature | Medium | Merged into 2b | — | Covered by agent-status updating last_activity |
| 2b | Agent status reporting (`kild agent-status`) | New feature | High | Issue created | [#218](https://github.com/Wirasm/kild/issues/218) | Includes per-agent hook config docs for all backends |
| 3a | Expose existing git stats via CLI + JSON | CLI enhancement | Medium | Issue created | [#219](https://github.com/Wirasm/kild/issues/219) | Diffstats, ahead/behind, diverged, worktree status |
| 3b | PR lifecycle tracking | New feature | Medium | Issue created | [#220](https://github.com/Wirasm/kild/issues/220) | PR state, URL, CI status, review status in session data |
| 3c | Branch health metrics & merge readiness | New feature | Medium | Issue created | [#221](https://github.com/Wirasm/kild/issues/221) | Commit activity, base drift, total diff, conflict detection |
| 3d | Cross-kild intelligence | New feature | High | Issue created (needs scoping) | [#222](https://github.com/Wirasm/kild/issues/222) | File overlap, conflict prediction, merge ordering |
| 4 | `kild hide` + window metadata for tiling WMs | CLI + trait | Medium | Issue created | [#224](https://github.com/Wirasm/kild/issues/224) | hide command + JSON metadata for Hyprland/etc. integration |
| 5 | `kild rebase` / `kild sync` commands | New feature | Medium | Issue created | [#225](https://github.com/Wirasm/kild/issues/225) | Primitives for merge queue. Report conflicts, don't resolve. |
| 6 | Local repo UX cleanup | Polish | Low | Folded into #219, #220, #221 | — | Main blocker fixed in PR #216. Remaining polish covered as notes on git issues. |
| 7 | Enriched JSON output for tooling | CLI enhancement | Medium | Folded into #219 + validation #226 | [#226](https://github.com/Wirasm/kild/issues/226) | #219 establishes pattern, each issue extends it, #226 validates the whole. |
| 8 | SDK/scope strategic decision | Architecture | Strategic | Resolved | — | Decision: option 3 (both). CLI `--json` for external tooling + `kild-core` as library for Rust consumers. KILD owns agent lifecycle + git intelligence. OS/WM integration via metadata exposure. |
| 9 | GPUI on Linux / kild-ui contributions | Exploration | — | Open | — | Matt exploring, not actionable yet |
| 10 | Intelligent merge queue | Vision | Future | Issue created | [#223](https://github.com/Wirasm/kild/issues/223) | Agentic pipeline: queue + CI + AI conflict resolution. Builds on #218-#222. |
| 11 | Pluggable isolation + session daemon + embedded terminal | Vision | Future | Issue created | [#227](https://github.com/Wirasm/kild/issues/227) | Worktrees become optional. Containers, VMs, devcontainers. tmux-like daemon. GPUI terminal in kild-ui. |
