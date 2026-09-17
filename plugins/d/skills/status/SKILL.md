---
name: status
description: Use when the user asks "where are we", "what's the status", "what were we doing", "is the plan still accurate", or runs /d:status.
allowed-tools: Bash, Read, Grep, Glob
---

# Status Report

The user often forgets where work was left between sessions — even when resuming the same session later. This skill produces a short, accurate orientation so work resumes from a true baseline instead of a stale assumption. **Do not silently continue work** if any check reveals drift; surface it and let the user decide.

# 1. Gather state

Run these checks in parallel where possible. Be quick — this is orientation, not a deep audit.

# 1a. Git branch status vs remote

```
git status -sb
git fetch --quiet origin
git rev-list --left-right --count @{upstream}...HEAD 2>/dev/null
git log --oneline -5
```

Capture:
- Current branch and whether it tracks an upstream.
- Ahead/behind counts vs upstream (or that no upstream is set).
- Whether the working tree is clean, has staged changes, or has unstaged changes.
- The last 1–3 commits (so the user is reminded what shipped recently).

If `git fetch` fails (offline, no remote), note it and continue with local-only info.

# 1b. Active plans and TODOs

Look for in-flight planning artifacts in the repo:
- `.claude/plans/*.md`, `PLAN.md`, `TODO.md`, or any file the user has previously pointed at as the active plan.
- Open `Skill`-managed plans/tasks if present in the current session.

For each, read enough to know:
- What the plan/TODO claims is **done**.
- What it claims is **in progress** or **next**.
- Any explicit acceptance criteria.

# 1c. Associated work item (only if a DevOps integration is connected)

Skip this section entirely if no DevOps integration is available, or if the repo has no DevOps association. Do **not** prompt the user to set it up here.

If available:
- Try to identify a work item from the current branch name (e.g. `feature/12345-...`, `bug/12345_...`) or from recent commit messages.
- If a work item id is found, fetch it via the DevOps integration and read its current **State**, **Assigned To**, and the most recent comments / history entries since the last session if you can tell.
- Also check for an active PR on this branch via the DevOps integration and note its status (Active / Completed / Abandoned) and any new threads.

If no work item id can be inferred, do not guess. Just report "no work item linked" and move on.

# 2. Reconcile

Compare what the plan/TODO says against what the code, branch, and work item actually show. Look specifically for:

- **Plan items already done in code** — TODO says "implement X" but X is in HEAD.
- **Plan items done differently** — implementation diverged from the planned approach.
- **Plan items no longer applicable** — surrounding code changed and the item no longer fits.
- **Code changes not in the plan** — commits or working-tree changes that don't map to any planned item.
- **Work item state mismatch** — work item is `Resolved` / `Closed` while the plan still treats it as in progress, or vice versa.
- **PR state mismatch** — PR is completed/abandoned but local branch still has unmerged work, or local has commits not in the PR.

Drift is the headline. If everything lines up, say so explicitly — that is also a useful report.

# 3. Report

Output a short, scannable summary. ASCII only (no Mermaid). Suggested shape:

```
Status report

Branch:    <name>  (ahead N, behind M of origin/<name>)
Tree:      clean | <X staged, Y unstaged>
Last:      <abbrev sha> <subject>

Plan:      <path or "none found">
  Done:    <items the plan considers done>
  Next:    <what the plan says is next>

Work item: <id> <title>  [<State>]   (or "not linked" / "devops not connected")
PR:        !<id> <title>  [<Status>]  (or "no active PR")

Drift:
  - <each mismatch, one line, file:line if applicable>
  (or: "none — plan, code, and tracking are aligned")

Suggested next step: <one concrete action, framed as a question>
```

Keep the whole report under ~25 lines unless drift requires more detail.

# 4. Hand off, don't drive

End by asking the user how to proceed. Do **not**:
- Silently start working on the "next" item.
- Mark plan items complete on your own.
- Edit the plan/TODO to match reality without explicit consent.

If drift exists, propose a reconciliation per item (update plan / finish remaining work / drop the item) and let the user pick. If everything is aligned, propose the next concrete step as a question and wait.
