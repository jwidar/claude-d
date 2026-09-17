---
name: comments
description: Use before writing ANY code, not just when a comment is already in mind — check this before every code-writing or code-editing turn, including doc comments, TODOs, and commented-out code. Also use when reviewing a diff that adds or changes comments. Default is no comments; this skill is the last-resort check for the rare case one is warranted.
---

# Comments in Code

When a reader hits a comment, they read the comment instead of the code. The
comment hijacks the reading path — the reader switches from code to prose, and
that switch itself is the cost. In a well-known language — C#, TypeScript, Java,
Python, Go — a comment that restates what the code does is not help, it is a
second thing to read that says nothing new.

Default position: **write no comment.** Make the code say it instead.

The presence of a comment essentially means there is something wrong with the
code. They read as "either the code is wrong or the reason it exists is wrong
or the code is something the developer tried to avoid or wants to avoid."
Comments call for attention before the code, because they explain how fucked
up the situation is. In this regard, reading a comment that does NOT reveal how
bad everything is proves to be an utter waste of time and energy and is extremely
frustrating, especially when littered all over the place.

We have a policy to not write comments and to add one is truly called for only
as a last resort when the code alone does not make sense.

# Before writing a comment: never write these

- **Restating the code.**
  ```csharp
  // Increment the counter
  counter++;

  // Loop over the orders
  foreach (var order in orders)
  ```
- **Doc comments with no information.** A `<summary>` that is the member name
  with spaces added is noise.
  ```csharp
  /// <summary>Gets or sets the customer name.</summary>
  public string CustomerName { get; set; }
  ```
- **Narrating the edit.** `// Added null check`, `// Changed to use the new API`,
  `// Fixed bug`. That belongs in the commit message, where it stays accurate.
- **Commented-out code.** Delete it. Git has it, and a commented block is
  ambiguous forever — nobody knows if it is a spare part or dead weight.
- **Section dividers.** `// --- Fields ---`, `#region Private Methods`. If a
  class needs signposting to navigate, the class is too big.
- **Restating the signature in words.** `// Takes an id and returns the order`.

# Before writing a comment: the context is the code, never the journey

A comment is read months later by someone who has only the file in front of
them. They were not in the session, did not read the request, and do not know
what the code looked like before. Anything that only makes sense to someone who
was there is meaningless to them — and misleading, because it implies a history
they cannot see.

So a comment must never refer to:

- **The conversation.** `// as discussed`, `// per the requirement`,
  `// the user wants this configurable`.
- **The change.** `// now uses the cache`, `// replaced the old parser`,
  `// simplified from the previous version`. "Now" and "old" stop being true at
  the next edit.
- **The task or its steps.** `// step 3 of the migration`,
  `// temporary until we finish the refactor`.
- **You.** No notes from the author to the reviewer, no reasoning about how the
  code was arrived at.

Everything above belongs in the commit message, the pull request, or a document
— places where the history is the actual subject. Write every comment as if the
code had always looked this way.

# Before writing a comment: write it only when it says something the code cannot

A comment earns its place when it carries information that is **not derivable
from reading the code**:

1. **Why, not what.** A decision whose reasoning is invisible.
   ```csharp
   // Sequential, not parallel: the vendor API rejects concurrent
   // requests from the same key with a 429.
   ```
2. **Side effects at the call site.** Required when calling an external API or
   third-party library that does something not implied by its name.
   ```csharp
   // Also writes an audit row and sends the confirmation mail.
   this.orders.Complete(id);
   ```
3. **An external constraint or workaround.** A spec rule, a protocol quirk, a
   library bug. Include the source — a link, an issue number, a spec section —
   so it can be checked and eventually removed.
4. **A non-obvious business rule.** Where the value comes from and why, when the
   code alone would look arbitrary.
   ```csharp
   // Invoices older than 18 months are archived by law (BFL 7:2).
   var cutoff = today.AddMonths(-18);
   ```
5. **A warning about a real trap.** Something a future reader would plausibly
   break by "cleaning up".
6. **A swallowed exception.** An empty `catch` block is a code smell that looks
   like an unintentional mistake. Always explain why the exception is silently
   caught.
   ```csharp
   catch (Exception)
   {
       // This is intentional because of reason X.
   }
   ```

# When writing a comment that earns its place: how it must read

The same rule as messages to the user — see the **How to talk to me** section
of `User_CLAUDE.md`. A comment is prose, and dense prose is exactly what
makes comments not worth reading.

- Plain sentences. No invented shorthand, no acronyms introduced without
  expansion.
- State the fact, not a hint at it.
- Two lines is usually enough. If it takes a paragraph, the code needs
  restructuring or the explanation belongs in a document.
- **Implementation comments go inside the body, not above the member.** A comment
  above a method or property declaration reads like contract documentation — the
  reader treats it as something they need to read to use the member. If the
  comment explains internal behaviour (why the implementation works a certain
  way), it belongs inside the method body, next to the code it explains.

# When writing a comment: keep it smaller than the code it annotates

A comment must never outweigh the code it annotates. A one-line guard clause,
a simple null check, or a short return does not earn a multi-line comment — if
it earns one at all. When the code is shorter than the comment, the comment is
the problem.

# When you feel the urge to comment: prefer these over a comment

Most urges to comment are a naming or structure problem in disguise:

- **Rename.** A comment explaining what a method does means the name does not.
- **Extract.** A comment labelling a block ("// validate the request") means
  that block wants to be a method with that name.
- **Name the value.** A comment explaining a literal means it wants to be a
  named constant.

# When writing a TODO

Only with an owner and a tracked item, or they become permanent litter:
`// TODO(jonas, #4821): remove once the legacy feed is off.` A bare `// TODO`
gets deleted.

# When editing existing code

- **Delete redundant comments in the code you touch.** Do not preserve noise out
  of politeness to whoever wrote it.
- **A comment that no longer matches the code is a bug.** Fix it or delete it —
  never leave it.
- Do **not** sweep an entire file or repo for comment cleanup unless asked. Stay
  inside the change you are already making.

# When reviewing a diff that adds or changes a comment

Treat an added comment as a finding when it restates the code, narrates the
edit, or is written densely enough to need a second read. Say which of the two
fixes applies: delete it, or replace it with the reason behind the code.
