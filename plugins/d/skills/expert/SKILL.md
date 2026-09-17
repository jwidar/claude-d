---
name: expert
description: Use when the user types /d:expert, says "hey expert", "ask the architect", "ask the style reviewer", "let's talk architecture", "let's discuss the design", or otherwise addresses a specialist by role or domain rather than asking Claude directly. Also use when the user asks to switch experts or says "different expert".
allowed-tools: Agent, Read, Write, Glob, Skill
---

# Expert Routing

This skill routes the user's message to one of the specialist agents and keeps
the choice sticky for the rest of the session.

# Available experts

| Key            | Agent type               | Domain                                    |
|----------------|--------------------------|-------------------------------------------|
| `architect`    | `d:systems-architect`    | Architecture, patterns, data flow, SOLID  |
| `csharp-style` | `d:csharp-style-reviewer`| C# style conventions beyond the formatter |

# When the user addresses an expert: routing

1. **Check for a sticky choice.** Read `<scratchpad>/expert-choice.txt`. If it
   exists and names a valid key, use that expert — skip to step 3.

2. **Infer from context.** Look at what the user said and what files are open.
   Pick the expert whose domain fits. When it is ambiguous, pick `architect` —
   it has the broader scope. Do not ask; the user said "expert", not "help me
   choose an expert."

3. **Save the choice.** Write the key to `<scratchpad>/expert-choice.txt` (create
   or overwrite).

4. **Launch the agent.** Pass the user's message (everything after `/d:expert` or
   the greeting) as the prompt. Include enough repo context for the agent to work
   — the current file, the diff, or whatever the question needs.

5. **Relay the answer.** Return what the agent said. Do not summarise, reframe, or
   add your own opinion on top of the agent's output.

# When the user asks to switch expert

If the user says "switch expert", "different expert", or names the other domain
explicitly ("ask the style reviewer"), overwrite the sticky choice and route
there instead.

# What this skill does NOT do

- It does not hold any of the experts' rules — those live in the agent files.
- It does not answer the question itself. If no expert fits, say so in one line.
