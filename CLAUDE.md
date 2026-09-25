# This repository

A personal **Claude Code plugin marketplace**. It carries the portable,
shareable half of one developer's Claude Code configuration — the plugin and
the marketplace manifest — and nothing machine- or user-specific. It is a
normal git repo — it is **not** the live `~/.claude` directory.

The personal half (always-on user instructions, portable settings, setup
script, session-start hooks, learning logs) lives in a sibling repo,
**claude-jonas**, which installs this repo as a plugin marketplace. See that
repo's own `CLAUDE.md` for how the two fit together.

# Layout

```
.claude-plugin/marketplace.json   Marketplace manifest (name: "jwidar")
plugins/d/                         The plugin (short name → skills invoke as /d:review)
  .claude-plugin/plugin.json       Plugin manifest
  agents/                          Specialist reviewers/designers (see the dir)
  skills/                          Procedures and conventions (see the dir)
  hooks/                           Stop: .editorconfig autoformat; SessionStart: path-casing warning
readme.md                          What this repo is and how to install it
```

# How this file is organized

Every header below names the **moment** a section applies — not its topic. Every
header is a top-level `#`; there is no `##` or deeper, so there is no hierarchy
to skip. A rule that applies at several moments is repeated at each one. That
repetition is intentional — do not deduplicate it. Sections that hold facts,
not rules ("Layout"), keep a topic header. The `d:tool-authoring` skill owns
these authoring rules; follow it when you edit this file. At every step, read
the headers and ask: "am I at this moment now?"

# Before adding or editing any file under `plugins/d/`

- **Consult the `d:tool-authoring` skill first.** It owns the authoring rules —
  one owner per capability, a skill with an agent is a trigger rather than a
  second copy, every rule written exactly once, and frontmatter that is trigger
  language only.
- **Path portability:** never hard-code `C:\Users\<name>`. Use `$env:USERPROFILE`,
  `$PSScriptRoot`, or `~`. Everything must work for any user.
- **Bump `version` in `plugins/d/.claude-plugin/plugin.json` in the same
  change.** Installs are cached; the bump is what makes
  `/plugin marketplace update` pull the change. This applies to every skill,
  agent, or hook edit — not only renames. It is repeated under "Before
  committing" because it is the step most often forgotten.
- **No scaffolding skill for the checklists in this file.** This repo has one
  plugin and one marketplace file, so these lines suffice. A scaffolding skill
  is only worth it once there are multiple plugins or a second marketplace
  manifest to keep in sync.

# Before renaming or adding a skill, an agent, or the plugin itself

A skill/agent **name** is duplicated across several files. Renaming or adding
one means updating every place in lockstep — a missed spot leaves stale
instructions live. Update the name in all of:

- the component's own `SKILL.md` (frontmatter `name:`) or agent `.md` (`name:`)
- `plugins/d/.claude-plugin/plugin.json` — `description`, and bump `version`
- `.claude-plugin/marketplace.json` — `description`
- `readme.md` — the skills / agents lists
- the **claude-jonas** repo's `User_CLAUDE.md` — any skill referenced by name
  **and path** (e.g. the mandatory `d:review` invocation rule hard-codes
  `Skill(skill="…")` and `plugins/d/skills/…/SKILL.md`)
- rename the skill directory with `git mv` so history is preserved

Leave generic prose untouched (e.g. "code-review mindset" is English, not a
skill name).

When the **plugin itself** is renamed, also update:

- `plugins/<name>/` — rename the directory with `git mv`
- `plugins/<name>/.claude-plugin/plugin.json` — `name`
- `.claude-plugin/marketplace.json` — `name` and `source`
- the **claude-jonas** repo's `User_settings.json` — the `enabledPlugins` key
  (`<name>@jwidar`)
- the **claude-jonas** repo's `setup.ps1` — the `<name>@jwidar` / `'<name>'`
  strings in comments and output
- the live `~/.claude/settings.json` — `setup.ps1` adds the new
  `enabledPlugins` key but does **not** remove the old one; delete it by hand
  or the stale plugin stays enabled

# Before writing an example into any file in this repo

**Never use a real example.** No real PR numbers, repository names, hostnames,
customer or product names, work item IDs, or text quoted from a real PR, commit,
or ticket. Every example is made up. This repo is shared; a real example leaks
internal information, and the plugin's readers do not need it — the shape of
the example is the point, not its facts.

# When a change implements or drops a backlog entry

This applies also when the work did not start from the backlog. When we have
processed an entry in `$env:USERPROFILE\.claude\feedback-backlog.md` or
`plugin-backlog.md` (implemented it or dropped it), tick it off (`- [x]`) at
that moment. Append the outcome:
`→ Promoted/Built/Dropped: <what and where, commit if any>`. Do not wait for
the user to ask.

# Before committing

- **Git ceremony override:** this repo overrides the global git rules —
  committing and pushing without asking is fine here (no CI, no central
  review). Still run the `d:review` skill before committing when changes
  warrant it.
- **Version bump check.** Run `git diff --cached --name-only` (or `git status`).
  If any file under `plugins/d/` is in the commit and
  `plugins/d/.claude-plugin/plugin.json` is not, stop: bump `version` and stage
  it in the same commit. Installs are cached; without the bump the change never
  reaches an installed copy.
- **Rename verification.** After a rename, grep the repo for the old name — only
  intended generic prose should remain — and `git status` must show a skill
  rename as `R`, not delete+add.
- **Backlog check.** If the commit implements or drops an entry in
  `feedback-backlog.md` or `plugin-backlog.md`, tick it off with its outcome
  before you commit.
