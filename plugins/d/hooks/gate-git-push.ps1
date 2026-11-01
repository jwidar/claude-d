$PushPattern = '(^|[\s;&|(])git(\s+(-C\s+(?<repo>"[^"]+"|\S+)|-c\s+\S+|--[\w-]+(=\S+)?))*\s+push\b(?<args>("[^"]*"|''[^'']*''|[^;&|\r\n"''])*)'
$PullRequestPattern = '(^|[\s;&|(])(gh\s+pr\s+create|az\s+repos\s+pr\s+create)\b(?<args>("[^"]*"|''[^'']*''|[^;&|\r\n"''])*)'
$QuotedTextPattern = '"[^"]*"|''[^'']*'''
$HeredocPattern = '<<-?\s*[''"]?(?<tag>\w+)[''"]?\r?\n(?<body>[\s\S]*?)\r?\n\s*\k<tag>\b'
$HereStringPattern = '@(?<quote>[''"])\r?\n(?<body>[\s\S]*?)\r?\n\k<quote>@'
$CompoundPattern = '&&|[;|\r\n]'
$ForcePattern = '(^|\s)(--force(-with-lease)?\b|-[a-zA-Z]*f\b|\+\S)'

$CompoundReason = 'This command runs {0} together with other commands. Run it as a command of its own, with nothing before or after it, so that the user can read the approval prompt.'
$ForceReason = 'A force push is the user''s own action. Do not run it. Stop, and give the user the exact command to run with !.'
$PullRequestRecord = 'A pull request is a permanent record: on Azure DevOps it can only be abandoned, not deleted.'
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
    $decision = Get-GateDecision -Command ([string] $hookInput.tool_input.command) -WorkingDirectory $hookInput.cwd
    if ($decision) {
        Write-Decision @decision
    }
}

function Get-GateDecision {
    param([string] $Command, [string] $WorkingDirectory)

    $scanned = Remove-TextBlocks -Command $Command
    $push = [regex]::Match($scanned, $PushPattern)
    $pullRequest = [regex]::Match($scanned, $PullRequestPattern)
    if (-not $push.Success -and -not $pullRequest.Success) {
        return $null
    }

    $action = if ($push.Success) { 'git push' } else { 'the pull request command' }
    if (Test-CompoundCommand -Command $scanned) {
        return @{ Decision = 'deny'; Reason = ($CompoundReason -f $action) }
    }

    if ($pullRequest.Success) {
        $pullRequestArgs = $pullRequest.Groups['args'].Value
        $problems = @(Get-DescriptionProblems -Command $Command -PullRequestArgs $pullRequestArgs -WorkingDirectory $WorkingDirectory)
        if ($problems.Count -gt 0) {
            return @{ Decision = 'deny'; Reason = "Rewrite the pull request: $($problems -join ' ')`n`n$DescriptionShape" }
        }
        return @{ Decision = 'ask'; Reason = (Get-PullRequestSummary -PullRequestArgs $pullRequestArgs) }
    }

    $pushArgs = $push.Groups['args'].Value
    if ($pushArgs -match $ForcePattern) {
        return @{ Decision = 'deny'; Reason = $ForceReason }
    }

    $repo = Get-RepoPath -Push $push -WorkingDirectory $WorkingDirectory
    if (Test-PushWithoutAsking -RepoPath $repo) {
        return $null
    }
    return @{ Decision = 'ask'; Reason = (Get-PushSummary -RepoPath $repo -PushArgs $pushArgs) }
}

function Remove-TextBlocks {
    param([string] $Command)

    $withoutHeredocs = [regex]::Replace($Command, $HeredocPattern, 'TEXT')
    return [regex]::Replace($withoutHeredocs, $HereStringPattern, "'TEXT'")
}

function Get-DescriptionProblems {
    param([string] $Command, [string] $PullRequestArgs, [string] $WorkingDirectory)

    $title = Get-OptionValue -Arguments $PullRequestArgs -Names @('--title', '-t')
    if ($title -match '(^|\s)#\d+\b') {
        'The title has a #1234 work item reference.'
    }

    $body = Get-PullRequestBody -Command $Command -PullRequestArgs $PullRequestArgs -WorkingDirectory $WorkingDirectory
    if (-not $body) {
        'It has no description. Pass one with --body (gh) or --description (az).'
        return
    }
    if ($body -match '(?m)^#+\s*Summary\b') {
        'The description has a "Summary" header.'
    }
    if ($body -match '(?mi)^#+\s*Test plan\b') {
        'The description has a "Test plan" section.'
    }
    if ($body -notmatch '(?m)^#+\s*(Manually tested|Checked by Claude)\b') {
        'The description does not say what was checked under "Manually tested" or "Checked by Claude".'
    }
    $lastLine = @($body -split '\r?\n' | Where-Object { $_.Trim() } | Select-Object -Last 1) -join ''
    if ($lastLine.Trim() -ne '/claude code') {
        'The description does not end with /claude code on its own line.'
    }
}

function Get-PullRequestBody {
    param([string] $Command, [string] $PullRequestArgs, [string] $WorkingDirectory)

    foreach ($pattern in @($HeredocPattern, $HereStringPattern)) {
        $block = [regex]::Match($Command, $pattern)
        if ($block.Success) {
            return $block.Groups['body'].Value
        }
    }
    $inline = Get-OptionValue -Arguments $PullRequestArgs -Names @('--body', '-b', '--description', '-d')
    if ($inline) {
        return $inline
    }
    $file = Get-OptionValue -Arguments $PullRequestArgs -Names @('--body-file', '-F')
    if ($file) {
        $path = if ([IO.Path]::IsPathRooted($file)) { $file } else { Join-Path $WorkingDirectory $file }
        if (Test-Path -LiteralPath $path) {
            return Get-Content -LiteralPath $path -Raw
        }
    }
    return $null
}

function Test-CompoundCommand {
    param([string] $Command)

    $unquoted = [regex]::Replace($Command.Trim(), $QuotedTextPattern, '')
    return $unquoted -match $CompoundPattern
}

function Get-RepoPath {
    param($Push, [string] $WorkingDirectory)

    $explicit = $Push.Groups['repo'].Value.Trim('"')
    if (-not $explicit) {
        return $WorkingDirectory
    }
    if ([IO.Path]::IsPathRooted($explicit)) {
        return $explicit
    }
    return Join-Path $WorkingDirectory $explicit
}

function Test-PushWithoutAsking {
    param([string] $RepoPath)

    $settingsPath = Join-Path $RepoPath '.claude/settings.local.json'
    if (-not (Test-Path -LiteralPath $settingsPath)) {
        return $false
    }
    $settings = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
    return $settings.env.D_PUSH_WITHOUT_ASKING -eq '1'
}

function Get-PushSummary {
    param([string] $RepoPath, [string] $PushArgs)

    $target = Get-PushTarget -RepoPath $RepoPath -PushArgs $PushArgs
    if (-not $target.RemoteBranch) {
        return "Push '$($target.Local)': it has no upstream branch and no remote was named, so git may refuse the push."
    }

    git -C $RepoPath rev-parse --verify --quiet "refs/remotes/$($target.Remote)/$($target.RemoteBranch)" | Out-Null
    if ($LASTEXITCODE -ne 0) {
        $count = git -C $RepoPath rev-list --count $target.Local --not --remotes
        return "Push '$($target.Local)' to $($target.Remote) as a new branch '$($target.RemoteBranch)': $count commit(s) not on any remote yet."
    }

    $count = git -C $RepoPath rev-list --count "$($target.Remote)/$($target.RemoteBranch)..$($target.Local)"
    if ($count -eq '0') {
        return "Nothing new to push: '$($target.Local)' has no commits that $($target.Remote)/$($target.RemoteBranch) lacks."
    }
    return "Push '$($target.Local)' to $($target.Remote)/$($target.RemoteBranch): $count new commit(s)."
}

function Get-PushTarget {
    param([string] $RepoPath, [string] $PushArgs)

    $positional = @($PushArgs.Trim() -split '\s+' | Where-Object { $_ -and -not $_.StartsWith('-') })
    $current = git -C $RepoPath branch --show-current
    if (-not $current) {
        $current = 'HEAD'
    }

    if ($positional.Count -ge 2) {
        $refspec = $positional[1] -split ':', 2
        $remoteBranch = if ($refspec.Count -eq 2) { $refspec[1] } else { $refspec[0] }
        return @{ Local = $refspec[0]; Remote = $positional[0]; RemoteBranch = $remoteBranch }
    }

    $upstream = git -C $RepoPath for-each-ref --format='%(upstream:short)' "refs/heads/$current"
    if ($upstream) {
        $remote, $remoteBranch = $upstream -split '/', 2
        if ($positional.Count -eq 0 -or $positional[0] -eq $remote) {
            return @{ Local = $current; Remote = $remote; RemoteBranch = $remoteBranch }
        }
    }

    if ($positional.Count -eq 1) {
        return @{ Local = $current; Remote = $positional[0]; RemoteBranch = $current }
    }
    return @{ Local = $current; Remote = $null; RemoteBranch = $null }
}

function Get-PullRequestSummary {
    param([string] $PullRequestArgs)

    $title = Get-OptionValue -Arguments $PullRequestArgs -Names @('--title', '-t')
    $source = Get-OptionValue -Arguments $PullRequestArgs -Names @('--head', '-H', '--source-branch')
    $target = Get-OptionValue -Arguments $PullRequestArgs -Names @('--base', '-B', '--target-branch')

    $titleText = if ($title) { "'$title'" } else { 'with no title on the command line' }
    $sourceText = if ($source) { "'$source'" } else { 'the current branch' }
    $targetText = if ($target) { "'$target'" } else { 'the default branch' }
    return "Open a pull request $titleText from $sourceText into $targetText. $PullRequestRecord"
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
        if ($rawInput -match '\bpush\b|\bpr\s+create\b') {
            Write-Decision -Decision 'ask' -Reason "The push check failed ($($_.Exception.Message)). Read the command before you approve it."
        }
    }
    exit 0
}
