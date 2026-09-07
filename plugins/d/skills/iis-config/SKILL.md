---
name: iis-config
description: Use when writing or reviewing a deployment script, install script, or provisioning code that touches IIS site settings (app pool identity, bindings, authentication, request limits, custom headers, etc.), and when deciding where an IIS setting belongs.
---

# IIS Configuration Placement

Site-level IIS settings belong in the application's own `web.config`, not in a
deployment script, install script, or provisioning tool (PowerShell, MSDeploy,
appcmd, etc.).

**Why:** a setting written by a script only exists if that script ran. It is
invisible to anyone reading the deployed application, is not versioned with the
app, and silently reverts or diverges if the site is ever recreated, redeployed
by a different script, or moved to a different server. `web.config` travels
with the app, is versioned in the app's own repo, and applies the same way on
every server without any script having to remember to set it.

## What goes in web.config

Anything the application itself is entitled to declare: authentication mode,
custom headers, request/response limits, URL rewrite rules, error pages,
compression, MIME types, session state, and any `<system.webServer>` /
`<system.web>` element.

## What stays in the deployment/install script

Only things that are properties of the *machine* or the *IIS installation*
itself, not the app: creating the app pool, setting the app pool's .NET
version or identity account, creating the site/binding itself, installing
IIS features/modules, and certificate binding. These cannot live in
`web.config` because they exist before the app's `web.config` is ever read.

## Reviewing a script

If a deployment or install script sets a value that also has a `web.config`
element for it (e.g. request limits via `appcmd set config` instead of
`<requestLimits>`), flag it and propose moving it to `web.config`.
