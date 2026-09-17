---
name: debug-setup
description: Use when the user first asks for debug or run support in a repo that has none, when creating or fixing `.claude/debugging.local.md`, a kill script, or VS Code `tasks.json` / `launch.json`, and when a build is blocked by locked binaries and no kill script exists yet.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# Setting up debug support in a repo

The run/debug contract itself — who starts services, who kills them — lives in
`User_CLAUDE.md` and is always in force. This skill is only the file scaffolding
that makes that contract concrete in a repo that does not have it yet.

When the user first asks for debug support in a repo, create both of the
following:

# When creating `.claude/debugging.local.md`

Record any repo-specific deviations from the default contract (e.g. which
IDE the user uses, which projects are startup projects, any env vars set
outside of launch configs).

Template:
```
# Debugging

The user owns the run/debug lifecycle. Claude owns kills.

Startup projects:
- $project_name (produces $project_name.exe)

Claude's contract:
- NEVER start services.
- MAY kill the project exes listed above when a build is blocked. Use
  `.claude/temp/kill-process-for-claude.cmd`.
- Ask the user to F5 / restart when a running service is needed.

Environment variables set by the IDE launch config (not by Claude):
- Web projects: ASPNETCORE_ENVIRONMENT = Development
- Non-web projects: DOTNET_ENVIRONMENT = Development (only when needed)
```

# When creating `.claude/temp/kill-process-for-claude.cmd`

Narrow to the project's own exe names:
```
@echo off
taskkill /F /IM $project_name.exe 2>nul
exit /b 0
```

Do not include a broad `dotnet.exe` / `node.exe` scan.

# When the user runs C# projects from VS Code: recommended layout

Applies whenever the user runs one or more C# projects from VS Code
(web apps, workers, console apps, test harnesses — any runnable project).
Create `.vscode/tasks.json` and `.vscode/launch.json`:

- `tasks.json` builds each startup project and a `build-all` compound.
  No kill task here — the IDE debugger stops its own processes, and
  kills belong to Claude's script, not the user's build flow.
- `launch.json` has one `coreclr` config per startup project plus a
  compound that launches them together. Point `program` at the compiled
  `.exe` (the AppHost), not the `.dll`, so F5 spawns the project's own
  exe (which the kill script can then match by name if ever needed).
- Set environment variables in `env` inside each launch config (not in
  `launchSettings.json`, which `dotnet exec` does not read):
  - Web projects (`Microsoft.NET.Sdk.Web`): `ASPNETCORE_ENVIRONMENT`,
    and `ASPNETCORE_URLS` if the project previously relied on URLs from
    `launchSettings.json`.
  - Non-web runnable projects: `DOTNET_ENVIRONMENT` if the Generic Host
    uses it; otherwise whatever the project itself reads.

Infer `$project_name` and the startup set from the repo context.
