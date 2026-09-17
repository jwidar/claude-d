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

## 3. A rule has one home across files

Any given instruction lives in exactly one **file** among the files that load
into the same session. Other files refer to it by name. Two repo `CLAUDE.md`
files never load together, so each repo may carry its own copy of a repo-level
rule.

- `User_CLAUDE.md` is loaded into every session. A rule that must be in force on
  every turn, whether or not a skill fires — "write no comment", "never start
  services" — lives there in full. Procedures, examples, and anything longer
  than a paragraph belong in a skill; `User_CLAUDE.md` then holds the skill name
  and the one-line reason to invoke it.
- `CLAUDE.md` (repo) holds repo facts — layout, maintenance steps, conventions
  specific to this repository. Not portable guidance.
- Skills and agents hold the rules themselves, under rule 2.

When you find the same rule in two files that load together, delete one. Do not
"keep them in sync". Inside one file, rule 4 applies — repetition there is
intended.

## 4. Instruction files are filed by moment, not by topic

Applies to every file Claude loads as its own instructions: `User_CLAUDE.md`,
every repo `CLAUDE.md`, and skill bodies. It does **not** apply to user-facing
documentation — readmes, docs, wiki pages. Those are written for a human reader
who navigates by topic; this rule is about how the model consumes instructions
for itself, which is a different problem.

An instruction in context is not an instruction applied. The model retrieves
what the current action cues, and a header is that cue. A rule under a topic
header ("Maintenance", "Code Quality Standards") is read but not applied at the
moment it matters ("committing", "writing code"). Depth adds a second filter: a
rule three heading levels down, under a scene-setting title, is weighted less
than a flat one. This was observed, not guessed: a version-bump rule under
`## Maintenance` was skipped in three consecutive commits while it sat in
context the whole time.

- **Every header names the moment its section applies.** "Before committing",
  "When I switch topic", "Before writing or editing any code". Not "Git", not
  "Conventions", not "Code Quality Standards".
- **Phrase the moment as the action the model is about to take**, not as the
  rule's subject. "Before pushing", not "Remote repositories". "When you create
  or edit any file", not "Line endings".
- **One heading level: `#`.** No `##` or deeper anywhere in these files. A
  section that holds facts, not rules — a layout listing, what the repo is — may
  keep a topic header; a section that holds a rule may not.
- **A rule that applies at several moments is written under each of them.** Do
  not deduplicate across sections. Do not cross-reference ("see above") in place
  of the rule; the reader at that moment has not read "above".
- **The file opens with a "How this file is organized" section** stating these
  conventions, so the next editor keeps them.
- **When a rule was skipped although it was in context, move it or repeat it**
  under the moment where it should have fired. Do not add emphasis, bold, or a
  caveat — those do not change which header the model is reading under. If the
  rule must never be missed, it is a hook, not prose.

## 5. Frontmatter is trigger language only

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

## 6. Before finishing

- Reread the new component against rule 1: name the one capability it owns, in
  one sentence. If that takes two sentences, split it or drop it.
- Grep the repo for the topic. Anything that now duplicates the new component
  gets deleted, not updated.
- Follow the name-sync and version-bump checklist in the repo's `CLAUDE.md`. A
  new or renamed component that is missing from one of those lists leaves stale
  instructions live.
