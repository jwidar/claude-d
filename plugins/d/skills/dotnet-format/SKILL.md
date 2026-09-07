---
name: dotnet-format
description: Use before running `dotnet format` across more than one file, a whole project, or a whole solution — or any time formatting/cleanup output needs closer inspection than the per-file save hook gives. Also use when creating or reviewing a repo's `.editorconfig` for gaps in the structurally-risky rule list, and when `dotnet format` reports a violation it could not fix.
---

# Safe dotnet format

The per-file `PostToolUse` hook (`plugins/d/hooks/format-cs-on-edit.ps1`) already
formats one file at a time at the repo's default severity. It is safe by
construction: single file, default severity, no manual severity override. This
skill governs everything the hook does not cover — a deliberate multi-file or
whole-solution pass, a diagnostic run to find something the hook missed, or
authoring/reviewing `.editorconfig` itself.

It exists because of one incident: raising `--severity` to see more diagnostic
detail silently changed which fixes got *applied* solution-wide, converting
~150 files of hand-written constructors into primary constructors — a hard
style violation. Follow the rules below to make that class of mistake
structurally impossible instead of relying on catching it after the fact.

## Rule 1 — never raise `--severity` to see more detail

In `dotnet format`, severity is not a reporting filter. It is the threshold for
which fixes get **applied**. Raising it from the project's configured default
(commonly `warning`) to `info` or `silent` does not just show you more
diagnostics — it applies every suggestion/silent-level fix in scope, including
ones your `.editorconfig` pins to a stricter style (see Rule 3).

Never run `dotnet format --severity info` (or `silent`) as a way to inspect
what's wrong. Use one of these instead, all of which surface file/line without
touching the apply threshold:

- **`dotnet format --verify-no-changes --report <path>`** — reports every
  location that *would* change, at the project's configured severity, without
  writing anything. Read the JSON report for file/line.
- **`dotnet format analyzers --diagnostics <ID>`** — targets exactly one
  diagnostic ID (e.g. `IDE1006`) at the default severity. Use this to isolate
  one rule's violations without touching any other rule's threshold.
- **A build with analyzers** (`dotnet build /p:TreatWarningsAsErrors=false`
  or just reading normal build output) — the compiler's own diagnostics
  already carry file/line for anything configured above `silent`.

## Rule 2 — auto-apply vs suggest-only

Before running any fix-applying command, classify what it will touch:

- **Auto-apply** — zero semantic or style risk. Whitespace, indentation,
  `using` sorting, `this.` qualification, naming-convention renames that match
  an existing `.editorconfig` naming rule. Safe to run and commit without
  asking first.
- **Suggest-only** — anything that changes code *shape or structure*, even if
  an analyzer calls it "correct": primary-constructor conversion, expression-
  bodied member conversion, pattern-match rewrites, LINQ-chain rewrites, brace
  removal/insertion beyond the plain style the project has pinned. These
  always go through the normal propose-before-implementing workflow — show
  the diff, wait for a decision, never apply silently as part of a "just
  formatting" pass.

A whole-solution `dotnet format` (no `--include` scoping) is capable of
producing suggest-only changes even at the correct severity, because
`.editorconfig` may not yet pin every risky rule (Rule 3). Treat the first run
in any repo as diagnostic — run with `--verify-no-changes --report` first,
scan the report for suggest-only categories, and only then decide whether to
apply.

## Rule 3 — pin structurally risky rules in `.editorconfig`

These analyzer rules change code *shape*, not just whitespace, so an unpinned
one will happily "fix" hand-written code into a different valid style the
moment severity allows it. Check every `.editorconfig` you create or touch for
explicit severities on these — an absent entry means the .NET SDK default
applies, which is often more aggressive than this project's house style:

| Rule | What it rewrites | This project's house style |
|---|---|---|
| `IDE0290` | Constructor → primary constructor | `csharp_style_prefer_primary_constructors = false` — this plugin disallows primary constructors |
| `IDE0021`/`IDE0022`/`IDE0025`/`IDE0027` | Method/property/accessor → expression-bodied member | Set explicitly per the project's preference; do not leave at SDK default if expression-bodied members are unwanted for multi-statement members |
| `IDE0057`/`IDE0058`/`IDE0059` | Substring/discard/unused-value rewrites | Usually safe, but confirm — these can change control flow subtly |
| `IDE0072` | Switch expression completeness rewrites | Can restructure a switch statement into an expression; suggest-only unless pinned |
| `IDE0090` | `new()` target-typed rewrites | Cosmetic; safe to auto-apply once pinned to the wanted form |
| `IDE0300`–`IDE0305` | Collection-initializer / collection-expression rewrites | Can change allocation shape; pin explicitly |
| `csharp_prefer_braces` | Adds braces around embedded statements | See Rule 4 — wanted, but the fixer alone does not fully match house style |
| Pattern-matching rules (`IDE0078`, `IDE0083`, `IDE0084`) | `if`/`is` chains → pattern-match rewrites | Suggest-only; pin to whatever this project actually wants, do not leave implicit |

When reviewing a new or updated `.editorconfig`, check this table proactively
— do not wait for a bad `dotnet format` run to reveal a gap. Report every rule
in the table that has no explicit severity as a finding, the same way a missing
test would be flagged.

## Rule 4 — grep for known-bad shapes after any format pass

Some fixes are individually correct but combine into an ugly result the
formatter does not clean up on its own. After any multi-file `dotnet format`
run, grep the touched files for these before considering the pass done:

- **Collapsed single-line brace body** — `csharp_prefer_braces = true:error`
  adds braces around an embedded statement but does not reflow the body onto
  its own line, leaving `{ return "Revoked"; }` on one line. House style is
  always one statement per line inside braces. Search touched files for a
  brace pair opening and closing on the same line as a statement:
  ```
  grep -nE '\{\s*[^{}]+;\s*\}' <touched files>
  ```
  Any hit that is not an empty block (`{ }`) or a legitimate single-line
  collection/object initializer is a violation — reflow it: opening brace at
  end of the `if`/`else`/loop line, statement on its own line, closing brace
  on its own line.

Add further known-bad shapes to this list as they turn up — this section is
meant to grow, not be exhaustive on day one.

## Rule 5 — finish what `dotnet format` reports as unfixable

Roslyn's `NamingStyleCodeFixProvider` (backing `IDE1006`) does not support
"Fix All in Solution/Document". `dotnet format` reports these as "Unable to
fix IDE1006" with no file/line and moves on — it does not mean the violation
doesn't exist, only that the bulk fixer can't apply it.

When this happens:

1. Run `dotnet format analyzers --diagnostics IDE1006 --verify-no-changes --report <path>` (Rule 1) to get every occurrence with file/line, not just the count.
2. For each occurrence, read the naming rule it violates from `.editorconfig` (e.g. private static fields need an `s_` prefix).
3. Locate every reference to the symbol — declaration and all usages, typically confined to one file for a `private`/`private static` member — with Grep.
4. Apply the rename yourself across all of them. This is a pure rename (auto-apply per Rule 2): it changes no behavior, only the identifier.

Never leave this for the user to trip over as an IDE squiggle later — a
reported-but-unfixed diagnostic is a to-do the tool already found for you.
