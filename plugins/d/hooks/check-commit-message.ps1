$CommitPattern = '(^|[\s;&|(])git(\s+(-C\s+(?<repo>"[^"]+"|\S+)|-c\s+\S+|--[\w-]+(=\S+)?))*\s+commit\b(?<args>[\s\S]*)'
$HeredocPattern = '<<-?\s*[''"]?(?<tag>\w+)[''"]?\r?\n(?<body>[\s\S]*?)\r?\n\s*\k<tag>\b'
$HereStringPattern = '@(?<quote>[''"])\r?\n(?<body>[\s\S]*?)\r?\n\k<quote>@'
$MessageOptionPattern = '(^|\s)(-m|--message)(\s+|=)("(?<text>[^"]*)"|''(?<text>[^'']*)'')'
$NotCommandFormPattern = '^(?<word>[A-Za-z]+(ed|ing))\b'
$ImperativeWordsEndingLikePast = @('Embed', 'Need', 'Feed', 'Seed', 'Speed', 'Shed', 'Proceed', 'Exceed', 'Succeed', 'Heed', 'Weed', 'Shred',
    'Bring', 'String', 'Ring', 'Sing', 'Swing', 'Spring', 'Wing')
$ListLinePattern = '(?m)^\s*([-*]|\d+[.)])\s+\S'
$WorkItemPattern = '(^|\s)#\d+\b'
$TrailerPattern = '^[\w-]+: '
$DefaultBranches = @('master', 'main')

$CommandFormRule = 'A commit subject reads as a command to the repo: what happens when the commit is applied ("Add ...", "Fix ...", "Change ..."), ' +
    'not "Added ..." or "Adding ...". It is a self-contained one-liner that a reader of git log --oneline understands without the diff. ' +
    'Describe the essence, not the details that the diff shows. Write it in ASD-STE100.'

function Main {
    $hookInput = Read-HookInput
    $decision = Get-CommitDecision -Command ([string] $hookInput.tool_input.command) -WorkingDirectory $hookInput.cwd
    if ($decision) {
        Write-Decision @decision
    }
}

function Read-HookInput {
    [Console]::InputEncoding = New-Object Text.UTF8Encoding $false
    return [Console]::In.ReadToEnd() | ConvertFrom-Json
}

function Get-CommitDecision {
    param([string] $Command, [string] $WorkingDirectory)

    $commit = [regex]::Match($Command, $CommitPattern)
    if (-not $commit.Success) {
        return $null
    }
    $commitArgs = $commit.Groups['args'].Value
    $message = Get-CommitMessage -CommitArgs $commitArgs
    $subject = Get-Subject -Message $message

    if ($subject -and -not (Test-CommandForm -Subject $subject)) {
        return @{ Decision = 'deny'; Reason = "The commit subject '$subject' is not in command form. $CommandFormRule" }
    }

    $concerns = @(Get-Concerns -Message $message -CommitArgs $commitArgs -WorkingDirectory $WorkingDirectory)
    if ($concerns.Count -eq 0) {
        return $null
    }
    $subjectText = if ($subject) { "'$subject'" } else { 'with a message from a file or an editor' }
    return @{ Decision = 'ask'; Reason = "Commit $subjectText. $($concerns -join ' ')" }
}

function Get-CommitMessage {
    param([string] $CommitArgs)

    foreach ($pattern in @($HeredocPattern, $HereStringPattern)) {
        $block = [regex]::Match($CommitArgs, $pattern)
        if ($block.Success) {
            return $block.Groups['body'].Value
        }
    }
    $parts = @([regex]::Matches($CommitArgs, $MessageOptionPattern) | ForEach-Object { $_.Groups['text'].Value })
    return $parts -join "`n`n"
}

function Get-Subject {
    param([string] $Message)

    return @($Message -split '\r?\n' | Where-Object { $_.Trim() } | Select-Object -First 1) -join '' | ForEach-Object { $_.Trim() }
}

function Test-CommandForm {
    param([string] $Subject)

    $first = [regex]::Match($Subject, $NotCommandFormPattern)
    if (-not $first.Success) {
        return $true
    }
    return $ImperativeWordsEndingLikePast -contains $first.Groups['word'].Value
}

function Get-Concerns {
    param([string] $Message, [string] $CommitArgs, [string] $WorkingDirectory)

    $body = @($Message -split '\r?\n' | Where-Object { $_ -notmatch $TrailerPattern }) -join "`n"
    if ($body -match $ListLinePattern) {
        'The message has a list. A list fits only when the user allowed it for this session.'
    }
    if ($Message -match $WorkItemPattern) {
        'The message refers to a work item with #. Approve only if you agreed to that reference.'
    }
    if ($CommitArgs -match '(^|\s)--amend\b') {
        $branch = git -C $WorkingDirectory branch --show-current
        if ($DefaultBranches -contains $branch) {
            "This amends a commit on $branch. Approve only if you asked for the amend."
        }
    }
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
    try {
        $ErrorActionPreference = 'Stop'
        Main
    }
    catch {
        # A failure here must never block the commit.
    }
    exit 0
}
