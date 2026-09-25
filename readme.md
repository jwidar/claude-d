# jwidar — Claude Code plugin marketplace

A **plugin marketplace** for Claude Code: skills, agents, and hooks packaged
as an installable plugin, kept in its own repo so it can be shared and
versioned independent of any one project or machine. Machine- and
user-specific configuration (always-on instructions, portable settings,
install script) is deliberately kept elsewhere — this repo only carries
things that work the same for anyone who installs the plugin.

## What's inside

- **Plugin `d`** (`plugins/d/`) — the portable capabilities. The name is a single
  letter so skills invoke as `/d:review` rather than something long to type:
  - skills: `review`, `teach`, `status`, `git-state`, `scratchpad`,
    `comments`, `tool-authoring`, `debug-setup`, `expert`, `caller-first`,
    `iis-config`, `dotnet-format`, `plugin-feedback`, `show-backlog`
  - agents: `systems-architect`, `csharp-style-reviewer`, `avalonia-ui-specialist`
  - hooks: a `PostToolUse` hook that applies `.editorconfig` formatting
    (`dotnet format`) to the `.cs` files touched by a `Write`/`Edit`, a `Stop`
    hook that summarizes the formatting time spent, and a `SessionStart` hook
    that warns when the launch path's casing does not match the filesystem's
    own

## Install on a machine

This repo has no install script of its own — it expects to be registered as
a local plugin marketplace by whatever settings.json points at it (directly,
or via a sibling repo's setup script), with `d@jwidar` then enabled in
`enabledPlugins`. Point a marketplace registration's `path` at a local clone
of this repo, or add it as a marketplace source by its GitHub URL.

## Update

Edit the plugin, then in any session run `/plugin marketplace update` (installs
are cached, so changes go live on update).
