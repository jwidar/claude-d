---
name: worktree-slot
description: Use when the SessionStart context says "Worktree slot", "Main clone with worktree slots", "Empty slot folder", or "Copied slot folder", and before you create or switch a branch, commit, stash, delete a branch, or run any git worktree command in such a repo. Also use when the user says "new worktree", says the work in a slot is done, asks to close or park a slot, or asks how the worktree slots work.
---

# The slot layout

One repo has one main clone and a set of worktree slots next to it. A slot
folder is named `<repo>.<number>`:

```
C:\src\Example\      main clone, stays on the default branch, no edits here
C:\src\Example.1\    slot 1, one Claude session
C:\src\Example.2\    slot 2, another Claude session
```

All slots share one object store, so branches, tags, and the stash list are
shared. Each slot path stays the same for a long time, so the Claude project
memory and IDE settings stay with the slot. An idle slot is parked on a detached
`origin/HEAD`. A slot is not removed after a task. It is used again.

# When the user says "new worktree"

The session runs in an empty folder named `<repo>.<number>`, next to the main
clone. Run the script from this skill's base directory:

```
powershell -NoProfile -File "<skill base directory>\new-slot.ps1" -Path "<session directory>"
```

The script makes the folder a worktree of the main clone, parked on a detached
`origin/HEAD`, and copies `.claude/*.local.*` from the main clone. Give the user
its output. When it refuses, give the reason and stop. Do not work around it.

After a success, tell the user to restart the session in the folder. A session
that started in an empty folder did not load the project instructions or hooks.

# When the SessionStart context says "Copied slot folder"

The folder is a copy of another slot. Its `.git` file points to the other
slot, so a git command here changes the HEAD and index of that slot. Tell the
user. Do not run git in this folder. A new slot starts from an empty folder.

# When the session starts in a slot

Run `git -C <slot> status -sb`.

- On a branch: work is in progress. Continue it. Do not switch away.
- Detached HEAD: the slot is parked. It is ready for new work.

# When the session runs in the main clone

The main clone stays on the default branch and has no edits. Tell the user once that work
belongs in a slot. If the user wants to work here, continue.

# Before the first edit in a parked slot

Make a work branch from a fresh `origin/HEAD`, the default branch of the remote:

```
git -C <slot> fetch origin
git -C <slot> switch --no-track -c <branch> origin/HEAD
```

`--no-track` keeps the default branch from becoming the upstream. The first
`git push -u origin <branch>` sets the correct one. Use the branch name that the user gives, or the repo's own convention. If
neither exists, ask.

# Before committing

- Never commit on a detached HEAD. A commit there belongs to no branch and is
  lost when the slot is parked. Make a work branch first.

# Before you switch a branch

- Never check out the default branch in a slot. The main clone holds it. Use
  `git switch --detach origin/HEAD`.
- Never check out a branch that another worktree holds. Git refuses with
  "already used by worktree at". Do not force it with
  `--ignore-other-worktrees`. Tell the user which slot holds the branch.

# Before you stash

The stash list is shared by all slots. Use `git stash push -m "<slot>: <reason>"`.
Pop or drop only an entry that this slot made.

# Before you delete a branch

A branch is shared by all slots. Delete only a branch that this session made,
or the branch that a closed slot was on. Delete it only when the user asks or
confirms.

# Before you run a git worktree command

Do not run `git worktree add`, `remove`, `move`, or `prune` unless the user asks.
Never edit files in another slot or in the main clone. The one exception is the
fast-forward that `close-slot.ps1` does in the main clone.

# When the user says the work in a slot is done, or asks to close or park it

The work is done when the user says so. The PR can be merged without Claude
knowing. Claude cannot see that a slot is idle. After a push, you can offer to
close the slot.

Run the script from this skill's base directory:

```
powershell -NoProfile -File "<skill base directory>\close-slot.ps1" -Path "<session directory>"
```

The script parks the slot on a detached `origin/HEAD` and fast-forwards the
default branch in the main clone. Give the user its output. When it refuses,
give the reason and stop. Do not work around it. When it reports unpushed
commits or a main clone that was not updated, tell the user. Do not repair the
main clone.

After a success, offer to delete the branch that the slot was on. The script
output names it ("It was on branch ..."). Do not offer it in these cases:

- The script reported unpushed commits. Say that the branch is kept.
- The branch is long-running: it lives beyond one task, for example `develop`
  or `release/*`, or the repo or the user names it as long-lived. Say that the
  branch is kept.

Ask with the AskUserQuestion tool. Recommend the delete. When you are not sure
that the branch is short-lived, recommend to keep it. On a yes, delete only the
local branch:

```
git -C <slot> branch -D <branch>
```

`-D` is necessary because a squash merge leaves the branch unmerged for git.
When the script reported no unpushed commits, each commit is on a remote. Do
not delete the remote branch.
