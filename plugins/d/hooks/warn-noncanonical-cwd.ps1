# SessionStart hook: warn when Claude Code registered this session under a
# project key whose casing does not match the filesystem's own.
#
# Why this matters:
#   Claude Code keys project state -- trust flags, onboarding, transcript and
#   memory directories -- by the literal path string it was launched with.
#   Windows paths are case-insensitive but case-PRESERVING, so `C:\SRC\CLAUDE`
#   and `C:\SRC\claude` are one directory yet two separate project keys. The
#   result is split memory, repeated trust dialogs, and duplicate entries in
#   ~/.claude.json.
#
# How the key is read:
#   The launch string is not exposed as an environment variable, and the shell's
#   cwd is not it: a RESUMED session keeps the original launch string while the
#   shell sits in the correct directory, and an editor-launched session gets its
#   string from VS Code rather than the shell. The SessionStart payload's
#   `transcript_path` is authoritative -- its parent directory name is the
#   launch string with every non-alphanumeric turned into `-`. Comparing that
#   encoded name catches both cases, and ignores the difference between forward
#   and back slashes, which is not a real mismatch.
#
# Contract:
#   - Runs at session start.
#   - Emits nothing when the key already matches the filesystem.
#   - Falls back to comparing the cwd when the payload has no transcript path.
#   - Never blocks and never fails the session: always exits 0.
#   - Cannot repair the current session -- the project key is assigned before
#     hooks run. It reports, so the next launch can be corrected.

$rawStdin = [Console]::In.ReadToEnd()

# Get-TrueCasePath is shared with the profile wrappers setup.ps1 installs.
# Missing helper means no check, never a failed session.
$helper = Join-Path $PSScriptRoot 'Get-TrueCasePath.ps1'
if (-not (Test-Path -LiteralPath $helper)) { exit 0 }
. $helper

# Encodes a path the way Claude Code names its per-project directory under
# ~/.claude/projects: every character that is not a letter or digit becomes a
# dash. Underscores and dots go too -- `C:\SRC\_FireBot` is keyed as
# `C--SRC--FireBot` -- so replacing only the separators would report a mismatch
# on a path whose casing is perfectly fine.
function ConvertTo-ProjectKeyName {
    param([string] $Path)

    return ($Path.TrimEnd('\', '/') -replace '[^a-zA-Z0-9]', '-')
}

# Pulls one string field out of the raw JSON payload. A regex rather than a
# parser: the payload is flat, and the hook must never fail on a shape change.
function Get-PayloadField {
    param([string] $Json, [string] $Name)

    if ([string]::IsNullOrWhiteSpace($Json)) { return $null }
    $pattern = '"' + [regex]::Escape($Name) + '"\s*:\s*"((?:[^"\\]|\\.)*)"'
    $match = [regex]::Match($Json, $pattern)
    if (-not $match.Success) { return $null }

    return $match.Groups[1].Value -replace '\\\\', '\'
}

$cwd = Get-PayloadField -Json $rawStdin -Name 'cwd'
if ([string]::IsNullOrWhiteSpace($cwd)) { $cwd = $env:CLAUDE_PROJECT_DIR }
if ([string]::IsNullOrWhiteSpace($cwd)) { $cwd = (Get-Location).Path }

$trueCase = Get-TrueCasePath -Path $cwd
if ($null -eq $trueCase) { exit 0 }

$expected = ConvertTo-ProjectKeyName -Path $trueCase

$transcript = Get-PayloadField -Json $rawStdin -Name 'transcript_path'
if ([string]::IsNullOrWhiteSpace($transcript)) {
    # No transcript path in the payload: fall back to the cwd, which is right
    # for a freshly launched terminal session and wrong only for a resume.
    $actual = ConvertTo-ProjectKeyName -Path $cwd
}
else {
    $actual = Split-Path -Path (Split-Path -Path $transcript -Parent) -Leaf
}

if ([string]::IsNullOrWhiteSpace($actual)) { exit 0 }
if ($actual -ceq $expected) { exit 0 }

Write-Output @"
NON-CANONICAL LAUNCH PATH -- tell the user about this in one line, early.

This session is registered under : $actual
The filesystem's own casing gives : $expected

Claude Code keys project state by the launch string, so this session gets its
own trust flag, transcript directory and memory folder, separate from sessions
launched with the filesystem's casing. Memory written here will not be visible
from the correctly-cased path, which is "$trueCase".

The ``claude`` and ``code`` wrapper functions installed by this repo's setup.ps1
normally prevent this. Common reasons one still slips through:

  - the session was RESUMED, so it kept the path the original session used
  - the editor was opened from its recent-folders list or the Start menu,
    rather than by typing ``code <folder>`` in a shell
  - the shell predates setup.ps1 and has not reloaded its profile

Reopening the folder with ``code <folder>`` from a PowerShell terminal, then
starting a NEW session rather than resuming, lands on "$trueCase".
"@

exit 0
