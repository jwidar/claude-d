$ReadVerbPattern = '^(get|list|search|read|fetch|query|find)'
$TextFieldNames = @('body', 'comment', 'content', 'text', 'message', 'description', 'title')
$MaxTextLength = 300

function Main {
    $hookInput = Read-HookInput
    $decision = Get-GateDecision -ToolName $hookInput.tool_name -ToolInput $hookInput.tool_input
    if ($decision) {
        Write-Ask -Reason $decision
    }
}

function Read-HookInput {
    [Console]::InputEncoding = New-Object Text.UTF8Encoding $false
    return [Console]::In.ReadToEnd() | ConvertFrom-Json
}

function Get-GateDecision {
    param(
        [string] $ToolName
        , $ToolInput
    )

    $parts = $ToolName -split '__'
    if ($parts.Count -lt 3) {
        return $null
    }
    $server = $parts[1]
    $tool = $parts[2..($parts.Count - 1)] -join '__'
    if ($tool -match $ReadVerbPattern) {
        return $null
    }

    $summary = "This posts to an external system ($server`: $tool). It leaves a record others can see."
    $text = Get-PostedText -ToolInput $ToolInput
    if ($text) {
        $summary += " Text: $text"
    }
    return $summary
}

function Get-PostedText {
    param($ToolInput)

    if ($null -eq $ToolInput) {
        return $null
    }
    foreach ($name in $TextFieldNames) {
        $value = $ToolInput.$name
        if ($value -is [string] -and $value) {
            return Limit-Text -Text $value
        }
    }
    return $null
}

function Limit-Text {
    param([string] $Text)

    $singleLine = ($Text -replace '\s+', ' ').Trim()
    if ($singleLine.Length -le $MaxTextLength) {
        return $singleLine
    }
    return $singleLine.Substring(0, $MaxTextLength) + '...'
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
        # A tool that matched the hook may post. Ask rather than let it through.
        Write-Ask -Reason 'This tool may post to an external system. Check it before you approve.'
    }
    exit 0
}
