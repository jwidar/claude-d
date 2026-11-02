# This repository

A **Claude Code plugin marketplace**: the plugin and the marketplace manifest,
and nothing machine- or user-specific. It is a normal git repo — it is **not**
the live `~/.claude` directory.

# How this file is organized

Every header below names the **moment** a section applies — not its topic. Every
header is a top-level `#`; there is no `##` or deeper, so there is no hierarchy
to skip. A rule that applies at several moments is repeated at each one. That
repetition is intentional — do not deduplicate it. The `d:tool-authoring` skill owns
these authoring rules; follow it when you edit this file. At every step, read
the headers and ask: "am I at this moment now?"

# Before adding or editing any file under `plugins/d/`

- **Consult the `d:tool-authoring` skill first.** It owns the authoring rules —
  one owner per capability, a skill with an agent is a trigger rather than a
  second copy, every rule written exactly once, and frontmatter that is trigger
  language only.
- **The plugin stays general.** It knows nothing about the user's projects,
  machines, or personal configuration, and it does not depend on them. Name no
  project and no personal repo or file. Azure DevOps and GitHub are the only
  environments that it may know. A rule that needs a personal file does not
  belong in this repo.
- **Path portability:** never hard-code `C:\Users\<name>`. Use `$env:USERPROFILE`,
  `$PSScriptRoot`, or `~`. Everything must work for any user.
- **Bump `version` in `plugins/d/.claude-plugin/plugin.json` in the same
  change.** Installs are cached; the bump is what makes the session-start
  update pull the change. This applies to every skill,
  agent, or hook edit — not only renames. It is repeated under "Before
  committing" because it is the step most often forgotten.
- **No scaffolding skill for the checklists in this file.** This repo has one
  plugin and one marketplace file, so these lines suffice. A scaffolding skill
  is only worth it once there are multiple plugins or a second marketplace
  manifest to keep in sync.

# Before writing a hook under `plugins/d/hooks/`

- **Read what a tool changed from the hook input, not from the disk.** Use
  `tool_input` or `tool_response.structuredPatch`. PostToolUse hooks run in
  parallel. Another hook (for example the formatter) can change the file while
  your hook reads it.
- **A hook that reminds, and does not block, returns its text as
  `hookSpecificOutput.additionalContext`.** Only then does the text reach
  Claude.
- **Text the user must see goes in `systemMessage`.** Plain stdout and
  `additionalContext` reach only Claude.

# Before renaming or adding a skill, an agent, or the plugin itself

A skill/agent **name** is duplicated across several files. Renaming or adding
one means updating every place in lockstep — a missed spot leaves stale
instructions live. Update the name in all of:

- the component's own `SKILL.md` (frontmatter `name:`) or agent `.md` (`name:`)
- `plugins/d/.claude-plugin/plugin.json` — `description`, and bump `version`
- `.claude-plugin/marketplace.json` — `description`
- `readme.md` — the skills / agents lists
- rename the skill directory with `git mv` so history is preserved

Leave generic prose untouched (e.g. "code-review mindset" is English, not a
skill name).

When the **plugin itself** is renamed, also update:

- `plugins/<name>/` — rename the directory with `git mv`
- `plugins/<name>/.claude-plugin/plugin.json` — `name`
- `.claude-plugin/marketplace.json` — `name` and `source`
- the live `~/.claude/settings.json` — the `enabledPlugins` key
  (`<name>@jwidar`); delete the old key or the stale plugin stays enabled

# Before writing an example into any file in this repo

**Never use a real example.** No real PR numbers, repository names, hostnames,
customer or product names, work item IDs, or text quoted from a real PR, commit,
or ticket. Every example is made up. This repo is shared; a real example leaks
internal information, and the plugin's readers do not need it — the shape of
the example is the point, not its facts.

# When a change implements, rejects, or drops a backlog entry

This applies also when the work did not start from the backlog. When we have
processed an entry in `$env:USERPROFILE\.claude\feedback-backlog.md` or
`plugin-backlog.md` (implemented it or rejected it), tick it off (`- [x]`) at
that moment. Append the outcome:
`→ Promoted/Built/Rejected: <what and where, commit if any>`. When the user
drops an entry, delete its line at that moment, and for a plugin entry also its
handover file. Do not wait for the user to ask.

# Before committing

- Run the `d:review` skill before committing when the changes warrant it.
- **Version bump check.** Run `git diff --cached --name-only` (or `git status`).
  If any file under `plugins/d/` is in the commit and
  `plugins/d/.claude-plugin/plugin.json` is not, stop: bump `version` and stage
  it in the same commit. Installs are cached; without the bump the change never
  reaches an installed copy.
- **Rename verification.** After a rename, grep the repo for the old name — only
  intended generic prose should remain — and `git status` must show a skill
  rename as `R`, not delete+add.
- **Backlog check.** If the commit implements or rejects an entry in
  `feedback-backlog.md` or `plugin-backlog.md`, tick it off with its outcome
  before you commit. If the user dropped it, delete its line.
