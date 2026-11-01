$PatLinePattern = '(?m)^\s*ado_pat\s*:'
$SettingsFileName = 'monitor-devops.local.md'

$PatRule = 'The Azure DevOps PAT lives only in $env:ADO_PAT. A monitor-devops.local.md file has no ado_pat: line: ' +
    'the monitor-devops MCP server falls back to the environment variable, and a value in the file overrides it, ' +
    'so a stale value causes a 401. Remove the line; do not update it to a fresh value. ' +
    'Keep the file and its other keys (ado_org_url, ado_project, ado_team, ado_backlog); ado_team and ado_backlog are load-bearing.'

function Main {
    $hookInput = Read-HookInput
    if ($hookInput.hook_event_name -eq 'SessionStart') {
        $path = Get-SettingsFileWithPat -Directory (Get-SessionDirectory)
        if ($path) {
            Write-SessionReport -UserMessage "$path has an ado_pat: line. A stale PAT there overrides `$env:ADO_PAT and causes a 401." `
                -Context "$path has an ado_pat: line. $PatRule"
        }
        return
    }

    if (Test-WritesPatLine -ToolInput $hookInput.tool_input) {
        Write-Denial -Reason "This change writes an ado_pat: line into $(Split-Path -Leaf $hookInput.tool_input.file_path). $PatRule"
    }
}

function Read-HookInput {
    [Console]::InputEncoding = New-Object Text.UTF8Encoding $false
    return [Console]::In.ReadToEnd() | ConvertFrom-Json
}

function Test-WritesPatLine {
    param($ToolInput)

    if ((Split-Path -Leaf ([string] $ToolInput.file_path)) -ne $SettingsFileName) {
        return $false
    }
    $written = if ($null -ne $ToolInput.content) { $ToolInput.content } else { $ToolInput.new_string }
    return [string] $written -match $PatLinePattern
}

function Get-SettingsFileWithPat {
    param([string] $Directory)

    $path = Join-Path $Directory ".claude\$SettingsFileName"
    if (-not (Test-Path -LiteralPath $path)) {
        return $null
    }
    if ((Get-Content -LiteralPath $path -Raw) -notmatch $PatLinePattern) {
        return $null
    }
    return $path
}

function Write-SessionReport {
    param(
        [string] $UserMessage
        , [string] $Context
    )

    $output = @{
        systemMessage = $UserMessage
        hookSpecificOutput = @{
            hookEventName = 'SessionStart'
            additionalContext = $Context
        }
    }
    [Console]::OutputEncoding = New-Object Text.UTF8Encoding $false
    [Console]::Out.Write(($output | ConvertTo-Json -Compress -Depth 3))
}

function Get-SessionDirectory {
    if ($env:CLAUDE_PROJECT_DIR) {
        return $env:CLAUDE_PROJECT_DIR
    }
    return (Get-Location).Path
}

function Write-Denial {
    param([string] $Reason)

    $output = @{
        hookSpecificOutput = @{
            hookEventName = 'PreToolUse'
            permissionDecision = 'deny'
            permissionDecisionReason = $Reason
        }
    }
    [Console]::OutputEncoding = New-Object Text.UTF8Encoding $false
    [Console]::Out.Write(($output | ConvertTo-Json -Compress -Depth 3))
}

if ($MyInvocation.InvocationName -ne '.') {
    try {
        $ErrorActionPreference = 'Stop'
        Main
    }
    catch {
        # A failure here must never block the edit or the session start.
    }
    exit 0
}
