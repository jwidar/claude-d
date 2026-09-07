# This Repository

A personal **Claude Code plugin marketplace**. It carries the portable,
shareable half of one developer's Claude Code configuration — the plugin and
the marketplace manifest — and nothing machine- or user-specific. It is a
normal git repo — it is **not** the live `~/.claude` directory.

The personal half (always-on user instructions, portable settings, setup
script, session-start hooks, learning logs) lives in a sibling repo,
**claude-jonas**, which installs this repo as a plugin marketplace. See that
repo's own `CLAUDE.md` for how the two fit together.

## Layout

```
.claude-plugin/marketplace.json   Marketplace manifest (name: "jwidar")
plugins/d/                         The plugin (short name → skills invoke as /d:review)
  .claude-plugin/plugin.json       Plugin manifest
  agents/                          Specialist reviewers/designers (see the dir)
  skills/                          Procedures and conventions (see the dir)
  hooks/                           Stop: .editorconfig autoformat; SessionStart: path-casing warning
readme.md                          What this repo is and how to install it
```

## Conventions

- **Authoring skills and agents:** the `d:tool-authoring` skill owns those rules — one
  owner per capability, a skill with an agent is a trigger rather than a second
  copy, every rule written exactly once, and frontmatter that is trigger language
  only. Consult it before adding or editing any component here.
- **Path portability:** never hard-code `C:\Users\<name>`. Use `$env:USERPROFILE`,
  `$PSScriptRoot`, or `~`. Everything must work for any user.
- **Git:** this repo overrides the global git ceremony — committing and pushing
  without asking is fine here (no CI, no central review). Still run the
  `d:review` skill before committing when changes warrant it.

## Maintenance

A skill/agent **name** or the plugin **description** is duplicated across several
files. Renaming or adding one means updating every place in lockstep — a missed
spot leaves stale instructions live. When changing the plugin, follow this
checklist.

**Renaming or adding a skill/agent** — update its name in all of:
- the component's own `SKILL.md` (frontmatter `name:`) or agent `.md` (`name:`)
- `plugins/d/.claude-plugin/plugin.json` — `description`
- `.claude-plugin/marketplace.json` — `description`
- `readme.md` — the skills / agents lists
- the **claude-jonas** repo's `User_CLAUDE.md` — any skill referenced by name
  **and path** (e.g. the mandatory `d:review` invocation rule hard-codes
  `Skill(skill="…")` and `plugins/d/skills/…/SKILL.md`)
- rename the skill directory with `git mv` so history is preserved

**Renaming the plugin itself** — everything above, plus:
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

**Any skill/agent/hook change** — bump `version` in
`plugins/d/.claude-plugin/plugin.json`. Installs are cached; the bump is
what makes `/plugin marketplace update` pull the change. Leave generic prose
untouched (e.g. "code-review mindset" is English, not a skill name).

**Verify** before committing: grep the repo for the old name — only intended
generic prose should remain — then `git status` should show a skill rename as
`R`, not delete+add.

Scope note: this repo has one plugin and one marketplace file, so these few lines
suffice. A scaffolding skill is
only worth it once there are multiple plugins or a second marketplace manifest to
keep in sync.
