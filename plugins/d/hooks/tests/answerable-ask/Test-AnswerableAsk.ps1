Import-Module (Join-Path $PSScriptRoot '..\..\AnswerableAsk.psm1') -Force

$handBack = 'You run as a subagent, where nobody can answer a permission prompt.'
$hooks = Join-Path $PSScriptRoot '..\..'

$ask = @{ Decision = 'ask'; Reason = 'Push x.' }
$deny = @{ Decision = 'deny'; Reason = 'Do not force push.' }
$mainInput = '{"session_id":"s","tool_input":{"command":"git push"}}'
$subagentInput = '{"session_id":"s","agent_id":"a1","tool_input":{"command":"git push"}}'
$nestedAgentIdInput = '{"session_id":"s","tool_input":{"agent_id":"a1","content":"Hi"}}'
$brokenSubagentInput = '{"agent_id":"a1","tool_input":{"command":"git push'
$brokenMainInput = '{"tool_input":{"command":"git push'

$pullRequestBody = "Some text.`n`n## Checked by Claude`n- One case: works.`n`n/claude code"
$pullRequestCommand = "gh pr create --title `"Add export retry`" --body `"$pullRequestBody`""
$commitWithList = "git commit -m `"Add export retry`n`n- one`n- two`""

function New-HookInput {
    param([hashtable] $ToolInput, [string] $ToolName = 'Bash', [switch] $Subagent)

    $hookInput = @{ session_id = 's'; cwd = $PSScriptRoot; tool_name = $ToolName; tool_input = $ToolInput }
    if ($Subagent) {
        $hookInput.agent_id = 'a1'
    }
    return $hookInput | ConvertTo-Json -Compress -Depth 4
}

function Invoke-Hook {
    param([string] $Script, [string] $RawInput)

    $stdinFile = [IO.Path]::GetTempFileName()
    try {
        [IO.File]::WriteAllText($stdinFile, $RawInput, (New-Object Text.UTF8Encoding $false))
        $output = cmd /c "powershell -NoProfile -File `"$hooks\$Script`" < `"$stdinFile`""
        if (-not $output) {
            return @{ Decision = $null; Reason = $null }
        }
        $decision = ($output | ConvertFrom-Json).hookSpecificOutput
        return @{ Decision = $decision.permissionDecision; Reason = $decision.permissionDecisionReason }
    }
    finally {
        Remove-Item $stdinFile
    }
}

$cases = @(
    @{ Name = 'main session ask stays ask'; Actual = { Resolve-AnswerableDecision -Decision $ask -RawInput $mainInput }; Decision = 'ask'; Reason = 'Push x.' }
    @{ Name = 'subagent ask becomes deny'; Actual = { Resolve-AnswerableDecision -Decision $ask -RawInput $subagentInput }; Decision = 'deny'; Reason = 'Push x.'; HandBack = $true }
    @{ Name = 'subagent deny stays deny'; Actual = { Resolve-AnswerableDecision -Decision $deny -RawInput $subagentInput }; Decision = 'deny'; Reason = 'Do not force push.' }
    @{ Name = 'agent_id inside tool_input is the main session'; Actual = { Resolve-AnswerableDecision -Decision $ask -RawInput $nestedAgentIdInput }; Decision = 'ask'; Reason = 'Push x.' }
    @{ Name = 'unparsed subagent input becomes deny'; Actual = { Resolve-AnswerableDecision -Decision $ask -RawInput $brokenSubagentInput }; Decision = 'deny'; Reason = 'Push x.'; HandBack = $true }
    @{ Name = 'unparsed main input stays ask'; Actual = { Resolve-AnswerableDecision -Decision $ask -RawInput $brokenMainInput }; Decision = 'ask'; Reason = 'Push x.' }

    @{ Name = 'push gate, main session'; Actual = { Invoke-Hook 'gate-git-push.ps1' (New-HookInput @{ command = $pullRequestCommand }) }; Decision = 'ask'; Reason = 'Open a pull request' }
    @{ Name = 'push gate, subagent'; Actual = { Invoke-Hook 'gate-git-push.ps1' (New-HookInput @{ command = $pullRequestCommand } -Subagent) }; Decision = 'deny'; Reason = 'Open a pull request'; HandBack = $true }
    @{ Name = 'push gate failure, main session'; Actual = { Invoke-Hook 'gate-git-push.ps1' $brokenMainInput }; Decision = 'ask'; Reason = 'The push check failed' }
    @{ Name = 'push gate failure, subagent'; Actual = { Invoke-Hook 'gate-git-push.ps1' $brokenSubagentInput }; Decision = 'deny'; Reason = 'The push check failed'; HandBack = $true }

    @{ Name = 'commit check, main session'; Actual = { Invoke-Hook 'check-commit-message.ps1' (New-HookInput @{ command = $commitWithList }) }; Decision = 'ask'; Reason = "Commit 'Add export retry'" }
    @{ Name = 'commit check, subagent'; Actual = { Invoke-Hook 'check-commit-message.ps1' (New-HookInput @{ command = $commitWithList } -Subagent) }; Decision = 'deny'; Reason = "Commit 'Add export retry'"; HandBack = $true }

    @{ Name = 'post gate, main session'; Actual = { Invoke-Hook 'gate-external-post.ps1' (New-HookInput @{ content = 'Hi' } -ToolName 'mcp__devops__add_pr_comment') }; Decision = 'ask'; Reason = 'This posts to an external system' }
    @{ Name = 'post gate, subagent'; Actual = { Invoke-Hook 'gate-external-post.ps1' (New-HookInput @{ content = 'Hi' } -ToolName 'mcp__devops__add_pr_comment' -Subagent) }; Decision = 'deny'; Reason = 'This posts to an external system'; HandBack = $true }
    @{ Name = 'post gate failure, main session'; Actual = { Invoke-Hook 'gate-external-post.ps1' $brokenMainInput }; Decision = 'ask'; Reason = 'This tool may post' }
    @{ Name = 'post gate failure, subagent'; Actual = { Invoke-Hook 'gate-external-post.ps1' $brokenSubagentInput }; Decision = 'deny'; Reason = 'This tool may post'; HandBack = $true }
)

$failures = 0
foreach ($case in $cases) {
    $actual = & $case.Actual
    $handBackMatches = [bool] $case.HandBack -eq ([string] $actual.Reason).Contains("`n`n$handBack")
    $passed = $actual.Decision -eq $case.Decision -and ([string] $actual.Reason).StartsWith($case.Reason) -and $handBackMatches
    if ($passed) {
        Write-Output "PASS  $($case.Name)"
    }
    else {
        Write-Output "FAIL  $($case.Name) -> $($actual.Decision): $($actual.Reason)"
        $failures++
    }
}
exit $failures
