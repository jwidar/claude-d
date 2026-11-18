Import-Module (Join-Path $PSScriptRoot 'AnswerableAsk.psm1') -Force

$CommitPattern = '(^|[\s;&|(])git(\s+(-C\s+(?<repo>"[^"]+"|\S+)|-c\s+\S+|--[\w-]+(=\S+)?))*\s+commit\b(?<args>[\s\S]*)'
$HeredocPattern = '<<-?\s*[''"]?(?<tag>\w+)[''"]?\r?\n(?<body>[\s\S]*?)\r?\n\s*\k<tag>\b'
$HereStringPattern = '@(?<quote>[''"])\r?\n(?<body>[\s\S]*?)\r?\n\k<quote>@'
$MessageOptionPattern = '(^|\s)(-[a-zA-Z]*m|--message)(\s+|=)("(?<text>[^"]*)"|''(?<text>[^'']*)'')'
$FileOptionPattern = '(^|\s)(-[a-zA-Z]*F|--file)(\s+|=)("(?<path>[^"]+)"|''(?<path>[^'']+)''|(?<path>[^\s;|&)]+))'
$VariableValuePattern = '(^|\s)(-[a-zA-Z]*[mF]|--message|--file)(\s+|=)["'']?\$(?!\()'
$NotCommandFormPattern = '^(?<word>[A-Za-z]+(ed|ing))\b'
$ImperativeWordsEndingLikePast = @('Embed', 'Need', 'Feed', 'Seed', 'Speed', 'Shed', 'Proceed', 'Exceed', 'Succeed', 'Heed', 'Weed', 'Shred',
    'Bring', 'String', 'Ring', 'Sing', 'Swing', 'Spring', 'Wing')
$ListLinePattern = '(?m)^\s*([-*]|\d+[.)])\s+\S'
$WorkItemPattern = '(?<![\w&])#\d+\b|\bAB#\d+\b'
$TrailerPattern = '^[\w-]+: '
$DefaultBranches = @('master', 'main')

$CommandFormRule = 'A commit subject reads as a command to the repo: what happens when the commit is applied ("Add ...", "Fix ...", "Change ..."), ' +
    'not "Added ..." or "Adding ...". It is a self-contained one-liner that a reader of git log --oneline understands without the diff. ' +
    'Describe the essence, not the details that the diff shows. Write it in ASD-STE100.'

$WorkItemRule = 'A commit message never refers to a work item with a # reference (#1234 or AB#1234), also when git log shows that pattern. ' +
    'Remove the reference.'

$LiteralValueRule = 'In a git commit command, write the -C path, the message, and the -F file path literally, not as a variable: the commit hooks read them from the command text.'

function Main {
    param([string] $RawInput)

    $hookInput = $RawInput | ConvertFrom-Json
    $decision = Get-CommitDecision -Command ([string] $hookInput.tool_input.command) -WorkingDirectory $hookInput.cwd
    if ($decision) {
        $answerable = Resolve-AnswerableDecision -Decision $decision -RawInput $RawInput
        Write-Decision @answerable
    }
}

function Read-RawInput {
    [Console]::InputEncoding = New-Object Text.UTF8Encoding $false
    return [Console]::In.ReadToEnd()
}

function Get-CommitDecision {
    param([string] $Command, [string] $WorkingDirectory)

    $commit = [regex]::Match($Command, $CommitPattern)
    if (-not $commit.Success) {
        return $null
    }
    $repo = $commit.Groups['repo'].Value.Trim('"')
    $commitArgs = $commit.Groups['args'].Value
    if ($repo.StartsWith('$') -or $commitArgs -match $VariableValuePattern) {
        return @{ Decision = 'deny'; Reason = $LiteralValueRule }
    }
    $directory = if (-not $repo) { $WorkingDirectory } elseif ([IO.Path]::IsPathRooted($repo)) { $repo } else { Join-Path $WorkingDirectory $repo }
    $message = Get-CommitMessage -CommitArgs $commitArgs -Directory $directory
    $subject = Get-Subject -Message $message

    if ($subject -and -not (Test-CommandForm -Subject $subject)) {
        return @{ Decision = 'deny'; Reason = "The commit subject '$subject' is not in command form. $CommandFormRule" }
    }

    if ($message -match $WorkItemPattern) {
        return @{ Decision = 'deny'; Reason = "The commit message has a work item reference. $WorkItemRule" }
    }

    $concerns = @(Get-Concerns -Message $message -CommitArgs $commitArgs -WorkingDirectory $directory)
    if ($concerns.Count -eq 0) {
        return $null
    }
    $subjectText = if ($subject) { "'$subject'" } else { 'with a message from a file or an editor' }
    return @{ Decision = 'ask'; Reason = "Commit $subjectText. $($concerns -join ' ')" }
}

function Get-CommitMessage {
    param([string] $CommitArgs, [string] $Directory)

    foreach ($pattern in @($HeredocPattern, $HereStringPattern)) {
        $block = [regex]::Match($CommitArgs, $pattern)
        if ($block.Success) {
            return $block.Groups['body'].Value
        }
    }
    $file = [regex]::Match($CommitArgs, $FileOptionPattern)
    if ($file.Success) {
        $path = $file.Groups['path'].Value
        $fullPath = if ([IO.Path]::IsPathRooted($path)) { $path } else { Join-Path $Directory $path }
        if (Test-Path -LiteralPath $fullPath -PathType Leaf) {
            return Get-Content -LiteralPath $fullPath -Raw
        }
        return ''
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
    $rawInput = Read-RawInput
    try {
        $ErrorActionPreference = 'Stop'
        Main -RawInput $rawInput
    }
    catch {
        if ($rawInput -match '\bcommit\b') {
            $failure = @{ Decision = 'ask'; Reason = "The commit message check failed ($($_.Exception.Message)). Read the message before you approve the commit." }
            $answerable = Resolve-AnswerableDecision -Decision $failure -RawInput $rawInput
            Write-Decision @answerable
        }
    }
    exit 0
}
