---
name: local-links
description: Use before writing a link to a local file in user-facing text — a scratchpad file, a temp file, a log, or any other file outside the repo. Also use when the user asks for a clickable path, or when a local file link did not open.
---

# Local File Links

A bare path is long, and a relative path is not clickable. A markdown link with
a short label and a full URL is both short and clickable.

# When you write a link to a local file

Write a markdown link. The label is the file name. The target is a URL that
holds the **full absolute path**, from the drive letter to the extension.

The URL prefix comes from the `Local file links:` line that the session-start
hook puts into context. It names `vscode://file/` in a VS Code terminal and
`file:///` elsewhere. If the line is not in context, use `file:///`.

> `[analysis.md](vscode://file/C:/Users/ALEX~1.DOE/AppData/Local/Temp/claude/C--src-CLAUDE/<session-id>/scratchpad/analysis.md)`
>
> `[analysis.md](file:///C:/Users/ALEX~1.DOE/AppData/Local/Temp/claude/C--src-CLAUDE/<session-id>/scratchpad/analysis.md)`

The user sees only `analysis.md`. A click opens the file.

- Use the path from the environment as it is. The 8.3 short form
  (`ALEX~1.DOE`) works.
- Change every `\` to `/` in the URL.
- To point at a line with `vscode://file/`, add `:<line>` to the URL and to the
  label:
  `[analysis.md:12](vscode://file/C:/Users/ALEX~1.DOE/AppData/Local/Temp/claude/C--src-CLAUDE/<session-id>/scratchpad/analysis.md:12)`.
  A `file:///` URL cannot point at a line. Put the line in the text instead.

# Never write a link target like this

- ❌ a relative path
- ❌ `~/AppData/...` or any abbreviated home form
- ❌ a path with `\`
