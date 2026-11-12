Import-Module (Join-Path $PSScriptRoot 'AnswerableAsk.psm1') -Force

$PushPattern = '(^|[\s;&|(/\\"''])git(\.exe)?["'']?(\s+(-C\s+("[^"]+"|\S+)|-c\s+("[^"]*"|\S+)|--(git-dir|work-tree|namespace|exec-path|config-env)\s+("[^"]*"|\S+)|--[\w-]+(=\S+)?))*\s+push\b(?<args>("[^"]*"|''[^'']*''|[^;&|\r\n"''])*)'
$HeredocPattern = '<<-?\s*[''"]?(?<tag>\w+)[''"]?\r?\n(?<body>[\s\S]*?)\r?\n\s*\k<tag>\b'
$HereStringPattern = '@(?<quote>[''"])\r?\n(?<body>[\s\S]*?)\r?\n\k<quote>@'
$ForcePattern = '(^|\s)(--force(-with-lease|-if-includes)?\b|--mirror\b|-[a-zA-Z]*f[a-zA-Z]*(\s|$)|\+\S)'
$RemoteRemovalPattern = '(^|\s)(--delete\b|--prune\b|-[a-zA-Z]*d[a-zA-Z]*(\s|$)|:\S)'

$ForceReason = 'Force push: git push{0}. It can overwrite commits on the remote.'
$RemoteRemovalReason = 'Delete refs on the remote: git push{0}. Branches are normally deleted when their pull request completes, so a delete from here is unusual.'

function Main {
    param([string] $RawInput)

    $hookInput = $RawInput | ConvertFrom-Json
    $decision = Get-GateDecision -Command ([string] $hookInput.tool_input.command)
    if ($decision) {
        $answerable = Resolve-AnswerableDecision -Decision $decision -RawInput $RawInput
        Write-Decision @answerable
    }
}

function Get-GateDecision {
    param([string] $Command)

    $scanned = Remove-TextBlocks -Command $Command
    $pushArgs = @([regex]::Matches($scanned, $PushPattern) | ForEach-Object { $_.Groups['args'].Value -replace '["'']', '' })
    $forcePushes = @($pushArgs -match $ForcePattern)
    if ($forcePushes.Count -gt 0) {
        return @{ Decision = 'ask'; Reason = ($ForceReason -f $forcePushes[0].TrimEnd()) }
    }
    $removals = @($pushArgs -match $RemoteRemovalPattern)
    if ($removals.Count -gt 0) {
        return @{ Decision = 'ask'; Reason = ($RemoteRemovalReason -f $removals[0].TrimEnd()) }
    }
    return $null
}

function Remove-TextBlocks {
    param([string] $Command)

    $withoutHeredocs = [regex]::Replace($Command, $HeredocPattern, 'TEXT')
    return [regex]::Replace($withoutHeredocs, $HereStringPattern, "'TEXT'")
}

function Read-RawInput {
    [Console]::InputEncoding = New-Object Text.UTF8Encoding $false
    return [Console]::In.ReadToEnd()
}

function Write-Decision {
    param([string] $Decision, [string] $Reason)

    $output = @{
        hookSpecificOutput = @{
            hookEventName = 'PreToolUse'
            permissionDecision = $Decision
            permissionDecisionReason = $Reason
        }
    }
    [Console]::OutputEncoding = New-Object Text.UTF8Encoding $false
    [Console]::Out.Write(($output | ConvertTo-Json -Compress -Depth 3))
}

if ($MyInvocation.InvocationName -ne '.') {
    $rawInput = Read-RawInput
    try {
        $ErrorActionPreference = 'Stop'
        Main -RawInput $rawInput
    }
    catch {
        if ($rawInput -match '\bpush\b') {
            $failure = @{ Decision = 'ask'; Reason = "The push check failed ($($_.Exception.Message)). Read the command before you approve it." }
            $answerable = Resolve-AnswerableDecision -Decision $failure -RawInput $rawInput
            Write-Decision @answerable
        }
    }
    exit 0
}
