$CliPullRequestPattern = '(^|[\s;&|("''])(?<tool>gh\s+pr|az\s+repos\s+pr)\s+(?<verb>create|edit|update)\b(?<args>("[^"]*"|''[^'']*''|[^;&|\r\n"''])*)'
$McpPullRequestToolPattern = '^mcp__.+__(?<verb>create|update)_pull_request$'
$HeredocPattern = '<<-?\s*[''"]?(?<tag>\w+)[''"]?\r?\n(?<body>[\s\S]*?)\r?\n\s*\k<tag>\b'
$HereStringPattern = '@(?<quote>[''"])\r?\n(?<body>[\s\S]*?)\r?\n\k<quote>@'
$TextBlockToken = 'TEXTBLOCK{0}'
$TextBlockTokenPattern = 'TEXTBLOCK(?<index>\d+)'
$DescriptionShape = @'
A PR description is written for non-developers who want to grasp at a high level what was done. Write it in ASD-STE100.
Start with the summary text, with no "Summary" header (Azure DevOps already shows a "Description" label). In one or two short paragraphs, say what situation existed, what changes for the user, and why. No code details there, and nothing the commits or the diff already say.
Then say what was checked and who ran it, one line per case with what it showed. Head the section "Manually tested" only when a person ran the cases, otherwise "Checked by Claude". A read of the code is not a test; mark it "not tested". No generic "Test plan" checklist.
End with /claude code on its own line. No #1234 work item reference in the title. The shape (made up):

    Some customers still open report links created by the old export service. Until now, such a link showed our own "temporarily unavailable" error. Now we hand an unknown link to the old service and show what it returns, so links from both systems keep working during the rollout.

    ## Checked by Claude
    - Our own report link: works as before.
    - A link only the old service knows: shows the old service's report page.

    /claude code
'@

function Main {
    param([string] $RawInput)

    $hookInput = $RawInput | ConvertFrom-Json
    $problems = @(Get-TextProblemsOfCall -ToolName $hookInput.tool_name -ToolInput $hookInput.tool_input -WorkingDirectory $hookInput.cwd)
    if ($problems.Count -gt 0) {
        Write-Deny -Reason "Rewrite the pull request: $($problems -join ' ')`n`n$DescriptionShape"
    }
}

function Get-TextProblemsOfCall {
    param([string] $ToolName, $ToolInput, [string] $WorkingDirectory)

    $pullRequests = if ($ToolName -match $McpPullRequestToolPattern) {
        Read-McpPullRequest -ToolInput $ToolInput -IsNew ($Matches.verb -eq 'create')
    }
    else {
        Read-CliPullRequests -Command ([string] $ToolInput.command) -WorkingDirectory $WorkingDirectory
    }
    foreach ($pullRequest in @($pullRequests)) {
        Get-TextProblems @pullRequest
    }
}

function Read-McpPullRequest {
    param($ToolInput, [bool] $IsNew)

    $description = if ($null -ne $ToolInput.description) { $ToolInput.description } else { $ToolInput.body }
    return @{ Title = [string] $ToolInput.title; Description = $description; IsNew = $IsNew }
}

function Read-CliPullRequests {
    param([string] $Command, [string] $WorkingDirectory)

    $split = Split-TextBlocks -Command $Command
    foreach ($match in [regex]::Matches($split.Command, $CliPullRequestPattern)) {
        $arguments = $match.Groups['args'].Value
        $descriptionOptions = if ($match.Groups['tool'].Value.StartsWith('gh')) { @('--body', '-b') } else { @('--description', '-d') }
        @{
            Title = Get-OptionValue -Arguments $arguments -Names @('--title', '-t')
            Description = Get-CliDescription -Arguments $arguments -DescriptionOptions $descriptionOptions -Bodies $split.Bodies -WorkingDirectory $WorkingDirectory
            IsNew = $match.Groups['verb'].Value -eq 'create'
        }
    }
}

function Split-TextBlocks {
    param([string] $Command)

    $bodies = [Collections.Generic.List[string]]::new()
    $scanned = $Command
    foreach ($pattern in @($HeredocPattern, $HereStringPattern)) {
        $scanned = [regex]::Replace($scanned, $pattern, {
                param($block)
                $bodies.Add($block.Groups['body'].Value)
                "'" + ($TextBlockToken -f ($bodies.Count - 1)) + "'"
            })
    }
    return @{ Command = $scanned; Bodies = $bodies }
}

function Get-CliDescription {
    param([string] $Arguments, [string[]] $DescriptionOptions, $Bodies, [string] $WorkingDirectory)

    $inline = Get-OptionValue -Arguments $Arguments -Names $DescriptionOptions
    if ($null -ne $inline) {
        return Resolve-TextBlock -Text $inline -Bodies $Bodies
    }
    $file = Get-OptionValue -Arguments $Arguments -Names @('--body-file', '-F')
    if ($file -and $file -ne '-') {
        $path = if ([IO.Path]::IsPathRooted($file)) { $file } else { Join-Path $WorkingDirectory $file }
        if (Test-Path -LiteralPath $path) {
            return Get-Content -LiteralPath $path -Raw
        }
    }
    if ($Arguments -match $TextBlockTokenPattern) {
        return $Bodies[[int] $Matches.index]
    }
    return $null
}

function Resolve-TextBlock {
    param([string] $Text, $Bodies)

    if ($Text -match $TextBlockTokenPattern) {
        return $Bodies[[int] $Matches.index]
    }
    return $Text
}

function Get-OptionValue {
    param([string] $Arguments, [string[]] $Names)

    $namePattern = ($Names | ForEach-Object { [regex]::Escape($_) }) -join '|'
    $match = [regex]::Match($Arguments, "(^|\s)($namePattern)(\s+|=)(""(?<value>[^""]*)""|'(?<value>[^']*)'|(?<value>\S+))", 'None')
    if (-not $match.Success) {
        return $null
    }
    return $match.Groups['value'].Value
}

function Get-TextProblems {
    param([string] $Title, [string] $Description, [bool] $IsNew)

    if ($Title -match '(^|\s)#\d+\b') {
        'The title has a #1234 work item reference.'
    }
    if (-not $Description) {
        if ($IsNew) {
            'It has no description.'
        }
        return
    }
    if ($Description -match '(?m)^#+\s*Summary\b') {
        'The description has a "Summary" header.'
    }
    if ($Description -match '(?mi)^#+\s*Test plan\b') {
        'The description has a "Test plan" section.'
    }
    if ($Description -notmatch '(?m)^#+\s*(Manually tested|Checked by Claude)\b') {
        'The description does not say what was checked under "Manually tested" or "Checked by Claude".'
    }
    $lastLine = @($Description -split '\r?\n' | Where-Object { $_.Trim() } | Select-Object -Last 1) -join ''
    if ($lastLine.Trim() -ne '/claude code') {
        'The description does not end with /claude code on its own line.'
    }
}

function Read-RawInput {
    [Console]::InputEncoding = New-Object Text.UTF8Encoding $false
    return [Console]::In.ReadToEnd()
}

function Write-Deny {
    param([string] $Reason)

    Write-HookOutput @{
        hookSpecificOutput = @{
            hookEventName = 'PreToolUse'
            permissionDecision = 'deny'
            permissionDecisionReason = $Reason
        }
    }
}

function Write-HookOutput {
    param([hashtable] $Output)

    [Console]::OutputEncoding = New-Object Text.UTF8Encoding $false
    [Console]::Out.Write(($Output | ConvertTo-Json -Compress -Depth 3))
}

if ($MyInvocation.InvocationName -ne '.') {
    try {
        $ErrorActionPreference = 'Stop'
        Main -RawInput (Read-RawInput)
    }
    catch {
        Write-HookOutput @{ systemMessage = "The pull request text check failed ($($_.Exception.Message)). The pull request goes out unchecked." }
    }
    exit 0
}
