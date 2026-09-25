---
name: show-backlog
description: Use when the user asks to see the backlog, the open backlog entries, or what is waiting — e.g. "show backlog", "what's in the backlog", "open feedback items", "plugin backlog" — or types /d:show-backlog.
allowed-tools: Bash, Read
---

# Show the backlog

# 1. Read both backlogs

Read `$env:USERPROFILE\.claude\feedback-backlog.md` and
`$env:USERPROFILE\.claude\plugin-backlog.md`. A missing file has no entries.
An open entry has `- [ ]`. A closed entry has `- [x]`.

# 2. Show the open entries

Group the open entries by backlog. For each entry, show one line with its ID,
its date, its project, and its text:

    - **F1a2** (2026-01-05, SomeProject): Do the thing a certain way.

Keep the text of the entry. Do not rewrite its meaning. A backlog with no open
entries gets one line that says so.

# 3. Close with the count

End with the number of closed entries in each backlog, in one line. Do not
list the closed entries unless the user asks for them.
