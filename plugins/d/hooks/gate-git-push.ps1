$PushPattern = '(^|[\s;&|(])git(\s+(-C\s+(?<repo>"[^"]+"|\S+)|-c\s+\S+|--[\w-]+(=\S+)?))*\s+push\b(?<args>("[^"]*"|''[^'']*''|[^;&|\r\n"''])*)'
$PullRequestPattern = '(^|[\s;&|(])(gh\s+pr\s+create|az\s+repos\s+pr\s+create)\b(?<args>("[^"]*"|''[^'']*''|[^;&|\r\n"''])*)'
$QuotedTextPattern = '"[^"]*"|''[^'']*'''
$CompoundPattern = '&&|[;|\r\n]'
$ForcePattern = '(^|\s)(--force(-with-lease)?\b|-[a-zA-Z]*f\b|\+\S)'

$CompoundReason = 'This command runs {0} together with other commands. Run it as a command of its own, with nothing before or after it, so that the user can read the approval prompt.'
$ForceReason = 'A force push is the user''s own action. Do not run it. Stop, and give the user the exact command to run with !.'
$PullRequestRecord = 'A pull request is a permanent record: on Azure DevOps it can only be abandoned, not deleted.'

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

    $push = [regex]::Match($Command, $PushPattern)
    $pullRequest = [regex]::Match($Command, $PullRequestPattern)
    if (-not $push.Success -and -not $pullRequest.Success) {
        return $null
    }

    $action = if ($push.Success) { 'git push' } else { 'the pull request command' }
    if (Test-CompoundCommand -Command $Command) {
        return @{ Decision = 'deny'; Reason = ($CompoundReason -f $action) }
    }

    if ($pullRequest.Success) {
        return @{ Decision = 'ask'; Reason = (Get-PullRequestSummary -PullRequestArgs $pullRequest.Groups['args'].Value) }
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
