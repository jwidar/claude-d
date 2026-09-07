---
name: tool-authoring
description: Use when creating, editing, renaming, splitting, or reviewing a skill or an agent — any change to a SKILL.md, an agent .md, their frontmatter, or the instructions in User_CLAUDE.md. Also use when deciding whether a new capability should be a skill, an agent, or neither.
---

# Authoring Skills and Agents

Every rule here exists because the alternative was tried and drifted. Instructions
that live in two places stop matching. Two components that both "handle" a topic
mean neither is authoritative, and whichever fires first wins by accident.

## 1. One owner per capability

A capability is owned by exactly one component. Before writing a new skill or
agent, find the existing one that covers the same ground. If there is one,
**extend it or replace it** — do not add a second.

Choosing which:

- **Agent** — when the work is a job to be performed on some input: reviewing,
  rewriting, analysing, designing. It runs in its own context, so it can do heavy
  reading without spending the main conversation's context, and it can run on a
  cheaper model.
- **Skill** — when the work is guidance the main conversation must follow while
  doing something else: a policy, a procedure, a set of conventions. Nothing to
  hand off, nothing to run separately.
- **Neither** — when it is one sentence. Put it in `User_CLAUDE.md`.

## 2. A skill that has an agent is a trigger, not a second copy

When a capability is owned by an agent, the skill's entire job is routing:

- **when** to invoke the agent, and when not to bother
- **what** to send it
- **what to do** with what comes back

The skill must **not** restate the agent's rules, criteria, or examples. If a
reader could do the job from the skill alone, the skill has absorbed the agent's
purpose and one of the two should not exist.

The reverse is not duplication: an agent runs in a fresh context and cannot read
the skill file, so the agent must be fully self-contained. That is the point of
the split — the rules live in the agent, and only the agent.

## 3. A rule is written once

Any given instruction has exactly one home. Everywhere else refers to it by name.

- `User_CLAUDE.md` is loaded into every session. It holds the pointer, never the
  rules. Two or three sentences and the skill name; if a section there grows past
  a short paragraph, it belongs in a skill.
- `CLAUDE.md` (repo) holds repo facts — layout, maintenance steps, conventions
  specific to this repository. Not portable guidance.
- Skills and agents hold the rules themselves, under rule 2.

When you find the same rule in two files, delete one. Do not "keep them in sync".

## 4. Frontmatter is trigger language only

The `description:` on a skill or an agent states **when it fires** — the
situations, the phrasings the user might use, the kinds of files or tasks
involved. Nothing else.

No explanation of what the component does. No summary of its rules. No rationale,
no benefits, no scope caveats. All of that is body content, loaded only once the
component is actually invoked; in the frontmatter it is dead weight carried in
every session's context.

```yaml
# Yes — situations only
description: Use when writing, editing, or reviewing comments in source code —
  including doc comments, TODOs, and commented-out code. Also use when the user
  asks whether a comment is needed.

# No — explains and justifies
description: Manages comments in code. Comments that restate the code add
  nothing and waste reading time, so this skill enforces a no-redundancy policy
  and explains what a comment must contain to earn its place.
```

Agent descriptions keep the `<example>` blocks this repo already uses — those are
trigger language, showing the situation that should cause the agent to be
launched. Keep the commentary inside them about *why this is the moment to
invoke*, not about what the agent knows.

## 5. Before finishing

- Reread the new component against rule 1: name the one capability it owns, in
  one sentence. If that takes two sentences, split it or drop it.
- Grep the repo for the topic. Anything that now duplicates the new component
  gets deleted, not updated.
- Follow the name-sync and version-bump checklist in the repo's `CLAUDE.md`. A
  new or renamed component that is missing from one of those lists leaves stale
  instructions live.
