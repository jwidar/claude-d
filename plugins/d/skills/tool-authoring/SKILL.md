---
name: tool-authoring
description: Use when creating, editing, renaming, splitting, moving, or reviewing any instruction Claude loads for itself — a SKILL.md, an agent .md, an output style, a rule file, hook text, a permission rule, their frontmatter, or the instructions in User_CLAUDE.md or a repo CLAUDE.md. Also use when deciding where a new rule or capability should live.
---

# Authoring instructions, skills, agents, and hooks

Every rule here exists because the alternative was tried and drifted. Instructions
that live in two places stop matching. Two components that both "handle" a topic
mean neither is authoritative, and whichever fires first wins by accident. A rule
that is always in context but rarely relevant dilutes the rules that matter.

# 1. Before you place a rule: choose the carrier by when it must fire

If a rule must never be missed, it is a permission rule or a hook, not prose.
Prose in context is read; it is not always applied.

Walk this list from the top. Take the first carrier that fits.

- **Permission rule** (`deny` / `ask` in `User_settings.json`). The action must
  never happen, or must always get the user's approval. The harness enforces it
  in every permission mode, also in auto mode, and a hook cannot override it.
  Write each Bash rule twice: `Bash(git push *)` and `PowerShell(git push *)`.
  The prose that remains states only the reason, if the reason is not obvious.
- **Hook with `additionalContext`.** The rule applies at a tool call: before a
  commit, after a write to a memory file, when a PR is created. Use the `if`
  field (`"if": "Bash(git commit *)"`) so the hook fires only for that command.
  The text arrives next to the tool call, at the moment it matters, and costs
  nothing in other turns. A hook that checks a file's content after a write
  (comments, line endings, mermaid fences) beats any prose about it.
- **Path-scoped rule** (`rules/*.md` in claude-jonas, copied to
  `~/.claude/rules/` by `setup.ps1`, with `paths:` frontmatter such as
  `"**/*.cs"`; a linked rules folder does not load them). The rule
  applies to one kind of file. It loads when Claude reads, writes, or edits a
  matching file. A plugin cannot ship a rule file, so rules live in
  claude-jonas.
- **Output style** (`output-styles/` in claude-jonas, linked to
  `~/.claude/output-styles/`). The rule shapes every message: tone, length,
  format, how to present a choice. It sits in the system prompt. A style
  file edit needs a restart.
- **`User_CLAUDE.md`.** The rule applies on most turns, in every project, and
  no tool call or file type marks its moment. Keep each rule there to a few
  lines. Keep the file under 200 lines.
- **Skill.** The content is a procedure, a set of examples, or anything longer
  than a paragraph, and the moment is a task the model recognizes from the
  request. When the model may miss the moment, add a hook that names the skill.
  Do not add a pointer line to `User_CLAUDE.md`; the skill's description already
  is that pointer.
- **Agent.** The work is a job on some input: review, design, rewrite,
  analysis. It runs in its own context and can run on a cheaper model.

Before you add any text that loads in every session, ask: does this apply on
every turn? If not, which carrier above brings it in at the right moment?

# 2. Before adding a component: one owner per capability

A capability is owned by exactly one component. Before writing a new skill,
agent, hook, or rule file, find the existing one that covers the same ground. If
there is one, **extend it or replace it** — do not add a second.

# 3. When a skill routes to an agent: the skill is a trigger, not a second copy

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

# 4. When a rule could live in two files: one home across files

Any given instruction lives in exactly one **carrier** among those that load into
the same session: `User_CLAUDE.md`, a rule file, the output style, a skill, hook
text. Other carriers refer to it by name. Two repo `CLAUDE.md` files never load
together, so each repo may carry its own copy of a repo-level rule. An agent is
the exception under rule 3.

- `CLAUDE.md` (repo) holds repo facts — layout, maintenance steps, conventions
  specific to this repository. Not portable guidance.
- A permission rule or a hook replaces prose; it does not sit next to a full
  copy of it.

When you find the same rule in two carriers that load together, delete one. Do
not "keep them in sync". Inside one file, rule 5 applies — repetition there is
intended.

# 5. When you file a rule in an instruction file: by moment, not by topic

Applies to every file Claude loads as its own instructions: `User_CLAUDE.md`,
every repo `CLAUDE.md`, rule files, the output style, and skill bodies. It does
**not** apply to user-facing documentation — readmes, docs, wiki pages. Those are
written for a human reader who navigates by topic; this rule is about how the
model consumes instructions for itself, which is a different problem.

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
- **A numbered step of a procedure is the exception** (`# 3. Check for prior
  lessons`). The procedure runs in order, so the number is the moment. A rule
  that also applies outside the procedure goes under its own moment header.
- **A rule that applies at several moments is written under each of them.** Do
  not deduplicate across sections. Do not cross-reference ("see above") in place
  of the rule; the reader at that moment has not read "above". When a moment is
  a tool call or a file type, move the rule to a hook or a rule file (rule 1)
  instead of repeating it.
- **`User_CLAUDE.md` and each repo `CLAUDE.md` open with a "How this file is
  organized" section** stating these conventions, so the next editor keeps them.
  Skills, agents, and rule files do not — this skill is that section for them.
- **When a rule was skipped although it was in context, move it** to a carrier
  higher in rule 1's list, or repeat it under the moment where it should have
  fired. Do not add emphasis, bold, or a caveat — those do not change which
  header the model is reading under.

# 6. When you write hook text

- Return it as `hookSpecificOutput.additionalContext`. Only then does the text
  reach Claude.
- Write it as facts and instructions about the task ("This commit needs …"), not
  as a message from the system. Text that poses as a system command can trip
  prompt-injection defenses.
- Keep it to what applies at that call. The limit is 10 000 characters; a few
  lines is the target.
- The `if` filter is best-effort. A hook that must block is backed by a
  permission rule.

# 7. When you write frontmatter: trigger language only

The `description:` on a skill or an agent states **when it fires** — the
situations, the phrasings the user might use, the kinds of files or tasks
involved. Nothing else. A rule file's frontmatter holds only `paths:`.

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

Agent descriptions keep at most two short `<example>` blocks — those are trigger
language, showing the situation that should cause the agent to be launched. Keep
the commentary inside them about *why this is the moment to invoke*, not about
what the agent knows.

# 8. Before finishing

- Reread the new component against rule 2: name the one capability it owns, in
  one sentence. If that takes two sentences, split it or drop it.
- Check the carrier against rule 1 once more. Text that loads in every session
  must earn that cost.
- Grep both repos for the topic. Anything that now duplicates the new component
  gets deleted, not updated.
- Follow the name-sync and version-bump checklist in the repo's `CLAUDE.md`. A
  new or renamed component that is missing from one of those lists leaves stale
  instructions live.
