---
name: review
description: "Use when the user asks to review code, review changes, or critique code quality, and before every commit. Examples: review this code, review my changes, code review, look this over before I commit"
allowed-tools: Bash, Read, Grep, Glob, AskUserQuestion, Agent
---

# Dev Review

You are performing a local-centric code review. Follow these steps in order — do not skip the context-gathering steps.

## 0. Pre-check: Existing PR Feedback

If the user presents a workitem or pull request, use `AskUserQuestion` to ask whether you should read the PR first to gather existing feedback. This avoids over-commenting with feedback that is already under control. Only proceed to the review after the user responds.

## 1. Gather Context

### 1a. Determine target branch and fetch

Determine the default branch of the remote:
```
git remote show origin | grep 'HEAD branch' | sed 's/.*: //'
```

Fetch to ensure remote tracking refs are current:
```
git fetch origin
```

Use `origin/<default-branch>` as the comparison target throughout the review. This represents the remote state of the target branch — the same baseline a pull request would use.

### 1b. Obtain the diff

- **Default: All branch changes** — run `git diff origin/<default-branch>...HEAD` to see everything introduced on this branch since it diverged.
- If reviewing specific staged changes: run `git diff --cached`
- If reviewing a specific file: run `git diff origin/<default-branch>...HEAD -- <file>`

Collect the list of changed files:
```
git diff --name-only origin/<default-branch>...HEAD
```

### 1c. Read changed files in full

The diff alone is not enough. For every file that appears in the diff, read the complete current version of that file. You need to understand:
- What the surrounding code looks like (the functions, classes, and modules the changes live inside)
- How the changed code integrates with its immediate neighbors
- Whether the changes are consistent with the rest of the file

### 1d. Study adjacent code and existing patterns

Before forming any opinions, examine the broader context:
- **Imports and dependencies** — read files that the changed files import from or depend on (interfaces, base classes, shared utilities)
- **Sibling files** — if a changed file follows a pattern (e.g., other controllers, other services in the same folder), read one or two siblings to understand the established conventions
- **Architecture and patterns** — identify the design patterns in use (dependency injection, repository pattern, mediator, etc.) so you can evaluate whether the changes respect or violate them

Do not skip this step. Many review findings come from understanding how changes fit into — or conflict with — the existing codebase, not from the diff in isolation.

### 1e. Determine review scope

Now that you have context, confirm the scope:
- What is the apparent intent of the changes? (new feature, bug fix, refactor, etc.)
- If the intent is unclear, ask the user before proceeding to the review.

### 1f. Check for matching pull request

Detect the repository name from the git remote URL:
```
basename -s .git "$(git remote get-url origin 2>/dev/null)"
```

If a DevOps integration is available, use it to check whether an active PR exists whose source branch matches the current branch. If a matching PR is found:
- Show the PR title, ID, and target branch
- Note that PR commenting will be available as an option per finding during the review

If no matching PR is found, or if no DevOps integration is available, proceed with local-only review silently. Do **not** ask for a blanket delivery choice here — each finding will be handled individually in step 3.

### 1g. Architectural assessment

Use the Agent tool to launch the `d:systems-architect` agent. Provide it with:
- The full diff from step 1b
- The list of changed files
- A summary of the patterns and architecture observed in steps 1c and 1d
- The intent/scope determined in step 1e

Prompt the architect to evaluate:
1. Whether the changes respect or violate existing architectural patterns
2. SOLID principle compliance at the component and system level
3. Abstraction boundaries — are responsibilities in the right place?
4. Component coupling — do the changes introduce inappropriate dependencies?
5. Whether the design approach is fundamentally right for the problem, or if a better structure exists

Retain the architect's findings for integration into the review in Phase 2 and presentation in Phase 3 at the highest priority tier. If the architect identifies no concerns, note that the changes are architecturally sound and proceed.

## 2. Review Criteria

Evaluate the code against these criteria:

### Architecture (from systems-architect)

Incorporate findings from the architectural assessment in step 1g. These are informed design evaluations, not suggestions — treat them as high-priority findings above all other categories.

Architectural findings include:
- Violations of established patterns in the codebase
- SOLID principle violations with structural impact (component and system level)
- Misplaced responsibilities or incorrect abstraction boundaries
- Coupling issues that will cause maintenance problems
- Fundamentally wrong design approaches for the problem at hand

Do not soften or hedge architectural findings. Present them as what they are: professional design evaluations backed by analysis of the codebase's existing architecture.

### Correctness
- Does the code do what it's supposed to our plan?
  - Is there no plan? Ask more questions about details
- Are there edge cases not handled?
- Are there potential runtime errors?
- Are relevant tests maintained?

### Security
- Input validation at system boundaries
- No SQL injection, XSS, command injection vulnerabilities
- Secrets not hardcoded
- Proper authentication/authorization checks

### Design (local patterns and style)

_For systemic architectural concerns, see Architecture above. This section covers file-level and method-level design._
- Does it follow existing patterns in the codebase?
- Single Responsibility - does each unit have one reason to change?
- Are abstractions at the right level?
- Is it over-engineered or under-engineered?
- Are the methods too long?
- Does it use static classes and methods unnecessarily?
- Does it avoid passing primitives as arguments? (true/false is often not very descriptive at the call site)
- **Caller-first**: does the code make sense from the call site without chasing implementations? Find callers of changed methods and interfaces — does the name and contract serve the caller's understanding? Flag abstractions that leak implementation details into the caller.
- **Infrastructure code**: entry points, configuration, service registration, and wiring are feature roots — they must read as a clear outline. Flag methods that mix registrations with building, execution, or validation in one long body. These should be broken into named methods whose names clarify the segments.

### Readability
- Are names descriptive and accurate?
  - Is it clear from the call site what the code means?
  - Does each name cover its abstraction completely — or does the reader need to open the definition to understand what they are looking at?
  - Do names serve the caller's understanding, or only the implementer's?
- Is the code self-documenting?
- Can a feature root's code be understood without chasing the implementations behind it?
- **Comments** — judge every added or changed comment against the `d:comments`
  skill, and raise what it disallows as a finding.

### Code style

- Standard `.editorconfig` formatting is applied automatically by a PostToolUse hook on Write/Edit (`dotnet format`), so do not raise findings for whitespace, indentation, or `using` ordering — assume they are already correct.
- For the personal C# conventions a formatter cannot enforce (comma-first argument wrapping, no primary constructors, fluent-chain breaking, Moq `Verify`/`Setup` wrapping, one-type-per-file, etc.), consult the `d:csharp-style-reviewer` agent on the changed `.cs` files and fold its findings in here.
- If the diff touches `.editorconfig`, consult `d:dotnet-format` and check it against the structurally-risky rule table — an unpinned risky rule is a finding, not just a future risk.
- If the diff was produced or followed by a multi-file `dotnet format` pass, apply `d:dotnet-format`'s Rule 4 grep for known-bad shapes (e.g. collapsed single-line brace bodies) before approving.
- Raise violations as findings scoped to the changed files. If a clean fix would touch many files outside the current work, note it but don't expand scope — ask the user first.

### Maintainability
- Is it testable?
- Are dependencies explicit?
- Will future developers understand the intent?
- Are breaking changes introduced without good reason?

## 3. Interactive Review

Present findings one at a time in an interview format. Never dump all findings at once.

Findings arrive as reports from `d:systems-architect` and `d:csharp-style-reviewer`.
Reword them plainly before presenting any of them — never paste a report through.

### 3a. Opening summary

Start with a single sentence describing the overall scope and nature of the changes. Do **not** list individual findings yet. Mention a few positive observations here if appropriate (keep brief, 2-3 bullet points max).

### 3b. Walk through each finding

Order findings by priority: Architecture first (from step 1g), then Critical, then Major, then Minor. When presenting architectural findings, state them with conviction — these are evaluated design positions, not tentative suggestions. Use language like "This violates...", "This should be...", "The correct approach is..." rather than "You might consider..." or "It could be better to...". For each finding, present:

- **Severity** and brief title
- **File**: `path/to/file.ext:line`
- **Issue**: Description of the problem
- **Suggestion**: How to fix it

Then use `AskUserQuestion` to let the user decide what to do with this specific finding. Always offer **at least** these options (use these exact labels in AskUserQuestion):
- **Fix locally** — mark for local fix
- **Comment on PR** — mark for posting as a PR comment (always offer this — the user may know a PR exists or plan to create one, even if the upfront check in 1f didn't find one)
- **Dismiss** — dismiss the finding

You may add a fourth option if you have a more specific or better-suited action to suggest for the particular finding.

The user can always provide free-text input via "Other" to discuss further, refine the finding, or explain their reasoning. If the user wants to discuss, engage in the discussion and then re-ask the action question.

Wait for the user's response before presenting the next finding.

### 3c. Action summary

After all findings have been walked through, produce a final summary grouped by chosen action:

**Issues to fix locally:**
List each agreed issue with file:line reference, one per line.

**Issues to post to PR:**
List each issue marked for PR commenting. Then execute: for each, use the DevOps integration to post the finding as an inline PR comment on the relevant file and line. Use markdown formatting and mark each thread as active.

**Dismissed issues:**
List briefly, for the record.

End with an overall verdict: **APPROVE**, **REQUEST CHANGES**, or **NEEDS DISCUSSION** — based on the issues the user agreed with (not the dismissed ones).

**Plan mode compatibility:** The action summary is purely documentation of review decisions — it does not require editing code. If plan mode is active, write the action summary as implementation tasks in the plan file. Each "fix locally" item becomes a task with file:line and what to change. Each "comment on PR" item becomes a task to post the comment. This way the review flows naturally into plan-then-implement.

## 4. Documentation restraint

A review produces findings and an action summary. It does **not** produce
documentation byproducts:

- Do not add backlog entries, TODO items, or memory entries per finding.
- Do not grow READMEs, changelogs, or other docs as a side effect of the review.
- Do not add multi-line comments to explain one-line fixes.

The action summary in step 3c is the only record. Everything else is noise.

## 5. Guidelines

- Be specific - reference exact file paths and line numbers
- Be constructive - suggest fixes, don't just criticize
- Prioritize - focus on issues that matter (architecture > correctness > security > design > style)
- Take strong positions on architecture — the systems-architect agent provides informed design evaluations, not suggestions. Present architectural findings as professional assessments, not options to consider.
- Be concise - the user steers from overview, dive into details only when asked
- Don't nitpick style unless it affects readability significantly
- Always present findings interactively, one at a time — never batch them into a single output block
