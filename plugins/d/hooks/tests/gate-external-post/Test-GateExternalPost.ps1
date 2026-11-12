. "$PSScriptRoot/../../gate-external-post.ps1"

$longText = 'word ' * 100

$cases = @(
    @{ Name = 'read tool'; ToolName = 'mcp__github__get_pull_request_comments'; ToolInput = @{ pull_number = 7 }; Expected = $null }
    @{ Name = 'list tool'; ToolName = 'mcp__devops__list_pull_requests'; ToolInput = @{}; Expected = $null }
    @{ Name = 'comment with a body'; ToolName = 'mcp__github__add_issue_comment'; ToolInput = @{ issue_number = 7; body = "Looks good.`nShip it." }; Expected = 'This posts to an external system (github: add_issue_comment). It leaves a record others can see. Text: Looks good. Ship it.' }
    @{ Name = 'pull request create'; ToolName = 'mcp__devops__create_pull_request'; ToolInput = @{ title = 'Add export retry' }; Expected = $null }
    @{ Name = 'pull request update'; ToolName = 'mcp__devops__update_pull_request'; ToolInput = @{ title = 'Add export retry' }; Expected = $null }
    @{ Name = 'pull request merge'; ToolName = 'mcp__github__merge_pull_request'; ToolInput = @{ pull_number = 7 }; Expected = 'This posts to an external system (github: merge_pull_request). It leaves a record others can see.' }
    @{ Name = 'pull request review'; ToolName = 'mcp__github__create_pull_request_review'; ToolInput = @{ body = 'Fine.' }; Expected = 'This posts to an external system (github: create_pull_request_review). It leaves a record others can see. Text: Fine.' }
    @{ Name = 'post with no text field'; ToolName = 'mcp__devops__resolve_comment_thread'; ToolInput = @{ thread_id = 3 }; Expected = 'This posts to an external system (devops: resolve_comment_thread). It leaves a record others can see.' }
    @{ Name = 'long text is cut'; ToolName = 'mcp__github__add_issue_comment'; ToolInput = @{ body = $longText }; Expected = '...' }
    @{ Name = 'not an MCP tool name'; ToolName = 'Write'; ToolInput = @{}; Expected = $null }
)

$failures = 0
foreach ($case in $cases) {
    $actual = Get-GateDecision -ToolName $case.ToolName -ToolInput ([pscustomobject] $case.ToolInput)
    $passed = if ($null -eq $case.Expected) { $null -eq $actual } elseif ($case.Expected -eq '...') { $actual -and $actual.EndsWith('...') } else { $actual -eq $case.Expected }
    if ($passed) {
        Write-Output "PASS  $($case.Name)"
    }
    else {
        Write-Output "FAIL  $($case.Name) -> $actual"
        $failures++
    }
}
exit $failures
