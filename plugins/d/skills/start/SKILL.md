---
name: start
description: Use at the beginning of a session, when the user opens with a greeting rather than a request, or when they ask "where were we", "what's going on", or type /d:start.
allowed-tools: Bash, Read, Glob, Grep
---

# Soft Start

The user's working memory is very low and reading is expensive. The first
message of a session decides whether they can work at all. It must cost almost
nothing to read.

**You do the digging. They read one line.**

# 1. Gather silently

Run these yourself. Do not narrate them, do not report their raw output.

```
git -C <repo> status -sb
git -C <repo> log --oneline -5
```

Then check, cheaply, for anything that says what was in flight:

- Uncommitted changes — which area of the repo they touch (not a file list).
- A branch name that names a task.
- `MEMORY.md` or a project `CLAUDE.md` note about work in progress.
- Anything the session summary carries about the last topic.

If a check is slow or unclear, drop it. A missing detail costs less than a
delayed or bloated opener.

# 2. Report

One line of where things stand, then a menu. Nothing else.

Shown here as plain text for illustration — the options themselves go in the
**AskUserQuestion** tool, not in your message:

    You're on master, 2 files changed under skills/, mid-way through the review skill.

      1. Finish the review skill
      2. Look at the uncommitted changes
      3. Something else

Rules for that line:

- **One sentence.** Branch, rough shape of uncommitted work, last topic.
- **No file lists, no diffs, no commit messages, no counts of anything else.**
- **No recap** of previous sessions, decisions, or reasoning.
- **No explanation of the menu itself.**

Rules for the menu:

- Use the **AskUserQuestion** tool — less to read, no typing to answer.
- Two to four options, labels of four words or fewer.
- Always include an exit option.

# When the user opens with a request, or nothing is in flight

If the user opens with a direct request, answer the request. Do not make them
walk through a menu to reach the thing they already asked for.

If the repo is clean and nothing is in flight, say so in one line and offer the
menu anyway — "Clean tree on master, nothing in flight" is a complete opener.

# Never put these in the opening message

Do not, in the opening message:

- List changed files "so they can see"
- Summarise recent commits
- Explain what you checked or how
- Offer more than four options
- Add a caveat, a note, or a "by the way"

Every one of those is the failure this skill exists to prevent.
