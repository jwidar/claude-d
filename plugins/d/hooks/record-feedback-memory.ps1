$FeedbackTypePattern = '(?m)^\s*type:\s*feedback\s*$'
$DescriptionPattern = '(?m)^description:\s*(.+?)\s*$'
$EmDash = [char] 0x2014

function Main {
    $hookInput = Read-HookInput
    $result = Add-FeedbackEntry -ToolInput $hookInput.tool_input `
        -Project (Split-Path -Leaf ([string] $hookInput.cwd)) `
        -BacklogPath (Join-Path $env:USERPROFILE '.claude\feedback-backlog.md') `
        -Date (Get-Date -Format 'yyyy-MM-dd')
    if ($result) {
        Write-Context -Text $result
    }
}

function Read-HookInput {
    [Console]::InputEncoding = New-Object Text.UTF8Encoding $false
    return [Console]::In.ReadToEnd() | ConvertFrom-Json
}

function Add-FeedbackEntry {
    param(
        $ToolInput
        , [string] $Project
        , [string] $BacklogPath
        , [string] $Date
    )

    $guidance = Get-FeedbackGuidance -ToolInput $ToolInput
    if (-not $guidance) {
        return $null
    }

    $existing = if (Test-Path -LiteralPath $BacklogPath) { [IO.File]::ReadAllText($BacklogPath) } else { '' }
    if ($existing.Contains($guidance)) {
        return $null
    }

    $entry = "- [ ] $Date ($Project) $EmDash $guidance"
    $id = New-EntryId -Entry $entry -ExistingText $existing
    $separator = if ($existing -and -not $existing.EndsWith("`n")) { "`r`n" } else { '' }
    [IO.File]::AppendAllText($BacklogPath, "$separator$id $entry`r`n", (New-Object Text.UTF8Encoding $false))

    return "This feedback memory is now entry $id in $BacklogPath. " +
        'If its description does not say the guidance in one line, edit the entry text. Never change the ID.'
}

function Get-FeedbackGuidance {
    param($ToolInput)

    $path = [string] $ToolInput.file_path
    if ((Split-Path -Leaf (Split-Path -Parent $path)) -ne 'memory' -or (Split-Path -Leaf $path) -eq 'MEMORY.md') {
        return $null
    }
    $content = [string] $ToolInput.content
    if ($content -notmatch $FeedbackTypePattern -or $content -notmatch $DescriptionPattern) {
        return $null
    }
    return $Matches[1].Trim('"', "'")
}

function New-EntryId {
    param(
        [string] $Entry
        , [string] $ExistingText
    )

    $sha1 = [Security.Cryptography.SHA1]::Create()
    $hash = -join ($sha1.ComputeHash([Text.Encoding]::UTF8.GetBytes($Entry)) | ForEach-Object { $_.ToString('x2') })
    for ($start = 0; $start -le $hash.Length - 3; $start += 3) {
        $id = 'F' + $hash.Substring($start, 3)
        if ($ExistingText -notmatch "(?m)^$id ") {
            return $id
        }
    }
    throw 'No free entry ID in the hash.'
}

function Write-Context {
    param([string] $Text)

    $output = @{
        hookSpecificOutput = @{
            hookEventName = 'PostToolUse'
            additionalContext = $Text
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
        # A failure here must never block the memory write.
    }
    exit 0
}
