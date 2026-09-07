---
name: scratchpad
description: Use BEFORE the first tool call that writes, edits, reads, or lists a file under the session scratchpad or any temp directory, and before any message that names such a file — temp scripts, notes, intermediate results, analysis output, anything that would otherwise go to /tmp. Also use when deciding where to put a temporary file, when the user asks where a temp file went, and on every later mention of one. Applies even to a single file, a one-line mention, or a path you already wrote out earlier.
---

# Scratchpad Files

The scratchpad path is long and session-specific, so it is tempting to shorten it
to `scratchpad/notes.md` or "the file I just wrote". Don't. A shortened path is
**not clickable** in the user's terminal — they cannot open it in VS Code, and
they have no way to reconstruct the full path themselves.

## The rule

Every time a scratchpad file is mentioned in user-facing text, write the **full
absolute path**, from the drive letter to the extension:

> `C:\Users\JONAS~1.WID\AppData\Local\Temp\claude\C--src-CLAUDE\<session-id>\scratchpad\analysis.md`

This holds for **every** mention, not just the first:

- The message where you create the file.
- Any later message that refers back to it ("as noted in …").
- Lists of several scratchpad files — each line gets its own full path.

Repetition is the point. The user's working memory does not carry the path
between messages, and a path they saw three messages ago is not clickable now.

## Never do this

- ❌ `scratchpad/analysis.md` — relative, not clickable
- ❌ `<scratchpad>/analysis.md` or `$SCRATCHPAD/analysis.md` — placeholders
- ❌ "I saved it to the scratchpad" — no path at all
- ❌ "the file above" / "the same file" on a follow-up mention
- ❌ `~/AppData/...` or any abbreviated home form

## Also

- Use the session scratchpad directory for temp files, not `/tmp` or the project
  tree — unless the user explicitly asks otherwise.
- One path per line when listing files; do not bury a path mid-sentence in prose.
