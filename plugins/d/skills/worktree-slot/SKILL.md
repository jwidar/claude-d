---
name: worktree-slot
description: Use when the SessionStart context says "Worktree slot" or "Main clone with worktree slots", and before you create or switch a branch, commit, stash, delete a branch, or run any git worktree command in such a repo. Also use when the user says the work in a slot is done, asks to park a slot, or asks how the worktree slots work.
---

# The slot layout

One repo has one main clone and a fixed set of worktree slots next to it:

```
C:\src\Example\          main clone, stays on master, no edits here
C:\src\Example.wt\1\     slot 1, one Claude session
C:\src\Example.wt\2\     slot 2, another Claude session
```

All slots share one object store, so branches, tags, and the stash list are
shared. Each slot path stays the same for a long time, so the Claude project
memory and IDE settings stay with the slot. An idle slot is parked on a detached
`origin/master`. A slot is not removed after a task. It is used again.

# When the session starts in a slot

Run `git -C <slot> status -sb`.

- On a branch: work is in progress. Continue it. Do not switch away.
- Detached HEAD: the slot is parked. It is ready for new work.

# When the session runs in the main clone

The main clone stays on `master` and has no edits. Tell the user once that work
belongs in a slot. If the user wants to work here, continue.

# Before the first edit in a parked slot

Make a work branch from a fresh `origin/master`:

```
git -C <slot> fetch origin
git -C <slot> switch --no-track -c <branch> origin/master
```

`--no-track` keeps `origin/master` from becoming the upstream. The first
`git push -u origin <branch>` sets the correct one. Use the branch name that the user gives, or the repo's own convention. If
neither exists, ask.

# Before committing

- Never commit on a detached HEAD. A commit there belongs to no branch and is
  lost when the slot is parked. Make a work branch first.

# Before you switch a branch

- Never check out `master` in a slot. The main clone holds it. Use
  `git switch --detach origin/master`.
- Never check out a branch that another worktree holds. Git refuses with
  "already used by worktree at". Do not force it with
  `--ignore-other-worktrees`. Tell the user which slot holds the branch.

# Before you stash

The stash list is shared by all slots. Use `git stash push -m "<slot>: <reason>"`.
Pop or drop only an entry that this slot made.

# Before you delete a branch

A branch is shared by all slots. Delete only a branch that this session made,
and only when the user asks.

# Before you run a git worktree command

Do not run `git worktree add`, `remove`, `move`, or `prune` unless the user asks.
Never edit files in another slot or in the main clone.

# When the work in a slot is done

The work is done when the user says so. Claude cannot see that a slot is idle.
After a push, you can offer to park the slot.

1. Run `git -C <slot> status -sb`. The tree must be clean. If it is not, stop and
   tell the user.
2. Run the `d:git-state` check. If the branch has commits that are not pushed,
   tell the user before you park. The branch stays, so nothing is lost.
3. Park the slot:

   ```
   git -C <slot> fetch origin
   git -C <slot> switch --detach origin/master
   ```

Do not delete the work branch.
