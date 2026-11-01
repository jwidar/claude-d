$StartPatterns = @(
    '(^|[\s;&|(])dotnet\s+(run|watch)\b'
    '(^|[\s;&|(])(npm|pnpm|yarn)\s+(run\s+)?(start|dev|serve|preview|watch)\b'
    '(^|[\s;&|(])Start-Process\b'
)
$MaxCommandLength = 120

function Main {
    $hookInput = Read-HookInput
    $reason = Get-GateDecision -Command $hookInput.tool_input.command -StartWithoutAsking $env:D_START_WITHOUT_ASKING
    if ($reason) {
        Write-Ask -Reason $reason
    }
}

function Read-HookInput {
    [Console]::InputEncoding = New-Object Text.UTF8Encoding $false
    return [Console]::In.ReadToEnd() | ConvertFrom-Json
}

function Get-GateDecision {
    param(
        [string] $Command
        , [string] $StartWithoutAsking
    )

    if ($StartWithoutAsking -eq '1') {
        return $null
    }
    foreach ($pattern in $StartPatterns) {
        if ($Command -match $pattern) {
            return "Start a program: $(Limit-Text -Text $Command). By default you start services yourself (F5 or a launch profile)."
        }
    }
    return $null
}

function Limit-Text {
    param([string] $Text)

    $singleLine = ($Text -replace '\s+', ' ').Trim()
    if ($singleLine.Length -le $MaxCommandLength) {
        return $singleLine
    }
    return $singleLine.Substring(0, $MaxCommandLength) + '...'
}

function Write-Ask {
    param([string] $Reason)

    $output = @{
        hookSpecificOutput = @{
            hookEventName = 'PreToolUse'
            permissionDecision = 'ask'
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
        # A failure here must never block the command.
    }
    exit 0
}
