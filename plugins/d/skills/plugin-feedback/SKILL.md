---
name: plugin-feedback
description: Use when the user wants to hand a plugin issue back to plugin development from a consumer session — e.g. "handover to plugin dev", "feedback to the plugin", "create a prompt for the plugin", "file this against the plugin", or any mention of an issue, bug, or missing capability in the `d` plugin (a skill, agent, or hook under plugins/d) that should be picked up later in the CLAUDE marketplace repo rather than fixed here.
---

# Plugin handover

Captures a plugin issue found in a consumer session so the CLAUDE marketplace
repo can pick it up later. This skill only records the handover — it never
edits plugin files itself (this session is not that repo).

## 1. Judge trivial vs non-trivial

- **Trivial** — a one-line fix or tweak is self-evident from the description
  alone (a typo, a wrong trigger phrase, a missing frontmatter field).
- **Non-trivial** — needs investigation, design, or carries enough context
  (repro steps, why it matters, what was tried) that a one-liner would lose it.

Judge it yourself from what the user said; don't ask unless genuinely unclear.

## 2. Trivial: append one line

Append to `$env:USERPROFILE\.claude\plugin-backlog.md` (create if missing):

```
- [ ] YYYY-MM-DD (<project>) — <the issue in one line>
```

Use today's date and the current repo's directory name for `<project>`.

## 3. Non-trivial: write the full handover, then a one-line pointer

Write the full write-up to
`$env:USERPROFILE\.claude\plugin-handovers\<slug>.md` — a short kebab-case
`<slug>` describing the issue. Include whatever the receiving session will need
without re-deriving it: which skill/agent/hook, what happened vs. expected,
repro, why it matters, relevant file paths or excerpts.

Then append one line to `plugin-backlog.md`:

```
- [ ] YYYY-MM-DD (<project>) — <short summary> → see plugin-handovers/<slug>.md
```

## 4. Confirm

Tell the user in one line what was written and where. Do not open or edit any
file under `C:\src\CLAUDE` — that repo processes the backlog on its own next
session there.
