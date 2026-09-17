---
name: git-state
description: Use whenever you are about to state, imply, or rely on whether changes are committed or pushed — e.g. "already committed", "it's pushed", "nothing to push", "the remote has this", "your work is safe on the remote". Also use when the user asks whether something was committed or pushed.
allowed-tools: Bash
---

# Verify Git State

Commit and push state are **facts about the repository**, not inferences from
what you did this session. Before you state — or quietly rely on — whether work
is committed or pushed, confirm it with git.

# Before asserting commit or push state: the trap

The repository changes outside your actions:

- The **user** commits, pushes, stashes, resets, or amends manually (IDE, CLI).
- A **previous session** or another tool left the tree dirty or commits unpushed.
- You committed but did not push — **commit ≠ push**.

So these inferences are all unsound:

- "I committed it, so it's in the repo." → Committed locally is not pushed.
- "I didn't push, so it isn't pushed." → The user may have pushed it.
- "The last thing I did was commit, so the tree is clean." → The user may have
  added or edited files since.
- "It was clean earlier, so it still is." → State is not frozen between turns.

If you did not run a command **this turn** that proves the state, you do not know it.

# When checking the state: what to run

Use `git -C <repo>` (never `cd … &&`). One command answers most questions:

```
git -C <repo> status -sb
```

It prints the branch, its tracking relationship, and the working tree in one shot:

- `## master...origin/master` — clean and in sync (nothing after the branch line).
- `## master...origin/master [ahead 2]` — 2 local commits **not pushed**.
- `## master...origin/master [behind 3]` — remote has commits you don't.
- `## master` with **no** `...origin/...` — branch has **no upstream**; it has
  never been pushed (or tracking isn't set). Say that — don't guess "pushed".
- Lines below (` M file`, `?? file`) — uncommitted changes; the tree is **dirty**.

To enumerate the unpushed commits:

```
git -C <repo> log --oneline origin/<branch>..HEAD
```

# When reporting the state

State the claim **with the evidence**, in the present tense of what you just saw:

- > `git status -sb` shows `## master...origin/master` with a clean tree — committed and pushed.
- > `git status -sb` reports `[ahead 2]`: two commits are committed but **not pushed**.
- > The branch has no upstream — this work has **not** been pushed yet.

If you have not checked this turn, do not assert the state. Say "let me check,"
run the command, then answer. Never let "I didn't push it" stand in for a check.
