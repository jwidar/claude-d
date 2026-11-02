---
name: secure-design
description: Use when designing, writing, or reviewing code that handles access or authentication, external input, sensitive data, secrets, logging, error handling, or dependencies. Also use when the user asks whether something is secure.
---

# When you design or write a change

Security is part of the design, not a layer added afterwards. Answer the question
of each principle that the change touches. Many answers are the same as for the
last change in the same area, and that is fine. None may be answered by accident.

- **Secure by default.** Most users never change the default settings. What
  happens if nobody changes the configuration?
- **Least privilege.** Users and systems have only the access they need to do
  their job. Who can access what, and what is the minimum access required?
- **Nothing from outside is trusted.** External data is validated before it is
  used. What enters the system here, and where is it checked?
- **Reuse proven security mechanisms.** Home-made authentication or encryption
  creates security and maintenance risks. Which proven mechanism does this use,
  and if none, why is a custom solution needed?
- **Protect sensitive information.** The protection matches the sensitivity of
  the information. What data does this handle, and what protection does it need
  in storage and over the wire?
- **Actions must be traceable.** Important actions leave enough evidence to
  investigate an incident. What is logged or recorded, and is it enough to
  investigate an incident?
- **Stay secure when things fail.** An error must not lead to more access or
  less protection. What happens when this fails, and what does the error tell
  the caller?
- **Assume protections can fail.** One failed security check must not be
  enough to compromise the system. If this check fails, what protection
  remains?
- **Know our dependencies.** Every dependency adds risk and maintenance work.
  What do we rely on, and how are vulnerabilities and updates handled?

You decide how. Do not ask the user to choose between a secure and a less
secure option; take the secure one and say why in one line.

# When you review a change

Answer the same questions for the changed code. A question that the change
touches and answers wrongly, or does not answer, is a finding. Also check the
code for these defects:

- Input used without validation at a system boundary.
- Injection: SQL, command, path, or markup built from input without
  parameterization or encoding.
- A secret in the code, in a config file, or in a log line.
- An endpoint or operation without an authentication or authorization check.
- An error message or log line that shows internal details or sensitive data.

# When a change needs expertise that you and the specialist agents do not have

Say so, and recommend a specialist. Do this also when a change introduces a
security risk that the design cannot remove.
