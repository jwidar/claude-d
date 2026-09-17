---
name: caller-first
description: Use when the user finds code unclear, hard to follow, or wants to evaluate specific code from the caller's perspective. Also use when they say "this doesn't make sense", "what does this do", "this is confusing", or type /d:caller-first.
---

# Caller-First Analysis

The user is looking at code that does not make sense from where they stand. Your
job is to find out why and propose concrete changes.

# 1. Identify the target

If the user pointed at specific code (a file, a selection, a symbol), start
there. If they described the confusion without pointing, ask once — file or
symbol name is enough.

# 2. Read the target and its callers

Read the target code in full. Then find every caller — grep for the method,
class, or interface name across the codebase. Read each call site in enough
context (the enclosing method or block) to understand how the target is used.

# 3. Evaluate from the caller's view

For each caller, answer:

- Does the name tell the caller what this does — without opening the definition?
- Does the contract (parameters, return type, interface) make sense at the call
  site, or does the caller need implementation knowledge to use it correctly?
- Are there side effects the caller cannot see from the name and signature?
- If this is a feature root: does the entry point's code read as a complete
  picture, or does it force the reader to chase implementations?

# 4. Diagnose

State what is unclear and why, in one or two sentences. Common causes:

- The name does not cover the abstraction — it hints but does not tell.
- The interface leaks — the caller must know how the implementation works.
- Responsibilities are tangled — the method does more than its name says.
- The feature root scatters logic — understanding it requires reading several
  implementations.

# 5. Propose changes

Present each proposal as one finding using `AskUserQuestion`:

- **What to change** — rename, extract, split interface, move responsibility
- **Why** — what it fixes from the caller's perspective
- **Options**: Fix it / Note for later / Dismiss

Only propose changes that improve the caller's reading experience. Do not
propose changes for implementation internals the caller never sees.

On existing committed code, always propose — never apply silently.
